import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * fibonacci-pipeline Edge Function
 *
 * Hourly pipeline that:
 * 1. Fetches OHLC candles from CoinGecko
 * 2. Detects swing highs/lows
 * 3. Computes Fibonacci retracement/extension levels
 * 4. Finds confluence zones across timeframes
 * 5. Evaluates entry signal conditions
 *
 * Triggered by pg_cron every hour (5 minutes past).
 */

// ─── Configuration ───────────────────────────────────────────────────────────

const ASSETS: Record<string, string> = {
  bitcoin: "BTC",
  ethereum: "ETH",
  solana: "SOL",
  binancecoin: "BNB",
  "render-token": "RENDER",
  ondo: "ONDO",
  sui: "SUI",
  uniswap: "UNI",
}

// CoinGecko /coins/{id}/ohlc returns different granularity based on `days`:
//   1-2 days → 30min candles, 3-30 days → 4h candles, 31+ days → 4-day candles
// For the demo API, the OHLC endpoint gives limited granularity.
// We'll fetch 1d (30-min → aggregate to 1h), 30d (4h native), 90d (aggregate to 1d).
const TIMEFRAME_CONFIGS = [
  { timeframe: "1h", days: 2, aggregateMinutes: 60 },
  { timeframe: "4h", days: 30, aggregateMinutes: 240 },
  { timeframe: "1d", days: 90, aggregateMinutes: 1440 },
] as const

// Swing detection parameters (tunable)
const SWING_PARAMS: Record<string, { lookback: number; minReversal: number }> = {
  "1d": { lookback: 5, minReversal: 8 },
  "4h": { lookback: 8, minReversal: 5 },
  "1h": { lookback: 10, minReversal: 2.5 },
}

// Fibonacci ratios
const FIB_RATIOS = [0.236, 0.382, 0.500, 0.618, 0.786] as const
const EXT_RATIOS = [1.272, 1.618] as const

// Confluence clustering tolerance
const CONFLUENCE_TOLERANCE_PCT = 2
const MAX_DISTANCE_PCT = 20

// Signal evaluation thresholds
const SIGNAL_PROXIMITY_PCT = 3 // Price must be within 3% of confluence zone
const MIN_RR_RATIO = 2.0
const STRONG_MIN_RR_RATIO = 3.0
const STRONG_MIN_CONFLUENCE = 3
const MAX_RISK_SCORE = 0.50
const MAX_FEAR_GREED = 45
const MIN_COINBASE_RANK = 50 // Must be OUTSIDE top 50 (higher number = less retail)
const SIGNAL_EXPIRY_HOURS = 72
const WICK_REJECTION_RATIO = 2.0 // Lower wick >= 2x body
const VOLUME_SPIKE_RATIO = 1.5 // Volume >= 1.5x 20-period average

// ─── Types ───────────────────────────────────────────────────────────────────

interface OHLCCandle {
  open_time: string
  open: number
  high: number
  low: number
  close: number
  volume: number | null
}

interface SwingPoint {
  id?: string
  asset: string
  timeframe: string
  type: "high" | "low"
  price: number
  candle_time: string
  reversal_pct: number
  is_active: boolean
}

interface FibLevel {
  timeframe: string
  level_name: string
  price: number
}

interface ConfluenceZone {
  asset: string
  zone_type: "support" | "resistance"
  zone_low: number
  zone_high: number
  zone_mid: number
  strength: number
  contributing_levels: FibLevel[]
  distance_pct: number
  is_active: boolean
}

interface MarketConditions {
  fearGreedIndex: number | null
  coinbaseRanking: number | null
  btcRiskScore: number | null
  macroRegime: string | null
}

// ─── Main Handler ────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405)
  }

  // Verify cron secret
  const secret = req.headers.get("x-cron-secret") ?? ""
  const expectedSecret = Deno.env.get("CRON_SECRET") ?? ""
  if (!expectedSecret || secret !== expectedSecret) {
    return jsonResponse({ error: "Unauthorized" }, 401)
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )

  const results: Record<string, unknown> = {}

  try {
    // Step 1: Fetch OHLC candles for all assets
    const ohlcResult = await fetchAllOHLC(supabase)
    results.ohlc = ohlcResult

    // Step 2: Detect swing points
    const swingResult = await detectAllSwings(supabase)
    results.swings = swingResult

    // Step 3: Compute Fibonacci levels
    const fibResult = await computeAllFibs(supabase)
    results.fibs = fibResult

    // Step 4: Find confluence zones
    const confluenceResult = await findAllConfluence(supabase)
    results.confluence = confluenceResult

    // Step 5: Evaluate entry conditions and generate new signals
    const evalResult = await evaluateEntrySignals(supabase)
    results.newSignals = evalResult

    // Step 6: Update existing signal statuses
    const signalResult = await updateSignalStatuses(supabase)
    results.signals = signalResult

    return jsonResponse({ success: true, ...results })
  } catch (err) {
    return jsonResponse({ error: "Pipeline failed", detail: String(err) }, 500)
  }
})

// ─── Step 1: Fetch OHLC ─────────────────────────────────────────────────────

