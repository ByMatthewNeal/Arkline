import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * compute-model-portfolios Edge Function
 *
 * Runs daily at 00:30 UTC (after compute-positioning-signals at 00:15).
 * Reads today's QPS signals + BTC risk level, applies Core/Edge strategy rules,
 * computes new NAV, and logs trades on allocation changes.
 */

const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? ""
const STABLECOIN_APY = 0.045
const DAILY_STABLE_RATE = Math.pow(1 + STABLECOIN_APY, 1 / 365) - 1

// BTC log regression config
const BTC_ORIGIN_DATE = new Date("2009-01-03")
const BTC_DEVIATION_BOUNDS: [number, number] = [-0.8, 0.8]

// ─── Types ──────────────────────────────────────────────────────────────────

interface Portfolio {
  id: string
  strategy: string
}

interface Signal {
  asset: string
  signal: string
  trend_score: number
  category: string
}

interface NavRow {
  nav: number
  allocations: Record<string, { pct: number; value: number; qty: number }>
  btc_signal: string
  btc_risk_level: number
  btc_risk_category: string
  gold_signal: string
  macro_regime: string
  dominant_alt: string | null
}

interface Position {
  qty: number
  value: number
  price: number
}

// ─── Helpers ────────────────────────────────────────────────────────────────

function todayUTC(): string {
  return new Date().toISOString().split("T")[0]
}

function roundAlloc(alloc: Record<string, number>): Record<string, number> {
  const r: Record<string, number> = {}
  for (const [k, v] of Object.entries(alloc)) {
    r[k] = Math.round(v * 10000) / 10000
  }
  return r
}

function allocsEqual(a: Record<string, number>, b: Record<string, number>): boolean {
  const ra = roundAlloc(a)
  const rb = roundAlloc(b)
  const keysA = Object.keys(ra).filter(k => ra[k] > 0)
  const keysB = Object.keys(rb).filter(k => rb[k] > 0)
  if (keysA.length !== keysB.length) return false
  for (const k of keysA) {
    if (ra[k] !== rb[k]) return false
  }
  return true
}

// ─── BTC Risk via Log Regression ────────────────────────────────────────────

async function computeBtcRisk(fmpKey: string): Promise<{
  risk_level: number
  price: number
  fair_value: number
  deviation: number
  category: string
} | null> {
  // Fetch BTC full history from FMP
  const url = `https://financialmodelingprep.com/stable/historical-price-eod/full?symbol=BTCUSD&apikey=${fmpKey}`
  const resp = await fetch(url)
  if (!resp.ok) return null
  const data = await resp.json()
  if (!Array.isArray(data) || data.length < 100) return null

  // Sort oldest first
  const sorted = [...data].sort((a: any, b: any) => a.date.localeCompare(b.date))

  // Least squares in log-log space
  const originTime = BTC_ORIGIN_DATE.getTime()
  let n = 0, sumX = 0, sumY = 0, sumXX = 0, sumXY = 0
  let lastPrice = 0

  for (const row of sorted) {
    const d = new Date(row.date)
    const days = Math.round((d.getTime() - originTime) / 86400000)
    const price = parseFloat(row.close)
    if (days <= 0 || price <= 0) continue
    const x = Math.log10(days)
    const y = Math.log10(price)
    sumX += x; sumY += y; sumXX += x * x; sumXY += x * y
    n++
    lastPrice = price
  }

  const denom = n * sumXX - sumX * sumX
  if (Math.abs(denom) < 1e-10) return null

  const b = (n * sumXY - sumX * sumY) / denom
  const a = (sumY - b * sumX) / n

  // Fair value at today
  const todayDays = Math.round((Date.now() - originTime) / 86400000)
  const logFair = a + b * Math.log10(todayDays)
  const fairValue = Math.pow(10, logFair)

  // Deviation and normalize
  const deviation = Math.log10(lastPrice) - Math.log10(fairValue)
  const [low, high] = BTC_DEVIATION_BOUNDS
  const clamped = Math.max(low, Math.min(high, deviation))
  const riskLevel = (clamped - low) / (high - low)

  let category: string
  if (riskLevel < 0.20) category = "Very Low Risk"
  else if (riskLevel < 0.40) category = "Low Risk"
  else if (riskLevel < 0.55) category = "Neutral"
  else if (riskLevel < 0.70) category = "Elevated Risk"
  else if (riskLevel < 0.90) category = "High Risk"
  else category = "Extreme Risk"

  return {
    risk_level: Math.round(riskLevel * 10000) / 10000,
    price: lastPrice,
    fair_value: Math.round(fairValue * 100) / 100,
    deviation: Math.round(deviation * 10000) / 10000,
    category,
  }
}

