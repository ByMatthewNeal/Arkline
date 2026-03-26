import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * fibonacci-pipeline Edge Function
 *
 * Multi-Asset Golden Pocket Strategy — 4H Entry / 1D Bias
 *
 * Runs every 30 minutes to catch bounces quickly.
 * Uses 1H candles for early bounce detection, 4H for trend/structure:
 *   1. Fetches 1h + 4h + 1D OHLC candles from Coinbase for each asset
 *   2. Detects swing highs/lows
 *   3. Computes 0.618/0.786 Fibonacci retracement levels
 *   4. Finds confluence zones across timeframes
 *   5. Checks EMA 20/50 trend alignment on 4h
 *   6. Evaluates bounce confirmation
 *   7. Generates signals with targets/stops
 *   8. Resolves open signals (T1, runner trail, SL, expiry)
 */

// ─── Multi-Asset Configuration ──────────────────────────────────────────────

interface AssetConfig {
  cbPair: string   // Coinbase product ID e.g. "BTC-USD"
  ticker: string   // Display ticker e.g. "BTC"
  tiers?: string[] // Which tiers to run: ["4h", "1h"] or subset. Default: both.
}

const ASSETS: AssetConfig[] = [
  // Top 10 — selected by live performance + 365-day backtest profit factor (2026-03-24)
  { cbPair: "BTC-USD",    ticker: "BTC" },    // Core asset, 3.48 PF
  { cbPair: "ETH-USD",    ticker: "ETH" },    // 4.52 PF, 57.1% live WR
  { cbPair: "SOL-USD",    ticker: "SOL" },    // 3.56 PF, 60.0% live WR
  { cbPair: "SUI-USD",    ticker: "SUI" },    // 4.51 PF, 72.7% live WR (best)
  { cbPair: "LINK-USD",   ticker: "LINK" },   // 4.31 PF, 62.5% live WR
  { cbPair: "ADA-USD",    ticker: "ADA" },    // 4.75 PF (highest backtest)
  { cbPair: "AVAX-USD",   ticker: "AVAX" },   // 3.62 PF, 100% live WR (n=3)
  { cbPair: "APT-USD",    ticker: "APT" },    // 3.53 PF, decent volume
  { cbPair: "XRP-USD",    ticker: "XRP" },    // 4.29 PF backtest
  { cbPair: "ATOM-USD",   ticker: "ATOM" },   // 4.50 PF, long-preferred
]

// Coinbase granularities: ONE_HOUR, TWO_HOUR, FOUR_HOUR, SIX_HOUR, ONE_DAY
const TIMEFRAME_CONFIGS = [
  { timeframe: "1h", granularity: "ONE_HOUR", limit: 100 },    // ~4 days, for faster bounce detection
  { timeframe: "4h", granularity: "FOUR_HOUR", limit: 250 },  // ~42 days, enough for EMA 50 + swing detection
  { timeframe: "1d", granularity: "ONE_DAY", limit: 200 },     // ~200 days (need 147+ for 21W EMA)
] as const

const SWING_PARAMS: Record<string, { lookback: number; minReversal: number }> = {
  "1h": { lookback: 10, minReversal: 2.5 },
  "4h": { lookback: 8, minReversal: 5.0 },
  "1d": { lookback: 5, minReversal: 8.0 },
}

// Only the golden pocket
const FIB_RATIOS = [0.618, 0.786]

const CONFLUENCE_TOLERANCE_PCT = 1.5
const SIGNAL_PROXIMITY_PCT = 3.0   // price must be within 3% of zone to evaluate
const MIN_RR_RATIO = 1.0
const STRONG_MIN_RR_RATIO = 2.0
const STRONG_MIN_CONFLUENCE = 2
const SIGNAL_EXPIRY_HOURS = 72       // 3 days

// ─── Tier Configuration ─────────────────────────────────────────────────────

interface TierConfig {
  tierName: string               // "4h" (swing) or "1h" (scalp)
  swingTimeframes: string[]      // which TFs to detect swings on
  trendTimeframe: string         // which TF for EMA trend check
  bounceTimeframes: string[]     // ordered preference for bounce check
  signalProximityPct: number
  confluenceTolerancePct: number
  expiryHours: number
}

const TIER_SWING: TierConfig = {
  tierName: "4h",
  swingTimeframes: ["4h", "1d"],
  trendTimeframe: "4h",
  bounceTimeframes: ["1h", "4h"],
  signalProximityPct: 3.0,
  confluenceTolerancePct: 1.5,
  expiryHours: 72,
}

const TIER_SCALP: TierConfig = {
  tierName: "1h",
  swingTimeframes: ["1h", "4h"],
  trendTimeframe: "4h",
  bounceTimeframes: ["1h"],
  signalProximityPct: 2.0,
  confluenceTolerancePct: 1.0,
  expiryHours: 48,
}
const WICK_REJECTION_RATIO = 1.2
const VOLUME_SPIKE_RATIO = 1.15

// EMA periods for trend filter
const EMA_FAST_PERIOD = 20
const EMA_SLOW_PERIOD = 50
const EMA_SLOPE_LOOKBACK = 6  // 6 x 4h = 24h for slope check
const EMA_PULLBACK_TOLERANCE = 0.015

// Delay between assets to stay safe on Binance rate limits
const INTER_ASSET_DELAY_MS = 100

// ─── Types ───────────────────────────────────────────────────────────────────

interface Candle {
  open_time: string
  open: number
  high: number
  low: number
  close: number
  volume: number
}

interface SwingPoint {
  type: "high" | "low"
  price: number
  candle_time: string
  reversal_pct: number
}

interface FibLevel {
  timeframe: string
  ratio: number
  price: number
  direction: "from_high" | "from_low"
}

interface ConfluenceZone {
  low: number
  high: number
  mid: number
  strength: number
  zone_type: "support" | "resistance"
  tf_count: number
  levels: FibLevel[]
}

interface ChartPattern {
  name: string           // e.g., "Bullish Double Bottom", "Bearish Head and Shoulders"
  type: "reversal" | "continuation"
  bias: "bullish" | "bearish"
  timeframe: "4h" | "1d"
  confidence: number     // 0-100
  description: string    // 1-2 sentence description
  neckline?: number      // Key breakout level if applicable
  target?: number        // Measured move target
}

// ─── Main Handler ────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405)
  }

  const secret = req.headers.get("x-cron-secret") ?? ""
  const expectedSecret = Deno.env.get("CRON_SECRET") ?? ""
  if (!expectedSecret || secret !== expectedSecret) {
    return jsonResponse({ error: "Unauthorized" }, 401)
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )

  // Parse request body for batch parameter
  let requestBody: Record<string, unknown> = {}
  try { requestBody = await req.json() } catch {}

  // Split assets into batches: batch=0 (first half), batch=1 (second half), undefined = all
  const batchIndex = typeof requestBody.batch === "number" ? requestBody.batch : undefined
  const midpoint = Math.ceil(ASSETS.length / 2)
  const assetsToProcess = batchIndex === 0
    ? ASSETS.slice(0, midpoint)
    : batchIndex === 1
      ? ASSETS.slice(midpoint)
      : ASSETS
  console.log(`Processing batch=${batchIndex ?? "all"}: ${assetsToProcess.map(a => a.ticker).join(", ")}`)

  const allResults: Record<string, unknown> = {}

  // Fetch macro context once for all assets
  let fearGreedIndex: number | undefined
  let btcRiskScore: number | undefined
  try {
    const fgResp = await fetch("https://api.alternative.me/fng/?limit=1")
    if (fgResp.ok) {
      const fgData = await fgResp.json()
      fearGreedIndex = fgData?.data?.[0]?.value ? Number(fgData.data[0].value) : undefined
    }
  } catch (err) {
    console.error(`Fear & Greed fetch failed: ${err}`)
  }
  try {
    const { data: riskRow } = await supabase
      .from("trade_signals")
      .select("composite_score")
      .eq("asset", "BTC")
      .in("status", ["active", "triggered"])
      .order("created_at", { ascending: false })
      .limit(1)
    btcRiskScore = riskRow?.[0]?.composite_score ? Number(riskRow[0].composite_score) : undefined
  } catch (err) {
    console.error(`BTC risk score fetch failed: ${err}`)
  }

  try {
    // Process assets in parallel batches of 3 to stay within compute limits
    for (let batchStart = 0; batchStart < assetsToProcess.length; batchStart += 3) {
      const batch = assetsToProcess.slice(batchStart, batchStart + 3)
      const batchResults = await Promise.all(batch.map(async (asset) => {
        const assetResults: Record<string, unknown> = {}

        // Fetch latest candles
        const candles = await fetchCandles(asset.cbPair)
        assetResults.candles = { "1h": candles["1h"]?.length ?? 0, "4h": candles["4h"].length, "1d": candles["1d"].length }

        // Store candles in DB
        await storeCandles(supabase, asset.ticker, candles)

        // Resolve open signals against latest candle
        const resolveResult = await resolveOpenSignals(supabase, asset.ticker, candles)
        assetResults.resolved = resolveResult

        if (candles["4h"].length === 0) {
          assetResults.skipped = "No 4h candles"
          return { ticker: asset.ticker, results: assetResults }
        }

        const currentPrice = candles["4h"][candles["4h"].length - 1].close

        // Compute volume profile from 4h candles (shared across tiers)
        const volumeNodes = computeVolumeProfile(candles["4h"])
        const enabledTiers = asset.tiers ?? ["4h", "1h"]  // Both swing + scalp tiers

        // ── Tier 1: Swing (4H/1D) ──────────────────────────────────────
        if (enabledTiers.includes("4h")) {
          const swingsSwing = detectAllSwings(candles, TIER_SWING.swingTimeframes)
          await storeSwings(supabase, asset.ticker, swingsSwing)
          assetResults.swings = { "4h": swingsSwing["4h"]?.length ?? 0, "1d": swingsSwing["1d"]?.length ?? 0 }

          const fibsSwing = computeAllFibs(swingsSwing)
          await storeFibs(supabase, asset.ticker, fibsSwing)
          assetResults.fibs = fibsSwing.length

          const zonesSwing = clusterLevels(fibsSwing, currentPrice, TIER_SWING.confluenceTolerancePct)
          await storeZones(supabase, asset.ticker, zonesSwing, currentPrice)
          assetResults.zones = zonesSwing.length

          const swingSignals = await evaluateSignals(supabase, asset.ticker, candles, zonesSwing, fibsSwing, currentPrice, volumeNodes, fearGreedIndex, btcRiskScore, swingsSwing, TIER_SWING)
          assetResults.newSignals = swingSignals
        }

        // ── Tier 2: Scalp (1H/4H) ──────────────────────────────────────
        if (enabledTiers.includes("1h")) {
          const swingsScalp = detectAllSwings(candles, TIER_SCALP.swingTimeframes)
          const fibsScalp = computeAllFibs(swingsScalp)
          const zonesScalp = clusterLevels(fibsScalp, currentPrice, TIER_SCALP.confluenceTolerancePct)

          const scalpSignals = await evaluateSignals(supabase, asset.ticker, candles, zonesScalp, fibsScalp, currentPrice, volumeNodes, fearGreedIndex, btcRiskScore, swingsScalp, TIER_SCALP)
          assetResults.scalpSignals = scalpSignals
        }

        await pruneOldCandles(supabase, asset.ticker)

        return { ticker: asset.ticker, results: assetResults }
      }))

      for (const { ticker, results } of batchResults) {
        allResults[ticker] = results
      }
    }

    // ── Compute & store market conditions summary ──
    const conditionsSummary = computeMarketConditions(allResults)
    await supabase.from("market_data_cache").upsert({
      key: "signal_market_conditions",
      data: conditionsSummary,
      updated_at: new Date().toISOString(),
    }, { onConflict: "key" })

    return jsonResponse({ success: true, assets: allResults })
  } catch (err) {
    return jsonResponse({ error: "Pipeline failed", detail: String(err), partial: allResults }, 500)
  }
})

