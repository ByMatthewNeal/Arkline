import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * compute-positioning-signals Edge Function
 *
 * Runs daily at 00:15 UTC. For each asset:
 *   1. Fetches daily candles from Coinbase (crypto) or FMP (traditional)
 *   2. Computes SMA 21/50/200, RSI(14), Bull Market Support Bands
 *   3. Computes trendScore (0-100)
 *   4. Derives positioning signal (bullish/neutral/bearish)
 *   5. Fetches yesterday's signal for change detection
 *   6. Upserts into positioning_signals
 */

// ─── Asset Configuration ────────────────────────────────────────────────────

type AssetSource = "coinbase" | "fmp" | "synthetic_btc"
type AssetCategory = "crypto" | "index" | "macro" | "commodity" | "stock" | "alt_btc"

interface AssetConfig {
  ticker: string        // Display ticker (stored in DB)
  displayName: string   // Full name for UI
  source: AssetSource
  symbol: string        // Coinbase pair, FMP symbol, or ALT-USD pair for synthetic
  category: AssetCategory
}

const ASSETS: AssetConfig[] = [
  // ── Crypto (Coinbase) ──
  { ticker: "BTC",    displayName: "Bitcoin",       source: "coinbase", symbol: "BTC-USD",    category: "crypto" },
  { ticker: "ETH",    displayName: "Ethereum",      source: "coinbase", symbol: "ETH-USD",    category: "crypto" },
  { ticker: "SOL",    displayName: "Solana",        source: "coinbase", symbol: "SOL-USD",    category: "crypto" },
  { ticker: "BNB",    displayName: "BNB",           source: "coinbase", symbol: "BNB-USD",    category: "crypto" },
  { ticker: "XRP",    displayName: "XRP",           source: "coinbase", symbol: "XRP-USD",    category: "crypto" },
  { ticker: "SUI",    displayName: "Sui",           source: "coinbase", symbol: "SUI-USD",    category: "crypto" },
  { ticker: "LINK",   displayName: "Chainlink",     source: "coinbase", symbol: "LINK-USD",   category: "crypto" },
  { ticker: "UNI",    displayName: "Uniswap",       source: "coinbase", symbol: "UNI-USD",    category: "crypto" },
  { ticker: "ONDO",   displayName: "Ondo",          source: "coinbase", symbol: "ONDO-USD",   category: "crypto" },
  { ticker: "RENDER", displayName: "Render",        source: "coinbase", symbol: "RENDER-USD", category: "crypto" },
  { ticker: "HYPE",   displayName: "Hyperliquid",   source: "fmp",      symbol: "HYPEUSD",    category: "crypto" },
  { ticker: "TAO",    displayName: "Bittensor",     source: "coinbase", symbol: "TAO-USD",    category: "crypto" },
  { ticker: "ZEC",    displayName: "Zcash",         source: "coinbase", symbol: "ZEC-USD",    category: "crypto" },
  { ticker: "AVAX",   displayName: "Avalanche",     source: "coinbase", symbol: "AVAX-USD",   category: "crypto" },
  { ticker: "DOGE",   displayName: "Dogecoin",      source: "coinbase", symbol: "DOGE-USD",   category: "crypto" },
  { ticker: "BCH",    displayName: "Bitcoin Cash",   source: "coinbase", symbol: "BCH-USD",    category: "crypto" },
  { ticker: "AAVE",   displayName: "Aave",           source: "coinbase", symbol: "AAVE-USD",   category: "crypto" },

  // ── Alt/BTC Pairs (relative strength vs Bitcoin) ──
  { ticker: "ETH/BTC",    displayName: "ETH/BTC",    source: "coinbase",      symbol: "ETH-BTC",    category: "alt_btc" },
  { ticker: "SOL/BTC",    displayName: "SOL/BTC",    source: "coinbase",      symbol: "SOL-BTC",    category: "alt_btc" },
  { ticker: "LINK/BTC",   displayName: "LINK/BTC",   source: "coinbase",      symbol: "LINK-BTC",   category: "alt_btc" },
  { ticker: "AVAX/BTC",   displayName: "AVAX/BTC",   source: "coinbase",      symbol: "AVAX-BTC",   category: "alt_btc" },
  { ticker: "DOGE/BTC",   displayName: "DOGE/BTC",   source: "coinbase",      symbol: "DOGE-BTC",   category: "alt_btc" },
  { ticker: "BCH/BTC",    displayName: "BCH/BTC",    source: "coinbase",      symbol: "BCH-BTC",    category: "alt_btc" },
  { ticker: "UNI/BTC",    displayName: "UNI/BTC",    source: "coinbase",      symbol: "UNI-BTC",    category: "alt_btc" },
  { ticker: "XRP/BTC",    displayName: "XRP/BTC",    source: "synthetic_btc", symbol: "XRP-USD",    category: "alt_btc" },
  { ticker: "BNB/BTC",    displayName: "BNB/BTC",    source: "synthetic_btc", symbol: "BNB-USD",    category: "alt_btc" },
  { ticker: "HYPE/BTC",   displayName: "HYPE/BTC",   source: "synthetic_btc", symbol: "HYPE-USD",   category: "alt_btc" },
  { ticker: "ZEC/BTC",    displayName: "ZEC/BTC",    source: "synthetic_btc", symbol: "ZEC-USD",    category: "alt_btc" },
  { ticker: "TAO/BTC",    displayName: "TAO/BTC",    source: "synthetic_btc", symbol: "TAO-USD",    category: "alt_btc" },
  { ticker: "SUI/BTC",    displayName: "SUI/BTC",    source: "synthetic_btc", symbol: "SUI-USD",    category: "alt_btc" },
  { ticker: "ONDO/BTC",   displayName: "ONDO/BTC",   source: "synthetic_btc", symbol: "ONDO-USD",   category: "alt_btc" },
  { ticker: "RENDER/BTC", displayName: "RENDER/BTC", source: "synthetic_btc", symbol: "RENDER-USD", category: "alt_btc" },
  { ticker: "AAVE/BTC",   displayName: "AAVE/BTC",   source: "coinbase",      symbol: "AAVE-BTC",   category: "alt_btc" },

  // ── Indices (FMP — ETF proxies) ──
  { ticker: "SPY",    displayName: "S&P 500",       source: "fmp", symbol: "SPY",   category: "index" },
  { ticker: "QQQ",    displayName: "Nasdaq 100",    source: "fmp", symbol: "QQQ",   category: "index" },
  { ticker: "DIA",    displayName: "Dow Jones",     source: "fmp", symbol: "DIA",   category: "index" },
  { ticker: "IWM",    displayName: "Russell 2000",  source: "fmp", symbol: "IWM",   category: "index" },

  // ── Macro ──
  { ticker: "VIX",    displayName: "Volatility Index", source: "fmp", symbol: "^VIX", category: "macro" },
  { ticker: "DXY",    displayName: "US Dollar Index",  source: "fmp", symbol: "UUP",  category: "macro" },
  { ticker: "TLT",    displayName: "20Y Treasuries",   source: "fmp", symbol: "TLT",  category: "macro" },

  // ── Commodities ──
  { ticker: "GOLD",   displayName: "Gold",            source: "fmp", symbol: "GCUSD", category: "commodity" },
  { ticker: "SILVER", displayName: "Silver",          source: "fmp", symbol: "SIUSD", category: "commodity" },
  { ticker: "OIL",    displayName: "Oil",             source: "fmp", symbol: "USO",   category: "commodity" },
  { ticker: "COPPER", displayName: "Copper",          source: "fmp", symbol: "CPER",  category: "commodity" },
  { ticker: "URA",    displayName: "Uranium",         source: "fmp", symbol: "URA",   category: "commodity" },
  { ticker: "DBA",    displayName: "Agriculture",     source: "fmp", symbol: "DBA",   category: "commodity" },
  { ticker: "DBB",    displayName: "Industrial Metals", source: "fmp", symbol: "DBB", category: "commodity" },
  { ticker: "REMX",   displayName: "Rare Earth Metals", source: "fmp", symbol: "REMX", category: "commodity" },

  // ── Stocks ──
  { ticker: "AAPL",   displayName: "Apple",           source: "fmp", symbol: "AAPL",  category: "stock" },
  { ticker: "NVDA",   displayName: "NVIDIA",          source: "fmp", symbol: "NVDA",  category: "stock" },
  { ticker: "GOOGL",  displayName: "Google",          source: "fmp", symbol: "GOOGL", category: "stock" },

  // ── Crypto Stocks (FMP) ──
  { ticker: "COIN",   displayName: "Coinbase",        source: "fmp", symbol: "COIN",  category: "stock" },
  { ticker: "MSTR",   displayName: "MicroStrategy",   source: "fmp", symbol: "MSTR",  category: "stock" },
  { ticker: "MARA",   displayName: "Marathon Digital", source: "fmp", symbol: "MARA",  category: "stock" },
  { ticker: "RIOT",   displayName: "Riot Platforms",   source: "fmp", symbol: "RIOT",  category: "stock" },
  { ticker: "GLXY",   displayName: "Galaxy Digital",   source: "fmp", symbol: "GLXY",  category: "stock" },
]