async function fetchAllOHLC(supabase: SupabaseClient): Promise<Record<string, unknown>> {
  const cgApiKey = Deno.env.get("COINGECKO_API_KEY") ?? ""
  const headerName = cgApiKey.startsWith("CG-") ? "x-cg-demo-api-key" : "x-cg-pro-api-key"

  const stats: Record<string, number> = { fetched: 0, upserted: 0, errors: 0 }

  for (const [cgId, symbol] of Object.entries(ASSETS)) {
    for (const config of TIMEFRAME_CONFIGS) {
      try {
        const url = `https://api.coingecko.com/api/v3/coins/${cgId}/ohlc?vs_currency=usd&days=${config.days}`
        const res = await fetch(url, {
          headers: { [headerName]: cgApiKey, Accept: "application/json" },
        })

        if (!res.ok) {
          stats.errors++
          continue
        }

        // CoinGecko returns [[timestamp, open, high, low, close], ...]
        const rawData: number[][] = await res.json()
        if (!Array.isArray(rawData) || rawData.length === 0) continue

        stats.fetched++

        // Aggregate candles to the target timeframe
        const candles = aggregateCandles(rawData, config.aggregateMinutes)

        // Upsert into ohlc_candles
        const rows = candles.map((c) => ({
          asset: symbol,
          timeframe: config.timeframe,
          open_time: c.open_time,
          open: c.open,
          high: c.high,
          low: c.low,
          close: c.close,
          volume: c.volume,
        }))

        if (rows.length > 0) {
          const { error } = await supabase
            .from("ohlc_candles")
            .upsert(rows, { onConflict: "asset,timeframe,open_time" })

          if (!error) stats.upserted += rows.length
          else stats.errors++
        }

        // Rate limit: ~30 calls/min on demo plan
        await sleep(2500)
      } catch {
        stats.errors++
      }
    }
  }

  // Prune old candles
  await pruneOldCandles(supabase)

  return stats
}

function aggregateCandles(raw: number[][], targetMinutes: number): OHLCCandle[] {
  if (raw.length === 0) return []

  const result: OHLCCandle[] = []
  const msInterval = targetMinutes * 60 * 1000

  let currentBucket = Math.floor(raw[0][0] / msInterval) * msInterval
  let open = raw[0][1]
  let high = raw[0][2]
  let low = raw[0][3]
  let close = raw[0][4]

  for (let i = 1; i < raw.length; i++) {
    const ts = raw[i][0]
    const bucket = Math.floor(ts / msInterval) * msInterval

    if (bucket !== currentBucket) {
      result.push({
        open_time: new Date(currentBucket).toISOString(),
        open,
        high,
        low,
        close,
        volume: null,
      })

      currentBucket = bucket
      open = raw[i][1]
      high = raw[i][2]
      low = raw[i][3]
      close = raw[i][4]
    } else {
      high = Math.max(high, raw[i][2])
      low = Math.min(low, raw[i][3])
      close = raw[i][4]
    }
  }

  // Push last bucket
  result.push({
    open_time: new Date(currentBucket).toISOString(),
    open,
    high,
    low,
    close,
    volume: null,
  })

  return result
}

async function pruneOldCandles(supabase: SupabaseClient) {
  const now = new Date()
  const retentionDays: Record<string, number> = { "1h": 14, "4h": 30, "1d": 90 }

  for (const [tf, days] of Object.entries(retentionDays)) {
    const cutoff = new Date(now.getTime() - days * 24 * 60 * 60 * 1000).toISOString()
    await supabase
      .from("ohlc_candles")
      .delete()
      .eq("timeframe", tf)
      .lt("open_time", cutoff)
  }
}

// ─── Step 2: Swing Detection ────────────────────────────────────────────────

async function detectAllSwings(supabase: SupabaseClient): Promise<Record<string, number>> {
  const stats = { detected: 0, deactivated: 0 }

  for (const symbol of Object.values(ASSETS)) {
    for (const [timeframe, params] of Object.entries(SWING_PARAMS)) {
      const { data: candles } = await supabase
        .from("ohlc_candles")
        .select("open_time, high, low, close")
        .eq("asset", symbol)
        .eq("timeframe", timeframe)
        .order("open_time", { ascending: true })

      if (!candles || candles.length < params.lookback * 2 + 1) continue

      const swings = detectSwings(
        candles as Array<{ open_time: string; high: number; low: number; close: number }>,
        params.lookback,
        params.minReversal,
      )

      // Deactivate old swing points for this asset/timeframe
      if (swings.length > 0) {
        await supabase
          .from("swing_points")
          .update({ is_active: false })
          .eq("asset", symbol)
          .eq("timeframe", timeframe)
          .eq("is_active", true)

        stats.deactivated++
      }

      // Find the most recent swing high and swing low
      const latestHigh = [...swings].reverse().find((s) => s.type === "high")
      const latestLow = [...swings].reverse().find((s) => s.type === "low")

      const toInsert: SwingPoint[] = []
      if (latestHigh) toInsert.push({ ...latestHigh, asset: symbol, timeframe, is_active: true })
      if (latestLow) toInsert.push({ ...latestLow, asset: symbol, timeframe, is_active: true })

      for (const sp of toInsert) {
        const { error } = await supabase
          .from("swing_points")
          .upsert(
            {
              asset: sp.asset,
              timeframe: sp.timeframe,
              type: sp.type,
              price: sp.price,
              candle_time: sp.candle_time,
              reversal_pct: sp.reversal_pct,
              is_active: true,
            },
            { onConflict: "asset,timeframe,type,candle_time" },
          )

        if (!error) stats.detected++
      }
    }
  }

  return stats
}