// ─── Market Conditions Summary ───────────────────────────────────────────────

function computeMarketConditions(allResults: Record<string, any>): {
  status: string
  headline: string
  detail: string
  topReasons: string[]
  totalSkipped: number
  totalGenerated: number
  updatedAt: string
} {
  const reasonCounts: Record<string, number> = {}
  let totalSkipped = 0
  let totalGenerated = 0

  for (const [, asset] of Object.entries(allResults)) {
    for (const key of ["newSignals", "scalpSignals"]) {
      const s = asset[key]
      if (!s) continue
      totalGenerated += s.generated ?? 0
      totalSkipped += s.skipped ?? 0
      for (const reason of s.skipReasons ?? []) {
        // Normalize: strip asset-specific price info to group similar reasons
        const normalized = reason
          .replace(/^(support|resistance) @[\d.]+: /, "")
          .replace(/\(price=[\d.]+\)/, "")
          .replace(/R:R [\d.]+ < [\d.]+/, "R:R too low")
          .replace(/score \d+ < 60/, "score below B-grade")
          .trim()
        reasonCounts[normalized] = (reasonCounts[normalized] ?? 0) + 1
      }
    }
  }

  const topReasons = Object.entries(reasonCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([reason, count]) => {
      const label = `${reason.charAt(0).toUpperCase()}${reason.slice(1)}`
      return `${label} — ${count} asset${count === 1 ? "" : "s"}`
    })

  const now = new Date().toISOString()

  if (totalGenerated > 0) {
    return {
      status: "active",
      headline: `${totalGenerated} signal${totalGenerated > 1 ? "s" : ""} generated`,
      detail: "The pipeline found setups that meet all quality criteria.",
      topReasons,
      totalSkipped,
      totalGenerated,
      updatedAt: now,
    }
  }

  // Determine dominant reason
  const dominant = Object.entries(reasonCounts).sort((a, b) => b[1] - a[1])[0]
  let headline = "Markets are choppy — no setups right now"
  let detail = "Price is ranging between levels without clean entries."

  if (dominant) {
    const [reason] = dominant
    if (reason.includes("no bounce")) {
      headline = "Zones identified, waiting for bounce confirmation"
      detail = "Price is near Fibonacci zones but hasn't shown a rejection candle yet. Signals fire after a confirmed bounce."
    } else if (reason.includes("EMA") || reason.includes("misalign")) {
      headline = "Trend isn't aligned with nearby zones"
      detail = "Support zones are nearby but the trend is bearish, or resistance zones are nearby but the trend is bullish. Waiting for alignment."
    } else if (reason.includes("R:R")) {
      headline = "Ranges are too tight for clean entries"
      detail = "Fibonacci zones exist but the risk-to-reward ratio is below 1:1. Waiting for price to stretch into better setups."
    } else if (reason.includes("score")) {
      headline = "Setups found but quality is below threshold"
      detail = "Potential signals didn't meet the B-grade (60+) composite score. This filters out low-conviction trades."
    }
  }

  return {
    status: "quiet",
    headline,
    detail,
    topReasons,
    totalSkipped,
    totalGenerated,
    updatedAt: now,
  }
}

// ─── Fetch Candles from Binance ──────────────────────────────────────────────

async function fetchCandles(cbPair: string): Promise<Record<string, Candle[]>> {
  const result: Record<string, Candle[]> = {}

  for (const config of TIMEFRAME_CONFIGS) {
    const url = `https://api.coinbase.com/api/v3/brokerage/market/products/${cbPair}/candles?granularity=${config.granularity}&limit=${config.limit}`
    const res = await fetch(url, { headers: { Accept: "application/json" } })

    if (!res.ok) {
      console.error(`Coinbase candles failed for ${cbPair} ${config.timeframe}: ${res.status}`)
      result[config.timeframe] = []
      continue
    }

    const data: { candles: { start: string; low: string; high: string; open: string; close: string; volume: string }[] } = await res.json()
    // Coinbase returns newest-first, reverse to oldest-first for indicator calculations
    result[config.timeframe] = data.candles.reverse().map((k) => ({
      open_time: new Date(Number(k.start) * 1000).toISOString(),
      open: parseFloat(k.open),
      high: parseFloat(k.high),
      low: parseFloat(k.low),
      close: parseFloat(k.close),
      volume: parseFloat(k.volume),
    }))

    await sleep(100)
  }

  return result
}

async function storeCandles(supabase: SupabaseClient, ticker: string, candles: Record<string, Candle[]>) {
  for (const [tf, tfCandles] of Object.entries(candles)) {
    if (tfCandles.length === 0) continue

    const rows = tfCandles.map((c) => ({
      asset: ticker,
      timeframe: tf,
      open_time: c.open_time,
      open: c.open,
      high: c.high,
      low: c.low,
      close: c.close,
      volume: c.volume,
    }))

    // Batch upsert in chunks of 500
    for (let i = 0; i < rows.length; i += 500) {
      await supabase
        .from("ohlc_candles")
        .upsert(rows.slice(i, i + 500), { onConflict: "asset,timeframe,open_time" })
    }
  }
}

async function pruneOldCandles(supabase: SupabaseClient, ticker: string) {
  const now = new Date()
  const retentionDays: Record<string, number> = { "1h": 7, "4h": 60, "1d": 180 }

  for (const [tf, days] of Object.entries(retentionDays)) {
    const cutoff = new Date(now.getTime() - days * 86400000).toISOString()
    await supabase
      .from("ohlc_candles")
      .delete()
      .eq("asset", ticker)
      .eq("timeframe", tf)
      .lt("open_time", cutoff)
  }
}

// ─── Swing Detection ─────────────────────────────────────────────────────────

function detectAllSwings(candles: Record<string, Candle[]>, timeframes?: string[]): Record<string, SwingPoint[]> {
  const result: Record<string, SwingPoint[]> = {}
  const tfs = timeframes ?? Object.keys(candles)

  for (const tf of tfs) {
    const tfCandles = candles[tf]
    const params = SWING_PARAMS[tf]
    if (!params || !tfCandles || tfCandles.length < params.lookback * 2 + 1) {
      result[tf] = []
      continue
    }
    result[tf] = detectSwings(tfCandles, params.lookback, params.minReversal)
  }

  return result
}

function detectSwings(candles: Candle[], lookback: number, minReversal: number): SwingPoint[] {
  const swings: SwingPoint[] = []

  for (let i = lookback; i < candles.length - lookback; i++) {
    const c = candles[i]

    // Swing high
    let isHigh = true
    for (let j = i - lookback; j <= i + lookback; j++) {
      if (j !== i && candles[j].high >= c.high) { isHigh = false; break }
    }
    if (isHigh) {
      const surroundingLows = []
      for (let j = Math.max(0, i - lookback); j <= Math.min(candles.length - 1, i + lookback); j++) {
        if (j !== i) surroundingLows.push(candles[j].low)
      }
      if (surroundingLows.length > 0) {
        const minLow = Math.min(...surroundingLows)
        const reversalPct = ((c.high - minLow) / minLow) * 100
        if (reversalPct >= minReversal) {
          swings.push({ type: "high", price: c.high, candle_time: c.open_time, reversal_pct: reversalPct })
        }
      }
    }

    // Swing low
    let isLow = true
    for (let j = i - lookback; j <= i + lookback; j++) {
      if (j !== i && candles[j].low <= c.low) { isLow = false; break }
    }
    if (isLow) {
      const surroundingHighs = []
      for (let j = Math.max(0, i - lookback); j <= Math.min(candles.length - 1, i + lookback); j++) {
        if (j !== i) surroundingHighs.push(candles[j].high)
      }
      if (surroundingHighs.length > 0) {
        const maxHigh = Math.max(...surroundingHighs)
        const reversalPct = ((maxHigh - c.low) / c.low) * 100
        if (reversalPct >= minReversal) {
          swings.push({ type: "low", price: c.low, candle_time: c.open_time, reversal_pct: reversalPct })
        }
      }
    }
  }

  return swings
}

async function storeSwings(supabase: SupabaseClient, ticker: string, swings: Record<string, SwingPoint[]>) {
  for (const [tf, tfSwings] of Object.entries(swings)) {
    if (tfSwings.length === 0) continue

    // Deactivate old swings
    await supabase
      .from("swing_points")
      .update({ is_active: false })
      .eq("asset", ticker)
      .eq("timeframe", tf)
      .eq("is_active", true)

    // Insert new swings
    for (const sp of tfSwings) {
      await supabase
        .from("swing_points")
        .upsert({
          asset: ticker,
          timeframe: tf,
          type: sp.type,
          price: sp.price,
          candle_time: sp.candle_time,
          reversal_pct: Math.round(sp.reversal_pct * 100) / 100,
          is_active: true,
        }, { onConflict: "asset,timeframe,type,candle_time" })
    }
  }
}

// ─── Fibonacci Levels ────────────────────────────────────────────────────────

function computeAllFibs(swings: Record<string, SwingPoint[]>): FibLevel[] {
  const allLevels: FibLevel[] = []

  for (const [tf, tfSwings] of Object.entries(swings)) {
    const highs = tfSwings
      .filter((s) => s.type === "high")
      .sort((a, b) => new Date(b.candle_time).getTime() - new Date(a.candle_time).getTime())
      .slice(0, 3)

    const lows = tfSwings
      .filter((s) => s.type === "low")
      .sort((a, b) => new Date(b.candle_time).getTime() - new Date(a.candle_time).getTime())
      .slice(0, 3)

    for (const sh of highs) {
      for (const sl of lows) {
        if (sh.price <= sl.price) continue
        const diff = sh.price - sl.price

        for (const ratio of FIB_RATIOS) {
          // Retracement from high (support for longs)
          allLevels.push({
            timeframe: tf,
            ratio,
            price: sh.price - diff * ratio,
            direction: "from_high",
          })
          // Retracement from low (resistance for shorts)
          allLevels.push({
            timeframe: tf,
            ratio,
            price: sl.price + diff * ratio,
            direction: "from_low",
          })
        }
      }
    }
  }

  return allLevels
}

async function storeFibs(supabase: SupabaseClient, ticker: string, _fibs: FibLevel[]) {
  // Mark old fibs as not current
  await supabase.from("fib_levels").update({ is_current: false })
    .eq("asset", ticker).eq("is_current", true)

  // We store a simplified representation — group by timeframe/direction pair
  // For the app, the confluence zones are what matter most
  // Fibs are stored for debugging/visualization
}

// ─── Confluence Clustering ───────────────────────────────────────────────────

function clusterLevels(fibs: FibLevel[], currentPrice: number, tolerancePct?: number): ConfluenceZone[] {
  const tolerance = tolerancePct ?? CONFLUENCE_TOLERANCE_PCT
  if (fibs.length === 0) return []

  // Filter to levels within 15% of current price
  const nearby = fibs
    .filter((l) => Math.abs((l.price - currentPrice) / currentPrice) * 100 <= 15)
    .sort((a, b) => a.price - b.price)

  if (nearby.length === 0) return []

  const clusters: ConfluenceZone[] = []
  let currentCluster: FibLevel[] = [nearby[0]]
  let clusterLow = nearby[0].price
  let clusterHigh = nearby[0].price

  for (let i = 1; i < nearby.length; i++) {
    const level = nearby[i]
    const clusterMid = (clusterLow + clusterHigh) / 2
    const distancePct = Math.abs((level.price - clusterMid) / clusterMid) * 100

    if (distancePct <= tolerance) {
      currentCluster.push(level)
      clusterHigh = Math.max(clusterHigh, level.price)
      clusterLow = Math.min(clusterLow, level.price)
    } else {
      if (currentCluster.length >= 2) {
        const mid = (clusterLow + clusterHigh) / 2
        const tfs = new Set(currentCluster.map((l) => l.timeframe))
        clusters.push({
          low: clusterLow,
          high: clusterHigh,
          mid,
          strength: currentCluster.length,
          zone_type: mid < currentPrice ? "support" : "resistance",
          tf_count: tfs.size,
          levels: [...currentCluster],
        })
      }
      currentCluster = [level]
      clusterLow = level.price
      clusterHigh = level.price
    }
  }

  if (currentCluster.length >= 2) {
    const mid = (clusterLow + clusterHigh) / 2
    const tfs = new Set(currentCluster.map((l) => l.timeframe))
    clusters.push({
      low: clusterLow,
      high: clusterHigh,
      mid,
      strength: currentCluster.length,
      zone_type: mid < currentPrice ? "support" : "resistance",
      tf_count: tfs.size,
      levels: [...currentCluster],
    })
  }

  return clusters
}

