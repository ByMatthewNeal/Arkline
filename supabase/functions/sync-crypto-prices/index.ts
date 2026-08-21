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
 *
 * Resilience: if CoinGecko's /coins/markets call fails (e.g. a lapsed API
 * subscription), we fall back to Binance's bulk 24h ticker and refresh just the
 * live prices (current_price + 24h change) on the last-known-good snapshot, so
 * prices keep flowing. Names, logos, market caps, ranks and sparklines are kept
 * from the last successful CoinGecko sync. (Global mcap/dominance still needs
 * CoinGecko and is not backfilled.)
 */

const COINGECKO_PRO_BASE = "https://pro-api.coingecko.com/api/v3"
const COINGECKO_FREE_BASE = "https://api.coingecko.com/api/v3"

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

  const stats = { markets: false, global: false, trending: false, marketsSource: "coingecko", errors: [] as string[] }

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

    // Fallback: keep live prices flowing from Binance when CoinGecko is down.
    try {
      const updated = await refreshPricesFromBinance(supabase)
      if (updated > 0) {
        stats.markets = true
        stats.marketsSource = "binance-fallback"
        console.log(`Fallback: refreshed ${updated} prices from Binance`)
      }
    } catch (fbErr) {
      const fbMsg = `markets-fallback: ${fbErr}`
      console.error(fbMsg)
      stats.errors.push(fbMsg)
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

/**
 * Fallback price refresh. Reads the last-known-good top-100 snapshot and
 * overwrites only `current_price` and `price_change_percentage_24h` using
 * Binance's bulk 24h ticker (one request for all symbols). Everything else
 * (name, image, market_cap, rank, sparkline) is preserved from the last good
 * CoinGecko sync. Returns the number of coins whose price was refreshed.
 */
async function refreshPricesFromBinance(
  supabase: ReturnType<typeof createClient>
): Promise<number> {
  // 1. Load the last-known-good snapshot.
  const { data: row, error } = await supabase
    .from("market_data_cache")
    .select("data")
    .eq("key", "crypto_assets_1_100")
    .maybeSingle()
  if (error) throw new Error(`snapshot read failed: ${error.message}`)
  if (!row?.data) throw new Error("no prior snapshot to refresh")

  let coins: Array<Record<string, unknown>>
  try {
    coins = JSON.parse(row.data as string)
  } catch {
    throw new Error("snapshot is not valid JSON")
  }
  if (!Array.isArray(coins) || coins.length === 0) {
    throw new Error("snapshot is empty")
  }

  // 2. One bulk request for every Binance USDT pair.
  const resp = await fetch("https://data-api.binance.vision/api/v3/ticker/24hr")
  if (!resp.ok) throw new Error(`Binance ${resp.status}`)
  const tickers = await resp.json()
  if (!Array.isArray(tickers)) throw new Error("Binance returned no tickers")

  const priceBySymbol = new Map<string, { price: number; changePct: number }>()
  for (const t of tickers) {
    const sym = t?.symbol
    if (typeof sym === "string" && sym.endsWith("USDT")) {
      const base = sym.slice(0, -4)
      const price = parseFloat(t.lastPrice)
      const changePct = parseFloat(t.priceChangePercent)
      if (isFinite(price) && price > 0) {
        priceBySymbol.set(base, { price, changePct })
      }
    }
  }
  if (priceBySymbol.size === 0) throw new Error("no usable Binance tickers")

  // 3. Overwrite prices in place. Stablecoins peg to ~1 when unlisted.
  const STABLE = new Set(["USDT", "USDC", "DAI", "TUSD", "USDE", "FDUSD", "USDD", "PYUSD"])
  const nowISO = new Date().toISOString()
  let updated = 0
  for (const c of coins) {
    const sym = String(c.symbol ?? "").toUpperCase()
    if (!sym) continue
    const hit = priceBySymbol.get(sym)
    if (hit) {
      c.current_price = hit.price
      if (isFinite(hit.changePct)) c.price_change_percentage_24h = hit.changePct
      c.last_updated = nowISO
      updated++
    } else if (STABLE.has(sym)) {
      c.current_price = 1
      c.price_change_percentage_24h = 0
      c.last_updated = nowISO
      updated++
    }
    // Otherwise keep the last-known price rather than zeroing it out.
  }
  if (updated === 0) throw new Error("no snapshot symbols matched Binance")

  // 4. Write back with a fresh timestamp so the freshness check goes green.
  await writeCache(supabase, "crypto_assets_1_100", coins, 300)
  return updated
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