// ─── Strategy Rules ─────────────────────────────────────────────────────────

function getDefensiveMix(goldSignal: string): Record<string, number> {
  if (goldSignal === "bullish") return { PAXG: 0.70, USDC: 0.30 }
  if (goldSignal === "neutral") return { PAXG: 0.40, USDC: 0.60 }
  return { PAXG: 0.0, USDC: 1.0 }
}

function applyDefensive(base: Record<string, number>, defensivePct: number, goldSignal: string): Record<string, number> {
  const mix = getDefensiveMix(goldSignal)
  const alloc = { ...base }
  for (const [asset, pct] of Object.entries(mix)) {
    if (pct > 0) {
      alloc[asset] = (alloc[asset] || 0) + defensivePct * pct
    }
  }
  return alloc
}

function getTopBullishAlts(altBtcSignals: Record<string, Signal>, n = 3): Array<[string, number]> {
  const candidates: Array<[string, number]> = []
  for (const [pair, sig] of Object.entries(altBtcSignals)) {
    if (sig.signal === "bullish") {
      const alt = pair.split("/")[0]
      if (!["BTC", "ETH", "SOL"].includes(alt)) {
        candidates.push([alt, sig.trend_score])
      }
    }
  }
  candidates.sort((a, b) => b[1] - a[1])
  return candidates.slice(0, n)
}

function distributeAltPct(topAlts: Array<[string, number]>, totalPct: number): Record<string, number> {
  if (topAlts.length === 0) return {}
  const totalScore = topAlts.reduce((sum, [, score]) => sum + score, 0)
  if (totalScore <= 0) {
    const weight = totalPct / topAlts.length
    const result: Record<string, number> = {}
    for (const [alt] of topAlts) result[alt] = weight
    return result
  }
  const result: Record<string, number> = {}
  for (const [alt, score] of topAlts) result[alt] = totalPct * (score / totalScore)
  return result
}

function computeCoreAllocation(btcSignal: string, btcRiskCategory: string, goldSignal: string, macroRegime: string): Record<string, number> {
  const isRiskOff = macroRegime.includes("Risk-Off")
  const isHighRisk = ["High Risk", "Extreme Risk", "Elevated Risk"].includes(btcRiskCategory)

  if (isRiskOff && isHighRisk) return applyDefensive({}, 1.0, goldSignal)

  if (btcSignal === "bullish") return { BTC: 0.60, ETH: 0.40 }

  if (btcSignal === "neutral") {
    if (["Very Low Risk", "Low Risk"].includes(btcRiskCategory)) {
      return applyDefensive({ BTC: 0.50, ETH: 0.30 }, 0.20, goldSignal)
    }
    return applyDefensive({ BTC: 0.30, ETH: 0.20 }, 0.50, goldSignal)
  }

  // Mild bearish (trend score 36-44): reduced crypto but not full exit
  if (btcSignal === "mild_bearish") {
    if (["Very Low Risk", "Low Risk"].includes(btcRiskCategory)) {
      return applyDefensive({ BTC: 0.30, ETH: 0.15 }, 0.55, goldSignal)
    }
    return applyDefensive({ BTC: 0.20, ETH: 0.10 }, 0.70, goldSignal)
  }

  // Full bearish
  if (btcRiskCategory === "Very Low Risk") return applyDefensive({ BTC: 0.40, ETH: 0.20 }, 0.40, goldSignal)
  if (btcRiskCategory === "Low Risk") return applyDefensive({ BTC: 0.25, ETH: 0.15 }, 0.60, goldSignal)
  // Bearish + Neutral/Elevated risk: keep small crypto position
  return applyDefensive({ BTC: 0.15, ETH: 0.05 }, 0.80, goldSignal)
}