async function storeZones(supabase: SupabaseClient, ticker: string, zones: ConfluenceZone[], currentPrice: number) {
  // Deactivate old zones
  await supabase.from("fib_confluence_zones")
    .update({ is_active: false })
    .eq("asset", ticker)
    .eq("is_active", true)

  for (const zone of zones) {
    const distancePct = Math.abs((zone.mid - currentPrice) / currentPrice) * 100
    await supabase.from("fib_confluence_zones").insert({
      asset: ticker,
      zone_type: zone.zone_type,
      zone_low: zone.low,
      zone_high: zone.high,
      zone_mid: zone.mid,
      strength: zone.strength,
      contributing_levels: zone.levels.map((l) => ({
        timeframe: l.timeframe,
        level_name: `${l.direction}_${l.ratio}`,
        price: l.price,
      })),
      distance_pct: Math.round(distancePct * 100) / 100,
      is_active: true,
    })
  }
}

// ─── EMA Trend Filter ────────────────────────────────────────────────────────

function calcEma(candles: Candle[], period: number): number | null {
  if (candles.length < period) return null
  const multiplier = 2 / (period + 1)
  let ema = 0
  for (let i = 0; i < period; i++) ema += candles[i].close
  ema /= period
  for (let i = period; i < candles.length; i++) {
    ema = (candles[i].close - ema) * multiplier + ema
  }
  return ema
}

function checkTrendAlignment(candles4h: Candle[], isBuy: boolean): boolean {
  if (candles4h.length < EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK) return true

  const emaFast = calcEma(candles4h, EMA_FAST_PERIOD)
  const emaSlow = calcEma(candles4h, EMA_SLOW_PERIOD)
  const emaSlowPrev = calcEma(candles4h.slice(0, -EMA_SLOPE_LOOKBACK), EMA_SLOW_PERIOD)

  if (emaFast === null || emaSlow === null || emaSlowPrev === null) return true

  const price = candles4h[candles4h.length - 1].close
  const emaSlopeUp = emaSlow > emaSlowPrev
  const emaSlopeDown = emaSlow < emaSlowPrev

  if (isBuy) {
    const trendOk = emaFast > emaSlow
    const pullbackOk = emaSlopeUp && Math.abs(price - emaSlow) / emaSlow < EMA_PULLBACK_TOLERANCE
    return trendOk || pullbackOk
  } else {
    const trendOk = emaFast < emaSlow
    const pullbackOk = emaSlopeDown && Math.abs(price - emaSlow) / emaSlow < EMA_PULLBACK_TOLERANCE
    return trendOk || pullbackOk
  }
}

/**
 * Daily-timeframe trend guard — blocks shorts in clear daily uptrends.
 * Asymmetric by design: longs are NEVER blocked because this strategy's
 * best edge is buying support during pullbacks (even in "downtrends").
 * Returns true if the signal direction is allowed.
 */
function checkDailyTrendGuard(dailyCandles: Candle[], isBuy: boolean): boolean {
  // Never block longs — buying pullbacks is the strategy's core edge
  if (isBuy) return true

  if (dailyCandles.length < EMA_SLOW_PERIOD + 5) return true  // Not enough data, allow

  const emaFast = calcEma(dailyCandles, EMA_FAST_PERIOD)
  const emaSlow = calcEma(dailyCandles, EMA_SLOW_PERIOD)
  const emaSlowPrev = calcEma(dailyCandles.slice(0, -5), EMA_SLOW_PERIOD)  // 5-day slope

  if (emaFast === null || emaSlow === null || emaSlowPrev === null) return true

  const spread = Math.abs(emaFast - emaSlow) / emaSlow * 100
  const slopeUp = emaSlow > emaSlowPrev

  // Block shorts when daily trend is clearly bullish: EMA20 > EMA50, slope rising, spread > 1%
  if (emaFast > emaSlow && slopeUp && spread > 1.0) {
    return false
  }

  return true
}

// ─── Choppiness Detector ─────────────────────────────────────────────────────

interface MarketRegime {
  isChoppy: boolean
  emaSpreadPct: number
  crossoverCount: number
  priceWhipsaws: number
}

/**
 * Detects choppy/ranging market conditions on 4H timeframe.
 * Choppy = EMAs close together, frequent crossovers, price whipsawing around EMA20.
 * Returns regime info used to raise signal quality thresholds.
 */
function detectMarketRegime(candles4h: Candle[]): MarketRegime {
  const regime: MarketRegime = { isChoppy: false, emaSpreadPct: 0, crossoverCount: 0, priceWhipsaws: 0 }

  if (candles4h.length < EMA_SLOW_PERIOD + 20) return regime

  // Compute EMA series for crossover detection
  const closes = candles4h.map(c => c.close)
  const mult20 = 2 / (EMA_FAST_PERIOD + 1)
  const mult50 = 2 / (EMA_SLOW_PERIOD + 1)

  // Bootstrap EMA20
  let ema20 = 0
  for (let i = 0; i < EMA_FAST_PERIOD; i++) ema20 += closes[i]
  ema20 /= EMA_FAST_PERIOD
  for (let i = EMA_FAST_PERIOD; i < EMA_SLOW_PERIOD; i++) {
    ema20 = (closes[i] - ema20) * mult20 + ema20
  }

  // Bootstrap EMA50
  let ema50 = 0
  for (let i = 0; i < EMA_SLOW_PERIOD; i++) ema50 += closes[i]
  ema50 /= EMA_SLOW_PERIOD

  // Walk forward from EMA_SLOW_PERIOD, tracking last 20 candles (~3.3 days)
  const lookback = 20
  let prevAbove = ema20 > ema50
  const recentEma20Above: boolean[] = []
  const recentPriceAboveEma20: boolean[] = []

  for (let i = EMA_SLOW_PERIOD; i < closes.length; i++) {
    ema20 = (closes[i] - ema20) * mult20 + ema20
    ema50 = (closes[i] - ema50) * mult50 + ema50

    const above = ema20 > ema50
    recentEma20Above.push(above)
    recentPriceAboveEma20.push(closes[i] > ema20)

    // Keep only last N
    if (recentEma20Above.length > lookback) recentEma20Above.shift()
    if (recentPriceAboveEma20.length > lookback) recentPriceAboveEma20.shift()

    prevAbove = above
  }

  // Current EMA spread
  regime.emaSpreadPct = Math.abs(ema20 - ema50) / ema50 * 100

  // Count EMA20/EMA50 crossovers in lookback
  for (let i = 1; i < recentEma20Above.length; i++) {
    if (recentEma20Above[i] !== recentEma20Above[i - 1]) regime.crossoverCount++
  }

  // Count price/EMA20 whipsaws in lookback
  for (let i = 1; i < recentPriceAboveEma20.length; i++) {
    if (recentPriceAboveEma20[i] !== recentPriceAboveEma20[i - 1]) regime.priceWhipsaws++
  }

  // Choppy if: EMAs tight AND (crossovers or whipsaws are frequent)
  const tightSpread = regime.emaSpreadPct < 1.5
  const frequentCrossovers = regime.crossoverCount >= 2
  const frequentWhipsaws = regime.priceWhipsaws >= 6
  regime.isChoppy = tightSpread && (frequentCrossovers || frequentWhipsaws)

  return regime
}

// ─── Momentum Filter ─────────────────────────────────────────────────────────

/**
 * Blocks shorts when price has rallied strongly in the last N daily candles (bounce in progress).
 * Blocks longs when price has dropped sharply in the last N daily candles (selloff in progress).
 * Prevents entering against active short-term momentum even when the larger trend "agrees".
 */
function checkMomentumFilter(dailyCandles: Candle[], isBuy: boolean): boolean {
  const lookback = 5   // 5 daily candles
  const threshold = 5  // 5% move

  if (dailyCandles.length < lookback + 1) return true  // Not enough data, allow

  const current = dailyCandles[dailyCandles.length - 1].close
  const past = dailyCandles[dailyCandles.length - 1 - lookback].close
  const changePct = ((current - past) / past) * 100

  // Block shorts during strong bounce (price up 5%+ in 5 days)
  if (!isBuy && changePct >= threshold) return false

  // Block longs during sharp selloff (price down 5%+ in 5 days)
  if (isBuy && changePct <= -threshold) return false

  return true
}

// ─── Bull Market Support Band ────────────────────────────────────────────────

const BMSB_SMA_PERIOD = 140  // 20 weeks × 7 days
const BMSB_EMA_PERIOD = 147  // 21 weeks × 7 days

function calcSma(candles: Candle[], period: number): number | null {
  if (candles.length < period) return null
  let sum = 0
  for (let i = candles.length - period; i < candles.length; i++) {
    sum += candles[i].close
  }
  return sum / period
}

function checkBMSB(dailyCandles: Candle[], currentPrice: number, isBuy: boolean): boolean {
  /**
   * Bull Market Support Band: 20W SMA + 21W EMA
   * Returns true if signal direction CONFLICTS with the macro regime (= counter-trend).
   *
   * Price ABOVE both → bullish → shorts are counter-trend
   * Price BELOW both → bearish → longs are counter-trend
   * Price BETWEEN → neutral → nothing is counter-trend
   */
  if (dailyCandles.length < BMSB_EMA_PERIOD) return false  // Not enough data, assume not counter-trend

  const sma20w = calcSma(dailyCandles, BMSB_SMA_PERIOD)
  const ema21w = calcEma(dailyCandles, BMSB_EMA_PERIOD)

  if (sma20w === null || ema21w === null) return false

  const bandTop = Math.max(sma20w, ema21w)
  const bandBottom = Math.min(sma20w, ema21w)

  if (currentPrice > bandTop) {
    // Bullish regime — shorts are counter-trend
    return !isBuy
  } else if (currentPrice < bandBottom) {
    // Bearish regime — longs are counter-trend
    return isBuy
  }
  // In the band — neutral
  return false
}

// ─── Volume Profile ─────────────────────────────────────────────────────────

interface VolumeNode {
  priceLow: number
  priceHigh: number
  priceMid: number
  volume: number
  relativeVolume: number
}

interface VolumeConfluenceResult {
  has_volume_confluence: boolean
  volume_node_count: number
  max_relative_volume: number
}

function computeVolumeProfile(candles: Candle[], numBins = 50): VolumeNode[] {
  if (candles.length < 20) return []

  const highs = candles.map(c => c.high)
  const lows = candles.map(c => c.low)
  const priceMax = Math.max(...highs)
  const priceMin = Math.min(...lows)
  const range = priceMax - priceMin
  if (range <= 0) return []

  const binSize = range / numBins
  const bins = new Array(numBins).fill(0)

  // Distribute volume across bins using typical price
  for (const c of candles) {
    const typical = (c.high + c.low + c.close) / 3
    const binIdx = Math.min(Math.floor((typical - priceMin) / binSize), numBins - 1)
    bins[binIdx] += c.volume
  }

  const avgVol = bins.reduce((a, b) => a + b, 0) / numBins
  if (avgVol <= 0) return []

  // Return high-volume nodes (>1.5x average)
  const nodes: VolumeNode[] = []
  for (let i = 0; i < numBins; i++) {
    const relVol = bins[i] / avgVol
    if (relVol >= 1.5) {
      nodes.push({
        priceLow: priceMin + i * binSize,
        priceHigh: priceMin + (i + 1) * binSize,
        priceMid: priceMin + (i + 0.5) * binSize,
        volume: bins[i],
        relativeVolume: Math.round(relVol * 100) / 100,
      })
    }
  }

  return nodes
}

