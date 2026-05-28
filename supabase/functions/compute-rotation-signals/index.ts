import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * compute-rotation-signals Edge Function
 *
 * Daily cron (01:00 UTC) that computes:
 *   1. Crypto vs Equities rotation score (-100 to +100)
 *   2. Sector performance rankings with relative strength vs SPY
 *   3. 1-2 sentence narrative via Claude Haiku
 *
 * Stores results in rotation_signals + sector_performance tables.
 */

// ─── Sector Definitions ────────────────────────────────────────────────────

interface SectorDef {
  id: string
  name: string
  stocks: string[]
  isDefensive: boolean
}

const SECTORS: SectorDef[] = [
  {
    id: "semiconductors",
    name: "Semiconductors",
    stocks: ["NVDA", "AMD", "AVGO", "TSM", "ASML", "MRVL", "QCOM", "LRCX", "MU"],
    isDefensive: false,
  },
  {
    id: "cloud_ai",
    name: "Cloud / AI Software",
    stocks: ["MSFT", "PLTR", "SNOW", "PATH", "NET", "ORCL"],
    isDefensive: false,
  },
  {
    id: "consumer_internet",
    name: "Consumer Internet",
    stocks: ["META", "AMZN", "GOOG", "NFLX", "SHOP"],
    isDefensive: false,
  },
  {
    id: "data_centers",
    name: "Data Centers & Hardware",
    stocks: ["SMCI", "DELL", "HPE", "ANET", "EQIX", "DLR"],
    isDefensive: false,
  },
  {
    id: "cybersecurity",
    name: "Cybersecurity",
    stocks: ["PANW", "CRWD", "FTNT"],
    isDefensive: false,
  },
  {
    id: "power_electrification",
    name: "Power & Electrification",
    stocks: ["ETN", "CARR", "PWR", "CMI", "GEV", "GNRC"],
    isDefensive: false,
  },
  {
    id: "utilities",
    name: "Utilities & Power Storage",
    stocks: ["VST", "CEG", "NEE", "FLNC"],
    isDefensive: false,
  },
  {
    id: "nuclear",
    name: "Nuclear",
    stocks: ["SMR", "OKLO", "CCJ", "BWXT", "UUUU", "DNN"],
    isDefensive: false,
  },
  {
    id: "crypto_miners",
    name: "Crypto Miners",
    stocks: ["MARA", "RIOT", "CIFR", "WULF", "CLSK", "IREN"],
    isDefensive: false,
  },
  {
    id: "fintech",
    name: "Fintech",
    stocks: ["HOOD", "SOFI", "COIN", "PYPL"],
    isDefensive: false,
  },
  {
    id: "space_quantum",
    name: "Space & Quantum",
    stocks: ["RKLB", "ASTS", "IONQ"],
    isDefensive: false,
  },
  {
    id: "rare_earths",
    name: "Rare Earths & Materials",
    stocks: ["MP", "REMX", "ALB"],
    isDefensive: false,
  },
  {
    id: "industrials",
    name: "Industrials",
    stocks: ["CAT", "J", "GEV"],
    isDefensive: false,
  },
  {
    id: "defensives",
    name: "Defensives",
    stocks: ["KO", "PG", "JNJ", "MRK", "WMT", "COST", "XOM", "CVX", "LMT"],
    isDefensive: true,
  },
]

