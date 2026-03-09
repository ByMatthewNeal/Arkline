import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * fibonacci-pipeline Edge Function
 *
 * Multi-Asset Golden Pocket Strategy — 4H Entry / 1D Bias
 *
 * Runs every 4 hours at 0:05, 4:05, 8:05, 12:05, 16:05, 20:05 UTC
 * (all six 4H candle closes):
 *   1. Fetches 4h + 1D OHLC candles from Binance for each asset
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
  symbol: string   // Binance pair e.g. "BTCUSDT"
  ticker: string   // Display ticker e.g. "BTC"
}

const ASSETS: AssetConfig[] = [
  { symbol: "BTCUSDT",  ticker: "BTC" },
  { symbol: "ETHUSDT",  ticker: "ETH" },
  { symbol: "SOLUSDT",  ticker: "SOL" },
  { symbol: "SUIUSDT",  ticker: "SUI" },
  { symbol: "LINKUSDT", ticker: "LINK" },
  { symbol: "ADAUSDT",  ticker: "ADA" },
]

const TIMEFRAME_CONFIGS = [
  { timeframe: "4h", interval: "4h", limit: 250 },  // ~42 days, enough for EMA 50 + swing detection
  { timeframe: "1d", interval: "1d", limit: 200 },   // ~200 days (need 147+ for 21W EMA)
] as const

const SWING_PARAMS: Record<string, { lookback: number; minReversal: number }> = {
  "4h": { lookback: 8, minReversal: 5.0 },
  "1d": { lookback: 5, minReversal: 8.0 },
}

// Only the golden pocket
const FIB_RATIOS = [0.618, 0.786]

const CONFLUENCE_TOLERANCE_PCT = 1.5
const SIGNAL_PROXIMITY_PCT = 2.0
const MIN_RR_RATIO = 1.0
const STRONG_MIN_RR_RATIO = 2.0
const STRONG_MIN_CONFLUENCE = 2
const SIGNAL_EXPIRY_HOURS = 72       // 3 days
const WICK_REJECTION_RATIO = 1.5
const VOLUME_SPIKE_RATIO = 1.3

// EMA periods for trend filter
const EMA_FAST_PERIOD = 20
const EMA_SLOW_PERIOD = 50
const EMA_SLOPE_LOOKBACK = 6  // 6 x 4h = 24h for slope check
const EMA_PULLBACK_TOLERANCE = 0.008

// Delay between assets to stay safe on Binance rate limits
const INTER_ASSET_DELAY_MS = 500

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

  // Consume request body (ignored — all runs are full pipeline)
  try { await req.json() } catch {}

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
    for (const asset of ASSETS) {
      const assetResults: Record<string, unknown> = {}

      // Fetch latest candles
      const candles = await fetchCandles(asset.symbol)
      assetResults.candles = { "4h": candles["4h"].length, "1d": candles["1d"].length }

      // Store candles in DB
      await storeCandles(supabase, asset.ticker, candles)

      // Resolve open signals against latest candle
      const resolveResult = await resolveOpenSignals(supabase, asset.ticker, candles)
      assetResults.resolved = resolveResult

      // Full pipeline: detect swings, compute fibs, find zones, generate signals
      const swings = detectAllSwings(candles)
      await storeSwings(supabase, asset.ticker, swings)
      assetResults.swings = { "4h": swings["4h"].length, "1d": swings["1d"].length }

      const fibs = computeAllFibs(swings)
      await storeFibs(supabase, asset.ticker, fibs)
      assetResults.fibs = fibs.length

      if (candles["4h"].length === 0) {
        assetResults.skipped = "No 4h candles"
        allResults[asset.ticker] = assetResults
        continue
      }

      const currentPrice = candles["4h"][candles["4h"].length - 1].close
      const zones = clusterLevels(fibs, currentPrice)
      await storeZones(supabase, asset.ticker, zones, currentPrice)
      assetResults.zones = zones.length

      // Compute volume profile from 4h candles
      const volumeNodes = computeVolumeProfile(candles["4h"])

      const newSignals = await evaluateSignals(supabase, asset.ticker, candles, zones, fibs, currentPrice, volumeNodes, fearGreedIndex, btcRiskScore)
      assetResults.newSignals = newSignals

      await pruneOldCandles(supabase, asset.ticker)

      allResults[asset.ticker] = assetResults

      // Small delay between assets
      await sleep(INTER_ASSET_DELAY_MS)
    }

    return jsonResponse({ success: true, assets: allResults })
  } catch (err) {
    return jsonResponse({ error: "Pipeline failed", detail: String(err), partial: allResults }, 500)
  }
})

// ─── Fetch Candles from Binance ──────────────────────────────────────────────