function detectSwings(
  candles: Array<{ open_time: string; high: number; low: number; close: number }>,
  lookback: number,
  minReversal: number,
): Array<{ type: "high" | "low"; price: number; candle_time: string; reversal_pct: number }> {
  const swings: Array<{
    type: "high" | "low"
    price: number
    candle_time: string
    reversal_pct: number
  }> = []

  for (let i = lookback; i < candles.length - lookback; i++) {
    const candle = candles[i]

    // Check for swing high
    let isSwingHigh = true
    for (let j = i - lookback; j <= i + lookback; j++) {
      if (j === i) continue
      if (candles[j].high >= candle.high) {
        isSwingHigh = false
        break
      }
    }

    if (isSwingHigh) {
      // Check if price reversed at least minReversal% from this high
      let minLowAfter = candle.high
      for (let j = i + 1; j < candles.length; j++) {
        minLowAfter = Math.min(minLowAfter, candles[j].low)
      }
      const reversalPct = ((candle.high - minLowAfter) / candle.high) * 100

      if (reversalPct >= minReversal) {
        swings.push({
          type: "high",
          price: candle.high,
          candle_time: candle.open_time,
          reversal_pct: Math.round(reversalPct * 100) / 100,
        })
      }
    }

    // Check for swing low
    let isSwingLow = true
    for (let j = i - lookback; j <= i + lookback; j++) {
      if (j === i) continue
      if (candles[j].low <= candle.low) {
        isSwingLow = false
        break
      }
    }

    if (isSwingLow) {
      // Check if price reversed at least minReversal% from this low
      let maxHighAfter = candle.low
      for (let j = i + 1; j < candles.length; j++) {
        maxHighAfter = Math.max(maxHighAfter, candles[j].high)
      }
      const reversalPct = ((maxHighAfter - candle.low) / candle.low) * 100

      if (reversalPct >= minReversal) {
        swings.push({
          type: "low",
          price: candle.low,
          candle_time: candle.open_time,
          reversal_pct: Math.round(reversalPct * 100) / 100,
        })
      }
    }
  }

  return swings
}

// ─── Step 3: Fibonacci Levels ───────────────────────────────────────────────

async function computeAllFibs(supabase: SupabaseClient): Promise<Record<string, number>> {
  const stats = { computed: 0 }

  // Mark all current fibs as not current
  await supabase.from("fib_levels").update({ is_current: false }).eq("is_current", true)

  for (const symbol of Object.values(ASSETS)) {
    for (const timeframe of Object.keys(SWING_PARAMS)) {
      // Get active swing high and low for this asset/timeframe
      const { data: swings } = await supabase
        .from("swing_points")
        .select("*")
        .eq("asset", symbol)
        .eq("timeframe", timeframe)
        .eq("is_active", true)

      if (!swings || swings.length < 2) continue

      const swingHigh = swings.find((s: SwingPoint) => s.type === "high")
      const swingLow = swings.find((s: SwingPoint) => s.type === "low")

      if (!swingHigh || !swingLow) continue

      const H = Number(swingHigh.price)
      const L = Number(swingLow.price)
      const range = H - L

      if (range <= 0) continue

      // Determine move direction: was the low before the high (upswing) or vice versa?
      const lowFirst = new Date(swingLow.candle_time) < new Date(swingHigh.candle_time)

      if (lowFirst) {
        // Upswing: retracement levels project downward from the high
        const retracementRow = {
          asset: symbol,
          timeframe,
          direction: "retracement",
          swing_high_price: H,
          swing_low_price: L,
          swing_high_time: swingHigh.candle_time,
          swing_low_time: swingLow.candle_time,
          level_236: H - range * 0.236,
          level_382: H - range * 0.382,
          level_500: H - range * 0.500,
          level_618: H - range * 0.618,
          level_786: H - range * 0.786,
          ext_1272: null,
          ext_1618: null,
          is_current: true,
        }

        // Extension levels project upward beyond the high
        const extensionRow = {
          ...retracementRow,
          direction: "extension",
          level_236: L + range * 0.236,
          level_382: L + range * 0.382,
          level_500: L + range * 0.500,
          level_618: L + range * 0.618,
          level_786: L + range * 0.786,
          ext_1272: L + range * 1.272,
          ext_1618: L + range * 1.618,
        }

        const { error: e1 } = await supabase
          .from("fib_levels")
          .upsert(retracementRow, {
            onConflict: "asset,timeframe,direction,swing_high_time,swing_low_time",
          })
        if (!e1) stats.computed++

        const { error: e2 } = await supabase
          .from("fib_levels")
          .upsert(extensionRow, {
            onConflict: "asset,timeframe,direction,swing_high_time,swing_low_time",
          })
        if (!e2) stats.computed++
      } else {
        // Downswing: retracement levels project upward from the low
        const retracementRow = {
          asset: symbol,
          timeframe,
          direction: "retracement",
          swing_high_price: H,
          swing_low_price: L,
          swing_high_time: swingHigh.candle_time,
          swing_low_time: swingLow.candle_time,
          level_236: L + range * 0.236,
          level_382: L + range * 0.382,
          level_500: L + range * 0.500,
          level_618: L + range * 0.618,
          level_786: L + range * 0.786,
          ext_1272: null,
          ext_1618: null,
          is_current: true,
        }

        // Extension levels project downward below the low
        const extensionRow = {
          ...retracementRow,
          direction: "extension",
          level_236: H - range * 0.236,
          level_382: H - range * 0.382,
          level_500: H - range * 0.500,
          level_618: H - range * 0.618,
          level_786: H - range * 0.786,
          ext_1272: H - range * 1.272,
          ext_1618: H - range * 1.618,
        }

        const { error: e1 } = await supabase
          .from("fib_levels")
          .upsert(retracementRow, {
            onConflict: "asset,timeframe,direction,swing_high_time,swing_low_time",
          })
        if (!e1) stats.computed++

        const { error: e2 } = await supabase
          .from("fib_levels")
          .upsert(extensionRow, {
            onConflict: "asset,timeframe,direction,swing_high_time,swing_low_time",
          })
        if (!e2) stats.computed++
      }
    }
  }

  return stats
}