function computeEdgeAllocation(
  btcSignal: string, btcRiskCategory: string, goldSignal: string, macroRegime: string,
  cryptoSignals: Record<string, Signal>, altBtcSignals: Record<string, Signal>,
): { alloc: Record<string, number>; dominantAlt: string | null } {
  const isRiskOff = macroRegime.includes("Risk-Off")
  const isHighRisk = ["High Risk", "Extreme Risk", "Elevated Risk"].includes(btcRiskCategory)
  const topAlts = getTopBullishAlts(altBtcSignals, 3)
  const dominantAlt = topAlts.length > 0 ? topAlts[0][0] : null

  if (isRiskOff && isHighRisk) return { alloc: applyDefensive({}, 1.0, goldSignal), dominantAlt: null }

  if (isRiskOff) {
    if (btcRiskCategory === "Very Low Risk") {
      return { alloc: applyDefensive({ BTC: 0.30, ETH: 0.20 }, 0.50, goldSignal), dominantAlt: null }
    }
    if (btcRiskCategory === "Low Risk") {
      return { alloc: applyDefensive({ BTC: 0.20, ETH: 0.10 }, 0.70, goldSignal), dominantAlt: null }
    }
    return { alloc: applyDefensive({ BTC: 0.10, ETH: 0.05 }, 0.85, goldSignal), dominantAlt: null }
  }

  const bullishAssets: string[] = []
  for (const asset of ["BTC", "ETH", "SOL"]) {
    if (cryptoSignals[asset]?.signal === "bullish") bullishAssets.push(asset)
  }

  if (bullishAssets.length >= 2 || btcSignal === "bullish") {
    const alloc: Record<string, number> = {}
    if (bullishAssets.includes("BTC") || btcSignal === "bullish") alloc.BTC = 0.30
    if (bullishAssets.includes("ETH") || cryptoSignals.ETH?.signal === "bullish") alloc.ETH = 0.25
    if (bullishAssets.includes("SOL")) alloc.SOL = 0.20
    // Distribute 15% among top bullish alts
    const altAlloc = distributeAltPct(topAlts, 0.15)
    Object.assign(alloc, altAlloc)
    const deployed = Object.values(alloc).reduce((a, b) => a + b, 0)
    const remaining = 1.0 - deployed
    if (remaining > 0.01) {
      return { alloc: applyDefensive(alloc, remaining, goldSignal), dominantAlt }
    }
    return { alloc, dominantAlt }
  }

  if (btcSignal === "mild_bearish") {
    const alloc: Record<string, number> = { BTC: 0.15 }
    if (bullishAssets.includes("ETH")) alloc.ETH = 0.10
    const altAlloc = distributeAltPct(topAlts, 0.05)
    Object.assign(alloc, altAlloc)
    const deployed = Object.values(alloc).reduce((a, b) => a + b, 0)
    return { alloc: applyDefensive(alloc, 1.0 - deployed, goldSignal), dominantAlt }
  }

  if (btcSignal === "bearish") {
    if (["Very Low Risk", "Low Risk"].includes(btcRiskCategory)) {
      return { alloc: applyDefensive({ BTC: 0.20, ETH: 0.10 }, 0.70, goldSignal), dominantAlt }
    }
    return { alloc: applyDefensive({ BTC: 0.10, ETH: 0.05 }, 0.85, goldSignal), dominantAlt }
  }

  // Mixed: deploy into bullish only
  const alloc: Record<string, number> = {}
  if (bullishAssets.length > 0) {
    const weight = 0.60 / bullishAssets.length
    for (const a of bullishAssets) alloc[a] = weight
  }
  const altAlloc = distributeAltPct(topAlts, 0.10)
  Object.assign(alloc, altAlloc)
  const deployed = Object.values(alloc).reduce((a, b) => a + b, 0)
  const remaining = 1.0 - deployed
  return { alloc: applyDefensive(alloc, Math.max(0, remaining), goldSignal), dominantAlt }
}