async function fetchCandles(symbol: string): Promise<Record<string, Candle[]>> {
  const result: Record<string, Candle[]> = {}

  for (const config of TIMEFRAME_CONFIGS) {
    const url = `https://api.binance.com/api/v3/klines?symbol=${symbol}&interval=${config.interval}&limit=${config.limit}`
    const res = await fetch(url, { headers: { Accept: "application/json" } })

    if (!res.ok) {
      result[config.timeframe] = []
      continue
    }

    const rawData: (string | number)[][] = await res.json()
    result[config.timeframe] = rawData.map((k) => ({
      open_time: new Date(Number(k[0])).toISOString(),
      open: parseFloat(String(k[1])),
      high: parseFloat(String(k[2])),
      low: parseFloat(String(k[3])),
      close: parseFloat(String(k[4])),
      volume: parseFloat(String(k[5])),
    }))

    await sleep(300)
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
  const retentionDays: Record<string, number> = { "4h": 60, "1d": 180 }

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

function detectAllSwings(candles: Record<string, Candle[]>): Record<string, SwingPoint[]> {
  const result: Record<string, SwingPoint[]> = {}

  for (const [tf, tfCandles] of Object.entries(candles)) {
    const params = SWING_PARAMS[tf]
    if (!params || tfCandles.length < params.lookback * 2 + 1) {
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

function clusterLevels(fibs: FibLevel[], currentPrice: number): ConfluenceZone[] {
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

    if (distancePct <= CONFLUENCE_TOLERANCE_PCT) {
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

  const latest = candles[candles.length - 1]
  const prev = candles[candles.length - 2]

  if (isBuy) {
    const body = Math.abs(latest.close - latest.open)
    const lowerWick = Math.min(latest.open, latest.close) - latest.low
    if (lowerWick >= WICK_REJECTION_RATIO * Math.max(body, 0.001) && latest.close > zoneLow) {
      details.wick_rejection = true
    }
    if (latest.close > zoneHigh && prev.close > zoneHigh && prev.low <= zoneHigh) {
      details.consecutive_closes = true
    }
  } else {
    const body = Math.abs(latest.close - latest.open)
    const upperWick = latest.high - Math.max(latest.open, latest.close)
    if (upperWick >= WICK_REJECTION_RATIO * Math.max(body, 0.001) && latest.close < zoneHigh) {
      details.wick_rejection = true
    }
    if (latest.close < zoneLow && prev.close < zoneLow && prev.high >= zoneLow) {
      details.consecutive_closes = true
    }
  }

  // Volume spike
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

  if (isBuy) {
    const levelsBelow = sorted.filter((p) => p < zone.low)
    const nextDown = levelsBelow.length > 0 ? levelsBelow[levelsBelow.length - 1] : null
    const stopLoss = nextDown ? nextDown * 0.997 : zoneMid * 0.985

    const levelsAbove = sorted.filter((p) => p > zone.high)
    const target1 = levelsAbove.length > 0 ? levelsAbove[0] : zoneMid * 1.03
    const target2 = levelsAbove.length > 1 ? levelsAbove[1] : target1 * 1.015

    return { target1, target2, stopLoss }
  } else {
    const levelsAbove = sorted.filter((p) => p > zone.high)
    const nextUp = levelsAbove.length > 0 ? levelsAbove[0] : null
    const stopLoss = nextUp ? nextUp * 1.003 : zoneMid * 1.015

    const levelsBelow = sorted.filter((p) => p < zone.low)
    const target1 = levelsBelow.length > 0 ? levelsBelow[levelsBelow.length - 1] : zoneMid * 0.97
    const target2 = levelsBelow.length > 1 ? levelsBelow[levelsBelow.length - 2] : target1 * 0.985

    return { target1, target2, stopLoss }
  }
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
): Promise<{ generated: number; skipped: number }> {
  const stats = { generated: 0, skipped: 0 }
  const candles4h = candles["4h"]

  if (!candles4h || candles4h.length < EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK) {
    return stats
  }

  const allFibPrices = fibs.map((f) => f.price)

  for (const zone of zones) {
    const distancePct = Math.abs((currentPrice - zone.mid) / currentPrice) * 100
    if (distancePct > SIGNAL_PROXIMITY_PCT) continue

    // Check for existing active/triggered signal near this zone
    const { data: existing } = await supabase
      .from("trade_signals")
      .select("id")
      .eq("asset", ticker)
      .in("status", ["active", "triggered"])
      .gte("entry_price_mid", zone.mid * 0.995)
      .lte("entry_price_mid", zone.mid * 1.005)
      .limit(1)

    if (existing && existing.length > 0) {
      stats.skipped++
      continue
    }

    const isBuy = zone.zone_type === "support"

    // EMA trend filter
    if (!checkTrendAlignment(candles4h, isBuy)) {
      stats.skipped++
      continue
    }

    // Bounce confirmation
    const bounce = checkBounce(candles4h.slice(-25), zone.low, zone.high, isBuy)
    if (!bounce.confirmed) {
      stats.skipped++
      continue
    }

    // Targets and stop
    const targets = computeTargetsAndStop(zone, allFibPrices, isBuy)
    if (!targets) continue

    const entryMid = zone.mid
    const riskDist = Math.abs(entryMid - targets.stopLoss)
    const rewardDist = Math.abs(targets.target1 - entryMid)
    const rrRatio = riskDist > 0 ? rewardDist / riskDist : 0

    if (rrRatio < MIN_RR_RATIO) continue

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

    const expiresAt = new Date(Date.now() + SIGNAL_EXPIRY_HOURS * 3600000).toISOString()

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

    const signalRow = {
      asset: ticker,
      signal_type: signalType,
      status: "triggered",  // Enter immediately on the 4h candle
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
      triggered_at: new Date().toISOString(),
      expires_at: expiresAt,
    }

    const { data: inserted, error } = await supabase
      .from("trade_signals")
      .insert(signalRow)
      .select("id")
      .single()

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

        fetch(`${supabaseUrl}/functions/v1/send-broadcast-notification`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-cron-secret": cronSecret,
          },
          body: JSON.stringify({
            broadcast_id: inserted.id,
            title: `${emoji} ${ticker} ${direction} Signal`,
            body: `${isStrong ? "Strong " : ""}${direction} at ${entryStr} | R:R ${rrRatio.toFixed(1)} | T1: ${t1Str} | SL: ${slStr}`,
            event_type: "signal_new",
            target_audience: { type: "premium" },
          }),
        }).catch(() => {})
      } catch {}

      // Generate briefing
      try {
        const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
        const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
        fetch(`${supabaseUrl}/functions/v1/generate-signal-briefing`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-cron-secret": cronSecret,
          },
          body: JSON.stringify({ signal_id: inserted.id }),
        }).catch(() => {})
      } catch {}
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

  const latestCandle = candles4h[candles4h.length - 1]
  const now = new Date()

  // Get all triggered signals for this asset
  const { data: signals } = await supabase
    .from("trade_signals")
    .select("*")
    .eq("asset", ticker)
    .eq("status", "triggered")

  if (!signals || signals.length === 0) return stats

  for (const signal of signals) {
    const isBuy = signal.signal_type === "buy" || signal.signal_type === "strong_buy"
    const entryMid = Number(signal.entry_price_mid)
    const t1 = signal.target_1 ? Number(signal.target_1) : null
    const sl = Number(signal.stop_loss)
    const risk1r = signal.risk_1r ? Number(signal.risk_1r) : Math.abs(entryMid - sl)
    const t1AlreadyHit = !!signal.t1_hit_at
    let bestPrice = signal.best_price ? Number(signal.best_price) : entryMid
    let runnerStop = signal.runner_stop ? Number(signal.runner_stop) : sl

    // --- Expiry check ---
    if (signal.expires_at && new Date(signal.expires_at) <= now) {
      const exitPrice = latestCandle.close

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
        if (latestCandle.low <= sl) {
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

        if (t1 && latestCandle.high >= t1) {
          const t1Pnl = ((t1 - entryMid) / entryMid) * 100
          await supabase.from("trade_signals").update({
            t1_hit_at: now.toISOString(),
            t1_pnl_pct: Math.round(t1Pnl * 100) / 100,
            best_price: latestCandle.high,
            runner_stop: entryMid,  // Move to breakeven
          }).eq("id", signal.id)
          notifyResolution(signal, "t1_hit", t1)
          stats.t1Hits++
        }
      } else {
        // Phase 2: Runner — trail stop at 1R behind best price
        bestPrice = Math.max(bestPrice, latestCandle.high)
        runnerStop = Math.max(runnerStop, bestPrice - risk1r)

        if (latestCandle.low <= runnerStop) {
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
        if (latestCandle.high >= sl) {
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

        if (t1 && latestCandle.low <= t1) {
          const t1Pnl = ((entryMid - t1) / entryMid) * 100
          await supabase.from("trade_signals").update({
            t1_hit_at: now.toISOString(),
            t1_pnl_pct: Math.round(t1Pnl * 100) / 100,
            best_price: latestCandle.low,
            runner_stop: entryMid,  // Move to breakeven
          }).eq("id", signal.id)
          notifyResolution(signal, "t1_hit", t1)
          stats.t1Hits++
        }
      } else {
        bestPrice = Math.min(bestPrice, latestCandle.low)
        runnerStop = Math.min(runnerStop, bestPrice + risk1r)

        if (latestCandle.high >= runnerStop) {
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

  fetch(`${supabaseUrl}/functions/v1/send-broadcast-notification`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "x-cron-secret": cronSecret },
    body: JSON.stringify({
      broadcast_id: signal.id,
      title, body,
      event_type: eventTypeMap[event],
      target_audience: { type: "premium" },
    }),
  }).catch(() => {})
}