const INTER_ASSET_DELAY_MS = 150

// ─── Types ──────────────────────────────────────────────────────────────────

interface Candle {
  open: number
  high: number
  low: number
  close: number
  volume: number
}

interface PositioningResult {
  asset: string
  category: AssetCategory
  signal: "bullish" | "neutral" | "bearish"
  prev_signal: string | null
  trend_score: number
  rsi: number | null
  price: number
  above_200_sma: boolean
}

// ─── Helpers ────────────────────────────────────────────────────────────────

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms))
}

// ─── Coinbase Candle Fetcher ────────────────────────────────────────────────

async function fetchCoinbaseCandles(productId: string, limit: number): Promise<Candle[]> {
  const now = Math.floor(Date.now() / 1000)
  const start = now - 86400 * limit

  const url = `https://api.coinbase.com/api/v3/brokerage/market/products/${productId}/candles?start=${start}&end=${now}&granularity=ONE_DAY`
  const resp = await fetch(url)
  if (!resp.ok) {
    throw new Error(`Coinbase ${productId} ${resp.status}: ${await resp.text()}`)
  }

  const json = await resp.json()
  const raw: Array<{ start: string; open: string; high: string; low: string; close: string; volume: string }> =
    json.candles ?? []

  return raw
    .map((c) => ({
      open: parseFloat(c.open),
      high: parseFloat(c.high),
      low: parseFloat(c.low),
      close: parseFloat(c.close),
      volume: parseFloat(c.volume),
    }))
    .reverse() // Coinbase returns newest first; we want chronological
}