// ─── Step 4: Confluence Detection ───────────────────────────────────────────

async function findAllConfluence(supabase: SupabaseClient): Promise<Record<string, number>> {
  const stats = { zones_found: 0 }

  // Deactivate all existing confluence zones (we'll recompute)
  await supabase.from("fib_confluence_zones").update({ is_active: false }).eq("is_active", true)

  for (const symbol of Object.values(ASSETS)) {
    // Get current price
    const { data: latestCandle } = await supabase
      .from("ohlc_candles")
      .select("close")
      .eq("asset", symbol)
      .eq("timeframe", "1h")
      .order("open_time", { ascending: false })
      .limit(1)

    if (!latestCandle || latestCandle.length === 0) continue
    const currentPrice = Number(latestCandle[0].close)

    // Get all current fib levels for this asset
    const { data: fibs } = await supabase
      .from("fib_levels")
      .select("*")
      .eq("asset", symbol)
      .eq("is_current", true)

    if (!fibs || fibs.length === 0) continue

    // Flatten all level prices with metadata
    const allLevels: FibLevel[] = []
    for (const fib of fibs) {
      const levelNames = ["level_236", "level_382", "level_500", "level_618", "level_786"]
      for (const name of levelNames) {
        if (fib[name] != null) {
          allLevels.push({
            timeframe: fib.timeframe,
            level_name: `${fib.direction}_${name.replace("level_", "")}`,
            price: Number(fib[name]),
          })
        }
      }
      // Include extension levels
      if (fib.ext_1272 != null) {
        allLevels.push({
          timeframe: fib.timeframe,
          level_name: `${fib.direction}_ext_1272`,
          price: Number(fib.ext_1272),
        })
      }
      if (fib.ext_1618 != null) {
        allLevels.push({
          timeframe: fib.timeframe,
          level_name: `${fib.direction}_ext_1618`,
          price: Number(fib.ext_1618),
        })
      }
    }

    // Sort by price
    allLevels.sort((a, b) => a.price - b.price)

    // Cluster levels within tolerance
    const zones = clusterLevels(allLevels, currentPrice, CONFLUENCE_TOLERANCE_PCT)

    // Filter: minimum 2 levels from different timeframes, within MAX_DISTANCE_PCT
    for (const zone of zones) {
      const uniqueTimeframes = new Set(zone.levels.map((l) => l.timeframe))
      if (uniqueTimeframes.size < 2) continue

      const distancePct = Math.abs(((zone.mid - currentPrice) / currentPrice) * 100)
      if (distancePct > MAX_DISTANCE_PCT) continue

      const zoneType: "support" | "resistance" = zone.mid < currentPrice ? "support" : "resistance"

      const row: ConfluenceZone = {
        asset: symbol,
        zone_type: zoneType,
        zone_low: zone.low,
        zone_high: zone.high,
        zone_mid: zone.mid,
        strength: zone.levels.length,
        contributing_levels: zone.levels,
        distance_pct: Math.round(distancePct * 100) / 100,
        is_active: true,
      }

      const { error } = await supabase.from("fib_confluence_zones").insert(row)
      if (!error) stats.zones_found++
    }
  }

  return stats
}

function clusterLevels(
  levels: FibLevel[],
  currentPrice: number,
  tolerancePct: number,
): Array<{ low: number; high: number; mid: number; levels: FibLevel[] }> {
  if (levels.length === 0) return []

  const clusters: Array<{ low: number; high: number; mid: number; levels: FibLevel[] }> = []
  let currentCluster: FibLevel[] = [levels[0]]
  let clusterLow = levels[0].price
  let clusterHigh = levels[0].price

  for (let i = 1; i < levels.length; i++) {
    const level = levels[i]
    const clusterMid = (clusterLow + clusterHigh) / 2
    const distancePct = Math.abs(((level.price - clusterMid) / clusterMid) * 100)

    if (distancePct <= tolerancePct) {
      currentCluster.push(level)
      clusterHigh = Math.max(clusterHigh, level.price)
      clusterLow = Math.min(clusterLow, level.price)
    } else {
      if (currentCluster.length >= 2) {
        clusters.push({
          low: clusterLow,
          high: clusterHigh,
          mid: (clusterLow + clusterHigh) / 2,
          levels: [...currentCluster],
        })
      }
      currentCluster = [level]
      clusterLow = level.price
      clusterHigh = level.price
    }
  }

  // Don't forget last cluster
  if (currentCluster.length >= 2) {
    clusters.push({
      low: clusterLow,
      high: clusterHigh,
      mid: (clusterLow + clusterHigh) / 2,
      levels: [...currentCluster],
    })
  }

  return clusters
}