function checkVolumeConfluence(zone: ConfluenceZone, volumeNodes: VolumeNode[]): VolumeConfluenceResult {
  const result: VolumeConfluenceResult = { has_volume_confluence: false, volume_node_count: 0, max_relative_volume: 0 }

  for (const node of volumeNodes) {
    // Check overlap: node range intersects zone range, or node mid is within 1% of zone mid
    const overlaps = node.priceHigh >= zone.low && node.priceLow <= zone.high
    const nearby = Math.abs(node.priceMid - zone.mid) / zone.mid < 0.01
    if (overlaps || nearby) {
      result.has_volume_confluence = true
      result.volume_node_count++
      result.max_relative_volume = Math.max(result.max_relative_volume, node.relativeVolume)
    }
  }

  result.max_relative_volume = Math.round(result.max_relative_volume * 100) / 100
  return result
}

// ─── Composite Signal Scoring ───────────────────────────────────────────────

function computeCompositeScore(params: {
  zone: ConfluenceZone
  candles4h: Candle[]
  bounce: { confirmed: boolean; details: Record<string, boolean> }
  volumeConfluence: VolumeConfluenceResult
  isBuy: boolean
  rrRatio: number
  counterTrend: boolean
  fearGreedIndex?: number
  btcRiskScore?: number
}): number {
  let score = 0

  // 1. Confluence Depth (0-30 pts)
  const strength = params.zone.strength
  if (strength >= 4) score += 30
  else if (strength >= 3) score += 20
  else score += 10
  // Multi-timeframe bonus
  if (params.zone.tf_count >= 2) score += 5
  score = Math.min(score, 35) // Cap this bucket

  // 2. EMA Alignment Strength (0-20 pts)
  if (params.candles4h.length >= EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK) {
    const emaFast = calcEma(params.candles4h, EMA_FAST_PERIOD)
    const emaSlow = calcEma(params.candles4h, EMA_SLOW_PERIOD)
    const emaSlowPrev = calcEma(params.candles4h.slice(0, -EMA_SLOPE_LOOKBACK), EMA_SLOW_PERIOD)

    if (emaFast !== null && emaSlow !== null && emaSlowPrev !== null) {
      const price = params.candles4h[params.candles4h.length - 1].close
      const spread = Math.abs(emaFast - emaSlow) / emaSlow * 100
      const slopeStrength = Math.abs(emaSlow - emaSlowPrev) / emaSlowPrev * 100

      // Directional alignment
      const aligned = params.isBuy ? emaFast > emaSlow : emaFast < emaSlow
      if (aligned) {
        score += 10
        if (spread > 1.0) score += 5
        if (slopeStrength > 0.3) score += 5
      } else {
        // Pullback to EMA scenario — partial credit
        if (Math.abs(price - emaSlow) / emaSlow < EMA_PULLBACK_TOLERANCE) score += 8
      }
    }
  }

  // 3. Volume Confirmation Quality (0-20 pts)
  let volScore = 0
  if (params.bounce.details.wick_rejection) volScore += 8
  if (params.bounce.details.volume_spike) volScore += 8
  if (params.bounce.details.consecutive_closes) volScore += 8
  if (params.volumeConfluence.has_volume_confluence) volScore += 4
  score += Math.min(volScore, 20)

  // 4. Risk/Reward (0-15 pts)
  if (params.rrRatio >= 3.0) score += 15
  else if (params.rrRatio >= 2.0) score += 10
  else score += 5

  // 5. Macro/Context (0-15 pts)
  let macroScore = 10 // Base
  if (params.counterTrend) macroScore -= 10
  // F&G bonus: extreme fear is bullish for longs, extreme greed for shorts
  if (params.fearGreedIndex !== undefined) {
    if (params.isBuy && params.fearGreedIndex < 25) macroScore += 3
    else if (!params.isBuy && params.fearGreedIndex > 75) macroScore += 3
  }
  score += Math.max(0, Math.min(macroScore, 15))

  return Math.min(Math.max(score, 0), 100)
}

// ─── Bounce Confirmation ─────────────────────────────────────────────────────

function checkBounce(
  candles: Candle[],
  zoneLow: number,
  zoneHigh: number,
  isBuy: boolean,
): { confirmed: boolean; details: Record<string, boolean> } {
  const details = { wick_rejection: false, volume_spike: false, consecutive_closes: false }

  if (candles.length < 3) return { confirmed: false, details }

  // First verify a recent candle actually touched/penetrated the zone (last 6 candles)
  const recentCandles = candles.slice(-6)
  const zoneMargin = (zoneHigh - zoneLow) * 0.5  // allow half-zone-width margin
  let zoneTouched = false
  if (isBuy) {
    zoneTouched = recentCandles.some(c => c.low <= zoneHigh + zoneMargin)
  } else {
    zoneTouched = recentCandles.some(c => c.high >= zoneLow - zoneMargin)
  }
  if (!zoneTouched) return { confirmed: false, details }

  const latest = candles[candles.length - 1]
  const prev = candles[candles.length - 2]

  if (isBuy) {
    // Wick rejection: candle dipped into/near zone and closed above
    const body = Math.abs(latest.close - latest.open)
    const lowerWick = Math.min(latest.open, latest.close) - latest.low
    if (lowerWick >= WICK_REJECTION_RATIO * Math.max(body, 0.001)
        && latest.low <= zoneHigh + zoneMargin
        && latest.close > zoneLow) {
      details.wick_rejection = true
    }
    if (latest.close > zoneHigh && prev.close > zoneHigh && prev.low <= zoneHigh) {
      details.consecutive_closes = true
    }
  } else {
    // Wick rejection: candle wicked into/near zone and closed below
    const body = Math.abs(latest.close - latest.open)
    const upperWick = latest.high - Math.max(latest.open, latest.close)
    if (upperWick >= WICK_REJECTION_RATIO * Math.max(body, 0.001)
        && latest.high >= zoneLow - zoneMargin
        && latest.close < zoneHigh) {
      details.wick_rejection = true
    }
    if (latest.close < zoneLow && prev.close < zoneLow && prev.high >= zoneLow) {
      details.consecutive_closes = true
    }
  }

  // Volume spike — only counts if zone was touched (already verified above)
  const volCandles = candles.slice(-21, -1)
  if (volCandles.length >= 10 && latest.volume > 0) {
    const avgVol = volCandles.reduce((sum, c) => sum + c.volume, 0) / volCandles.length
    if (avgVol > 0 && latest.volume >= VOLUME_SPIKE_RATIO * avgVol) {
      details.volume_spike = true
    }
  }

  return { confirmed: details.wick_rejection || details.volume_spike || details.consecutive_closes, details }
}

// ─── Targets & Stop Loss ─────────────────────────────────────────────────────

function computeTargetsAndStop(
  zone: ConfluenceZone,
  allFibPrices: number[],
  isBuy: boolean,
): { target1: number; target2: number; stopLoss: number } | null {
  const sorted = [...allFibPrices].sort((a, b) => a - b)
  const zoneMid = zone.mid

  // Minimum distance between T1 and T2 (1.5% of zone mid)
  const minTargetGap = zoneMid * 0.015

  if (isBuy) {
    const levelsBelow = sorted.filter((p) => p < zone.low)
    const nextDown = levelsBelow.length > 0 ? levelsBelow[levelsBelow.length - 1] : null
    const stopLoss = nextDown ? nextDown * 0.997 : zoneMid * 0.985

    const levelsAbove = sorted.filter((p) => p > zone.high)
    const target1 = levelsAbove.length > 0 ? levelsAbove[0] : zoneMid * 1.03
    // T2 must be meaningfully above T1
    const t2Candidate = levelsAbove.find((p) => p > target1 + minTargetGap)
    const target2 = t2Candidate ?? target1 * 1.03

    return { target1, target2, stopLoss }
  } else {
    const levelsAbove = sorted.filter((p) => p > zone.high)
    const nextUp = levelsAbove.length > 0 ? levelsAbove[0] : null
    const stopLoss = nextUp ? nextUp * 1.003 : zoneMid * 1.015

    const levelsBelow = sorted.filter((p) => p < zone.low).reverse()
    const target1 = levelsBelow.length > 0 ? levelsBelow[0] : zoneMid * 0.97
    // T2 must be meaningfully below T1
    const t2Candidate = levelsBelow.find((p) => p < target1 - minTargetGap)
    const target2 = t2Candidate ?? target1 * 0.97

    return { target1, target2, stopLoss }
  }
}

// ─── Chart Pattern Detection ────────────────────────────────────────────────

const PATTERN_MIN_CONFIDENCE = 40