function computeAlphaAllocation(
  btcSignal: string, btcRiskCategory: string, goldSignal: string, macroRegime: string,
  cryptoSignals: Record<string, Signal>, altBtcSignals: Record<string, Signal>,
): { alloc: Record<string, number>; dominantAlt: string | null } {
  const isRiskOff = macroRegime.includes("Risk-Off")
  const isHighRisk = ["High Risk", "Extreme Risk", "Elevated Risk"].includes(btcRiskCategory)
  const topAlts = getTopBullishAlts(altBtcSignals, 3)
  const dominantAlt = topAlts.length > 0 ? topAlts[0][0] : null

  if (isRiskOff && isHighRisk) return { alloc: applyDefensive({}, 1.0, goldSignal), dominantAlt: null }

  if (isRiskOff) {
    if (btcRiskCategory === "Very Low Risk") {
      return { alloc: applyDefensive({ BTC: 0.25, ETH: 0.15 }, 0.60, goldSignal), dominantAlt: null }
    }
    if (btcRiskCategory === "Low Risk") {
      return { alloc: applyDefensive({ BTC: 0.15, ETH: 0.10 }, 0.75, goldSignal), dominantAlt: null }
    }
    return { alloc: applyDefensive({ BTC: 0.10, ETH: 0.05 }, 0.85, goldSignal), dominantAlt: null }
  }

  const bullishAssets: string[] = []
  for (const asset of ["BTC", "ETH", "SOL"]) {
    if (cryptoSignals[asset]?.signal === "bullish") bullishAssets.push(asset)
  }

  if (bullishAssets.length >= 2 || btcSignal === "bullish") {
    const alloc: Record<string, number> = {}
    if (bullishAssets.includes("BTC") || btcSignal === "bullish") alloc.BTC = 0.20
    if (bullishAssets.includes("ETH") || cryptoSignals.ETH?.signal === "bullish") alloc.ETH = 0.15
    if (bullishAssets.includes("SOL")) alloc.SOL = 0.15
    // 40% into top bullish alts
    const altAlloc = distributeAltPct(topAlts, 0.40)
    Object.assign(alloc, altAlloc)
    const deployed = Object.values(alloc).reduce((a, b) => a + b, 0)
    const remaining = 1.0 - deployed
    if (remaining > 0.01) {
      return { alloc: applyDefensive(alloc, remaining, goldSignal), dominantAlt }
    }
    return { alloc, dominantAlt }
  }

  if (btcSignal === "mild_bearish") {
    const alloc: Record<string, number> = { BTC: 0.10 }
    if (bullishAssets.includes("ETH")) alloc.ETH = 0.08
    const altAlloc = distributeAltPct(topAlts, 0.12)
    Object.assign(alloc, altAlloc)
    const deployed = Object.values(alloc).reduce((a, b) => a + b, 0)
    return { alloc: applyDefensive(alloc, 1.0 - deployed, goldSignal), dominantAlt }
  }

  if (btcSignal === "bearish") {
    if (["Very Low Risk", "Low Risk"].includes(btcRiskCategory)) {
      const alloc: Record<string, number> = { BTC: 0.15, ETH: 0.10 }
      const altAlloc = distributeAltPct(topAlts, 0.10)
      Object.assign(alloc, altAlloc)
      const deployed = Object.values(alloc).reduce((a, b) => a + b, 0)
      return { alloc: applyDefensive(alloc, 1.0 - deployed, goldSignal), dominantAlt }
    }
    return { alloc: applyDefensive({ BTC: 0.08, ETH: 0.04 }, 0.88, goldSignal), dominantAlt: null }
  }

  // Mixed
  const alloc: Record<string, number> = {}
  if (bullishAssets.length > 0) {
    const weight = 0.45 / bullishAssets.length
    for (const a of bullishAssets) alloc[a] = weight
  }
  const altAlloc = distributeAltPct(topAlts, 0.25)
  Object.assign(alloc, altAlloc)
  const deployed = Object.values(alloc).reduce((a, b) => a + b, 0)
  const remaining = 1.0 - deployed
  return { alloc: applyDefensive(alloc, Math.max(0, remaining), goldSignal), dominantAlt }
}

function determineMacroRegime(signals: Signal[]): string {
  let bearishCount = 0, total = 0
  for (const sig of signals) {
    if (sig.category === "index" || sig.asset === "VIX") {
      total++
      // VIX bearish (high VIX) = risk-off
      if (sig.signal === "bearish") bearishCount++
    }
  }
  if (total === 0) return "Mixed"
  return bearishCount / total >= 0.5 ? "Risk-Off" : "Risk-On"
}

// ─── NAV Computation ────────────────────────────────────────────────────────

