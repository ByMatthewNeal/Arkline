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
 * subscription), we fall back to Binance's bulk 24h ticker (primary) and
 * Coinbase's exchange-rates map (secondary) to refresh live prices on the
 * last-known-good snapshot, so prices keep flowing. Names, logos, market caps,
 * ranks and sparklines are kept from the last successful CoinGecko sync.
 * (Global mcap/dominance still needs CoinGecko and is not backfilled.)
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

    // Fallback: keep live prices flowing from Binance + Coinbase when CoinGecko is down.
    try {
      const updated = await refreshPricesFromFallbacks(supabase)
      if (updated > 0) {
        stats.markets = true
        stats.marketsSource = "binance+coinbase-fallback"
        console.log(`Fallback: refreshed ${updated} prices from Binance/Coinbase`)
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
 * overwrites only `current_price` (and 24h change where available) using two
 * bulk sources: Binance's 24h ticker (price + 24h change) as primary, and
 * Coinbase's exchange-rates map (price only) to fill whatever Binance doesn't
 * list. Everything else (name, image, market_cap, rank, sparkline) is preserved
 * from the last good CoinGecko sync. Returns the number of coins refreshed.
 */
async function refreshPricesFromFallbacks(
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

  // 2. Primary source — Binance bulk 24h ticker (price + 24h change).
  const binance = new Map<string, { price: number; changePct: number }>()
  try {
    const resp = await fetch("https://data-api.binance.vision/api/v3/ticker/24hr")
    if (resp.ok) {
      const tickers = await resp.json()
      if (Array.isArray(tickers)) {
        for (const t of tickers) {
          const sym = t?.symbol
          if (typeof sym === "string" && sym.endsWith("USDT")) {
            const base = sym.slice(0, -4)
            const price = parseFloat(t.lastPrice)
            const changePct = parseFloat(t.priceChangePercent)
            if (isFinite(price) && price > 0) {
              binance.set(base, { price, changePct })
            }
          }
        }
      }
    } else {
      console.error(`Binance fallback ${resp.status}`)
    }
  } catch (e) {
    console.error(`Binance fallback fetch failed: ${e}`)
  }

  // 3. Secondary source — Coinbase exchange-rates (one bulk call, price only).
  //    rates[X] = amount of X per 1 USD, so USD price = 1 / rate.
  const coinbase = new Map<string, number>()
  try {
    const resp = await fetch("https://api.coinbase.com/v2/exchange-rates?currency=USD")
    if (resp.ok) {
      const body = await resp.json()
      const rates = body?.data?.rates ?? {}
      for (const [sym, rateStr] of Object.entries(rates)) {
        const rate = parseFloat(rateStr as string)
        if (isFinite(rate) && rate > 0) {
          coinbase.set(sym.toUpperCase(), 1 / rate)
        }
      }
    } else {
      console.error(`Coinbase fallback ${resp.status}`)
    }
  } catch (e) {
    console.error(`Coinbase fallback fetch failed: ${e}`)
  }

  if (binance.size === 0 && coinbase.size === 0) {
    throw new Error("no fallback price source available")
  }

  // 4. Overwrite prices in place: Binance first (has 24h change), then Coinbase,
  //    then a ~1 peg for stablecoins. Otherwise keep the last-known price.
  const STABLE = new Set(["USDT", "USDC", "DAI", "TUSD", "USDE", "FDUSD", "USDD", "PYUSD"])
  const nowISO = new Date().toISOString()
  let fromBinance = 0
  let fromCoinbase = 0
  for (const c of coins) {
    const sym = String(c.symbol ?? "").toUpperCase()
    if (!sym) continue
    const b = binance.get(sym)
    if (b) {
      c.current_price = b.price
      if (isFinite(b.changePct)) c.price_change_percentage_24h = b.changePct
      c.last_updated = nowISO
      fromBinance++
    } else if (coinbase.has(sym)) {
      c.current_price = coinbase.get(sym)!
      c.last_updated = nowISO
      // Coinbase rates carry no 24h change; leave the prior value untouched.
      fromCoinbase++
    } else if (STABLE.has(sym)) {
      c.current_price = 1
      c.price_change_percentage_24h = 0
      c.last_updated = nowISO
      fromCoinbase++
    }
  }

  const updated = fromBinance + fromCoinbase
  if (updated === 0) throw new Error("no snapshot symbols matched a fallback source")
  console.log(`Fallback coverage — Binance: ${fromBinance}, Coinbase/stable: ${fromCoinbase}`)

  // 5. Write back with a fresh timestamp so the freshness check goes green.
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