function detectChartPattern(
  candles: Record<string, Candle[]>,
  swings: Record<string, SwingPoint[]>,
): ChartPattern | null {
  const allPatterns: ChartPattern[] = []

  for (const tf of ["4h", "1d"] as const) {
    const tfSwings = swings[tf] ?? []
    const tfCandles = candles[tf] ?? []
    if (tfSwings.length < 3) continue

    // Separate and sort by time (most recent first)
    const highs = tfSwings
      .filter(s => s.type === "high")
      .sort((a, b) => new Date(b.candle_time).getTime() - new Date(a.candle_time).getTime())
    const lows = tfSwings
      .filter(s => s.type === "low")
      .sort((a, b) => new Date(b.candle_time).getTime() - new Date(a.candle_time).getTime())

    // ── Reversal Patterns ──

    // Double Top: 2 recent highs within 2% with a valley between
    if (highs.length >= 2) {
      const [h1, h2] = highs
      const pctDiff = Math.abs(h1.price - h2.price) / Math.max(h1.price, h2.price) * 100
      if (pctDiff <= 2.0) {
        // Find a low between the two highs
        const h1Time = new Date(h1.candle_time).getTime()
        const h2Time = new Date(h2.candle_time).getTime()
        const minTime = Math.min(h1Time, h2Time)
        const maxTime = Math.max(h1Time, h2Time)
        const valleyBetween = lows.find(l => {
          const lt = new Date(l.candle_time).getTime()
          return lt > minTime && lt < maxTime
        })
        if (valleyBetween) {
          const neckline = valleyBetween.price
          const peakAvg = (h1.price + h2.price) / 2
          const measuredMove = peakAvg - neckline
          let conf = 55
          if (pctDiff <= 1.0) conf += 10
          if (valleyBetween.reversal_pct >= 3) conf += 10
          // Volume confirmation: check if volume decreasing on second peak
          if (tfCandles.length > 10) {
            const h1Idx = tfCandles.findIndex(c => c.open_time === h1.candle_time)
            const h2Idx = tfCandles.findIndex(c => c.open_time === h2.candle_time)
            if (h1Idx >= 0 && h2Idx >= 0) {
              const h1Vol = tfCandles[h1Idx].volume
              const h2Vol = tfCandles[h2Idx].volume
              if (h2Vol < h1Vol * 0.85) conf += 10 // Lower volume on second peak = stronger
            }
          }
          allPatterns.push({
            name: "Bearish Double Top",
            type: "reversal",
            bias: "bearish",
            timeframe: tf,
            confidence: Math.min(conf, 95),
            description: `Two swing highs within ${pctDiff.toFixed(1)}% of each other with a valley at ${neckline.toFixed(2)}. Breakdown below neckline targets ${(neckline - measuredMove).toFixed(2)}.`,
            neckline,
            target: neckline - measuredMove,
          })
        }
      }
    }

    // Double Bottom: 2 recent lows within 2% with a peak between
    if (lows.length >= 2) {
      const [l1, l2] = lows
      const pctDiff = Math.abs(l1.price - l2.price) / Math.min(l1.price, l2.price) * 100
      if (pctDiff <= 2.0) {
        const l1Time = new Date(l1.candle_time).getTime()
        const l2Time = new Date(l2.candle_time).getTime()
        const minTime = Math.min(l1Time, l2Time)
        const maxTime = Math.max(l1Time, l2Time)
        const peakBetween = highs.find(h => {
          const ht = new Date(h.candle_time).getTime()
          return ht > minTime && ht < maxTime
        })
        if (peakBetween) {
          const neckline = peakBetween.price
          const troughAvg = (l1.price + l2.price) / 2
          const measuredMove = neckline - troughAvg
          let conf = 55
          if (pctDiff <= 1.0) conf += 10
          if (peakBetween.reversal_pct >= 3) conf += 10
          if (tfCandles.length > 10) {
            const l1Idx = tfCandles.findIndex(c => c.open_time === l1.candle_time)
            const l2Idx = tfCandles.findIndex(c => c.open_time === l2.candle_time)
            if (l1Idx >= 0 && l2Idx >= 0) {
              const l1Vol = tfCandles[l1Idx].volume
              const l2Vol = tfCandles[l2Idx].volume
              if (l2Vol < l1Vol * 0.85) conf += 10
            }
          }
          allPatterns.push({
            name: "Bullish Double Bottom",
            type: "reversal",
            bias: "bullish",
            timeframe: tf,
            confidence: Math.min(conf, 95),
            description: `Two swing lows within ${pctDiff.toFixed(1)}% of each other with a peak at ${neckline.toFixed(2)}. Breakout above neckline targets ${(neckline + measuredMove).toFixed(2)}.`,
            neckline,
            target: neckline + measuredMove,
          })
        }
      }
    }

    // Triple Top: 3 highs within 2%
    if (highs.length >= 3) {
      const [h1, h2, h3] = highs
      const avgPrice = (h1.price + h2.price + h3.price) / 3
      const maxDev = Math.max(
        Math.abs(h1.price - avgPrice),
        Math.abs(h2.price - avgPrice),
        Math.abs(h3.price - avgPrice),
      ) / avgPrice * 100
      if (maxDev <= 2.0) {
        const lowestValley = Math.min(
          ...lows.filter(l => {
            const lt = new Date(l.candle_time).getTime()
            const oldest = Math.min(
              new Date(h1.candle_time).getTime(),
              new Date(h2.candle_time).getTime(),
              new Date(h3.candle_time).getTime(),
            )
            const newest = Math.max(
              new Date(h1.candle_time).getTime(),
              new Date(h2.candle_time).getTime(),
              new Date(h3.candle_time).getTime(),
            )
            return lt >= oldest && lt <= newest
          }).map(l => l.price)
        )
        const neckline = isFinite(lowestValley) ? lowestValley : avgPrice * 0.97
        const measuredMove = avgPrice - neckline
        allPatterns.push({
          name: "Bearish Triple Top",
          type: "reversal",
          bias: "bearish",
          timeframe: tf,
          confidence: Math.min(70 + (maxDev <= 1.0 ? 10 : 0), 95),
          description: `Three swing highs clustered near ${avgPrice.toFixed(2)} forming strong resistance. Breakdown below ${neckline.toFixed(2)} targets ${(neckline - measuredMove).toFixed(2)}.`,
          neckline,
          target: neckline - measuredMove,
        })
      }
    }

    // Triple Bottom: 3 lows within 2%
    if (lows.length >= 3) {
      const [l1, l2, l3] = lows
      const avgPrice = (l1.price + l2.price + l3.price) / 3
      const maxDev = Math.max(
        Math.abs(l1.price - avgPrice),
        Math.abs(l2.price - avgPrice),
        Math.abs(l3.price - avgPrice),
      ) / avgPrice * 100
      if (maxDev <= 2.0) {
        const highestPeak = Math.max(
          ...highs.filter(h => {
            const ht = new Date(h.candle_time).getTime()
            const oldest = Math.min(
              new Date(l1.candle_time).getTime(),
              new Date(l2.candle_time).getTime(),
              new Date(l3.candle_time).getTime(),
            )
            const newest = Math.max(
              new Date(l1.candle_time).getTime(),
              new Date(l2.candle_time).getTime(),
              new Date(l3.candle_time).getTime(),
            )
            return ht >= oldest && ht <= newest
          }).map(h => h.price)
        )
        const neckline = isFinite(highestPeak) ? highestPeak : avgPrice * 1.03
        const measuredMove = neckline - avgPrice
        allPatterns.push({
          name: "Bullish Triple Bottom",
          type: "reversal",
          bias: "bullish",
          timeframe: tf,
          confidence: Math.min(70 + (maxDev <= 1.0 ? 10 : 0), 95),
          description: `Three swing lows clustered near ${avgPrice.toFixed(2)} forming strong support. Breakout above ${neckline.toFixed(2)} targets ${(neckline + measuredMove).toFixed(2)}.`,
          neckline,
          target: neckline + measuredMove,
        })
      }
    }

    // Head and Shoulders (bearish reversal): 3 highs, middle highest, outer 2 within 5%
    if (highs.length >= 3) {
      // Sort by time ascending for left-head-right order
      const chronoHighs = [...highs].sort((a, b) => new Date(a.candle_time).getTime() - new Date(b.candle_time).getTime())
      for (let i = 0; i <= chronoHighs.length - 3; i++) {
        const left = chronoHighs[i]
        const head = chronoHighs[i + 1]
        const right = chronoHighs[i + 2]
        if (head.price > left.price && head.price > right.price) {
          const shoulderDiff = Math.abs(left.price - right.price) / Math.max(left.price, right.price) * 100
          if (shoulderDiff <= 5.0) {
            // Find lows between left-head and head-right for neckline
            const leftTime = new Date(left.candle_time).getTime()
            const headTime = new Date(head.candle_time).getTime()
            const rightTime = new Date(right.candle_time).getTime()
            const trough1 = lows.find(l => {
              const lt = new Date(l.candle_time).getTime()
              return lt > leftTime && lt < headTime
            })
            const trough2 = lows.find(l => {
              const lt = new Date(l.candle_time).getTime()
              return lt > headTime && lt < rightTime
            })
            if (trough1 && trough2) {
              const neckline = (trough1.price + trough2.price) / 2
              const measuredMove = head.price - neckline
              let conf = 60
              if (shoulderDiff <= 2.5) conf += 10
              if (measuredMove / head.price * 100 >= 5) conf += 5
              allPatterns.push({
                name: "Bearish Head and Shoulders",
                type: "reversal",
                bias: "bearish",
                timeframe: tf,
                confidence: Math.min(conf, 95),
                description: `Head at ${head.price.toFixed(2)} with shoulders at ${left.price.toFixed(2)} and ${right.price.toFixed(2)}. Neckline at ${neckline.toFixed(2)}, measured move targets ${(neckline - measuredMove).toFixed(2)}.`,
                neckline,
                target: neckline - measuredMove,
              })
            }
            break // Only detect the most recent H&S
          }
        }
      }
    }

    // Inverse Head and Shoulders (bullish reversal): 3 lows, middle lowest, outer 2 within 5%
    if (lows.length >= 3) {
      const chronoLows = [...lows].sort((a, b) => new Date(a.candle_time).getTime() - new Date(b.candle_time).getTime())
      for (let i = 0; i <= chronoLows.length - 3; i++) {
        const left = chronoLows[i]
        const head = chronoLows[i + 1]
        const right = chronoLows[i + 2]
        if (head.price < left.price && head.price < right.price) {
          const shoulderDiff = Math.abs(left.price - right.price) / Math.min(left.price, right.price) * 100
          if (shoulderDiff <= 5.0) {
            const leftTime = new Date(left.candle_time).getTime()
            const headTime = new Date(head.candle_time).getTime()
            const rightTime = new Date(right.candle_time).getTime()
            const peak1 = highs.find(h => {
              const ht = new Date(h.candle_time).getTime()
              return ht > leftTime && ht < headTime
            })
            const peak2 = highs.find(h => {
              const ht = new Date(h.candle_time).getTime()
              return ht > headTime && ht < rightTime
            })
            if (peak1 && peak2) {
              const neckline = (peak1.price + peak2.price) / 2
              const measuredMove = neckline - head.price
              let conf = 60
              if (shoulderDiff <= 2.5) conf += 10
              if (measuredMove / head.price * 100 >= 5) conf += 5
              allPatterns.push({
                name: "Bullish Inverse Head and Shoulders",
                type: "reversal",
                bias: "bullish",
                timeframe: tf,
                confidence: Math.min(conf, 95),
                description: `Head at ${head.price.toFixed(2)} with shoulders at ${left.price.toFixed(2)} and ${right.price.toFixed(2)}. Neckline at ${neckline.toFixed(2)}, measured move targets ${(neckline + measuredMove).toFixed(2)}.`,
                neckline,
                target: neckline + measuredMove,
              })
            }
            break
          }
        }
      }
    }

    // Rising Wedge (bearish): higher highs AND higher lows, converging
    if (highs.length >= 3 && lows.length >= 3) {
      const chronoHighs = [...highs].sort((a, b) => new Date(a.candle_time).getTime() - new Date(b.candle_time).getTime()).slice(-4)
      const chronoLows = [...lows].sort((a, b) => new Date(a.candle_time).getTime() - new Date(b.candle_time).getTime()).slice(-4)

      if (chronoHighs.length >= 3 && chronoLows.length >= 3) {
        const highsRising = chronoHighs.every((h, i) => i === 0 || h.price > chronoHighs[i - 1].price)
        const lowsRising = chronoLows.every((l, i) => i === 0 || l.price > chronoLows[i - 1].price)

        if (highsRising && lowsRising) {
          // Check convergence: rate of rise for lows > rate of rise for highs
          const highSlope = (chronoHighs[chronoHighs.length - 1].price - chronoHighs[0].price) / chronoHighs[0].price
          const lowSlope = (chronoLows[chronoLows.length - 1].price - chronoLows[0].price) / chronoLows[0].price
          if (lowSlope > highSlope && highSlope > 0) {
            const convergenceRatio = lowSlope / Math.max(highSlope, 0.001)
            let conf = 50
            if (convergenceRatio >= 1.5) conf += 10
            if (chronoHighs.length >= 4) conf += 5
            if (chronoLows.length >= 4) conf += 5
            allPatterns.push({
              name: "Bearish Rising Wedge",
              type: "reversal",
              bias: "bearish",
              timeframe: tf,
              confidence: Math.min(conf, 95),
              description: `Higher highs and higher lows converging, with support rising faster than resistance. Typically resolves with a breakdown below the lower trendline.`,
            })
          }
        }
      }
    }

    // Falling Wedge (bullish): lower lows AND lower highs, converging
    if (highs.length >= 3 && lows.length >= 3) {
      const chronoHighs = [...highs].sort((a, b) => new Date(a.candle_time).getTime() - new Date(b.candle_time).getTime()).slice(-4)
      const chronoLows = [...lows].sort((a, b) => new Date(a.candle_time).getTime() - new Date(b.candle_time).getTime()).slice(-4)

      if (chronoHighs.length >= 3 && chronoLows.length >= 3) {
        const highsFalling = chronoHighs.every((h, i) => i === 0 || h.price < chronoHighs[i - 1].price)
        const lowsFalling = chronoLows.every((l, i) => i === 0 || l.price < chronoLows[i - 1].price)

        if (highsFalling && lowsFalling) {
          const highSlope = (chronoHighs[0].price - chronoHighs[chronoHighs.length - 1].price) / chronoHighs[0].price
          const lowSlope = (chronoLows[0].price - chronoLows[chronoLows.length - 1].price) / chronoLows[0].price
          if (highSlope > lowSlope && lowSlope > 0) {
            const convergenceRatio = highSlope / Math.max(lowSlope, 0.001)
            let conf = 50
            if (convergenceRatio >= 1.5) conf += 10
            if (chronoHighs.length >= 4) conf += 5
            if (chronoLows.length >= 4) conf += 5
            allPatterns.push({
              name: "Bullish Falling Wedge",
              type: "reversal",
              bias: "bullish",
              timeframe: tf,
              confidence: Math.min(conf, 95),
              description: `Lower highs and lower lows converging, with resistance falling faster than support. Typically resolves with a breakout above the upper trendline.`,
            })
          }
        }
      }
    }

    // ── Continuation Patterns ──

    // Bull/Bear Flag: strong impulse followed by narrow counter-trend consolidation
    if (tfCandles.length >= 15) {
      const recent = tfCandles.slice(-15)
      // Check for impulse in first 5 candles
      const impulseCandles = recent.slice(0, 5)
      const impulseStart = impulseCandles[0].open
      const impulseEnd = impulseCandles[impulseCandles.length - 1].close
      const impulsePct = ((impulseEnd - impulseStart) / impulseStart) * 100

      const consolidationCandles = recent.slice(5)
      const consolHigh = Math.max(...consolidationCandles.map(c => c.high))
      const consolLow = Math.min(...consolidationCandles.map(c => c.low))
      const consolRange = ((consolHigh - consolLow) / consolLow) * 100

      if (Math.abs(impulsePct) > 5) {
        const isBullImpulse = impulsePct > 0
        // Retracement: how much of the impulse did the consolidation give back?
        const retracement = isBullImpulse
          ? ((impulseEnd - consolLow) / (impulseEnd - impulseStart)) * 100
          : ((consolHigh - impulseEnd) / (impulseStart - impulseEnd)) * 100

        if (retracement >= 3 && retracement <= 50 && consolRange < Math.abs(impulsePct) * 0.6) {
          let conf = 50
          if (retracement >= 10 && retracement <= 38.2) conf += 15 // Ideal flag retracement
          if (consolRange < Math.abs(impulsePct) * 0.4) conf += 10 // Tight consolidation
          // Volume declining during consolidation
          const impulseAvgVol = impulseCandles.reduce((s, c) => s + c.volume, 0) / impulseCandles.length
          const consolAvgVol = consolidationCandles.reduce((s, c) => s + c.volume, 0) / consolidationCandles.length
          if (consolAvgVol < impulseAvgVol * 0.7) conf += 10

          const flagTarget = isBullImpulse
            ? consolLow + (impulseEnd - impulseStart)
            : consolHigh - (impulseStart - impulseEnd)

          allPatterns.push({
            name: isBullImpulse ? "Bullish Bull Flag" : "Bearish Bear Flag",
            type: "continuation",
            bias: isBullImpulse ? "bullish" : "bearish",
            timeframe: tf,
            confidence: Math.min(conf, 95),
            description: `${Math.abs(impulsePct).toFixed(1)}% impulse move followed by ${consolRange.toFixed(1)}% consolidation range with ${retracement.toFixed(1)}% retracement. Flag target at ${flagTarget.toFixed(2)}.`,
            target: flagTarget,
          })
        }
      }
    }

    // Ascending Triangle: flat resistance + rising support
    if (highs.length >= 2 && lows.length >= 3) {
      const recentHighs = highs.slice(0, 3)
      const recentLows = [...lows.slice(0, 4)].sort((a, b) => new Date(a.candle_time).getTime() - new Date(b.candle_time).getTime())

      const highAvg = recentHighs.reduce((s, h) => s + h.price, 0) / recentHighs.length
      const highMaxDev = Math.max(...recentHighs.map(h => Math.abs(h.price - highAvg) / highAvg * 100))

      // Flat resistance: highs within 1.5% of each other
      if (highMaxDev <= 1.5 && recentLows.length >= 3) {
        // Rising support: each successive low is higher
        const risingLows = recentLows.every((l, i) => i === 0 || l.price >= recentLows[i - 1].price * 0.995)
        if (risingLows) {
          const resistance = highAvg
          const height = resistance - recentLows[0].price
          let conf = 55
          if (recentHighs.length >= 3) conf += 10
          if (recentLows.length >= 4) conf += 5
          if (highMaxDev <= 0.75) conf += 5
          allPatterns.push({
            name: "Bullish Ascending Triangle",
            type: "continuation",
            bias: "bullish",
            timeframe: tf,
            confidence: Math.min(conf, 95),
            description: `Flat resistance near ${resistance.toFixed(2)} with rising support. Breakout above resistance targets ${(resistance + height).toFixed(2)}.`,
            neckline: resistance,
            target: resistance + height,
          })
        }
      }
    }

    // Descending Triangle: flat support + declining resistance
    if (lows.length >= 2 && highs.length >= 3) {
      const recentLows = lows.slice(0, 3)
      const recentHighs = [...highs.slice(0, 4)].sort((a, b) => new Date(a.candle_time).getTime() - new Date(b.candle_time).getTime())

      const lowAvg = recentLows.reduce((s, l) => s + l.price, 0) / recentLows.length
      const lowMaxDev = Math.max(...recentLows.map(l => Math.abs(l.price - lowAvg) / lowAvg * 100))

      if (lowMaxDev <= 1.5 && recentHighs.length >= 3) {
        const fallingHighs = recentHighs.every((h, i) => i === 0 || h.price <= recentHighs[i - 1].price * 1.005)
        if (fallingHighs) {
          const support = lowAvg
          const height = recentHighs[0].price - support
          let conf = 55
          if (recentLows.length >= 3) conf += 10
          if (recentHighs.length >= 4) conf += 5
          if (lowMaxDev <= 0.75) conf += 5
          allPatterns.push({
            name: "Bearish Descending Triangle",
            type: "continuation",
            bias: "bearish",
            timeframe: tf,
            confidence: Math.min(conf, 95),
            description: `Flat support near ${support.toFixed(2)} with declining resistance. Breakdown below support targets ${(support - height).toFixed(2)}.`,
            neckline: support,
            target: support - height,
          })
        }
      }
    }

    // Symmetrical Triangle: converging highs (lower) and lows (higher)
    if (highs.length >= 3 && lows.length >= 3) {
      const chronoHighs = [...highs.slice(0, 4)].sort((a, b) => new Date(a.candle_time).getTime() - new Date(b.candle_time).getTime())
      const chronoLows = [...lows.slice(0, 4)].sort((a, b) => new Date(a.candle_time).getTime() - new Date(b.candle_time).getTime())

      if (chronoHighs.length >= 3 && chronoLows.length >= 3) {
        const lowerHighs = chronoHighs.every((h, i) => i === 0 || h.price <= chronoHighs[i - 1].price * 1.005)
        const higherLows = chronoLows.every((l, i) => i === 0 || l.price >= chronoLows[i - 1].price * 0.995)

        if (lowerHighs && higherLows) {
          const latestHigh = chronoHighs[chronoHighs.length - 1].price
          const latestLow = chronoLows[chronoLows.length - 1].price
          const height = chronoHighs[0].price - chronoLows[0].price

          // Determine bias from prior trend using the oldest swing points
          const priorTrendBullish = chronoLows[0].price < chronoHighs[0].price * 0.95
          const bias = priorTrendBullish ? "bullish" : "bearish"

          let conf = 50
          if (chronoHighs.length >= 4) conf += 5
          if (chronoLows.length >= 4) conf += 5
          if (latestHigh - latestLow < height * 0.6) conf += 10 // Good convergence

          allPatterns.push({
            name: `${bias === "bullish" ? "Bullish" : "Bearish"} Symmetrical Triangle`,
            type: "continuation",
            bias,
            timeframe: tf,
            confidence: Math.min(conf, 95),
            description: `Converging lower highs and higher lows forming a symmetrical triangle. Height of ${height.toFixed(2)} suggests a measured move of similar magnitude on breakout.`,
            target: bias === "bullish" ? latestHigh + height : latestLow - height,
          })
        }
      }
    }
  }

  // Filter by minimum confidence and return the highest confidence pattern
  const validPatterns = allPatterns.filter(p => p.confidence >= PATTERN_MIN_CONFIDENCE)
  if (validPatterns.length === 0) return null

  validPatterns.sort((a, b) => b.confidence - a.confidence)
  return validPatterns[0]
}