async function fetchCurrentPrices(assets: string[]): Promise<Record<string, number>> {
  const prices: Record<string, number> = {}
  // Fetch from Coinbase for crypto assets
  const coinbasePairs: Record<string, string> = {
    BTC: "BTC-USD", ETH: "ETH-USD", SOL: "SOL-USD", BNB: "BNB-USD",
    XRP: "XRP-USD", SUI: "SUI-USD", LINK: "LINK-USD", UNI: "UNI-USD",
    ONDO: "ONDO-USD", RENDER: "RENDER-USD", TAO: "TAO-USD",
    ZEC: "ZEC-USD", AVAX: "AVAX-USD", DOGE: "DOGE-USD", BCH: "BCH-USD",
    PAXG: "PAXG-USD", HYPE: "HYPE-USD", AAVE: "AAVE-USD",
  }

  for (const asset of assets) {
    if (asset === "USDC") { prices[asset] = 1.0; continue }
    const pair = coinbasePairs[asset]
    if (!pair) continue
    try {
      const resp = await fetch(`https://api.exchange.coinbase.com/products/${pair}/ticker`)
      if (resp.ok) {
        const data = await resp.json()
        prices[asset] = parseFloat(data.price)
      }
    } catch { /* skip */ }
  }
  return prices
}

function computeNav(
  prevPositions: Record<string, Position>, prevNav: number,
  prices: Record<string, number>, newAllocation: Record<string, number>,
  rebalance: boolean,
): { nav: number; positions: Record<string, Position> } {
  if (Object.keys(prevPositions).length === 0 || rebalance) {
    // Compute current NAV from existing positions
    let currentNav = prevNav
    if (Object.keys(prevPositions).length > 0) {
      currentNav = 0
      for (const [asset, pos] of Object.entries(prevPositions)) {
        if (asset === "USDC") {
          currentNav += pos.value * (1 + DAILY_STABLE_RATE)
        } else {
          const p = prices[asset] ?? pos.price
          currentNav += p > 0 && pos.qty > 0 ? pos.qty * p : pos.value
        }
      }
    }

    // Allocate at new weights
    const newPositions: Record<string, Position> = {}
    for (const [asset, weight] of Object.entries(newAllocation)) {
      if (weight <= 0) continue
      const value = currentNav * weight
      if (asset === "USDC") {
        newPositions[asset] = { qty: value, value, price: 1.0 }
      } else {
        const p = prices[asset] ?? 0
        newPositions[asset] = { qty: p > 0 ? value / p : 0, value, price: p }
      }
    }
    return { nav: currentNav, positions: newPositions }
  }

  // Mark to market
  let currentNav = 0
  const updated: Record<string, Position> = {}
  for (const [asset, pos] of Object.entries(prevPositions)) {
    if (asset === "USDC") {
      const newVal = pos.value * (1 + DAILY_STABLE_RATE)
      updated[asset] = { qty: newVal, value: newVal, price: 1.0 }
      currentNav += newVal
    } else {
      const p = prices[asset] ?? pos.price
      const newVal = pos.qty * p
      updated[asset] = { qty: pos.qty, value: newVal, price: p }
      currentNav += newVal
    }
  }
  return { nav: currentNav, positions: updated }
}

// ─── Market Context ─────────────────────────────────────────────────────────

