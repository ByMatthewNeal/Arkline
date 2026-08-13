import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * compute-metals-portfolio Edge Function
 *
 * Systematic metals model portfolio (asset_class='metal', strategy='metals').
 * Fully self-driving like the crypto books. Each trading day it:
 *   1. Fits gold's long-term log-regression channel (trailing ~2y of daily
 *      closes) and classifies the current zone: Deep Value ... Overextended.
 *      (Same math as the app's LogRegressionService.)
 *   2. Maps the zone to a target gold weight (cheap = more gold, extended =
 *      less), nudged by an RSI-14 guardrail, clamped to a band.
 *   3. Holds the remainder in cash (~4% APY), rebalancing only when the target
 *      changes — so it self-runs but doesn't churn.
 *   4. Tracks weighted-average (blended) cost basis for the gold lot.
 *
 * Body: {}  (daily) | { "backfill": true, "from": "YYYY-MM-DD" }
 */

const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? ""
const CASH_APY = 0.04
const DAILY_CASH_RATE = Math.pow(1 + CASH_APY, 1 / 365) - 1
const WINDOW = 504 // ~2 trading years for the channel fit
const DEFAULT_FROM = "2019-01-01"
const GOLD_MIN = 0.40 // gold is a permanent multi-year core — never trimmed below this
const GOLD_MAX = 0.60
const MIN_HOLD_DAYS = 21 // don't rebalance again within ~3 weeks (hedge, not trader)

// Gold is always held as a multi-year core; the zone only decides how much
// extra to hold above the floor (cheap = lean heavier, extended = lean lighter).
const ZONE_WEIGHT: Record<string, number> = {
  deepValue: 0.60,
  value: 0.55,
  fair: 0.50,
  elevated: 0.45,
  overextended: 0.40,
}

interface Candle { date: string; close: number }

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })
}

async function fetchFMPDaily(symbol: string, key: string): Promise<Candle[]> {
  const url = `https://financialmodelingprep.com/stable/historical-price-eod/full?symbol=${encodeURIComponent(symbol)}&apikey=${key}`
  const r = await fetch(url)
  if (!r.ok) throw new Error(`FMP ${symbol} ${r.status}`)
  const j = await r.json()
  const raw: Array<{ date: string; close: number }> = Array.isArray(j) ? j : (j.historical ?? [])
  return raw
    .filter((x) => x.date && x.close > 0)
    .map((x) => ({ date: x.date, close: x.close }))
    .sort((a, b) => (a.date < b.date ? -1 : 1))
}

// Log-regression channel zone for the LAST close in `closes`. Natural log,
// index-based x, population sigma, +-1 / +-2 sigma bands. Mirrors the Swift
// LogRegressionService.classifyZone.
const ZONES = ["deepValue", "value", "fair", "elevated", "overextended"]
const BOUNDS = [-2, -1, 1, 2] // sigma boundary between ZONES[i] and ZONES[i+1]

// Position of the latest close in sigmas above/below the fitted trend line.
function channelZ(closes: number[]): number | null {
  const n = closes.length
  if (n < 20) return null
  const logs = closes.map((c) => Math.log(c))
  let sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0
  for (let i = 0; i < n; i++) { sumX += i; sumY += logs[i]; sumXY += i * logs[i]; sumX2 += i * i }
  const denom = n * sumX2 - sumX * sumX
  if (denom === 0) return null
  const slope = (n * sumXY - sumX * sumY) / denom
  const intercept = (sumY - slope * sumX) / n
  let ssr = 0
  for (let i = 0; i < n; i++) { const r = logs[i] - (slope * i + intercept); ssr += r * r }
  const sigma = Math.sqrt(ssr / n)
  if (sigma <= 0) return null
  const lastF = slope * (n - 1) + intercept
  return (logs[n - 1] - lastF) / sigma
}

// Zone from sigma position, with hysteresis so price hovering at a band edge
// doesn't flip the zone (which would churn trades). Raw classification when
// there's no current zone (inception).
function zoneFromZ(z: number, currentZone: string | null): string {
  const m = 0.2
  let idx = currentZone ? ZONES.indexOf(currentZone) : -1
  if (idx < 0) {
    idx = 0
    for (const b of BOUNDS) if (z > b) idx++
    return ZONES[idx]
  }
  while (idx < 4 && z > BOUNDS[idx] + m) idx++
  while (idx > 0 && z < BOUNDS[idx - 1] - m) idx--
  return ZONES[idx]
}