// ─── Signal Evaluation ───────────────────────────────────────────────────────

async function evaluateSignals(
  supabase: SupabaseClient,
  ticker: string,
  candles: Record<string, Candle[]>,
  zones: ConfluenceZone[],
  fibs: FibLevel[],
  currentPrice: number,
  volumeNodes: VolumeNode[] = [],
  fearGreedIndex?: number,
  btcRiskScore?: number,
  swings?: Record<string, SwingPoint[]>,
  tier: TierConfig = TIER_SWING,
): Promise<{ generated: number; skipped: number; skipReasons: string[] }> {
  const stats = { generated: 0, skipped: 0, skipReasons: [] as string[] }
  const trendCandles = candles[tier.trendTimeframe]
  const candles4h = candles["4h"] ?? []

  if (!trendCandles || trendCandles.length < EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK) {
    return stats
  }

  // Detect chart pattern for this asset (once per evaluation, shared across zones)
  const chartPattern = swings ? detectChartPattern(candles, swings) : null

  const allFibPrices = fibs.map((f) => f.price)

  // Detect market regime (choppy vs trending) — used to raise quality thresholds
  const regime = detectMarketRegime(candles4h)
  if (regime.isChoppy) {
    console.log(`[${ticker}] Choppy market detected (spread=${regime.emaSpreadPct.toFixed(2)}%, crossovers=${regime.crossoverCount}, whipsaws=${regime.priceWhipsaws})`)
  }
  const choppyMinRR = regime.isChoppy ? 2.0 : MIN_RR_RATIO  // Require 2:1 R:R in choppy markets
  const choppyBounceThreshold = regime.isChoppy ? 2 : 1       // Require 2 of 3 bounce signals in choppy markets

  // 24-hour cooldown per asset: skip if any signal was generated in the last 24h
  const cooldownCutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
  const { data: recentSignals } = await supabase
    .from("trade_signals")
    .select("id")
    .eq("asset", ticker)
    .eq("timeframe", tier.tierName)
    .gte("generated_at", cooldownCutoff)
    .limit(1)

  if (recentSignals && recentSignals.length > 0) {
    stats.skipReasons.push(`24h cooldown: signal already generated for ${ticker}`)
    stats.skipped++
    return stats
  }

  for (const zone of zones) {
    const distancePct = Math.abs((currentPrice - zone.mid) / currentPrice) * 100
    if (distancePct > tier.signalProximityPct) continue

    // Check for existing active/triggered signal near this zone for this tier
    const { data: existing } = await supabase
      .from("trade_signals")
      .select("id")
      .eq("asset", ticker)
      .eq("timeframe", tier.tierName)
      .in("status", ["active", "triggered"])
      .gte("entry_zone_low", zone.low * 0.995)
      .lte("entry_zone_high", zone.high * 1.005)
      .limit(1)

    if (existing && existing.length > 0) {
      stats.skipReasons.push(`${zone.zone_type} @${zone.mid.toFixed(2)}: duplicate signal exists`)
      stats.skipped++
      continue
    }

    // Cross-tier dedup: if a swing (4h) signal already covers this zone, skip the scalp (1h) signal
    if (tier.tierName === "1h") {
      const { data: higherTf } = await supabase
        .from("trade_signals")
        .select("id")
        .eq("asset", ticker)
        .eq("timeframe", "4h")
        .in("status", ["active", "triggered"])
        .gte("entry_zone_low", zone.low * 0.985)
        .lte("entry_zone_high", zone.high * 1.015)
        .limit(1)
      if (higherTf && higherTf.length > 0) {
        stats.skipReasons.push(`${zone.zone_type} @${zone.mid.toFixed(2)}: swing signal covers zone`)
        stats.skipped++
        continue
      }
    }

    const isBuy = zone.zone_type === "support"

    // Price position check: skip if price broke through the zone decisively
    // For buy: skip if price dropped far below support (broken support)
    // For sell: skip if price rose far above resistance (broken resistance)
    const zonePastPct = 5.0
    if (isBuy && currentPrice < zone.low * (1 - zonePastPct / 100)) {
      console.log(`[${ticker}] Zone ${zone.mid.toFixed(2)} (${zone.zone_type}): price broke below support`)
      stats.skipReasons.push(`${zone.zone_type} @${zone.mid.toFixed(2)}: price broke below support (price=${currentPrice.toFixed(2)})`)
      stats.skipped++
      continue
    }
    if (!isBuy && currentPrice > zone.high * (1 + zonePastPct / 100)) {
      console.log(`[${ticker}] Zone ${zone.mid.toFixed(2)} (${zone.zone_type}): price broke above resistance`)
      stats.skipReasons.push(`${zone.zone_type} @${zone.mid.toFixed(2)}: price broke above resistance (price=${currentPrice.toFixed(2)})`)
      stats.skipped++
      continue
    }

    // EMA trend filter (always on trend timeframe)
    if (!checkTrendAlignment(trendCandles, isBuy)) {
      console.log(`[${ticker}] Zone ${zone.mid.toFixed(2)} (${zone.zone_type}): EMA misalign [${tier.tierName}]`)
      stats.skipReasons.push(`${zone.zone_type} @${zone.mid.toFixed(2)}: EMA trend misaligned for ${isBuy ? "buy" : "sell"} [${tier.tierName}]`)
      stats.skipped++
      continue
    }

    // Daily trend guard — block counter-trend signals when daily trend is clearly directional
    const dailyCandles = candles["1d"] ?? []
    if (!checkDailyTrendGuard(dailyCandles, isBuy)) {
      console.log(`[${ticker}] Zone ${zone.mid.toFixed(2)} (${zone.zone_type}): daily trend blocks ${isBuy ? "buy" : "sell"}`)
      stats.skipReasons.push(`${zone.zone_type} @${zone.mid.toFixed(2)}: daily trend blocks ${isBuy ? "long" : "short"}`)
      stats.skipped++
      continue
    }

    // Momentum filter — block signals against strong short-term moves (bounce/selloff)
    if (!checkMomentumFilter(dailyCandles, isBuy)) {
      const dir = isBuy ? "long during selloff" : "short during bounce"
      console.log(`[${ticker}] Zone ${zone.mid.toFixed(2)} (${zone.zone_type}): momentum blocks ${dir}`)
      stats.skipReasons.push(`${zone.zone_type} @${zone.mid.toFixed(2)}: momentum blocks ${dir}`)
      stats.skipped++
      continue
    }

    // Bounce confirmation — check preferred timeframes in order
    let bounce = { confirmed: false, details: { wick_rejection: false, volume_spike: false, consecutive_closes: false } }
    for (const btf of tier.bounceTimeframes) {
      const btfCandles = candles[btf] ?? []
      if (btfCandles.length >= 3) {
        const check = checkBounce(btfCandles.slice(-25), zone.low, zone.high, isBuy)
        if (check.confirmed) {
          bounce = check
          break
        }
      }
    }
    if (!bounce.confirmed) {
      console.log(`[${ticker}] Zone ${zone.mid.toFixed(2)} (${zone.zone_type}): no bounce [${tier.tierName}]`)
      stats.skipReasons.push(`${zone.zone_type} @${zone.mid.toFixed(2)}: no bounce confirmation [${tier.tierName}]`)
      stats.skipped++
      continue
    }

    // In choppy markets, require stronger bounce confirmation (2 of 3 signals)
    if (regime.isChoppy) {
      const bounceCount = (bounce.details.wick_rejection ? 1 : 0)
        + (bounce.details.volume_spike ? 1 : 0)
        + (bounce.details.consecutive_closes ? 1 : 0)
      if (bounceCount < choppyBounceThreshold) {
        console.log(`[${ticker}] Zone ${zone.mid.toFixed(2)} (${zone.zone_type}): choppy market — weak bounce (${bounceCount}/3) [${tier.tierName}]`)
        stats.skipReasons.push(`${zone.zone_type} @${zone.mid.toFixed(2)}: choppy market, weak bounce (${bounceCount}/${choppyBounceThreshold} needed)`)
        stats.skipped++
        continue
      }
    }

    // Targets and stop
    const targets = computeTargetsAndStop(zone, allFibPrices, isBuy)
    if (!targets) continue

    // Use current price as entry — more realistic than zone.mid since bounce already happened
    const entryMid = currentPrice
    const riskDist = Math.abs(entryMid - targets.stopLoss)
    const rewardDist = Math.abs(targets.target1 - entryMid)
    const rrRatio = riskDist > 0 ? rewardDist / riskDist : 0

    const effectiveMinRR = regime.isChoppy ? choppyMinRR : MIN_RR_RATIO
    if (rrRatio < effectiveMinRR) {
      const reason = regime.isChoppy
        ? `R:R ${rrRatio.toFixed(2)} < ${effectiveMinRR} (choppy market)`
        : `R:R ${rrRatio.toFixed(2)} < ${effectiveMinRR}`
      console.log(`[${ticker}] Zone ${zone.mid.toFixed(2)} (${zone.zone_type}): ${reason}`)
      stats.skipReasons.push(`${zone.zone_type} @${zone.mid.toFixed(2)}: ${reason}`)
      stats.skipped++
      continue
    }

    const isStrong = rrRatio >= STRONG_MIN_RR_RATIO && zone.strength >= STRONG_MIN_CONFLUENCE
    const signalType = isBuy
      ? (isStrong ? "strong_buy" : "buy")
      : (isStrong ? "strong_sell" : "sell")

    // Bull Market Support Band regime check (informational, not a filter)
    const counterTrend = checkBMSB(candles["1d"] ?? [], currentPrice, isBuy)

    // Volume confluence check
    const volConfluence = checkVolumeConfluence(zone, volumeNodes)

    // Composite signal score
    const compositeScore = computeCompositeScore({
      zone,
      candles4h,
      bounce,
      volumeConfluence: volConfluence,
      isBuy,
      rrRatio: rrRatio,
      counterTrend,
      fearGreedIndex,
      btcRiskScore,
    })

    // Only publish B-grade or higher signals (score >= 60)
    if (compositeScore < 60) {
      console.log(`[${ticker}] Zone ${zone.mid.toFixed(2)} (${zone.zone_type}): score ${compositeScore} < 60`)
      stats.skipReasons.push(`${zone.zone_type} @${zone.mid.toFixed(2)}: score ${compositeScore} < 60`)
      stats.skipped++
      continue
    }

    const expiresAt = new Date(Date.now() + tier.expiryHours * 3600000).toISOString()

    // Store the confluence zone first to get its ID
    const { data: zoneRow } = await supabase
      .from("fib_confluence_zones")
      .select("id")
      .eq("asset", ticker)
      .eq("is_active", true)
      .gte("zone_mid", zone.mid * 0.999)
      .lte("zone_mid", zone.mid * 1.001)
      .limit(1)

    const confluenceZoneId = zoneRow?.[0]?.id ?? null

    // Derive macro regime label from Fear & Greed + BTC risk
    let macroRegime: string | null = null
    if (fearGreedIndex !== undefined) {
      if (fearGreedIndex >= 70) macroRegime = "Risk-On"
      else if (fearGreedIndex <= 30) macroRegime = "Risk-Off"
      else macroRegime = "Neutral"
    }

    const signalRow = {
      asset: ticker,
      signal_type: signalType,
      status: "triggered",  // Enter at current price after bounce confirmation
      timeframe: tier.tierName,
      entry_zone_low: zone.low,
      entry_zone_high: zone.high,
      entry_price_mid: entryMid,
      confluence_zone_id: confluenceZoneId,
      target_1: targets.target1,
      target_2: targets.target2,
      stop_loss: targets.stopLoss,
      risk_reward_ratio: Math.round(rrRatio * 100) / 100,
      risk_1r: riskDist,
      best_price: entryMid,
      runner_stop: targets.stopLoss,
      ema_trend_aligned: true,
      bounce_confirmed: true,
      confirmation_details: bounce.details,
      counter_trend: counterTrend,
      composite_score: compositeScore,
      volume_confluence: volConfluence,
      fear_greed_index: fearGreedIndex ?? null,
      btc_risk_score: btcRiskScore ?? null,
      macro_regime: macroRegime,
      chart_pattern: chartPattern ?? null,
      triggered_at: new Date().toISOString(),
      expires_at: expiresAt,
    }

    const { data: inserted, error } = await supabase
      .from("trade_signals")
      .insert(signalRow)
      .select("id")
      .single()

    if (error) {
      console.error(`[${ticker}] Zone ${zone.mid.toFixed(2)}: DB insert error: ${error.message}`)
    }
    if (!error && inserted) {
      stats.generated++

      // Send push notification
      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
      const cronSecret = Deno.env.get("CRON_SECRET") ?? ""

      try {
        const emoji = isBuy ? "📈" : "📉"
        const direction = isBuy ? "Long" : "Short"
        const entryStr = entryMid > 1000
          ? `$${Math.round(entryMid).toLocaleString()}`
          : entryMid > 1
            ? `$${entryMid.toFixed(2)}`
            : `$${entryMid.toFixed(4)}`

        const t1Str = targets.target1 > 1000
          ? `$${Math.round(targets.target1).toLocaleString()}`
          : targets.target1 > 1
            ? `$${targets.target1.toFixed(2)}`
            : `$${targets.target1.toFixed(4)}`

        const slStr = targets.stopLoss > 1000
          ? `$${Math.round(targets.stopLoss).toLocaleString()}`
          : targets.stopLoss > 1
            ? `$${targets.stopLoss.toFixed(2)}`
            : `$${targets.stopLoss.toFixed(4)}`

        const anonKeyNotif = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
        fetch(`${supabaseUrl}/functions/v1/send-broadcast-notification`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${anonKeyNotif}`,
            "x-cron-secret": cronSecret,
          },
          body: JSON.stringify({
            broadcast_id: inserted.id,
            title: `${emoji} ${tier.tierName === "1h" ? "Scalp" : "Swing"}: ${ticker} ${direction} Signal`,
            body: `${isStrong ? "Strong " : ""}${direction} at ${entryStr} | R:R ${rrRatio.toFixed(1)} | T1: ${t1Str} | SL: ${slStr}`,
            event_type: "signal_new",
            target_audience: { type: "all" },
          }),
        }).catch(() => {})
      } catch {}

      // Generate briefing (await to ensure it completes before pipeline moves on)
      try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
        const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
        const briefingResp = await fetch(`${supabaseUrl}/functions/v1/generate-signal-briefing`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-cron-secret": cronSecret,
          },
          body: JSON.stringify({ signal_id: inserted.id }),
        })
        if (!briefingResp.ok) {
          const errText = await briefingResp.text().catch(() => "")
          console.error(`[briefing] Failed for ${ticker} signal ${inserted.id}: ${briefingResp.status} ${errText}`)
        }
      } catch (err) {
        console.error(`[briefing] Error for ${ticker}: ${err}`)
      }
    }
  }

  return stats
}

// ─── Signal Resolution (50% at T1, trail runner with 1R stop) ────────────────

async function resolveOpenSignals(
  supabase: SupabaseClient,
  ticker: string,
  candles: Record<string, Candle[]>,
): Promise<{ resolved: number; t1Hits: number; runnerStops: number; losses: number; expired: number }> {
  const stats = { resolved: 0, t1Hits: 0, runnerStops: 0, losses: 0, expired: 0 }

  const candles4h = candles["4h"]
  if (!candles4h || candles4h.length === 0) return stats

  // Candles are oldest-first; keep last 6 for per-signal timestamp filtering
  const recent4h = candles4h.slice(-6)
  const latestClose = recent4h[recent4h.length - 1].close
  const now = new Date()

  // Aggregate candles only after a signal's trigger time (prevents false T1/SL hits)
  function aggregateAfter(afterIso: string): { high: number; low: number; close: number } | null {
    const afterMs = new Date(afterIso).getTime()
    const valid = recent4h.filter(c => new Date(c.open_time).getTime() >= afterMs)
    if (valid.length === 0) {
      // Signal just created — use only the latest candle
      const latest = recent4h[recent4h.length - 1]
      return { high: latest.high, low: latest.low, close: latest.close }
    }
    let aggHigh = -Infinity
    let aggLow = Infinity
    for (const c of valid) {
      aggHigh = Math.max(aggHigh, c.high)
      aggLow = Math.min(aggLow, c.low)
    }
    return { high: aggHigh, low: aggLow, close: valid[valid.length - 1].close }
  }

  // Get all triggered signals for this asset
  const { data: signals } = await supabase
    .from("trade_signals")
    .select("*")
    .eq("asset", ticker)
    .eq("status", "triggered")

  if (!signals || signals.length === 0) return stats

  // Wick buffer: SL must be breached by 0.3% to count as a stop-out.
  // Prevents false triggers from exchange-specific wicks (Coinbase spot vs perp).
  const SL_BUFFER_PCT = 0.003

  for (const signal of signals) {
    // Skip if already resolved by signal-monitor (race condition guard)
    if (signal.closed_at) continue

    const isBuy = signal.signal_type === "buy" || signal.signal_type === "strong_buy"
    const entryMid = Number(signal.entry_price_mid)
    const t1 = signal.target_1 ? Number(signal.target_1) : null
    const sl = Number(signal.stop_loss)
    const risk1r = signal.risk_1r ? Number(signal.risk_1r) : Math.abs(entryMid - sl)
    const t1AlreadyHit = !!signal.t1_hit_at
    let bestPrice = signal.best_price ? Number(signal.best_price) : entryMid
    let runnerStop = signal.runner_stop ? Number(signal.runner_stop) : sl

    // Per-signal candle aggregation — only candles after this signal was created
    const candle = aggregateAfter(signal.triggered_at)
    if (!candle) continue
    // Latest candle only for runner trailing (avoids stale highs/lows)
    const latestOnly = recent4h[recent4h.length - 1]

    // --- Expiry check ---
    if (signal.expires_at && new Date(signal.expires_at) <= now) {
      const exitPrice = latestClose

      if (t1AlreadyHit) {
        // Runner was still open — close at current price
        const runnerPnl = isBuy
          ? ((exitPrice - entryMid) / entryMid) * 100
          : ((entryMid - exitPrice) / entryMid) * 100
        const t1Pnl = signal.t1_pnl_pct ? Number(signal.t1_pnl_pct) : 0
        const totalPnl = (t1Pnl + runnerPnl) / 2

        await supabase.from("trade_signals").update({
          status: totalPnl > 0 ? "target_hit" : "expired",
          outcome: totalPnl > 0 ? "win" : "loss",
          outcome_pct: Math.round(totalPnl * 100) / 100,
          runner_exit_price: exitPrice,
          runner_pnl_pct: Math.round(runnerPnl * 100) / 100,
          closed_at: now.toISOString(),
          duration_hours: Math.round((now.getTime() - new Date(signal.triggered_at).getTime()) / 3600000),
        }).eq("id", signal.id)
        notifyResolution(signal, totalPnl > 0 ? "expired_win" : "expired_loss", exitPrice)
      } else {
        const pnl = isBuy
          ? ((exitPrice - entryMid) / entryMid) * 100
          : ((entryMid - exitPrice) / entryMid) * 100

        await supabase.from("trade_signals").update({
          status: "expired",
          outcome: "loss",
          outcome_pct: Math.round(pnl * 100) / 100,
          closed_at: now.toISOString(),
          duration_hours: Math.round((now.getTime() - new Date(signal.triggered_at).getTime()) / 3600000),
        }).eq("id", signal.id)
        notifyResolution(signal, "expired_loss", exitPrice)
      }

      stats.expired++
      stats.resolved++
      continue
    }

    if (isBuy) {
      if (!t1AlreadyHit) {
        // Phase 1: Full position — check SL then T1
        // SL must be breached by buffer to filter out exchange-specific wicks
        if (candle.low <= sl * (1 - SL_BUFFER_PCT)) {
          const pnl = ((sl - entryMid) / entryMid) * 100
          await supabase.from("trade_signals").update({
            status: "invalidated",
            outcome: "loss",
            outcome_pct: Math.round(pnl * 100) / 100,
            closed_at: now.toISOString(),
            duration_hours: Math.round((now.getTime() - new Date(signal.triggered_at).getTime()) / 3600000),
          }).eq("id", signal.id)
          notifyResolution(signal, "stop_loss", sl)
          stats.losses++
          stats.resolved++
          continue
        }

        if (t1 && candle.high >= t1) {
          const t1Pnl = ((t1 - entryMid) / entryMid) * 100
          await supabase.from("trade_signals").update({
            t1_hit_at: now.toISOString(),
            t1_pnl_pct: Math.round(t1Pnl * 100) / 100,
            best_price: candle.high,
            runner_stop: entryMid,  // Move to breakeven
          }).eq("id", signal.id)
          notifyResolution(signal, "t1_hit", t1)
          stats.t1Hits++
          continue // Skip runner eval this cycle
        }
      } else {
        // Phase 2: Runner — use latest candle only (not aggregated) to avoid stale data
        bestPrice = Math.max(bestPrice, latestOnly.high)
        runnerStop = Math.max(runnerStop, bestPrice - risk1r)

        if (latestOnly.low <= runnerStop) {
          const runnerPnl = ((runnerStop - entryMid) / entryMid) * 100
          const t1Pnl = signal.t1_pnl_pct ? Number(signal.t1_pnl_pct) : 0
          const totalPnl = (t1Pnl + runnerPnl) / 2

          await supabase.from("trade_signals").update({
            status: totalPnl > 0 ? "target_hit" : "invalidated",
            outcome: totalPnl > 0 ? "win" : "loss",
            outcome_pct: Math.round(totalPnl * 100) / 100,
            runner_exit_price: runnerStop,
            runner_pnl_pct: Math.round(runnerPnl * 100) / 100,
            best_price: bestPrice,
            runner_stop: runnerStop,
            closed_at: now.toISOString(),
            duration_hours: Math.round((now.getTime() - new Date(signal.triggered_at).getTime()) / 3600000),
          }).eq("id", signal.id)
          notifyResolution(signal, totalPnl > 0 ? "runner_win" : "runner_loss", runnerStop)
          stats.runnerStops++
          stats.resolved++
        } else {
          // Update trailing values
          await supabase.from("trade_signals").update({
            best_price: bestPrice,
            runner_stop: runnerStop,
          }).eq("id", signal.id)
        }
      }
    } else {
      // --- SHORT ---
      if (!t1AlreadyHit) {
        // SL must be breached by buffer to filter out exchange-specific wicks
        if (candle.high >= sl * (1 + SL_BUFFER_PCT)) {
          const pnl = ((entryMid - sl) / entryMid) * 100
          await supabase.from("trade_signals").update({
            status: "invalidated",
            outcome: "loss",
            outcome_pct: Math.round(pnl * 100) / 100,
            closed_at: now.toISOString(),
            duration_hours: Math.round((now.getTime() - new Date(signal.triggered_at).getTime()) / 3600000),
          }).eq("id", signal.id)
          notifyResolution(signal, "stop_loss", sl)
          stats.losses++
          stats.resolved++
          continue
        }

        if (t1 && candle.low <= t1) {
          const t1Pnl = ((entryMid - t1) / entryMid) * 100
          await supabase.from("trade_signals").update({
            t1_hit_at: now.toISOString(),
            t1_pnl_pct: Math.round(t1Pnl * 100) / 100,
            best_price: candle.low,
            runner_stop: entryMid,  // Move to breakeven
          }).eq("id", signal.id)
          notifyResolution(signal, "t1_hit", t1)
          stats.t1Hits++
          continue // Skip runner eval this cycle
        }
      } else {
        // Phase 2: Runner — use latest candle only (not aggregated) to avoid stale data
        bestPrice = Math.min(bestPrice, latestOnly.low)
        runnerStop = Math.min(runnerStop, bestPrice + risk1r)

        if (latestOnly.high >= runnerStop) {
          const runnerPnl = ((entryMid - runnerStop) / entryMid) * 100
          const t1Pnl = signal.t1_pnl_pct ? Number(signal.t1_pnl_pct) : 0
          const totalPnl = (t1Pnl + runnerPnl) / 2

          await supabase.from("trade_signals").update({
            status: totalPnl > 0 ? "target_hit" : "invalidated",
            outcome: totalPnl > 0 ? "win" : "loss",
            outcome_pct: Math.round(totalPnl * 100) / 100,
            runner_exit_price: runnerStop,
            runner_pnl_pct: Math.round(runnerPnl * 100) / 100,
            best_price: bestPrice,
            runner_stop: runnerStop,
            closed_at: now.toISOString(),
            duration_hours: Math.round((now.getTime() - new Date(signal.triggered_at).getTime()) / 3600000),
          }).eq("id", signal.id)
          notifyResolution(signal, totalPnl > 0 ? "runner_win" : "runner_loss", runnerStop)
          stats.runnerStops++
          stats.resolved++
        } else {
          await supabase.from("trade_signals").update({
            best_price: bestPrice,
            runner_stop: runnerStop,
          }).eq("id", signal.id)
        }
      }
    }
  }

  return stats
}

// ─── Utilities ───────────────────────────────────────────────────────────────

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

// ─── Resolution Notification Helper ─────────────────────────────────────────

type ResolutionEvent = "stop_loss" | "t1_hit" | "runner_win" | "runner_loss" | "expired_win" | "expired_loss"

function notifyResolution(signal: any, event: ResolutionEvent, price: number): void {
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  if (!supabaseUrl || !cronSecret) return

  const ticker = signal.asset
  const isBuy = signal.signal_type === "buy" || signal.signal_type === "strong_buy"
  const direction = isBuy ? "Long" : "Short"
  const priceStr = price > 1000 ? `$${Math.round(price).toLocaleString()}` : price > 1 ? `$${price.toFixed(2)}` : `$${price.toFixed(4)}`

  let emoji: string, title: string, body: string
  const entryMid = Number(signal.entry_price_mid)
  const pnl = isBuy ? ((price - entryMid) / entryMid) * 100 : ((entryMid - price) / entryMid) * 100
  const t1Pnl = signal.t1_pnl_pct ? Number(signal.t1_pnl_pct) : 0

  switch (event) {
    case "stop_loss":
      emoji = "🛑"; title = `${emoji} ${ticker} ${direction} — Stop Loss Hit`
      body = `Closed at ${priceStr}. PnL: ${pnl >= 0 ? "+" : ""}${pnl.toFixed(2)}%`
      break
    case "t1_hit":
      emoji = "🎯"; title = `${emoji} ${ticker} ${direction} — Target 1 Hit!`
      body = `T1 at ${priceStr} reached. 50% locked, runner trailing with BE stop.`
      break
    case "runner_win":
      emoji = "✅"; title = `${emoji} ${ticker} ${direction} — Runner Closed (Win)`
      body = `Trailing stop at ${priceStr}. T1: +${t1Pnl.toFixed(2)}%`
      break
    case "runner_loss":
      emoji = "📉"; title = `${emoji} ${ticker} ${direction} — Runner Closed`
      body = `Trailing stop at ${priceStr}. T1: +${t1Pnl.toFixed(2)}%`
      break
    case "expired_win":
      emoji = "⏰"; title = `${emoji} ${ticker} ${direction} — Expired (Profit)`
      body = `Signal expired at ${priceStr}. T1: +${t1Pnl.toFixed(2)}%`
      break
    case "expired_loss":
      emoji = "⏰"; title = `${emoji} ${ticker} ${direction} — Expired`
      body = `Signal expired at ${priceStr}. No target reached.`
      break
  }

  // Map event to preference key
  const eventTypeMap: Record<ResolutionEvent, string> = {
    stop_loss: "signal_stop_loss",
    t1_hit: "signal_t1_hit",
    runner_win: "signal_runner_close",
    runner_loss: "signal_runner_close",
    expired_win: "signal_expiry",
    expired_loss: "signal_expiry",
  }

  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
  fetch(`${supabaseUrl}/functions/v1/send-broadcast-notification`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${anonKey}`, "x-cron-secret": cronSecret },
    body: JSON.stringify({
      broadcast_id: signal.id,
      title, body,
      event_type: eventTypeMap[event],
      target_audience: { type: "all" },
    }),
  }).catch(() => {})
}