async function fetchMarketContext(
  supabase: ReturnType<typeof createClient>,
  today: string,
): Promise<{ headlines: string[]; events: string[] }> {
  const context: { headlines: string[]; events: string[] } = { headlines: [], events: [] }

  try {
    // 1. Economic events for today (high impact only)
    const { data: events } = await supabase
      .from("economic_events")
      .select("event, actual, forecast, previous, impact")
      .eq("date", today)
      .eq("impact", "High")
      .limit(5)

    if (events && events.length > 0) {
      for (const e of events) {
        let line = e.event
        if (e.actual != null) line += ` (actual: ${e.actual}`
        if (e.forecast != null) line += `, forecast: ${e.forecast}`
        if (e.actual != null) line += ")"
        context.events.push(line)
      }
    }

    // 2. Top headlines from Google News RSS (crypto + market)
    const queries = ["crypto+market", "stock+market+today"]
    for (const q of queries) {
      try {
        const rssUrl = `https://news.google.com/rss/search?q=${q}&hl=en-US&gl=US&ceid=US:en`
        const resp = await fetch(rssUrl)
        if (resp.ok) {
          const xml = await resp.text()
          // Extract titles from RSS XML
          const titleMatches = xml.matchAll(/<item>[\s\S]*?<title>([\s\S]*?)<\/title>/g)
          let count = 0
          for (const match of titleMatches) {
            if (count >= 3) break
            const title = match[1]
              .replace(/<!\[CDATA\[/g, "").replace(/\]\]>/g, "")
              .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
              .replace(/&#39;/g, "'").replace(/&quot;/g, '"')
              .trim()
            if (title && !context.headlines.includes(title)) {
              context.headlines.push(title)
              count++
            }
          }
        }
      } catch { /* skip */ }
    }
  } catch (err) {
    console.error("Failed to fetch market context:", err)
  }

  return context
}

// ─── Main ───────────────────────────────────────────────────────────────────

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

Deno.serve(async (req) => {
  // Auth: cron secret or service role
  const authHeader = req.headers.get("authorization") ?? ""
  const cronSecret = req.headers.get("x-cron-secret") ?? ""
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  const fmpKey = Deno.env.get("FMP_API_KEY") ?? ""

  if (cronSecret !== CRON_SECRET && authHeader !== `Bearer ${serviceRoleKey}`) {
    return jsonResponse({ error: "Unauthorized" }, 401)
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey)
  let today = todayUTC()
  try {
    const body = await req.json()
    if (body?.date) today = body.date
  } catch { /* no body or not JSON */ }

  try {
    console.log(`[model-portfolios] Computing for ${today}`)

    // 1. Get portfolio metadata
    const { data: portfolios } = await supabase
      .from("model_portfolios")
      .select("id, strategy")
    const portfolioMap: Record<string, string> = {}
    for (const p of portfolios ?? []) portfolioMap[p.strategy] = p.id

    // 2. Get today's QPS signals
    const { data: signals } = await supabase
      .from("positioning_signals")
      .select("asset, signal, trend_score, category")
      .eq("signal_date", today)
    if (!signals || signals.length === 0) {
      return jsonResponse({ error: "No QPS signals for today" }, 400)
    }
    console.log(`  ${signals.length} QPS signals loaded`)

    const cryptoSignals: Record<string, Signal> = {}
    const altBtcSignals: Record<string, Signal> = {}
    let goldSignal = "neutral"
    const allSignals: Signal[] = signals

    for (const sig of signals) {
      if (sig.category === "crypto") cryptoSignals[sig.asset] = sig
      if (sig.category === "alt_btc") altBtcSignals[sig.asset] = sig
      if (sig.asset === "GOLD") {
        // Map bearish for gold defensive mix (no mild_bearish distinction needed)
        goldSignal = sig.signal === "bearish" ? "bearish" : sig.signal
      }
    }

    // Derive btcSignal with mild_bearish tier for model portfolios
    // QPS stores bearish for scores <45, but we differentiate 36-44 as mild_bearish
    let btcSignal = cryptoSignals.BTC?.signal ?? "neutral"
    if (btcSignal === "bearish" && cryptoSignals.BTC?.trend_score >= 36) {
      btcSignal = "mild_bearish"
    }
    const macroRegime = determineMacroRegime(allSignals)

    // 3. Compute BTC risk
    const btcRisk = await computeBtcRisk(fmpKey)
    const btcRiskLevel = btcRisk?.risk_level ?? 0.5
    const btcRiskCategory = btcRisk?.category ?? "Neutral"
    console.log(`  BTC risk: ${btcRiskLevel} (${btcRiskCategory})`)
    console.log(`  BTC signal: ${btcSignal}, Gold: ${goldSignal}, Regime: ${macroRegime}`)

    // 4. Save risk history
    if (btcRisk) {
      await supabase.from("model_portfolio_risk_history").upsert({
        asset: "BTC",
        risk_date: today,
        risk_level: btcRisk.risk_level,
        price: btcRisk.price,
        fair_value: btcRisk.fair_value,
        deviation: btcRisk.deviation,
      }, { onConflict: "asset,risk_date" })
    }

    // 5. Pre-fetch market context (headlines + events) for trade log
    let marketContext: { headlines: string[]; events: string[] } | null = null

    // 6. Get yesterday's NAV + positions for each portfolio
    const rebalancedStrategies: { strategy: string; triggers: string[] }[] = []

    for (const strategy of ["core", "edge", "alpha"]) {
      const portfolioId = portfolioMap[strategy]
      if (!portfolioId) continue

      const { data: prevNavRows } = await supabase
        .from("model_portfolio_nav")
        .select("*")
        .eq("portfolio_id", portfolioId)
        .order("nav_date", { ascending: false })
        .limit(1)

      const prevNav = prevNavRows?.[0]
      const prevNavValue = prevNav?.nav ?? 50000
      const prevAllocations: Record<string, { pct: number; value: number; qty: number }> =
        prevNav?.allocations ? (typeof prevNav.allocations === "string" ? JSON.parse(prevNav.allocations) : prevNav.allocations) : {}

      // Reconstruct positions from previous allocations
      const prevPositions: Record<string, Position> = {}
      for (const [asset, data] of Object.entries(prevAllocations)) {
        if (typeof data === "object" && data !== null && "qty" in data) {
          prevPositions[asset] = { qty: data.qty, value: data.value, price: data.value / (data.qty || 1) }
        }
      }

      // 6. Compute new allocation
      let newAlloc: Record<string, number>
      let dominantAlt: string | null = null

      if (strategy === "core") {
        newAlloc = computeCoreAllocation(btcSignal, btcRiskCategory, goldSignal, macroRegime)
      } else if (strategy === "edge") {
        const result = computeEdgeAllocation(btcSignal, btcRiskCategory, goldSignal, macroRegime, cryptoSignals, altBtcSignals)
        newAlloc = result.alloc
        dominantAlt = result.dominantAlt
      } else {
        const result = computeAlphaAllocation(btcSignal, btcRiskCategory, goldSignal, macroRegime, cryptoSignals, altBtcSignals)
        newAlloc = result.alloc
        dominantAlt = result.dominantAlt
      }

      // Normalize
      const total = Object.values(newAlloc).reduce((a, b) => a + b, 0)
      if (total > 0) {
        for (const k of Object.keys(newAlloc)) newAlloc[k] /= total
      }

      // 7. Determine if rebalance needed
      const prevAllocPcts: Record<string, number> = {}
      for (const [asset, data] of Object.entries(prevAllocations)) {
        if (typeof data === "object" && data !== null && "pct" in data) {
          prevAllocPcts[asset] = (data.pct as number) / 100
        } else if (typeof data === "number") {
          prevAllocPcts[asset] = data / 100
        }
      }

      const rebalance = !allocsEqual(newAlloc, prevAllocPcts)

      // 8. Fetch current prices for all assets in allocation
      const allAssets = new Set([
        ...Object.keys(newAlloc),
        ...Object.keys(prevPositions),
      ])
      const prices = await fetchCurrentPrices([...allAssets])

      // 9. Compute NAV
      const { nav, positions } = computeNav(
        prevPositions, prevNavValue, prices, newAlloc, rebalance || Object.keys(prevPositions).length === 0,
      )
      console.log(`  ${strategy}: NAV $${nav.toFixed(2)}, rebalance=${rebalance}`)

      // 10. Build allocations JSON with full detail
      const allocJson: Record<string, { pct: number; value: number; qty: number }> = {}
      for (const [asset, weight] of Object.entries(newAlloc)) {
        if (weight <= 0) continue
        const pos = positions[asset]
        allocJson[asset] = {
          pct: Math.round(weight * 1000) / 10,
          value: pos ? Math.round(pos.value * 100) / 100 : 0,
          qty: pos ? Math.round(pos.qty * 100000000) / 100000000 : 0,
        }
      }

      // 11. Upsert NAV row (map mild_bearish → bearish for DB/iOS)
      const dbBtcSignal = btcSignal === "mild_bearish" ? "bearish" : btcSignal
      await supabase.from("model_portfolio_nav").upsert({
        portfolio_id: portfolioId,
        nav_date: today,
        nav: Math.round(nav * 100) / 100,
        allocations: allocJson,
        btc_signal: dbBtcSignal,
        btc_risk_level: btcRiskLevel,
        btc_risk_category: btcRiskCategory,
        gold_signal: goldSignal === "mild_bearish" ? "bearish" : goldSignal,
        macro_regime: macroRegime,
        dominant_alt: strategy !== "core" ? dominantAlt : null,
      }, { onConflict: "portfolio_id,nav_date" })

      // 12. Log trade if allocation changed
      if (rebalance && prevNav) {
        const triggers: string[] = []
        if (prevNav.btc_signal !== btcSignal) triggers.push(`BTC ${prevNav.btc_signal} → ${btcSignal}`)
        if (prevNav.macro_regime !== macroRegime) triggers.push(`Regime ${prevNav.macro_regime} → ${macroRegime}`)
        if (prevNav.gold_signal !== goldSignal) triggers.push(`Gold ${prevNav.gold_signal} → ${goldSignal}`)
        if (prevNav.btc_risk_category !== btcRiskCategory) triggers.push(`BTC Risk ${prevNav.btc_risk_category} → ${btcRiskCategory}`)

        const fromAlloc: Record<string, number> = {}
        for (const [k, v] of Object.entries(prevAllocations)) {
          if (typeof v === "object" && v !== null && "pct" in v) fromAlloc[k] = v.pct as number
          else if (typeof v === "number") fromAlloc[k] = v
        }
        const toAlloc: Record<string, number> = {}
        for (const [k, v] of Object.entries(allocJson)) toAlloc[k] = v.pct

        // Lazy-fetch market context on first rebalance of the day
        if (!marketContext) {
          marketContext = await fetchMarketContext(supabase, today)
          console.log(`  Market context: ${marketContext.headlines.length} headlines, ${marketContext.events.length} events`)
        }

        await supabase.from("model_portfolio_trades").insert({
          portfolio_id: portfolioId,
          trade_date: today,
          trigger: triggers.length > 0 ? triggers.join("; ") : "Rebalance",
          from_allocation: fromAlloc,
          to_allocation: toAlloc,
          market_context: (marketContext.headlines.length > 0 || marketContext.events.length > 0) ? marketContext : null,
        })

        rebalancedStrategies.push({ strategy, triggers })
      }
    }

    // 12b. Send push notifications for rebalanced portfolios
    if (rebalancedStrategies.length > 0) {
      // Find users who follow each strategy, plus users who follow none (get all rebalances)
      const { data: followers } = await supabase
        .from("profiles")
        .select("id, followed_model_portfolio")

      const followersByStrategy: Record<string, string[]> = { core: [], edge: [], alpha: [] }
      const unfollowedUsers: string[] = []
      for (const f of (followers ?? [])) {
        if (f.followed_model_portfolio && followersByStrategy[f.followed_model_portfolio]) {
          followersByStrategy[f.followed_model_portfolio].push(f.id)
        } else if (!f.followed_model_portfolio) {
          unfollowedUsers.push(f.id)
        }
      }

      for (const { strategy, triggers } of rebalancedStrategies) {
        const name = strategy === "core" ? "Core" : strategy === "edge" ? "Edge" : "Alpha"
        const title = `Arkline ${name} Rebalanced`
        const body = triggers.length > 0 ? triggers.join(", ") : `${name} allocations updated`

        // Send to users following this strategy + users not following any specific one
        const targetUsers = [...followersByStrategy[strategy], ...unfollowedUsers]
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
              broadcast_id: strategy,
              title,
              body,
              event_type: "model_portfolio_rebalance",
              target_audience: { type: "specific", user_ids: targetUsers },
            }),
          })
          console.log(`  Sent ${name} rebalance notification to ${targetUsers.length} users`)
        } catch (err) {
          console.error(`  Failed to send ${name} rebalance notification: ${err}`)
        }
      }

    }

    // 13. SPY benchmark
    const fmpUrl = `https://financialmodelingprep.com/stable/historical-price-eod/full?symbol=SPY&apikey=${fmpKey}`
    const fmpResp = await fetch(fmpUrl)
    if (fmpResp.ok) {
      const fmpData = await fmpResp.json()
      if (Array.isArray(fmpData) && fmpData.length > 0) {
        const latestSpy = fmpData[0]  // newest first
        const spyPrice = parseFloat(latestSpy.close)

        // Get first benchmark row for starting price
        const { data: firstBench } = await supabase
          .from("benchmark_nav")
          .select("spy_price, nav")
          .order("nav_date", { ascending: true })
          .limit(1)

        let spyNav: number
        if (firstBench && firstBench.length > 0) {
          const startPrice = firstBench[0].spy_price
          const shares = 50000 / startPrice
          spyNav = shares * spyPrice
        } else {
          spyNav = 50000 // first day
        }

        await supabase.from("benchmark_nav").upsert({
          nav_date: today,
          spy_price: Math.round(spyPrice * 100) / 100,
          nav: Math.round(spyNav * 100) / 100,
        }, { onConflict: "nav_date" })
      }
    }

    return jsonResponse({ success: true, date: today })
  } catch (err) {
    console.error("[model-portfolios] Error:", err)
    return jsonResponse({ error: String(err) }, 500)
  }
})