// Wilder's RSI at the last close of `closes`.
function rsiLast(closes: number[], period = 14): number | null {
  if (closes.length < period + 1) return null
  let gains = 0, losses = 0
  for (let i = 1; i <= period; i++) { const ch = closes[i] - closes[i - 1]; if (ch > 0) gains += ch; else losses += -ch }
  let avgG = gains / period, avgL = losses / period
  for (let i = period + 1; i < closes.length; i++) {
    const ch = closes[i] - closes[i - 1]
    avgG = (avgG * (period - 1) + (ch > 0 ? ch : 0)) / period
    avgL = (avgL * (period - 1) + (ch < 0 ? -ch : 0)) / period
  }
  if (avgL === 0) return 100
  return 100 - 100 / (1 + avgG / avgL)
}

function targetGoldWeight(zone: string, rsi: number | null): number {
  let w = ZONE_WEIGHT[zone] ?? 0.35
  if (rsi != null) { if (rsi > 75) w -= 0.05; else if (rsi < 30) w += 0.05 }
  w = Math.max(GOLD_MIN, Math.min(GOLD_MAX, w))
  return Math.round(w * 100) / 100
}

Deno.serve(async (req) => {
  const cronSecret = req.headers.get("x-cron-secret") ?? ""
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  const authHeader = req.headers.get("authorization") ?? ""
  if (cronSecret !== CRON_SECRET && authHeader !== `Bearer ${serviceRoleKey}`) {
    return jsonResponse({ error: "Unauthorized" }, 401)
  }
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const fmpKey = Deno.env.get("FMP_API_KEY") ?? ""
  if (!fmpKey) return jsonResponse({ error: "FMP_API_KEY not configured" }, 500)
  const supabase = createClient(supabaseUrl, serviceRoleKey)

  let backfill = false
  let from = DEFAULT_FROM
  let runDate = new Date().toISOString().split("T")[0]
  try {
    const b = await req.json()
    if (b?.backfill === true) backfill = true
    if (b?.from) from = b.from
    if (b?.date) runDate = b.date
  } catch { /* no body */ }

  const { data: pf } = await supabase
    .from("model_portfolios").select("id, starting_nav").eq("strategy", "metals").maybeSingle()
  if (!pf) return jsonResponse({ error: "metals portfolio not found" }, 400)
  const startingNav = Number(pf.starting_nav) || 50000

  const gold = await fetchFMPDaily("GCUSD", fmpKey)
  if (gold.length < WINDOW + 5) return jsonResponse({ error: `insufficient gold history (${gold.length})` }, 502)
  const closes = gold.map((g) => g.close)
  const dates = gold.map((g) => g.date)

  const windowFrom = backfill ? from : runDate

  // Resume from the latest NAV row (empty on a fresh backfill).
  const { data: lastRows } = await supabase
    .from("model_portfolio_nav").select("nav_date, allocations, signal_context")
    .eq("portfolio_id", pf.id).order("nav_date", { ascending: false }).limit(1)
  const last = lastRows?.[0]

  let goldOz = 0, cashValue = 0, avgCost = 0, currentTarget = -1
  let currentZone: string | null = null
  let lastRebalance: string | null = null
  let prevDate: string | null = null
  if (last) {
    const alloc = typeof last.allocations === "string" ? JSON.parse(last.allocations) : last.allocations
    const g = alloc?.GOLD ?? {}
    const c = alloc?.CASH ?? {}
    goldOz = Number(g.qty) || 0
    avgCost = Number(g.entry_price) || 0
    cashValue = Number(c.value) || 0
    const ctx = typeof last.signal_context === "string" ? JSON.parse(last.signal_context) : last.signal_context
    currentTarget = ctx?.target_gold != null ? Number(ctx.target_gold) : -1
    currentZone = ctx?.zone ?? null
    lastRebalance = ctx?.last_rebalance ?? null
    prevDate = last.nav_date
  }

  const navRows: Record<string, unknown>[] = []
  const tradeRows: Record<string, unknown>[] = []

  for (let i = WINDOW - 1; i < gold.length; i++) {
    const d = dates[i]
    if (d < windowFrom) continue
    if (prevDate && d <= prevDate) continue
    const price = closes[i]
    const z = channelZ(closes.slice(i - WINDOW + 1, i + 1))
    if (z == null) continue
    const zone = zoneFromZ(z, currentZone)
    const rsi = rsiLast(closes.slice(0, i + 1))
    const target = targetGoldWeight(zone, rsi)

    let nav: number
    if (goldOz === 0 && cashValue === 0 && currentTarget < 0) {
      // Inception
      nav = startingNav
      goldOz = (nav * target) / price
      cashValue = nav * (1 - target)
      avgCost = price
      currentTarget = target
      currentZone = zone
      lastRebalance = d
    } else {
      const gap = prevDate ? Math.max(1, Math.round((new Date(d).getTime() - new Date(prevDate).getTime()) / 86400000)) : 1
      cashValue = cashValue * Math.pow(1 + DAILY_CASH_RATE, gap)
      const markedGold = goldOz * price
      nav = markedGold + cashValue
      // Rebalance only when the valuation zone changes AND we've held at least
      // the minimum period — filters transient boundary flips into ~monthly moves.
      const heldEnough = !lastRebalance || Math.round((new Date(d).getTime() - new Date(lastRebalance).getTime()) / 86400000) >= MIN_HOLD_DAYS
      if (zone !== currentZone && heldEnough) {
        const newGold = nav * target
        const newOz = newGold / price
        const dOz = newOz - goldOz
        if (dOz > 0) avgCost = (goldOz * avgCost + dOz * price) / (goldOz + dOz)
        tradeRows.push({
          portfolio_id: pf.id,
          trade_date: d,
          trigger: `Gold ${zone}${rsi != null ? `, RSI ${Math.round(rsi)}` : ""} — target ${Math.round(target * 100)}% gold`,
          from_allocation: { GOLD: Math.round((markedGold / nav) * 1000) / 10, CASH: Math.round((cashValue / nav) * 1000) / 10 },
          to_allocation: { GOLD: Math.round(target * 1000) / 10, CASH: Math.round((1 - target) * 1000) / 10 },
          market_context: null,
        })
        goldOz = newOz
        cashValue = nav * (1 - target)
        currentTarget = target
        currentZone = zone
        lastRebalance = d
      }
    }

    const goldValue = goldOz * price
    navRows.push({
      portfolio_id: pf.id,
      nav_date: d,
      nav: Math.round(nav * 100) / 100,
      allocations: {
        GOLD: { pct: Math.round((goldValue / nav) * 1000) / 10, value: Math.round(goldValue * 100) / 100, qty: Math.round(goldOz * 1e8) / 1e8, entry_price: Math.round(avgCost * 100) / 100 },
        CASH: { pct: Math.round((cashValue / nav) * 1000) / 10, value: Math.round(cashValue * 100) / 100, qty: Math.round(cashValue * 100) / 100 },
      },
      signal_context: {
        ...(backfill && d < runDate ? { backfilled: true } : {}),
        zone,
        rsi: rsi != null ? Math.round(rsi * 10) / 10 : null,
        target_gold: currentTarget,
        last_rebalance: lastRebalance,
      },
    })
    prevDate = d
  }

  for (let k = 0; k < navRows.length; k += 200) {
    const { error } = await supabase.from("model_portfolio_nav").upsert(navRows.slice(k, k + 200), { onConflict: "portfolio_id,nav_date" })
    if (error) return jsonResponse({ error: `NAV upsert failed: ${error.message}` }, 500)
  }
  if (tradeRows.length > 0) {
    const { error } = await supabase.from("model_portfolio_trades").insert(tradeRows)
    if (error) console.error("trade insert failed:", error.message)
  }

  return jsonResponse({
    success: true,
    backfill,
    rows: navRows.length,
    trades: tradeRows.length,
    first: navRows.length ? (navRows[0] as { nav_date: string }).nav_date : null,
    last: navRows.length ? (navRows[navRows.length - 1] as { nav_date: string }).nav_date : null,
  })
})
