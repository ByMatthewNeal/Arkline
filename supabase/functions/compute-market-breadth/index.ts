import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * compute-market-breadth Edge Function
 *
 * Daily cron (01:30 UTC) that computes:
 *   1. Market breadth: % of top tokens in an uptrend
 *   2. EMA 12/21 on breadth series for trend analysis
 *   3. Bullish/bearish crossover detection
 *
 * Data source: CoinGecko top 250 tokens (3 pages of 100)
 *
 * A token is "in uptrend" if:
 *   - 7D sparkline exists AND current price > sparkline simple moving average
 *   - OR if no sparkline: 24h change > 0 AND 7d change > 0
 *
 * Runs daily at 01:30 UTC via cron.
 */

const COINGECKO_PRO_BASE = "https://pro-api.coingecko.com/api/v3"
const COINGECKO_FREE_BASE = "https://api.coingecko.com/api/v3"

// EMA smoothing factors
const EMA_SHORT = 12
const EMA_LONG = 21

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  // Auth check
  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  const secret = req.headers.get("x-cron-secret") ?? ""
  if (!cronSecret || secret !== cronSecret) {
    return json({ error: "Unauthorized" }, 401)
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const cgKey = Deno.env.get("COINGECKO_API_KEY") ?? ""

  const supabase = createClient(supabaseUrl, supabaseKey)

  const isPro = !!cgKey
  const BASE = isPro ? COINGECKO_PRO_BASE : COINGECKO_FREE_BASE
  const headers: Record<string, string> = { Accept: "application/json" }
  if (cgKey) headers["x-cg-pro-api-key"] = cgKey

  try {
    // ── 1. Fetch token data (up to 300 tokens across 3 pages) ──
    const allTokens: CoinMarketData[] = []

    for (const page of [1, 2, 3]) {
      const url = `${BASE}/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=${page}&sparkline=true&price_change_percentage=7d`
      const resp = await fetch(url, { headers })

      if (!resp.ok) {
        const text = await resp.text()
        console.error(`CoinGecko page ${page} failed: ${resp.status} ${text}`)
        // If page 1 fails, try cache fallback
        if (page === 1) {
          const cached = await readCache(supabase, "crypto_assets_1_100")
          if (cached) {
            allTokens.push(...cached)
            console.log("Using cached crypto_assets_1_100 as fallback")
          }
        }
        break
      }

      const data: CoinMarketData[] = await resp.json()
      allTokens.push(...data)
      console.log(`Page ${page}: fetched ${data.length} tokens`)

      // Rate limit pause between pages
      if (page < 3) await sleep(1500)
    }

    if (allTokens.length === 0) {
      return json({ error: "No token data available" }, 500)
    }

    // Filter out stablecoins and wrapped tokens
    const STABLECOINS = new Set([
      "tether", "usd-coin", "dai", "binance-usd", "true-usd", "pax-dollar",
      "frax", "usdd", "first-digital-usd", "paypal-usd", "ethena-usde",
      "wrapped-bitcoin", "wrapped-ether", "staked-ether", "wrapped-steth",
      "rocket-pool-eth",
    ])

    const tokens = allTokens.filter(
      (t) => !STABLECOINS.has(t.id) && t.current_price > 0
    )

    // ── 2. Compute breadth ──
    let trendingCount = 0
    const totalTokens = tokens.length

    for (const token of tokens) {
      if (isInUptrend(token)) {
        trendingCount++
      }
    }

    const breadthPct = totalTokens > 0 ? (trendingCount / totalTokens) * 100 : 0

    // Get BTC price
    const btc = allTokens.find((t) => t.id === "bitcoin")
    const btcPrice = btc?.current_price ?? null

    // ── 3. Fetch historical breadth for EMA calculation ──
    const { data: history } = await supabase
      .from("market_breadth")
      .select("signal_date, breadth_pct, ema_12, ema_21, trend")
      .order("signal_date", { ascending: false })
      .limit(30)

    const sortedHistory = (history ?? []).sort(
      (a: BreadthRow, b: BreadthRow) => a.signal_date.localeCompare(b.signal_date)
    )

    // ── 4. Compute EMAs ──
    let ema12: number
    let ema21: number

    if (sortedHistory.length > 0) {
      const prev = sortedHistory[sortedHistory.length - 1]
      const prevEma12 = prev.ema_12 ?? prev.breadth_pct
      const prevEma21 = prev.ema_21 ?? prev.breadth_pct

      const k12 = 2 / (EMA_SHORT + 1)
      const k21 = 2 / (EMA_LONG + 1)

      ema12 = breadthPct * k12 + prevEma12 * (1 - k12)
      ema21 = breadthPct * k21 + prevEma21 * (1 - k21)
    } else {
      // First data point — seed EMAs with current value
      ema12 = breadthPct
      ema21 = breadthPct
    }

    // ── 5. Determine trend and crossover ──
    const trend = ema12 > ema21 ? "bullish" : ema12 < ema21 ? "bearish" : "neutral"

    const prevTrend = sortedHistory.length > 0
      ? sortedHistory[sortedHistory.length - 1].trend
      : null

    let crossover: string | null = null
    if (prevTrend && prevTrend !== trend) {
      if (trend === "bullish" && prevTrend === "bearish") {
        crossover = "bullish_crossover"
      } else if (trend === "bearish" && prevTrend === "bullish") {
        crossover = "bearish_crossover"
      }
    }

    // ── 6. Upsert today's breadth ──
    const today = new Date().toISOString().split("T")[0]

    const row = {
      signal_date: today,
      total_tokens: totalTokens,
      trending_tokens: trendingCount,
      breadth_pct: Math.round(breadthPct * 10) / 10,
      ema_12: Math.round(ema12 * 10) / 10,
      ema_21: Math.round(ema21 * 10) / 10,
      trend,
      prev_trend: prevTrend,
      crossover,
      btc_price: btcPrice,
    }

    const { error: upsertError } = await supabase
      .from("market_breadth")
      .upsert(row, { onConflict: "signal_date" })

    if (upsertError) {
      console.error("Upsert failed:", upsertError.message)
      return json({ error: upsertError.message }, 500)
    }

    console.log(
      `Market Breadth: ${breadthPct.toFixed(1)}% (${trendingCount}/${totalTokens}), ` +
      `EMA12=${ema12.toFixed(1)} EMA21=${ema21.toFixed(1)}, trend=${trend}` +
      (crossover ? ` [${crossover}]` : "")
    )

    // ── 7. Send push notification on crossover ──
    if (crossover) {
      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
      const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
      const cronSecret = Deno.env.get("CRON_SECRET") ?? ""

      const isBullish = crossover === "bullish_crossover"
      const emoji = isBullish ? "📈" : "📉"
      const direction = isBullish ? "Bullish" : "Bearish"
      const title = `${emoji} Market Breadth — ${direction} Crossover`
      const body = `EMA 12 crossed ${isBullish ? "above" : "below"} EMA 21. Breadth: ${row.breadth_pct}% (${trendingCount}/${totalTokens} tokens trending).`

      fetch(`${supabaseUrl}/functions/v1/send-broadcast-notification`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${anonKey}`,
          "x-cron-secret": cronSecret,
        },
        body: JSON.stringify({
          broadcast_id: `breadth_${today}`,
          title,
          body,
          event_type: "breadth_crossover",
          target_audience: { type: "all" },
        }),
      }).catch((err) => console.error("Breadth notification failed:", err))
    }

    return json({
      success: true,
      date: today,
      breadth_pct: row.breadth_pct,
      trending_tokens: trendingCount,
      total_tokens: totalTokens,
      ema_12: row.ema_12,
      ema_21: row.ema_21,
      trend,
      crossover,
      btc_price: btcPrice,
    })
  } catch (err) {
    console.error("compute-market-breadth error:", err)
    return json({ error: String(err) }, 500)
  }
})

// ─── Uptrend Detection ─────────────────────────────────────────────────────

interface CoinMarketData {
  id: string
  symbol: string
  current_price: number
  price_change_percentage_24h?: number
  price_change_percentage_7d_in_currency?: number
  sparkline_in_7d?: { price: number[] }
}

function isInUptrend(token: CoinMarketData): boolean {
  const sparkline = token.sparkline_in_7d?.price

  if (sparkline && sparkline.length >= 24) {
    // Primary method: current price vs 7D SMA from sparkline
    const sma = sparkline.reduce((sum, p) => sum + p, 0) / sparkline.length
    return token.current_price > sma
  }

  // Fallback: positive 7D change
  if (token.price_change_percentage_7d_in_currency != null) {
    return token.price_change_percentage_7d_in_currency > 0
  }

  // Last resort: positive 24h change
  return (token.price_change_percentage_24h ?? 0) > 0
}

// ─── Helpers ────────────────────────────────────────────────────────────────

interface BreadthRow {
  signal_date: string
  breadth_pct: number
  ema_12: number | null
  ema_21: number | null
  trend: string
}

async function readCache(
  supabase: ReturnType<typeof createClient>,
  key: string
): Promise<CoinMarketData[] | null> {
  const { data } = await supabase
    .from("market_data_cache")
    .select("data")
    .eq("key", key)
    .maybeSingle()

  if (data?.data) {
    return JSON.parse(data.data)
  }
  return null
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