// ─── FMP Candle Fetcher ─────────────────────────────────────────────────────

async function fetchFMPCandles(symbol: string, fmpKey: string): Promise<Candle[]> {
  const url = `https://financialmodelingprep.com/stable/historical-price-eod/full?symbol=${encodeURIComponent(symbol)}&apikey=${fmpKey}`
  const resp = await fetch(url)
  if (!resp.ok) {
    throw new Error(`FMP ${symbol} ${resp.status}: ${await resp.text()}`)
  }

  const json = await resp.json()

  // FMP returns an array of { date, open, high, low, close, volume, ... } newest first
  const raw: Array<{ date: string; open: number; high: number; low: number; close: number; volume: number }> =
    Array.isArray(json) ? json : (json.historical ?? [])

  return raw
    .map((c) => ({
      open: c.open,
      high: c.high,
      low: c.low,
      close: c.close,
      volume: c.volume ?? 0,
    }))
    .reverse() // Chronological order (oldest first)
}

// ─── Technical Indicators ───────────────────────────────────────────────────

function computeSMA(closes: number[], period: number): number[] {
  const result: number[] = []
  for (let i = 0; i < closes.length; i++) {
    if (i < period - 1) {
      result.push(NaN)
      continue
    }
    let sum = 0
    for (let j = i - period + 1; j <= i; j++) sum += closes[j]
    result.push(sum / period)
  }
  return result
}

function computeEMA(closes: number[], period: number): number[] {
  const result: number[] = []
  const k = 2 / (period + 1)
  for (let i = 0; i < closes.length; i++) {
    if (i === 0) {
      result.push(closes[0])
    } else {
      result.push(closes[i] * k + result[i - 1] * (1 - k))
    }
  }
  return result
}

function computeRSI(closes: number[], period = 14): number | null {
  if (closes.length < period + 1) return null

  let avgGain = 0
  let avgLoss = 0

  for (let i = 1; i <= period; i++) {
    const change = closes[i] - closes[i - 1]
    if (change > 0) avgGain += change
    else avgLoss += Math.abs(change)
  }
  avgGain /= period
  avgLoss /= period

  for (let i = period + 1; i < closes.length; i++) {
    const change = closes[i] - closes[i - 1]
    const gain = change > 0 ? change : 0
    const loss = change < 0 ? Math.abs(change) : 0
    avgGain = (avgGain * (period - 1) + gain) / period
    avgLoss = (avgLoss * (period - 1) + loss) / period
  }

  if (avgLoss === 0) return 100
  const rs = avgGain / avgLoss
  return 100 - 100 / (1 + rs)
}