// ─── Step 5: Evaluate Entry Signals ─────────────────────────────────────────

async function evaluateEntrySignals(supabase: SupabaseClient): Promise<Record<string, number>> {
  const stats = { generated: 0, skipped_conditions: 0 }

  // Fetch market conditions once (shared across all asset evaluations)
  const conditions = await fetchMarketConditions(supabase)

  // Only generate signals when BTC conditions support it (alts follow BTC structure)
  if (conditions.fearGreedIndex !== null && conditions.fearGreedIndex > MAX_FEAR_GREED) {
    stats.skipped_conditions++
    return stats
  }
  if (conditions.btcRiskScore !== null && conditions.btcRiskScore > MAX_RISK_SCORE) {
    stats.skipped_conditions++
    return stats
  }
  if (conditions.coinbaseRanking !== null && conditions.coinbaseRanking <= MIN_COINBASE_RANK) {
    stats.skipped_conditions++
    return stats
  }

  // Get all active confluence zones
  const { data: zones } = await supabase
    .from("fib_confluence_zones")
    .select("*")
    .eq("is_active", true)
    .lte("distance_pct", SIGNAL_PROXIMITY_PCT)

  if (!zones || zones.length === 0) return stats

  for (const zone of zones) {
    // Check if there's already an active/triggered signal for this zone
    const { data: existingSignals } = await supabase
      .from("trade_signals")
      .select("id")
      .eq("confluence_zone_id", zone.id)
      .in("status", ["active", "triggered"])
      .limit(1)

    if (existingSignals && existingSignals.length > 0) continue

    // Get current price and candles for this asset
    const { data: recentCandles } = await supabase
      .from("ohlc_candles")
      .select("open_time, open, high, low, close, volume")
      .eq("asset", zone.asset)
      .eq("timeframe", "1h")
      .order("open_time", { ascending: false })
      .limit(25) // Need 20 for volume average + recent candles for bounce check

    if (!recentCandles || recentCandles.length < 3) continue

    const currentPrice = Number(recentCandles[0].close)

    // Check proximity: is price within SIGNAL_PROXIMITY_PCT of the zone?
    const distancePct = Math.abs(((currentPrice - Number(zone.zone_mid)) / currentPrice) * 100)
    if (distancePct > SIGNAL_PROXIMITY_PCT) continue

    // Check bounce confirmation
    const isBuyZone = zone.zone_type === "support"
    const confirmation = checkBounceConfirmation(
      recentCandles as Array<{ open_time: string; open: number; high: number; low: number; close: number; volume: number | null }>,
      Number(zone.zone_low),
      Number(zone.zone_high),
      isBuyZone,
    )

    if (!confirmation.confirmed) continue

    // Compute targets and stop loss
    const targets = computeTargetsAndStop(supabase, zone, currentPrice, isBuyZone)
    const { target1, target2, stopLoss } = await targets

    if (!target1 || !stopLoss) continue

    // Compute risk/reward ratio
    const entryMid = Number(zone.zone_mid)
    const riskDistance = Math.abs(entryMid - stopLoss)
    const rewardDistance = Math.abs(target1 - entryMid)
    const rrRatio = riskDistance > 0 ? rewardDistance / riskDistance : 0

    if (rrRatio < MIN_RR_RATIO) continue

    // Determine signal strength
    const confluenceStrength = Number(zone.strength)
    const isStrong = rrRatio >= STRONG_MIN_RR_RATIO && confluenceStrength >= STRONG_MIN_CONFLUENCE
    const signalType = isBuyZone
      ? (isStrong ? "strong_buy" : "buy")
      : (isStrong ? "strong_sell" : "sell")

    // Generate the signal
    const expiresAt = new Date(Date.now() + SIGNAL_EXPIRY_HOURS * 3600 * 1000).toISOString()

    const signalRow = {
      asset: zone.asset,
      signal_type: signalType,
      status: "active",
      entry_zone_low: zone.zone_low,
      entry_zone_high: zone.zone_high,
      entry_price_mid: zone.zone_mid,
      confluence_zone_id: zone.id,
      target_1: target1,
      target_2: target2,
      stop_loss: stopLoss,
      risk_reward_ratio: Math.round(rrRatio * 100) / 100,
      invalidation_note: isBuyZone
        ? `Daily close below $${stopLoss.toLocaleString()}`
        : `Daily close above $${stopLoss.toLocaleString()}`,
      btc_risk_score: conditions.btcRiskScore,
      fear_greed_index: conditions.fearGreedIndex,
      macro_regime: conditions.macroRegime,
      coinbase_ranking: conditions.coinbaseRanking,
      bounce_confirmed: true,
      confirmation_details: confirmation.details,
      expires_at: expiresAt,
    }

    const { data: inserted, error } = await supabase
      .from("trade_signals")
      .insert(signalRow)
      .select("id")
      .single()

    if (!error && inserted) {
      stats.generated++

      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
      const cronSecret = Deno.env.get("CRON_SECRET") ?? ""

      // Trigger briefing generation asynchronously
      try {
        fetch(`${supabaseUrl}/functions/v1/generate-signal-briefing`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-cron-secret": cronSecret,
          },
          body: JSON.stringify({ signal_id: inserted.id }),
        }).catch(() => { /* fire and forget */ })
      } catch { /* non-fatal */ }

      // Send push notification for strong signals
      if (isStrong) {
        try {
          const emoji = isBuyZone ? "🎯" : "⚠️"
          const entryLow = Number(zone.zone_low)
          const entryHigh = Number(zone.zone_high)
          fetch(`${supabaseUrl}/functions/v1/send-broadcast-notification`, {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-cron-secret": cronSecret,
            },
            body: JSON.stringify({
              broadcast_id: inserted.id,
              title: `${emoji} ${zone.asset} Swing Setup`,
              body: `${signalType === "strong_buy" ? "Strong Buy" : "Strong Sell"} zone at $${entryLow.toLocaleString()}–$${entryHigh.toLocaleString()}. R:R ${rrRatio.toFixed(1)}x`,
              target_audience: { type: "premium" },
            }),
          }).catch(() => { /* fire and forget */ })
        } catch { /* non-fatal */ }
      }
    }
  }

  return stats
}

