import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * sync-crypto-prices Edge Function
 *
 * Fetches CoinGecko market data server-side and writes to market_data_cache.
 * All iOS clients read from this cache instead of hitting CoinGecko directly.
 *
 * Endpoints cached:
 * - /coins/markets (top 100, with sparkline) → key "crypto_assets_1_100"
 * - /global → key "global_market_data"
 * - /search/trending + /coins/markets (for trending) → key "trending_coins"
 *
 * Runs every 5 minutes via cron.
 */

const COINGECKO_PRO_BASE = "https://pro-api.coingecko.com/api/v3"
const COINGECKO_FREE_BASE = "https://api.coingecko.com/api/v3"
const FMP_BASE = "https://financialmodelingprep.com/stable"

// Map FMP symbols to CoinGecko-style IDs for the top coins
const FMP_SYMBOL_TO_CG_ID: Record<string, string> = {
  BTCUSD: "bitcoin", ETHUSD: "ethereum", BNBUSD: "binancecoin", SOLUSD: "solana",
  XRPUSD: "ripple", ADAUSD: "cardano", DOGEUSD: "dogecoin", TRXUSD: "tron",
  TONUSD: "the-open-network", LINKUSD: "chainlink", AVAXUSD: "avalanche-2",
  XLMUSD: "stellar", SUIUSD: "sui", DOTUSD: "polkadot", BCHUSD: "bitcoin-cash",
  HBARUSD: "hedera-hashgraph", LTCUSD: "litecoin", UNIUSD: "uniswap",
  NEARUSD: "near", APTUSD: "aptos", AABORUSD: "arbitrum", RENDERUSD: "render-token",
  PEPE1USD: "pepe", ATOMUSD: "cosmos", FILUSD: "filecoin", IMXUSD: "immutable-x",
  INJUSD: "injective-protocol", ONDOUSD: "ondo-finance", TAOUSD: "bittensor",
  MATICUSD: "matic-network", TIAUSD: "celestia", OPUSD: "optimism",
  FTMUSD: "fantom", AAVEUSD: "aave", ENAUSD: "ethena", FETUSD: "fetch-ai",
  ARBUSD: "arbitrum", MKRUSD: "maker", FLOWUSD: "flow", ALGOUSD: "algorand",
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  const secret = req.headers.get("x-cron-secret") ?? ""
  if (!cronSecret || secret !== cronSecret) {
    return json({ error: "Unauthorized" }, 401)
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const cgKey = Deno.env.get("COINGECKO_API_KEY") ?? ""
  const fmpKey = Deno.env.get("FMP_API_KEY") ?? ""

  const supabase = createClient(supabaseUrl, supabaseKey)

  // Paid plans use pro-api.coingecko.com + x-cg-pro-api-key header
  const isPro = !!cgKey
  const COINGECKO_BASE = isPro ? COINGECKO_PRO_BASE : COINGECKO_FREE_BASE

  const headers: Record<string, string> = {
    "Accept": "application/json",
  }

  if (cgKey) {
    headers["x-cg-pro-api-key"] = cgKey
  }

  const stats = { markets: false, global: false, trending: false, fmpFallback: false, errors: [] as string[] }

  // 1. Fetch top 100 coins with sparkline
  try {
    const url = `${COINGECKO_BASE}/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=100&page=1&sparkline=true`
    const resp = await fetch(url, { headers })
    if (!resp.ok) {
      const text = await resp.text()
      throw new Error(`${resp.status}: ${text}`)
    }
    const data = await resp.json()
    if (Array.isArray(data) && data.length > 0) {
      await writeCache(supabase, "crypto_assets_1_100", data, 300)
      stats.markets = true
      console.log(`Cached ${data.length} coins to crypto_assets_1_100`)
    }
  } catch (err) {
    const msg = `markets: ${err}`
    console.error(msg)
    stats.errors.push(msg)

    // FMP fallback for top coins
    if (fmpKey) {
      try {
        console.log("CoinGecko failed, trying FMP fallback for crypto quotes...")
        const fmpData = await fetchFMPCryptoFallback(fmpKey)
        if (fmpData.length > 0) {
          await writeCache(supabase, "crypto_assets_1_100", fmpData, 300)
          stats.fmpFallback = true
          console.log(`FMP fallback: cached ${fmpData.length} coins`)
        }
      } catch (fmpErr) {
        const fmpMsg = `fmp fallback: ${fmpErr}`
        console.error(fmpMsg)
        stats.errors.push(fmpMsg)
      }
    }
  }

  // Small delay to avoid rate limiting
  await sleep(1500)

  // 2. Fetch global market data
  try {
    const url = `${COINGECKO_BASE}/global`
    const resp = await fetch(url, { headers })
    if (!resp.ok) {
      const text = await resp.text()
      throw new Error(`${resp.status}: ${text}`)
    }
    const data = await resp.json()
    if (data) {
      await writeCache(supabase, "global_market_data", data, 300)
      stats.global = true
      console.log("Cached global market data")
    }
  } catch (err) {
    const msg = `global: ${err}`
    console.error(msg)
    stats.errors.push(msg)
  }

  await sleep(1500)

  // 3. Fetch trending coins → then fetch their market data
  try {
    const trendingUrl = `${COINGECKO_BASE}/search/trending`
    const trendingResp = await fetch(trendingUrl, { headers })
    if (!trendingResp.ok) {
      const text = await trendingResp.text()
      throw new Error(`trending ${trendingResp.status}: ${text}`)
    }
    const trendingData = await trendingResp.json()
    const coinIds = (trendingData.coins ?? []).map((c: { item: { id: string } }) => c.item.id)

    if (coinIds.length > 0) {
      await sleep(1500)

      // Fetch full market data for trending coins
      const marketsUrl = `${COINGECKO_BASE}/coins/markets?vs_currency=usd&ids=${coinIds.join(",")}&order=market_cap_desc&sparkline=false`
      const marketsResp = await fetch(marketsUrl, { headers })
      if (!marketsResp.ok) {
        const text = await marketsResp.text()
        throw new Error(`trending markets ${marketsResp.status}: ${text}`)
      }
      const marketsData = await marketsResp.json()
      if (Array.isArray(marketsData)) {
        await writeCache(supabase, "trending_coins", marketsData, 300)
        stats.trending = true
        console.log(`Cached ${marketsData.length} trending coins`)
      }
    }
  } catch (err) {
    const msg = `trending: ${err}`
    console.error(msg)
    stats.errors.push(msg)
  }

  console.log(`Crypto price sync: ${JSON.stringify(stats)}`)
  return json(stats)
})

