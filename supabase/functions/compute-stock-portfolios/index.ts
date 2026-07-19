import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * compute-stock-portfolios Edge Function
 *
 * Stock model portfolios (asset_class='stock'). Unlike the crypto function,
 * allocations are CURATED: Matt posts target allocations into
 * model_portfolio_targets; this function marks NAV to market daily and
 * rebalances only when a new target becomes effective.
 *
 * Modes (POST body):
 *   {}                                  → daily run (weekday, after US close)
 *   { "date": "YYYY-MM-DD" }            → daily run for a specific date
 *   { "backfill": true, "from": "..." } → backfill from `from` (default 2026-01-01) to today
 *
 * Scheduled weekdays 22:05 UTC (after US market close), see migration
 * 20260714000002_stock_portfolio_cron.sql.
 */

const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? ""
const CASH_APY = 0.04
const DAILY_CASH_RATE = Math.pow(1 + CASH_APY, 1 / 365) - 1
const DEFAULT_BACKFILL_FROM = "2026-01-01"

// ─── Types ──────────────────────────────────────────────────────────────────

interface StockPortfolio {
  id: string
  strategy: string
  name: string
  starting_nav: number
}

interface Target {
  id: string
  portfolio_id: string
  effective_date: string
  allocations: Record<string, number>
  rationale: string | null
  applied_at: string | null
}

interface Position {
  qty: number
  value: number
  price: number
}

interface AllocDetail {
  pct: number
  value: number
  qty: number
  entry_price?: number
}

// ─── Helpers ────────────────────────────────────────────────────────────────