// ─── Market Conditions (fetched once per pipeline run) ──────────────────────

async function fetchMarketConditions(supabase: SupabaseClient): Promise<MarketConditions> {
  const conditions: MarketConditions = {
    fearGreedIndex: null,
    coinbaseRanking: null,
    btcRiskScore: null,
    macroRegime: null,
  }

  // 1. Fear & Greed Index from Alternative.me
  try {
    const fgRes = await fetch("https://api.alternative.me/fng/?limit=1")
    if (fgRes.ok) {
      const fgData = await fgRes.json()
      conditions.fearGreedIndex = Number(fgData?.data?.[0]?.value) || null
    }
  } catch { /* non-fatal */ }

  // 2. Coinbase ranking from app_store_rankings table
  try {
    const { data: rankRow } = await supabase
      .from("app_store_rankings")
      .select("ranking")
      .eq("app_name", "Coinbase")
      .order("recorded_date", { ascending: false })
      .limit(1)

    if (rankRow && rankRow.length > 0) {
      conditions.coinbaseRanking = Number(rankRow[0].ranking)
    }
  } catch { /* non-fatal */ }

  // 3. BTC risk score — server-side approximation using RSI + price vs 200 SMA
  try {
    conditions.btcRiskScore = await computeServerSideRiskScore(supabase)
  } catch { /* non-fatal */ }

  // 4. Macro regime — derive from latest market summary if available
  try {
    const todayUTC = new Date().toISOString().split("T")[0]
    const { data: summary } = await supabase
      .from("market_summaries")
      .select("summary")
      .eq("summary_date", todayUTC)
      .order("generated_at", { ascending: false })
      .limit(1)

    if (summary && summary.length > 0) {
      const text = summary[0].summary as string
      // Extract regime from briefing text (it's always mentioned in Posture section)
      const regimeMatch = text.match(/Risk[\s-](?:On|Off)[\s-]+(?:Dis)?(?:Inflation|Disinflation)/i)
      conditions.macroRegime = regimeMatch ? regimeMatch[0] : null
    }
  } catch { /* non-fatal */ }

  return conditions
}

// ─── Server-Side Risk Score Approximation ───────────────────────────────────

async function computeServerSideRiskScore(supabase: SupabaseClient): Promise<number | null> {
  // Simplified risk score using data available server-side:
  // - RSI (computed from daily candles)
  // - Price position vs 200-day SMA
  // - Fear & Greed (already fetched, but we compute independently here)
  // Returns 0.0 (lowest risk / best to accumulate) to 1.0 (highest risk)

  const { data: dailyCandles } = await supabase
    .from("ohlc_candles")
    .select("close")
    .eq("asset", "BTC")
    .eq("timeframe", "1d")
    .order("open_time", { ascending: true })

  if (!dailyCandles || dailyCandles.length < 20) return null

  const closes = dailyCandles.map((c: { close: number }) => Number(c.close))

  // Compute 14-period RSI
  const rsi = computeRSI(closes, 14)
  if (rsi === null) return null

  // RSI risk: 0 at RSI=30 (oversold), 1 at RSI=70 (overbought)
  const rsiRisk = Math.max(0, Math.min(1, (rsi - 30) / 40))

  // Price vs simple moving average (use available candles, up to 90)
  const smaLength = Math.min(closes.length, 90) // Use up to 90-day SMA from available data
  const sma = closes.slice(-smaLength).reduce((a, b) => a + b, 0) / smaLength
  const currentPrice = closes[closes.length - 1]
  const priceVsSma = (currentPrice - sma) / sma

  // SMA risk: 0 when price is well below SMA, 1 when well above
  // -20% below = 0.0, at SMA = 0.5, +40% above = 1.0
  const smaRisk = Math.max(0, Math.min(1, (priceVsSma + 0.2) / 0.6))

  // Weighted average: RSI 50%, SMA position 50%
  const riskScore = rsiRisk * 0.5 + smaRisk * 0.5

  return Math.round(riskScore * 1000) / 1000
}