// ─── FMP Fallback ─────────────────────────────────────────────────────────────

interface FMPCryptoQuote {
  symbol: string
  name: string
  price: number
  changePercentage: number
  change: number
  volume: number
  dayLow: number
  dayHigh: number
  yearHigh: number
  yearLow: number
  marketCap: number | null
  exchange: string
  timestamp: number
}

/**
 * Fetch crypto quotes from FMP and transform to CoinGecko-compatible format.
 * FMP returns all crypto quotes from /cryptocurrency-quotes, which we filter
 * and sort by market cap to match the CoinGecko top-100 shape.
 */
async function fetchFMPCryptoFallback(apiKey: string): Promise<unknown[]> {
  const url = `${FMP_BASE}/cryptocurrency-quotes?apikey=${apiKey}`
  const resp = await fetch(url)
  if (!resp.ok) {
    throw new Error(`FMP ${resp.status}: ${await resp.text()}`)
  }

  const quotes: FMPCryptoQuote[] = await resp.json()
  if (!Array.isArray(quotes)) throw new Error("FMP returned non-array")

  // Filter to USD pairs, sort by market cap, take top 100
  const usdQuotes = quotes
    .filter((q) => q.symbol.endsWith("USD") && q.exchange === "CRYPTO" && q.price > 0)
    .sort((a, b) => (b.marketCap ?? 0) - (a.marketCap ?? 0))
    .slice(0, 100)

  // Transform to CoinGecko coins/markets shape so iOS CryptoAsset model can decode it
  return usdQuotes.map((q, i) => {
    const ticker = q.symbol.replace(/USD$/, "").toLowerCase()
    const cgId = FMP_SYMBOL_TO_CG_ID[q.symbol] ?? ticker

    return {
      id: cgId,
      symbol: ticker,
      name: q.name.replace(/ USD$/, ""),
      current_price: q.price,
      price_change_24h: q.change,
      price_change_percentage_24h: q.changePercentage,
      image: `https://assets.coingecko.com/coins/images/1/large/${ticker}.png`, // may 404 for some
      market_cap: q.marketCap ?? 0,
      market_cap_rank: i + 1,
      fully_diluted_valuation: null,
      total_volume: q.volume,
      high_24h: q.dayHigh,
      low_24h: q.dayLow,
      circulating_supply: null,
      total_supply: null,
      max_supply: null,
      ath: q.yearHigh,
      ath_change_percentage: q.yearHigh > 0 ? ((q.price - q.yearHigh) / q.yearHigh) * 100 : null,
      ath_date: null,
      atl: q.yearLow,
      atl_change_percentage: q.yearLow > 0 ? ((q.price - q.yearLow) / q.yearLow) * 100 : null,
      atl_date: null,
      sparkline_in_7d: null, // FMP doesn't provide sparkline
      last_updated: new Date(q.timestamp * 1000).toISOString(),
    }
  })
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function writeCache(
  supabase: ReturnType<typeof createClient>,
  key: string,
  data: unknown,
  ttlSeconds: number
) {
  const jsonString = JSON.stringify(data)
  const { error } = await supabase
    .from("market_data_cache")
    .upsert(
      {
        key,
        data: jsonString,
        updated_at: new Date().toISOString(),
        ttl_seconds: ttlSeconds,
      },
      { onConflict: "key" }
    )

  if (error) {
    console.error(`Cache write failed for "${key}": ${error.message}`)
    throw error
  }
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