// ─── Main Handler ──────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  const secret = req.headers.get("x-cron-secret") ?? ""
  if (!cronSecret || secret !== cronSecret) {
    return json({ error: "Unauthorized" }, 401)
  }

  const fmpKey = Deno.env.get("FMP_API_KEY")
  if (!fmpKey) return json({ error: "FMP_API_KEY not set" }, 500)

  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!anthropicKey) return json({ error: "ANTHROPIC_API_KEY not set" }, 500)

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const supabase = createClient(supabaseUrl, supabaseKey)

  const today = new Date().toISOString().slice(0, 10)
  const errors: string[] = []

  console.log(`[rotation] Starting computation for ${today}`)

  // ── Step 1: Fetch BTC + SPY price history ──────────────────────────────

  let btcCandles: number[] = []
  let spyCandles: number[] = []

  try {
    btcCandles = await fetchCoinbaseCloses("BTC-USD", 200)
    console.log(`[rotation] BTC: ${btcCandles.length} candles`)
  } catch (e) {
    errors.push(`BTC fetch failed: ${e}`)
  }

  try {
    spyCandles = await fetchFMPCloses("SPY", fmpKey, 200)
    console.log(`[rotation] SPY: ${spyCandles.length} candles`)
  } catch (e) {
    errors.push(`SPY fetch failed: ${e}`)
  }

  if (btcCandles.length < 30 || spyCandles.length < 30) {
    return json({ error: "Insufficient price data", errors })
  }

  const btc7d = computeReturn(btcCandles, 7)
  const spy7d = computeReturn(spyCandles, 7)
  const btc30d = computeReturn(btcCandles, 30)
  const spy30d = computeReturn(spyCandles, 30)
  const btc90d = computeReturn(btcCandles, 90)
  const spy90d = computeReturn(spyCandles, 90)
  const btcYtd = computeYTDReturn(btcCandles)
  const spyYtd = computeYTDReturn(spyCandles)

  // ── Step 2: Fetch auxiliary signals from existing tables ───────────────

  // BTC + SPY positioning signals
  const { data: btcSignal } = await supabase
    .from("positioning_signals")
    .select("signal")
    .eq("asset", "BTC")
    .order("signal_date", { ascending: false })
    .limit(1)
    .maybeSingle()

  const { data: spySignal } = await supabase
    .from("positioning_signals")
    .select("signal")
    .eq("asset", "SPY")
    .order("signal_date", { ascending: false })
    .limit(1)
    .maybeSingle()

  // VIX + DXY
  const { data: vixSignal } = await supabase
    .from("positioning_signals")
    .select("price")
    .eq("asset", "VIX")
    .order("signal_date", { ascending: false })
    .limit(1)
    .maybeSingle()

  const { data: dxySignals } = await supabase
    .from("positioning_signals")
    .select("price, signal_date")
    .eq("asset", "DXY")
    .order("signal_date", { ascending: false })
    .limit(8)

  const vixLevel = vixSignal?.price ?? 20
  const dxyNow = dxySignals?.[0]?.price ?? 100
  const dxy7dAgo = dxySignals?.[7]?.price ?? dxyNow
  const dxyChange = dxy7dAgo > 0 ? ((dxyNow - dxy7dAgo) / dxy7dAgo) * 100 : 0
  const dxyTrend = dxyChange > 0.5 ? "strengthening" : dxyChange < -0.5 ? "weakening" : "flat"

  // Fear & Greed
  let fearGreedValue = 50
  let fearGreedTrend = "flat"
  try {
    const fngResp = await fetch("https://api.alternative.me/fng/?limit=8")
    const fngData = await fngResp.json()
    const fngEntries: Array<{ value: string }> = fngData.data ?? []
    if (fngEntries.length > 0) {
      fearGreedValue = parseInt(fngEntries[0].value) || 50
      const fng7dAgo = fngEntries.length >= 7 ? parseInt(fngEntries[6].value) || 50 : 50
      const fngDelta = fearGreedValue - fng7dAgo
      fearGreedTrend = fngDelta > 5 ? "rising" : fngDelta < -5 ? "falling" : "flat"
    }
  } catch (e) {
    errors.push(`Fear & Greed fetch failed: ${e}`)
  }

  // BTC dominance
  let btcDominance = 0
  let btcDomTrend = "flat"
  try {
    const globalResp = await fetch("https://api.coingecko.com/api/v3/global")
    const globalData = await globalResp.json()
    btcDominance = globalData.data?.market_cap_percentage?.btc ?? 0
  } catch (e) {
    errors.push(`BTC dominance fetch failed: ${e}`)
  }
  // Approximate trend from price action — rising BTC dom = BTC outperforming alts
  btcDomTrend = btc7d > 3 ? "rising" : btc7d < -3 ? "falling" : "flat"

  // ── Step 3: Compute rotation score ────────────────────────────────────

  const btcRisk = btcSignal?.signal ?? "neutral"
  const spyRisk = spySignal?.signal ?? "neutral"

  // Component 1: Relative performance (30%)
  const perfDelta = spy30d - btc30d
  const perfComponent = clamp(perfDelta * 2, -100, 100)

  // Component 2: Risk level comparison (20%)
  let riskComponent = 0
  const riskMap: Record<string, number> = { bullish: -1, neutral: 0, bearish: 1 }
  const btcRiskVal = riskMap[btcRisk] ?? 0
  const spyRiskVal = riskMap[spyRisk] ?? 0
  riskComponent = (spyRiskVal - btcRiskVal) * -30 // BTC bullish + SPY bearish = favor crypto

  // Component 3: Fear & Greed (15%)
  let fngComponent = 0
  if (fearGreedValue < 25 && fearGreedTrend === "rising") {
    fngComponent = -40 // Recovery from fear → favor crypto
  } else if (fearGreedValue > 75) {
    fngComponent = 20 // Euphoria → rotation risk
  } else if (fearGreedTrend === "falling" && fearGreedValue < 45) {
    fngComponent = 30 // Risk-off from crypto
  }

  // Component 4: DXY (15%)
  let dxyComponent = 0
  if (dxyChange > 2) dxyComponent = 60
  else if (dxyChange < -2) dxyComponent = -40
  else dxyComponent = dxyChange * 15

  // Component 5: BTC dominance (10%)
  let domComponent = 0
  if (btcDomTrend === "rising") domComponent = -20 // BTC accumulation phase
  else if (btcDomTrend === "falling") domComponent = 10

  // Component 6: VIX (10%)
  let vixComponent = 0
  if (vixLevel > 30) vixComponent = 80
  else if (vixLevel > 20) vixComponent = 30
  else if (vixLevel < 15) vixComponent = -10

  const rawScore =
    perfComponent * 0.30 +
    riskComponent * 0.20 +
    fngComponent * 0.15 +
    dxyComponent * 0.15 +
    domComponent * 0.10 +
    vixComponent * 0.10

  const rotationScore = Math.round(clamp(rawScore, -100, 100))

  // Derive regime
  let regime: string
  if (vixLevel > 30 && rotationScore > 0) {
    regime = "risk_off"
  } else if (rotationScore <= -30) {
    regime = "crypto_favored"
  } else if (rotationScore >= 30) {
    regime = "equity_favored"
  } else {
    regime = "neutral"
  }

  console.log(`[rotation] Score: ${rotationScore}, Regime: ${regime}`)
  console.log(`[rotation] BTC 30d: ${btc30d.toFixed(1)}%, SPY 30d: ${spy30d.toFixed(1)}%`)

  // ── Step 4: Compute sector performance ────────────────────────────────

  const sectorResults: SectorRow[] = []

  for (const sector of SECTORS) {
    try {
      const result = await computeSectorPerformance(sector, spy30d, fmpKey)
      if (result) sectorResults.push(result)
    } catch (e) {
      errors.push(`Sector ${sector.id} failed: ${e}`)
      console.error(`[rotation] Sector ${sector.id} failed: ${e}`)
    }
    await sleep(100)
  }

  // Sort by relative strength for logging
  sectorResults.sort((a, b) => (b.relative_strength_vs_spy ?? 0) - (a.relative_strength_vs_spy ?? 0))
  console.log(`[rotation] Computed ${sectorResults.length} sectors`)
  for (const s of sectorResults.slice(0, 5)) {
    console.log(`  ${s.sector_name}: RS ${(s.relative_strength_vs_spy ?? 0).toFixed(1)}%, top: ${s.top_performer} (${(s.top_performer_return ?? 0).toFixed(1)}%)`)
  }

  // ── Step 5: Generate narrative ────────────────────────────────────────

  let narrative = ""
  const topSectors = sectorResults.slice(0, 3).map((s) => s.sector_name).join(", ")
  const defensiveRank = sectorResults.findIndex((s) => s.sector_id === "defensives") + 1

  try {
    const prompt = `Given these market rotation inputs, write 1-2 concise sentences explaining the current crypto vs equities regime. Be specific about what's driving the signal. No emoji. Under 200 characters.

Score: ${rotationScore} (${regime})
BTC 30d return: ${btc30d.toFixed(1)}%
SPY 30d return: ${spy30d.toFixed(1)}%
BTC signal: ${btcRisk}, SPY signal: ${spyRisk}
Fear & Greed: ${fearGreedValue} (${fearGreedTrend})
DXY: ${dxyTrend} (${dxyChange.toFixed(1)}% 7d)
VIX: ${vixLevel.toFixed(1)}
BTC dominance: ${btcDominance.toFixed(1)}%
Top sectors: ${topSectors}
Defensives rank: ${defensiveRank} of ${sectorResults.length}`

    narrative = await callHaiku(anthropicKey, prompt)
    console.log(`[rotation] Narrative: ${narrative}`)
  } catch (e) {
    errors.push(`Narrative generation failed: ${e}`)
    narrative = `Rotation score ${rotationScore}: ${regime.replace("_", " ")}. BTC ${btc30d.toFixed(0)}% vs SPY ${spy30d.toFixed(0)}% over 30d.`
  }

  // ── Step 6: Upsert results ────────────────────────────────────────────

  const { error: rotError } = await supabase.from("rotation_signals").upsert(
    {
      signal_date: today,
      rotation_score: rotationScore,
      regime,
      narrative,
      btc_7d_return: btc7d,
      spy_7d_return: spy7d,
      btc_30d_return: btc30d,
      spy_30d_return: spy30d,
      btc_90d_return: btc90d,
      spy_90d_return: spy90d,
      btc_ytd_return: btcYtd,
      spy_ytd_return: spyYtd,
      btc_risk_level: btcRisk,
      spy_risk_level: spyRisk,
      fear_greed_value: fearGreedValue,
      fear_greed_trend: fearGreedTrend,
      dxy_trend: dxyTrend,
      dxy_value: dxyNow,
      vix_level: vixLevel,
      btc_dominance: btcDominance,
      btc_dominance_trend: btcDomTrend,
    },
    { onConflict: "signal_date" }
  )
  if (rotError) errors.push(`Rotation upsert failed: ${rotError.message}`)

  for (const sector of sectorResults) {
    const { error: secError } = await supabase.from("sector_performance").upsert(
      { ...sector, signal_date: today },
      { onConflict: "signal_date,sector_id" }
    )
    if (secError) errors.push(`Sector ${sector.sector_id} upsert failed: ${secError.message}`)
  }

  // ── Step 7: Detect regime change and notify ──────────────────────────────

  let regimeChanged = false
  let prevRegime: string | null = null
  try {
    const { data: prevSignal } = await supabase
      .from("rotation_signals")
      .select("regime")
      .lt("signal_date", today)
      .order("signal_date", { ascending: false })
      .limit(1)

    prevRegime = prevSignal?.[0]?.regime ?? null
    regimeChanged = prevRegime !== null && prevRegime !== regime

    if (regimeChanged) {
      const regimeDisplay = (r: string) => r.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase())
      const title = "Rotation Regime Shift"
      const body = `${regimeDisplay(prevRegime!)} → ${regimeDisplay(regime)}. ${narrative.slice(0, 120)}`

      console.log(`[rotation] Regime changed: ${prevRegime} → ${regime}, sending notification`)

      try {
        await fetch(`${supabaseUrl}/functions/v1/send-broadcast-notification`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${Deno.env.get("SUPABASE_ANON_KEY") ?? ""}`,
            "x-cron-secret": cronSecret,
          },
          body: JSON.stringify({
            broadcast_id: "rotation_signal",
            title,
            body,
            event_type: "rotation_regime_change",
            target_audience: { type: "all" },
          }),
        })
        console.log(`[rotation] Regime shift notification sent`)
      } catch (notifErr) {
        errors.push(`Notification failed: ${notifErr}`)
        console.error(`[rotation] Notification failed: ${notifErr}`)
      }
    }
  } catch (prevErr) {
    errors.push(`Regime change detection failed: ${prevErr}`)
  }

  const result = {
    date: today,
    rotation_score: rotationScore,
    regime,
    prev_regime: prevRegime,
    regime_changed: regimeChanged,
    narrative,
    sectors_computed: sectorResults.length,
    errors,
  }

  console.log(`[rotation] Complete: ${JSON.stringify(result)}`)
  return json(result)
})

// ─── Sector Performance Computation ────────────────────────────────────────

interface SectorRow {
  sector_id: string
  sector_name: string
  return_7d: number | null
  return_30d: number | null
  relative_strength_vs_spy: number | null
  top_performer: string | null
  top_performer_return: number | null
  stock_returns: Record<string, number>
  is_defensive: boolean
}

async function computeSectorPerformance(
  sector: SectorDef,
  spy30d: number,
  fmpKey: string
): Promise<SectorRow | null> {
  const stockReturns: Record<string, { r7d: number; r30d: number }> = {}

  for (const ticker of sector.stocks) {
    try {
      const closes = await fetchFMPCloses(ticker, fmpKey, 35)
      if (closes.length >= 30) {
        stockReturns[ticker] = {
          r7d: computeReturn(closes, 7),
          r30d: computeReturn(closes, 30),
        }
      }
    } catch {
      // Skip unavailable tickers
    }
    await sleep(100)
  }

  const tickers = Object.keys(stockReturns)
  if (tickers.length === 0) return null

  const avg7d = tickers.reduce((sum, t) => sum + stockReturns[t].r7d, 0) / tickers.length
  const avg30d = tickers.reduce((sum, t) => sum + stockReturns[t].r30d, 0) / tickers.length

  // Find top performer by 30d return
  let topTicker = tickers[0]
  let topReturn = stockReturns[tickers[0]].r30d
  for (const t of tickers) {
    if (stockReturns[t].r30d > topReturn) {
      topTicker = t
      topReturn = stockReturns[t].r30d
    }
  }

  return {
    sector_id: sector.id,
    sector_name: sector.name,
    return_7d: round2(avg7d),
    return_30d: round2(avg30d),
    relative_strength_vs_spy: round2(avg30d - spy30d),
    top_performer: topTicker,
    top_performer_return: round2(topReturn),
    stock_returns: Object.fromEntries(
      tickers.map((t) => [t, round2(stockReturns[t].r30d)])
    ),
    is_defensive: sector.isDefensive,
  }
}

// ─── Data Fetchers ─────────────────────────────────────────────────────────

async function fetchCoinbaseCloses(productId: string, days: number): Promise<number[]> {
  const now = Math.floor(Date.now() / 1000)
  const start = now - 86400 * days

  const url = `https://api.coinbase.com/api/v3/brokerage/market/products/${productId}/candles?start=${start}&end=${now}&granularity=ONE_DAY`
  const resp = await fetch(url)
  if (!resp.ok) throw new Error(`Coinbase ${productId} ${resp.status}`)

  const json = await resp.json()
  const candles: Array<{ close: string }> = json.candles ?? []
  return candles.map((c) => parseFloat(c.close)).reverse()
}

async function fetchFMPCloses(symbol: string, apiKey: string, days: number): Promise<number[]> {
  const url = `https://financialmodelingprep.com/stable/historical-price-eod/full?symbol=${encodeURIComponent(symbol)}&apikey=${apiKey}`
  const resp = await fetch(url)
  if (!resp.ok) throw new Error(`FMP ${symbol} ${resp.status}`)

  const json = await resp.json()
  const raw: Array<{ close: number }> = Array.isArray(json) ? json : (json.historical ?? [])

  // FMP returns newest first — take N days and reverse to chronological
  return raw.slice(0, days).map((c) => c.close).reverse()
}

// ─── Claude Haiku ──────────────────────────────────────────────────────────

async function callHaiku(apiKey: string, userMessage: string): Promise<string> {
  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 200,
      system:
        "You are a concise market rotation analyst. Write short, direct sentences about crypto vs equities allocation. No emoji. No hedging.",
      messages: [{ role: "user", content: userMessage }],
    }),
  })

  if (!resp.ok) {
    throw new Error(`Haiku ${resp.status}: ${await resp.text()}`)
  }

  const data = await resp.json()
  return data.content?.[0]?.text?.trim() ?? ""
}

// ─── Helpers ───────────────────────────────────────────────────────────────

function computeReturn(closes: number[], days: number): number {
  if (closes.length < days + 1) return 0
  const recent = closes[closes.length - 1]
  const past = closes[closes.length - 1 - days]
  return past > 0 ? ((recent - past) / past) * 100 : 0
}

function computeYTDReturn(closes: number[]): number {
  if (closes.length < 2) return 0
  const now = new Date()
  const jan1 = new Date(now.getFullYear(), 0, 1)
  const daysSinceJan1 = Math.floor((now.getTime() - jan1.getTime()) / 86400000)
  const idx = closes.length - 1 - Math.min(daysSinceJan1, closes.length - 1)
  const recent = closes[closes.length - 1]
  const start = closes[Math.max(0, idx)]
  return start > 0 ? ((recent - start) / start) * 100 : 0
}

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value))
}

function round2(n: number): number {
  return Math.round(n * 100) / 100
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms))
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