// ─── Trend Score Computation ────────────────────────────────────────────────
//
// Scoring weights (v4 — 200 SMA penalty 2026-03-29):
//
// PRIMARY: Daily close relative to key SMAs (user's framework)
//   Above 200 SMA:   +18  (strongest bullish signal — long-term trend intact)
//   Below 200 SMA:   -8   (bearish pressure — below institutional trend line)
//   Above 50 SMA:    +8   (intermediate support holding)
//   Above 21 SMA:    +8   (short-term trend positive)
//   Below 21 SMA:    -10  (short-term trend broken — bearish)
//
// SECONDARY: SMA crossover direction
//   21 SMA > 50 SMA: +6   (trend confirmation)
//   21 SMA < 50 SMA: -6   (trend deterioration)
//
// TERTIARY: RSI & BMSB fine-tuning
//   RSI ≤30: +5, RSI ≤40: +3, RSI ≥75: -3
//   BMSB above: +4, in band: +1, below: -2
//
// Signal thresholds: ≥70 bullish, ≥45 neutral, <45 bearish

function computeTrendScore(candles: Candle[]): {
  trendScore: number
  rsi: number | null
  above200SMA: boolean
  price: number
} {
  const closes = candles.map((c) => c.close)
  const price = closes[closes.length - 1]

  const sma21 = computeSMA(closes, 21)
  const sma50 = computeSMA(closes, 50)
  const rsi = computeRSI(closes)

  const latestSma21 = sma21[sma21.length - 1]
  const latestSma50 = sma50[sma50.length - 1]

  // SMA 200 — only if enough data
  const sma200 = closes.length >= 200 ? computeSMA(closes, 200) : []
  const latestSma200 = sma200.length > 0 ? sma200[sma200.length - 1] : NaN
  const above200SMA = !isNaN(latestSma200) && price > latestSma200

  // Bull Market Support Band: 20W SMA (~140D) and 21W EMA (~147D)
  const hasBMSB = closes.length >= 148
  const sma140 = hasBMSB ? computeSMA(closes, 140) : []
  const ema147 = hasBMSB ? computeEMA(closes, 147) : []
  const bmsbSma = sma140.length > 0 ? sma140[sma140.length - 1] : NaN
  const bmsbEma = ema147.length > 0 ? ema147[ema147.length - 1] : NaN

  const aboveSma21 = !isNaN(latestSma21) && price > latestSma21
  const aboveSma50 = !isNaN(latestSma50) && price > latestSma50

  // ── Base: 50 ──
  let score = 50

  // ── PRIMARY: SMA position (key framework) ──
  // 200 SMA = bull/bear dividing line (symmetric weighting)
  if (above200SMA) {
    score += 18
  } else if (!isNaN(latestSma200)) {
    score -= 8   // Below 200 SMA = bearish pressure
  }

  // Above 50 SMA = intermediate support holding
  if (aboveSma50) score += 8

  // Above 21 SMA = short-term trend positive
  if (aboveSma21) {
    score += 8
  } else if (!isNaN(latestSma21)) {
    // Below 21 SMA = short-term trend broken
    score -= 10
  }

  // ── SECONDARY: SMA crossover direction ──
  if (!isNaN(latestSma21) && !isNaN(latestSma50)) {
    if (latestSma21 > latestSma50) {
      score += 6   // Trend confirmation
    } else {
      score -= 6   // Trend deterioration
    }
  }

  // ── TERTIARY: RSI mean-reversion ──
  if (rsi !== null) {
    if (rsi <= 30) {
      score += 5        // Deeply oversold — contrarian boost
    } else if (rsi <= 40) {
      score += 3        // Approaching oversold — mild boost
    } else if (rsi >= 75) {
      score -= 3        // Overbought — exhaustion drag
    }
  }

  // ── TERTIARY: BMSB position ──
  if (!isNaN(bmsbSma) && !isNaN(bmsbEma)) {
    const bmsbTop = Math.max(bmsbSma, bmsbEma)
    const bmsbBot = Math.min(bmsbSma, bmsbEma)
    if (price > bmsbTop) {
      score += 4
    } else if (price >= bmsbBot) {
      score += 1
    } else {
      score -= 2
    }
  }

  // Clamp to 0-100
  score = Math.max(0, Math.min(100, score))

  return { trendScore: score, rsi, above200SMA: above200SMA, price, aboveSma21, aboveSma50 }
}