function computeRSI(closes: number[], period: number): number | null {
  if (closes.length < period + 1) return null

  let avgGain = 0
  let avgLoss = 0

  // Initial average
  for (let i = 1; i <= period; i++) {
    const change = closes[i] - closes[i - 1]
    if (change > 0) avgGain += change
    else avgLoss += Math.abs(change)
  }
  avgGain /= period
  avgLoss /= period

  // Smooth with Wilder's method
  for (let i = period + 1; i < closes.length; i++) {
    const change = closes[i] - closes[i - 1]
    const gain = change > 0 ? change : 0
    const loss = change < 0 ? Math.abs(change) : 0
    avgGain = (avgGain * (period - 1) + gain) / period
    avgLoss = (avgLoss * (period - 1) + loss) / period
  }

  if (avgLoss === 0) return 100
  const rs = avgGain / avgLoss
  return 100 - (100 / (1 + rs))
}

// ─── Bounce Confirmation ────────────────────────────────────────────────────

function checkBounceConfirmation(
  candles: Array<{ open_time: string; open: number; high: number; low: number; close: number; volume: number | null }>,
  zoneLow: number,
  zoneHigh: number,
  isBuyZone: boolean,
): { confirmed: boolean; details: Record<string, boolean> } {
  const details: Record<string, boolean> = {
    wick_rejection: false,
    volume_spike: false,
    consecutive_closes: false,
  }

  if (candles.length < 3) return { confirmed: false, details }

  // Most recent candles (index 0 = most recent)
  const latest = candles[0]
  const prev = candles[1]

  if (isBuyZone) {
    // Check wick rejection: lower wick >= 2x body, close above zone
    const body = Math.abs(latest.close - latest.open)
    const lowerWick = Math.min(latest.open, latest.close) - latest.low
    if (lowerWick >= WICK_REJECTION_RATIO * Math.max(body, 0.01) && latest.close > zoneLow) {
      details.wick_rejection = true
    }

    // Check consecutive closes above zone after touching it
    if (latest.close > zoneHigh && prev.close > zoneHigh && prev.low <= zoneHigh) {
      details.consecutive_closes = true
    }
  } else {
    // Sell zone: upper wick rejection
    const body = Math.abs(latest.close - latest.open)
    const upperWick = latest.high - Math.max(latest.open, latest.close)
    if (upperWick >= WICK_REJECTION_RATIO * Math.max(body, 0.01) && latest.close < zoneHigh) {
      details.wick_rejection = true
    }

    // Consecutive closes below zone
    if (latest.close < zoneLow && prev.close < zoneLow && prev.high >= zoneLow) {
      details.consecutive_closes = true
    }
  }

  // Check volume spike: latest candle volume >= 1.5x 20-period average
  const volumeCandles = candles.slice(1, 21).filter((c) => c.volume != null)
  if (volumeCandles.length >= 10 && latest.volume != null) {
    const avgVolume = volumeCandles.reduce((sum, c) => sum + (c.volume ?? 0), 0) / volumeCandles.length
    if (avgVolume > 0 && latest.volume >= VOLUME_SPIKE_RATIO * avgVolume) {
      details.volume_spike = true
    }
  }

  // At least 1 confirmation required
  const confirmed = details.wick_rejection || details.volume_spike || details.consecutive_closes
  return { confirmed, details }
}

// ─── Target & Stop Loss Computation ─────────────────────────────────────────

async function computeTargetsAndStop(
  supabase: SupabaseClient,
  zone: ConfluenceZone & { id: string; asset: string },
  currentPrice: number,
  isBuyZone: boolean,
): Promise<{ target1: number | null; target2: number | null; stopLoss: number | null }> {
  // Get fib levels for this asset to find next level for stop loss
  const { data: fibs } = await supabase
    .from("fib_levels")
    .select("*")
    .eq("asset", zone.asset)
    .eq("is_current", true)

  if (!fibs || fibs.length === 0) return { target1: null, target2: null, stopLoss: null }

  // Collect all level prices
  const allPrices: number[] = []
  for (const fib of fibs) {
    for (const key of ["level_236", "level_382", "level_500", "level_618", "level_786"]) {
      if (fib[key] != null) allPrices.push(Number(fib[key]))
    }
    if (fib.ext_1272 != null) allPrices.push(Number(fib.ext_1272))
    if (fib.ext_1618 != null) allPrices.push(Number(fib.ext_1618))
  }

  allPrices.sort((a, b) => a - b)
  const zoneMid = Number(zone.zone_mid)

  if (isBuyZone) {
    // Stop loss: 1-2% below the next fib level down from the zone
    const levelsBelow = allPrices.filter((p) => p < Number(zone.zone_low))
    const nextLevelDown = levelsBelow.length > 0 ? levelsBelow[levelsBelow.length - 1] : null
    const stopLoss = nextLevelDown
      ? nextLevelDown * 0.985 // 1.5% below next level
      : zoneMid * 0.95 // Fallback: 5% below zone

    // Target 1: nearest resistance zone or 1.272 extension above
    const levelsAbove = allPrices.filter((p) => p > Number(zone.zone_high))
    const target1 = levelsAbove.length > 0 ? levelsAbove[0] : zoneMid * 1.15

    // Target 2: 1.618 extension or second level above
    const target2 = levelsAbove.length > 1 ? levelsAbove[1] : target1 * 1.05

    return { target1, target2, stopLoss }
  } else {
    // Sell zone: inverse logic
    const levelsAbove = allPrices.filter((p) => p > Number(zone.zone_high))
    const nextLevelUp = levelsAbove.length > 0 ? levelsAbove[0] : null
    const stopLoss = nextLevelUp
      ? nextLevelUp * 1.015
      : zoneMid * 1.05

    const levelsBelow = allPrices.filter((p) => p < Number(zone.zone_low))
    const target1 = levelsBelow.length > 0 ? levelsBelow[levelsBelow.length - 1] : zoneMid * 0.85
    const target2 = levelsBelow.length > 1 ? levelsBelow[levelsBelow.length - 2] : target1 * 0.95

    return { target1, target2, stopLoss }
  }
}