function todayUTC(): string {
  return new Date().toISOString().split("T")[0]
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

function daysBetween(a: string, b: string): number {
  return Math.round((new Date(b).getTime() - new Date(a).getTime()) / 86400000)
}

// ─── FMP price history ──────────────────────────────────────────────────────

/** Returns map of date → close, plus sorted ascending list of dates. */
async function fetchHistory(
  symbol: string,
  fmpKey: string,
): Promise<{ closes: Map<string, number>; dates: string[] } | null> {
  const url = `https://financialmodelingprep.com/stable/historical-price-eod/full?symbol=${symbol}&apikey=${fmpKey}`
  const resp = await fetch(url)
  if (!resp.ok) {
    console.warn(`  [prices] FMP fetch failed for ${symbol}: ${resp.status}`)
    return null
  }
  const data = await resp.json()
  if (!Array.isArray(data) || data.length === 0) {
    console.warn(`  [prices] FMP returned no data for ${symbol}`)
    return null
  }
  const closes = new Map<string, number>()
  for (const row of data) {
    const price = parseFloat(row.close)
    if (row.date && price > 0) closes.set(row.date, price)
  }
  const dates = [...closes.keys()].sort()
  return { closes, dates }
}

/** Price at date d, falling back to the most recent prior close (holidays, IPO gaps). */
function priceAt(hist: { closes: Map<string, number>; dates: string[] }, d: string): number | null {
  const exact = hist.closes.get(d)
  if (exact) return exact
  // Binary-search the latest date <= d
  let lo = 0, hi = hist.dates.length - 1, best = -1
  while (lo <= hi) {
    const mid = (lo + hi) >> 1
    if (hist.dates[mid] <= d) { best = mid; lo = mid + 1 } else { hi = mid - 1 }
  }
  return best >= 0 ? hist.closes.get(hist.dates[best]) ?? null : null
}

// ─── Signal context ─────────────────────────────────────────────────────────

interface DateContext {
  macro_regime: string | null
  vix_signal: string | null
  vix_score: number | null
}

/** Regime per date from positioning_signals (index category + VIX), one query for the whole window. */
async function fetchRegimeByDate(
  supabase: ReturnType<typeof createClient>,
  fromDate: string,
  toDate: string,
): Promise<Map<string, DateContext>> {
  const byDate = new Map<string, DateContext>()
  const { data } = await supabase
    .from("positioning_signals")
    .select("signal_date, asset, signal, trend_score, category")
    .gte("signal_date", fromDate)
    .lte("signal_date", toDate)
    .or("category.eq.index,asset.eq.VIX")

  const grouped = new Map<string, Array<{ asset: string; signal: string; trend_score: number; category: string }>>()
  for (const row of data ?? []) {
    const list = grouped.get(row.signal_date) ?? []
    list.push(row)
    grouped.set(row.signal_date, list)
  }

  // Note: unlike the crypto function's determineMacroRegime, we (a) require index
  // signals (SPY/QQQ/DIA/IWM) and carry the last regime forward on days that only
  // have a VIX row, and (b) invert VIX for risk purposes — a bearish VIX trend
  // (falling volatility) is risk-ON, not risk-off.
  let lastRegime: string | null = null
  for (const date of [...grouped.keys()].sort()) {
    const signals = grouped.get(date)!
    let bearish = 0, total = 0
    let vixSignal: string | null = null
    let vixScore: number | null = null
    for (const s of signals) {
      if (s.asset === "VIX") {
        vixSignal = s.signal
        vixScore = Number(s.trend_score)
        total++
        if (s.signal === "bullish") bearish++ // rising volatility = risk-off vote
      } else if (s.category === "index") {
        total++
        if (s.signal === "bearish") bearish++
      }
    }
    const hasIndexData = signals.some((s) => s.category === "index")
    const regime = hasIndexData
      ? (bearish / total >= 0.5 ? "Risk-Off" : "Risk-On")
      : lastRegime // VIX-only day (weekend/timing gap) — carry forward
    if (regime) lastRegime = regime
    byDate.set(date, { macro_regime: regime, vix_signal: vixSignal, vix_score: vixScore })
  }
  return byDate
}

/** Top sectors by relative strength vs SPY for the latest available date (daily mode only). */
async function fetchLeadingSectors(
  supabase: ReturnType<typeof createClient>,
): Promise<string[]> {
  try {
    const { data } = await supabase
      .from("sector_performance")
      .select("sector_name, relative_strength_vs_spy, signal_date")
      .order("signal_date", { ascending: false })
      .limit(30)
    if (!data || data.length === 0) return []
    const latestDate = data[0].signal_date
    return data
      .filter((r) => r.signal_date === latestDate && r.relative_strength_vs_spy != null)
      .sort((a, b) => Number(b.relative_strength_vs_spy) - Number(a.relative_strength_vs_spy))
      .slice(0, 3)
      .map((r) => r.sector_name)
  } catch {
    return []
  }
}

// ─── NAV computation ────────────────────────────────────────────────────────

function markToMarket(
  positions: Record<string, Position>,
  prices: Record<string, number>,
  cashGrowth: number,
): { nav: number; positions: Record<string, Position> } {
  let nav = 0
  const updated: Record<string, Position> = {}
  for (const [asset, pos] of Object.entries(positions)) {
    if (asset === "CASH") {
      const v = pos.value * cashGrowth
      updated[asset] = { qty: v, value: v, price: 1.0 }
      nav += v
    } else {
      const p = prices[asset] ?? pos.price
      const v = pos.qty * p
      updated[asset] = { qty: pos.qty, value: v, price: p }
      nav += v
    }
  }
  return { nav, positions: updated }
}

function rebalanceTo(
  nav: number,
  allocation: Record<string, number>,
  prices: Record<string, number>,
): Record<string, Position> {
  const positions: Record<string, Position> = {}
  for (const [asset, weight] of Object.entries(allocation)) {
    if (weight <= 0) continue
    const value = nav * weight
    if (asset === "CASH") {
      positions[asset] = { qty: value, value, price: 1.0 }
    } else {
      const p = prices[asset] ?? 0
      positions[asset] = { qty: p > 0 ? value / p : 0, value, price: p }
    }
  }
  return positions
}

function buildAllocJson(
  positions: Record<string, Position>,
  nav: number,
  prevAlloc: Record<string, AllocDetail>,
): Record<string, AllocDetail> {
  const out: Record<string, AllocDetail> = {}
  for (const [asset, pos] of Object.entries(positions)) {
    if (pos.value <= 0) continue
    let entryPrice: number | undefined
    if (asset === "CASH") {
      entryPrice = undefined
    } else if (prevAlloc[asset]?.entry_price && prevAlloc[asset].entry_price! > 0) {
      entryPrice = prevAlloc[asset].entry_price
    } else {
      entryPrice = pos.price
    }
    out[asset] = {
      pct: Math.round((pos.value / nav) * 1000) / 10,
      value: Math.round(pos.value * 100) / 100,
      qty: Math.round(pos.qty * 100000000) / 100000000,
      ...(entryPrice ? { entry_price: Math.round(entryPrice * 100) / 100 } : {}),
    }
  }
  return out
}

// ─── Main ───────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  const authHeader = req.headers.get("authorization") ?? ""
  const cronSecret = req.headers.get("x-cron-secret") ?? ""
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  const fmpKey = Deno.env.get("FMP_API_KEY") ?? ""

  if (cronSecret !== CRON_SECRET && authHeader !== `Bearer ${serviceRoleKey}`) {
    return jsonResponse({ error: "Unauthorized" }, 401)
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey)

  let runDate = todayUTC()
  let backfill = false
  let backfillFrom = DEFAULT_BACKFILL_FROM
  try {
    const body = await req.json()
    if (body?.date) runDate = body.date
    if (body?.backfill === true) backfill = true
    if (body?.from) backfillFrom = body.from
  } catch { /* no body */ }

  try {
    console.log(`[stock-portfolios] ${backfill ? `Backfill from ${backfillFrom}` : `Daily run for ${runDate}`}`)

    // 1. Load stock portfolios + their targets
    const { data: portfolios } = await supabase
      .from("model_portfolios")
      .select("id, strategy, name, starting_nav")
      .eq("asset_class", "stock")
    if (!portfolios || portfolios.length === 0) {
      return jsonResponse({ error: "No stock portfolios found" }, 400)
    }

    const { data: allTargets } = await supabase
      .from("model_portfolio_targets")
      .select("id, portfolio_id, effective_date, allocations, rationale, applied_at")
      .in("portfolio_id", portfolios.map((p: StockPortfolio) => p.id))
      .order("effective_date", { ascending: true })
    const targetsByPortfolio = new Map<string, Target[]>()
    for (const t of (allTargets ?? []) as Target[]) {
      const list = targetsByPortfolio.get(t.portfolio_id) ?? []
      list.push(t)
      targetsByPortfolio.set(t.portfolio_id, list)
    }

    // 2. Universe = union of all target tickers (ex-CASH), plus SPY for the trading calendar
    const universe = new Set<string>()
    for (const t of (allTargets ?? []) as Target[]) {
      for (const sym of Object.keys(t.allocations)) if (sym !== "CASH") universe.add(sym)
    }

    const histories = new Map<string, { closes: Map<string, number>; dates: string[] }>()
    const spyHist = await fetchHistory("SPY", fmpKey)
    if (!spyHist) return jsonResponse({ error: "Failed to fetch SPY history (trading calendar)" }, 502)
    for (const sym of universe) {
      const h = await fetchHistory(sym, fmpKey)
      if (h) histories.set(sym, h)
      else console.warn(`  Missing price history for ${sym} — will carry last known price`)
    }

    // 3. Trading days in window (SPY close dates are the calendar)
    const windowFrom = backfill ? backfillFrom : runDate
    const tradingDays = spyHist.dates.filter((d) => d >= windowFrom && d <= runDate)
    if (tradingDays.length === 0) {
      console.log(`  ${runDate} is not a trading day — nothing to do`)
      return jsonResponse({ success: true, skipped: "not a trading day", date: runDate })
    }

    // 4. Regime context for the window (query starts 10 days early so the
    //    carry-forward has data even when the run date only has a VIX row)
    const regimeLookback = new Date(new Date(windowFrom).getTime() - 10 * 86400000)
      .toISOString().split("T")[0]
    const regimeByDate = await fetchRegimeByDate(supabase, regimeLookback, runDate)
    const regimeDates = [...regimeByDate.keys()].sort()
    /** Context at date d, falling back to the nearest prior date with signals. */
    const contextAt = (d: string): DateContext | undefined => {
      if (regimeByDate.has(d)) return regimeByDate.get(d)
      let best: string | undefined
      for (const rd of regimeDates) { if (rd <= d) best = rd; else break }
      return best ? regimeByDate.get(best) : undefined
    }
    const leadingSectors = backfill ? [] : await fetchLeadingSectors(supabase)

    const rebalanced: { portfolio: StockPortfolio; trigger: string }[] = []

    // 5. Process each portfolio
    for (const portfolio of portfolios as StockPortfolio[]) {
      const targets = targetsByPortfolio.get(portfolio.id) ?? []
      if (targets.length === 0) {
        console.warn(`  ${portfolio.strategy}: no targets — skipping`)
        continue
      }

      // Resume point: latest NAV row
      const { data: lastNavRows } = await supabase
        .from("model_portfolio_nav")
        .select("nav_date, nav, allocations")
        .eq("portfolio_id", portfolio.id)
        .order("nav_date", { ascending: false })
        .limit(1)
      const lastNav = lastNavRows?.[0]

      let positions: Record<string, Position> = {}
      let prevAllocJson: Record<string, AllocDetail> = {}
      let prevDate: string | null = null
      let currentTargetId: string | null = null

      if (lastNav) {
        prevDate = lastNav.nav_date
        prevAllocJson = typeof lastNav.allocations === "string" ? JSON.parse(lastNav.allocations) : lastNav.allocations
        for (const [asset, d] of Object.entries(prevAllocJson)) {
          positions[asset] = { qty: d.qty, value: d.value, price: d.qty > 0 ? d.value / d.qty : 0 }
        }
        // The target in force at the last NAV date
        const inForce = targets.filter((t) => t.effective_date <= lastNav.nav_date).pop()
        currentTargetId = inForce?.id ?? null
      }

      const days = tradingDays.filter((d) => !prevDate || d > prevDate)
      if (days.length === 0) {
        console.log(`  ${portfolio.strategy}: up to date (${prevDate})`)
        continue
      }

      const navRows: Record<string, unknown>[] = []
      const tradeRows: Record<string, unknown>[] = []
      const appliedTargetIds: string[] = []

      for (const d of days) {
        // Prices for this date
        const prices: Record<string, number> = {}
        for (const [sym, hist] of histories) {
          const p = priceAt(hist, d)
          if (p) prices[sym] = p
        }

        // Cash accrual over calendar days since previous row
        const gap = prevDate ? Math.max(1, daysBetween(prevDate, d)) : 1
        const cashGrowth = Math.pow(1 + DAILY_CASH_RATE, gap)

        // Target in force at d
        const target = targets.filter((t) => t.effective_date <= d).pop()
        if (!target) { prevDate = d; continue } // before first target — no NAV yet

        const isRebalance = target.id !== currentTargetId
        let nav: number

        if (Object.keys(positions).length === 0) {
          // Inception
          nav = Number(portfolio.starting_nav) || 50000
          positions = rebalanceTo(nav, target.allocations, prices)
          currentTargetId = target.id
          appliedTargetIds.push(target.id)
        } else if (isRebalance) {
          const marked = markToMarket(positions, prices, cashGrowth)
          nav = marked.nav
          const fromAlloc: Record<string, number> = {}
          for (const [k, v] of Object.entries(prevAllocJson)) fromAlloc[k] = v.pct
          positions = rebalanceTo(nav, target.allocations, prices)
          const toAlloc: Record<string, number> = {}
          for (const [k, w] of Object.entries(target.allocations)) {
            if (w > 0) toAlloc[k] = Math.round(w * 1000) / 10
          }
          tradeRows.push({
            portfolio_id: portfolio.id,
            trade_date: d,
            trigger: target.rationale ? `Position change — ${target.rationale}` : "Position change",
            from_allocation: fromAlloc,
            to_allocation: toAlloc,
            market_context: null,
          })
          currentTargetId = target.id
          appliedTargetIds.push(target.id)
          if (!backfill) rebalanced.push({ portfolio, trigger: target.rationale ?? "Allocations updated" })
        } else {
          const marked = markToMarket(positions, prices, cashGrowth)
          nav = marked.nav
          positions = marked.positions
        }

        const allocJson = buildAllocJson(positions, nav, prevAllocJson)
        const ctx = contextAt(d)
        navRows.push({
          portfolio_id: portfolio.id,
          nav_date: d,
          nav: Math.round(nav * 100) / 100,
          allocations: allocJson,
          macro_regime: ctx?.macro_regime ?? null,
          signal_context: {
            ...(backfill && d < todayUTC() ? { backfilled: true } : {}),
            ...(ctx?.vix_signal ? { vix_signal: ctx.vix_signal, vix_score: ctx.vix_score } : {}),
            ...(leadingSectors.length > 0 && !backfill ? { leading_sectors: leadingSectors } : {}),
          },
        })

        prevAllocJson = allocJson
        prevDate = d
      }

      // Batch upserts (chunked)
      for (let i = 0; i < navRows.length; i += 200) {
        const { error } = await supabase
          .from("model_portfolio_nav")
          .upsert(navRows.slice(i, i + 200), { onConflict: "portfolio_id,nav_date" })
        if (error) throw new Error(`NAV upsert failed for ${portfolio.strategy}: ${error.message}`)
      }
      if (tradeRows.length > 0) {
        const { error } = await supabase.from("model_portfolio_trades").insert(tradeRows)
        if (error) console.error(`  Trade insert failed for ${portfolio.strategy}: ${error.message}`)
      }
      if (appliedTargetIds.length > 0) {
        await supabase
          .from("model_portfolio_targets")
          .update({ applied_at: new Date().toISOString() })
          .in("id", appliedTargetIds)
          .is("applied_at", null)
      }

      console.log(`  ${portfolio.strategy}: wrote ${navRows.length} NAV rows, ${tradeRows.length} position changes`)
    }

    // 6. Notifications (daily mode only) — mirrors crypto function pattern
    if (!backfill && rebalanced.length > 0) {
      const { data: followers } = await supabase
        .from("profiles")
        .select("id, followed_stock_portfolio")

      for (const { portfolio, trigger } of rebalanced) {
        const targetUsers: string[] = []
        for (const f of followers ?? []) {
          if (!f.followed_stock_portfolio || f.followed_stock_portfolio === portfolio.strategy) {
            targetUsers.push(f.id)
          }
        }
        if (targetUsers.length === 0) continue
        try {
          await fetch(`${supabaseUrl}/functions/v1/send-broadcast-notification`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${Deno.env.get("SUPABASE_ANON_KEY") ?? ""}`,
              "x-cron-secret": CRON_SECRET,
            },
            body: JSON.stringify({
              broadcast_id: portfolio.strategy,
              title: `${portfolio.name} — Position Change`,
              body: trigger,
              event_type: "model_portfolio_rebalance",
              target_audience: { type: "specific", user_ids: targetUsers },
            }),
          })
          console.log(`  Sent position-change notification for ${portfolio.strategy} to ${targetUsers.length} users`)
        } catch (err) {
          console.error(`  Notification failed for ${portfolio.strategy}: ${err}`)
        }
      }
    }

    return jsonResponse({ success: true, date: runDate, backfill })
  } catch (err) {
    console.error("[stock-portfolios] Error:", err)
    return jsonResponse({ error: String(err) }, 500)
  }
})
