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

const COINGECKO_BASE = "https://api.coingecko.com/api/v3"

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

  const headers: Record<string, string> = {
    "Accept": "application/json",
  }

  // CoinGecko Demo API key goes in header for free tier
  if (cgKey) {
    if (cgKey.startsWith("CG-")) {
      headers["x-cg-demo-api-key"] = cgKey
    } else {
      headers["x-cg-pro-api-key"] = cgKey
    }
  }

  const stats = { markets: false, global: false, trending: false, errors: [] as string[] }

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

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms))
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