// ─── Signal Derivation ──────────────────────────────────────────────────────

function deriveSignal(
  trendScore: number,
  above200SMA: boolean,
  has200SMA: boolean,
  aboveSma21: boolean,
  aboveSma50: boolean
): "bullish" | "neutral" | "bearish" {
  if (trendScore >= 70) {
    // Below 200 SMA caps bullish → neutral (only if we have 200 SMA data)
    if (has200SMA && !above200SMA) return "neutral"
    // Below both 21 AND 50 SMA caps bullish → neutral
    // (short-term trend is broken, 200 SMA alone can't make it bullish)
    if (!aboveSma21 && !aboveSma50) return "neutral"
    return "bullish"
  }
  if (trendScore >= 45) {
    return "neutral"
  }
  return "bearish"
}

// ─── Main Handler ───────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  // Auth check
  const secret = req.headers.get("x-cron-secret") ?? ""
  const expectedSecret = Deno.env.get("CRON_SECRET") ?? ""
  if (!expectedSecret || secret !== expectedSecret) {
    return jsonResponse({ error: "Unauthorized" }, 401)
  }

  const fmpKey = Deno.env.get("FMP_API_KEY") ?? ""
  if (!fmpKey) {
    return jsonResponse({ error: "FMP_API_KEY not configured" }, 500)
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const supabase = createClient(supabaseUrl, supabaseKey)

  const today = new Date().toISOString().split("T")[0]
  const yesterday = new Date(Date.now() - 86400000).toISOString().split("T")[0]

  const results: PositioningResult[] = []
  const errors: string[] = []

  for (const asset of ASSETS) {
    try {
      // Fetch candles from appropriate source
      let candles: Candle[]
      if (asset.source === "synthetic_btc") {
        // Compute ALT/BTC ratio from ALT-USD / BTC-USD candles
        const altCandles = await fetchCoinbaseCandles(asset.symbol, 210)
        const btcCandles = await fetchCoinbaseCandles("BTC-USD", 210)
        const minLen = Math.min(altCandles.length, btcCandles.length)
        // Align from the end (most recent) and divide
        const altSlice = altCandles.slice(-minLen)
        const btcSlice = btcCandles.slice(-minLen)
        candles = altSlice.map((a, i) => ({
          open:   a.open   / btcSlice[i].open,
          high:   a.high   / btcSlice[i].low,    // ALT high / BTC low = max ratio
          low:    a.low    / btcSlice[i].high,    // ALT low / BTC high = min ratio
          close:  a.close  / btcSlice[i].close,
          volume: a.volume,
        }))
      } else if (asset.source === "coinbase") {
        candles = await fetchCoinbaseCandles(asset.symbol, 210)
      } else {
        candles = await fetchFMPCandles(asset.symbol, fmpKey)
        // FMP returns full history; take last 300 for consistency
        if (candles.length > 300) {
          candles = candles.slice(-300)
        }
      }

      // Need at least 22 candles for SMA 21 (minimum useful analysis)
      if (candles.length < 22) {
        errors.push(`${asset.ticker}: only ${candles.length} candles (need 22)`)
        continue
      }

      // Compute indicators
      const { trendScore, rsi, above200SMA, price, aboveSma21, aboveSma50 } = computeTrendScore(candles)
      const has200SMA = candles.length >= 200

      // Derive signal
      const signal = deriveSignal(trendScore, above200SMA, has200SMA, aboveSma21, aboveSma50)

      // Fetch yesterday's signal for change detection
      const { data: prevRow } = await supabase
        .from("positioning_signals")
        .select("signal")
        .eq("asset", asset.ticker)
        .eq("signal_date", yesterday)
        .maybeSingle()

      const prevSignal = prevRow?.signal ?? null

      results.push({
        asset: asset.ticker,
        category: asset.category,
        signal,
        prev_signal: prevSignal,
        trend_score: Math.round(trendScore * 10) / 10,
        rsi: rsi !== null ? Math.round(rsi * 10) / 10 : null,
        price: Math.round(price * 100) / 100,
        above_200_sma: above200SMA,
        _aboveSma21: aboveSma21,
        _aboveSma50: aboveSma50,
      })
    } catch (err) {
      errors.push(`${asset.ticker}: ${(err as Error).message}`)
    }

    await sleep(INTER_ASSET_DELAY_MS)
  }

  // ── VIX Contrarian Boost ──────────────────────────────────────────────────
  // When VIX z-score ≥ 2σ (fear spike), apply contrarian bullish boost to
  // crypto, index, and stock assets. This captures the insight that extreme
  // fear readings historically precede risk-asset rallies.
  const vixResult = results.find((r) => r.asset === "VIX")
  if (vixResult) {
    try {
      // Fetch VIX 90-day history to compute z-score
      const vixCandles = await fetchFMPCandles("^VIX", fmpKey)
      const vixCloses = vixCandles.slice(-90).map((c) => c.close)
      if (vixCloses.length >= 20) {
        const mean = vixCloses.reduce((a, b) => a + b, 0) / vixCloses.length
        const sd = Math.sqrt(
          vixCloses.reduce((sum, v) => sum + (v - mean) ** 2, 0) / (vixCloses.length - 1)
        )
        if (sd > 0) {
          const vixZ = (vixResult.price - mean) / sd
          console.log(`VIX z-score: ${vixZ.toFixed(2)} (price=${vixResult.price}, mean=${mean.toFixed(1)}, sd=${sd.toFixed(1)})`)

          if (vixZ >= 2.0) {
            // Fear spike: boost crypto, index, and stock scores by +5
            const boostAmount = 5
            const boostCategories = new Set(["crypto", "index", "stock"])
            let boosted = 0
            for (const r of results) {
              if (boostCategories.has(r.category)) {
                const oldScore = r.trend_score
                r.trend_score = Math.min(100, r.trend_score + boostAmount)
                // Rederive signal with boosted score
                const has200 = r.above_200_sma !== undefined
                r.signal = deriveSignal(r.trend_score, r.above_200_sma, has200, r._aboveSma21 ?? false, r._aboveSma50 ?? false)
                boosted++
              }
            }
            console.log(`VIX fear spike (${vixZ.toFixed(1)}σ): applied +${boostAmount} contrarian boost to ${boosted} assets`)
          }
        }
      }
    } catch (err) {
      console.error(`VIX z-score calculation failed: ${(err as Error).message}`)
    }
  }

  // Upsert all results
  if (results.length > 0) {
    const rows = results.map((r) => ({
      asset: r.asset,
      signal_date: today,
      signal: r.signal,
      prev_signal: r.prev_signal,
      trend_score: r.trend_score,
      rsi: r.rsi,
      price: r.price,
      above_200_sma: r.above_200_sma,
      category: r.category,
    }))

    const { error: upsertError } = await supabase
      .from("positioning_signals")
      .upsert(rows, { onConflict: "asset,signal_date" })

    if (upsertError) {
      errors.push(`Upsert failed: ${upsertError.message}`)
    }
  }

  const changes = results.filter((r) => r.prev_signal && r.signal !== r.prev_signal)

  // ── Store daily Fear & Greed snapshot ──────────────────────────────────────
  let fearGreedStored = false
  try {
    const fgResp = await fetch("https://api.alternative.me/fng/?limit=1")
    if (fgResp.ok) {
      const fgData = await fgResp.json()
      const fg = fgData?.data?.[0]
      if (fg?.value) {
        await supabase
          .from("fear_greed_history")
          .upsert({
            date: today,
            value: Number(fg.value),
            classification: fg.value_classification ?? "Unknown",
          }, { onConflict: "date" })
        fearGreedStored = true
      }
    }
  } catch (e) {
    console.error("Fear & Greed fetch failed (non-fatal):", e)
  }

  return jsonResponse({
    success: true,
    date: today,
    signals: results.length,
    changes: changes.length,
    fear_greed_stored: fearGreedStored,
    breakdown: {
      crypto: results.filter((r) => r.category === "crypto").length,
      alt_btc: results.filter((r) => r.category === "alt_btc").length,
      index: results.filter((r) => r.category === "index").length,
      macro: results.filter((r) => r.category === "macro").length,
      commodity: results.filter((r) => r.category === "commodity").length,
      stock: results.filter((r) => r.category === "stock").length,
    },
    errors: errors.length > 0 ? errors : undefined,
  })
})