// ─── Step 6: Update Signal Statuses ─────────────────────────────────────────

async function updateSignalStatuses(supabase: SupabaseClient): Promise<Record<string, number>> {
  const stats = { expired: 0, invalidated: 0, target_hit: 0, partial: 0 }
  const now = new Date()

  // Get all active/triggered signals
  const { data: signals } = await supabase
    .from("trade_signals")
    .select("*")
    .in("status", ["active", "triggered"])

  if (!signals || signals.length === 0) return stats

  for (const signal of signals) {
    // Check expiration (active signals that haven't been triggered within 72h)
    if (signal.status === "active" && signal.expires_at) {
      if (new Date(signal.expires_at) <= now) {
        await supabase
          .from("trade_signals")
          .update({ status: "expired", closed_at: now.toISOString() })
          .eq("id", signal.id)
        stats.expired++
        continue
      }
    }

    // Get latest price
    const { data: latestCandle } = await supabase
      .from("ohlc_candles")
      .select("close, high, low")
      .eq("asset", signal.asset)
      .eq("timeframe", "1h")
      .order("open_time", { ascending: false })
      .limit(1)

    if (!latestCandle || latestCandle.length === 0) continue
    const currentPrice = Number(latestCandle[0].close)
    const currentLow = Number(latestCandle[0].low)
    const currentHigh = Number(latestCandle[0].high)

    const isBuy = signal.signal_type === "buy" || signal.signal_type === "strong_buy"

    // Check if price entered the zone (active → triggered)
    if (signal.status === "active") {
      const inZone = currentPrice >= Number(signal.entry_zone_low) &&
        currentPrice <= Number(signal.entry_zone_high)
      if (inZone) {
        await supabase
          .from("trade_signals")
          .update({ status: "triggered", triggered_at: now.toISOString() })
          .eq("id", signal.id)
      }
    }

    // Check targets and stop loss for triggered signals
    if (signal.status === "triggered") {
      const t1 = signal.target_1 ? Number(signal.target_1) : null
      const t2 = signal.target_2 ? Number(signal.target_2) : null
      const entryMid = Number(signal.entry_price_mid)
      const t1AlreadyHit = !!signal.t1_hit_at

      // Check T2 hit first (full win)
      if (t2 && (isBuy ? currentHigh >= t2 : currentLow <= t2)) {
        const outcomePct = isBuy
          ? ((t2 - entryMid) / entryMid) * 100
          : ((entryMid - t2) / entryMid) * 100

        await supabase
          .from("trade_signals")
          .update({
            status: "target_hit",
            outcome: "win",
            outcome_pct: Math.round(outcomePct * 100) / 100,
            closed_at: now.toISOString(),
            t1_hit_at: signal.t1_hit_at ?? now.toISOString(),
            duration_hours: Math.round(
              (now.getTime() - new Date(signal.triggered_at).getTime()) / 3600000,
            ),
          })
          .eq("id", signal.id)
        stats.target_hit++
        continue
      }

      // Check T1 hit (record it but keep signal open for T2)
      let t1JustHit = false
      if (!t1AlreadyHit && t1 && (isBuy ? currentHigh >= t1 : currentLow <= t1)) {
        await supabase
          .from("trade_signals")
          .update({ t1_hit_at: now.toISOString() })
          .eq("id", signal.id)
        t1JustHit = true
        // Don't close — let it run for T2
      }

      // Check stop loss
      const stopHit = isBuy
        ? currentLow <= Number(signal.stop_loss)
        : currentHigh >= Number(signal.stop_loss)

      if (stopHit) {
        // If T1 was already hit (or just hit this iteration), this is a partial win
        const isPartial = t1AlreadyHit || t1JustHit
        const exitPrice = isPartial && t1 ? t1 : Number(signal.stop_loss)
        const outcomePct = isBuy
          ? ((exitPrice - entryMid) / entryMid) * 100
          : ((entryMid - exitPrice) / entryMid) * 100

        await supabase
          .from("trade_signals")
          .update({
            status: isPartial ? "target_hit" : "invalidated",
            outcome: isPartial ? "partial" : "loss",
            outcome_pct: Math.round(outcomePct * 100) / 100,
            closed_at: now.toISOString(),
            duration_hours: Math.round(
              (now.getTime() - new Date(signal.triggered_at).getTime()) / 3600000,
            ),
          })
          .eq("id", signal.id)

        if (isPartial) {
          stats.partial++
        } else {
          stats.invalidated++
        }
      }
    }
  }

  return stats
}

// ─── Utilities ──────────────────────────────────────────────────────────────

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms))
}
