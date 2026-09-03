import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// Service configuration: how to reach each upstream API and inject its key
interface ServiceConfig {
  baseURL: string
  envVar: string
  auth: { type: "header"; name: string } | { type: "query"; name: string } | { type: "dynamic-header" } | { type: "none" }
}

const SERVICES: Record<string, ServiceConfig> = {
  fmp: {
    baseURL: "https://financialmodelingprep.com/stable",
    envVar: "FMP_API_KEY",
    auth: { type: "query", name: "apikey" },
  },
  coingecko: {
    baseURL: "https://pro-api.coingecko.com/api/v3",
    envVar: "COINGECKO_API_KEY",
    auth: { type: "dynamic-header" }, // header name depends on key prefix
  },
  metals: {
    baseURL: "https://metals-api.com/api",
    envVar: "METALS_API_KEY",
    auth: { type: "query", name: "access_key" },
  },
  taapi: {
    baseURL: "https://api.taapi.io",
    envVar: "TAAPI_API_KEY",
    auth: { type: "query", name: "secret" }, // GET: query param, POST: injected into body
  },
  fred: {
    baseURL: "https://api.stlouisfed.org/fred",
    envVar: "FRED_API_KEY",
    auth: { type: "query", name: "api_key" },
  },
  coinglass: {
    baseURL: "https://open-api-v4.coinglass.com/api",
    envVar: "COINGLASS_API_KEY",
    auth: { type: "header", name: "CG-API-KEY" },
  },
  finnhub: {
    baseURL: "https://finnhub.io/api/v1",
    envVar: "FINNHUB_API_KEY",
    auth: { type: "header", name: "X-Finnhub-Token" },
  },
  "binance-futures": {
    baseURL: "https://fapi.binance.com",
    envVar: "",
    auth: { type: "none" },
  },
}

// True if the bearer is a JWT issued by this Supabase project (user token,
// possibly expired, or the anon key). Decodes the payload only — no signature
// check (see the auth note below).
function isProjectToken(authHeader: string | null): boolean {
  if (!authHeader) return false
  const token = authHeader.replace(/^Bearer\s+/i, "").trim()
  const parts = token.split(".")
  if (parts.length !== 3) return false
  try {
    let b64 = parts[1].replace(/-/g, "+").replace(/_/g, "/")
    b64 += "=".repeat((4 - (b64.length % 4)) % 4)
    const payload = JSON.parse(atob(b64)) as { iss?: string; ref?: string }
    return (typeof payload.iss === "string" && payload.iss.includes("supabase")) ||
      payload.ref === "mprbbjgrshfbupheuscn"
  } catch {
    return false
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Auth. This proxy only serves PUBLIC market data (vendor API keys stay
  // server-side and are never returned), so it does not need a live per-user
  // session. Requiring one via getUser() caused frequent 401s whenever the
  // app's access token lapsed — which surfaced to users as $0 prices, because
  // the whole proxy (incl. the FMP→Yahoo fallback) sits behind this check.
  //
  // Instead, accept any request whose Authorization carries a token issued by
  // THIS Supabase project — a user token (even an expired one) or the anon key.
  // The signature isn't re-verified: the anon key is public anyway, and the real
  // protection is that vendor keys never leave the server. This keeps anonymous
  // internet callers out while tolerating lapsed user tokens.
  if (!isProjectToken(req.headers.get("Authorization"))) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Parse request
  let service: string
  let path: string
  let method: string
  let queryItems: Record<string, string> | null
  let body: Record<string, unknown> | null
  try {
    const parsed = await req.json()
    service = parsed.service
    path = parsed.path
    method = (parsed.method ?? "GET").toUpperCase()
    queryItems = parsed.queryItems ?? null
    body = parsed.body ?? null
  } catch {
    return new Response(JSON.stringify({ error: "Invalid request body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  }

  if (!service || !path) {
    return new Response(JSON.stringify({ error: "Missing service or path" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Path validation: prevent traversal and injection
  if (
    !path.startsWith("/") ||
    path.includes("..") ||
    path.includes("@") ||
    path.includes("://") ||
    path.includes("\\")
  ) {
    return new Response(JSON.stringify({ error: "Invalid path" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Look up service config
  const config = SERVICES[service]
  if (!config) {
    return new Response(JSON.stringify({ error: `Unknown service: ${service}` }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  }

  // FMP price quotes (stocks, crypto, metals) all go through /quote. When FMP is
  // unavailable (missing key, 4xx, or a soft "Error Message" body), we transparently
  // serve the same shape from Yahoo so equity/metals prices don't freeze.
  const isFmpQuote = service === "fmp" && path.startsWith("/quote")

  // Get API key
  const apiKey = Deno.env.get(config.envVar) ?? ""

  // A missing secret used to fall through as an EMPTY key, and the failure mode
  // differed per vendor in a way that was very hard to diagnose:
  //   - FMP replies 4xx, which the client surfaces as a generic error
  //   - metals-api replies HTTP 200 with {"success":false,"error":{...}}, which
  //     the client cannot decode, so the search silently renders nothing
  // Fail loudly and name the service instead of proxying a request we know
  // cannot succeed.
  if (!apiKey && config.auth.type !== "none") {
    if (isFmpQuote) {
      const fb = await fmpYahooQuoteFallback(queryItems)
      if (fb) return fb
    }
    console.error(`[api-proxy] ${config.envVar} is not set — refusing to call ${service}${path}`)
    return new Response(
      JSON.stringify({ error: `Server is missing the API key for '${service}'`, service }),
      { status: 503, headers: { "Content-Type": "application/json" } },
    )
  }

  // Build upstream URL
  const url = new URL(config.baseURL + path)

  // Add client query params
  if (queryItems) {
    for (const [key, value] of Object.entries(queryItems)) {
      url.searchParams.append(key, String(value))
    }
  }

  // Inject API key
  const headers: Record<string, string> = {}

  if (config.auth.type === "header") {
    headers[config.auth.name] = apiKey
  } else if (config.auth.type === "query") {
    if (method === "POST" && service === "taapi" && body) {
      // TAAPI POST: inject secret into body instead of query
      body["secret"] = apiKey
    } else {
      url.searchParams.append(config.auth.name, apiKey)
    }
  } else if (config.auth.type === "dynamic-header") {
    // CoinGecko: always use pro header for paid plans
    headers["x-cg-pro-api-key"] = apiKey
  }

  // Build fetch options
  const fetchOptions: RequestInit = {
    method: method,
    headers: {
      ...headers,
      "Accept": "application/json",
    },
  }

  if (method === "POST" && body) {
    fetchOptions.headers = { ...fetchOptions.headers, "Content-Type": "application/json" }
    fetchOptions.body = JSON.stringify(body)
  }

  // Forward to upstream API
  const upstreamResponse = await fetch(url.toString(), fetchOptions)
  const responseData = await upstreamResponse.text()

  // Log upstream failures with the service and path (never the key or the full
  // URL, which carries the key as a query param). Without this a broken vendor
  // key is invisible: every proxy call still shows as whatever status the
  // vendor returned, and metals-api in particular returns 200 on auth failure.
  // A "soft error" is HTTP 200 carrying a vendor-level error payload. metals-api
  // and FMP both do this, and it's the most confusing failure mode in this proxy:
  // the request log shows a healthy 200 while the feature is dead, because the
  // client can't decode an error shape and renders an empty list.
  const isSoftError = upstreamResponse.ok &&
    (responseData.includes('"success":false') || responseData.includes('"Error Message"'))

  if (!upstreamResponse.ok || isSoftError) {
    console.error(
      `[api-proxy] ${isSoftError ? "soft error" : `upstream ${upstreamResponse.status}`} from ${service}${path} :: ${responseData.slice(0, 300)}`,
    )

    // FMP quote fallback: keep equity/crypto/metals prices flowing via Yahoo
    // when FMP is down (lapsed key, rate limit, or plan-tier restriction).
    if (isFmpQuote) {
      const fb = await fmpYahooQuoteFallback(queryItems)
      if (fb) return fb
    }

    // Relay a soft error as 502 (never report a vendor failure as success). The
    // body passes through untouched so clients inspecting it still see the reason.
    if (isSoftError) {
      return new Response(responseData, {
        status: 502,
        headers: { "Content-Type": "application/json", "X-Upstream-Soft-Error": service },
      })
    }
    // Non-2xx with no fallback: relay the upstream status and body as-is.
    return new Response(responseData, {
      status: upstreamResponse.status,
      headers: { "Content-Type": "application/json" },
    })
  }

  return new Response(responseData, {
    status: upstreamResponse.status,
    headers: { "Content-Type": "application/json" },
  })
})

// ─── FMP /quote → Yahoo fallback ────────────────────────────────────────────
// Reshapes Yahoo's v8 chart endpoint into the FMP "stable /quote" array shape
// the clients decode (FMPQuote / FMPLightQuote). Returns null if it can't, so
// the caller relays the original FMP error instead.

const FMP_TO_YAHOO_METAL: Record<string, string> = {
  GCUSD: "GC=F", // gold
  SIUSD: "SI=F", // silver
  PLUSD: "PL=F", // platinum
  PAUSD: "PA=F", // palladium
  HGUSD: "HG=F", // copper
  CLUSD: "CL=F", // WTI crude
  NGUSD: "NG=F", // natural gas
}

function fmpSymbolToYahoo(fmpSymbol: string): { yahoo: string; kind: "metal" | "crypto" | "stock" } {
  const s = fmpSymbol.toUpperCase()
  if (FMP_TO_YAHOO_METAL[s]) return { yahoo: FMP_TO_YAHOO_METAL[s], kind: "metal" }
  // Crypto quotes come in as BTCUSD / ETHUSD → Yahoo uses BTC-USD / ETH-USD.
  if (s.endsWith("USD") && s.length > 4) return { yahoo: `${s.slice(0, -3)}-USD`, kind: "crypto" }
  return { yahoo: s, kind: "stock" }
}

async function fmpYahooQuoteFallback(
  queryItems: Record<string, string> | null,
): Promise<Response | null> {
  const fmpSymbol = queryItems?.symbol
  if (!fmpSymbol) return null

  const { yahoo, kind } = fmpSymbolToYahoo(fmpSymbol)
  try {
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(yahoo)}?interval=1d&range=1d`
    const resp = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0", "Accept": "application/json" } })
    if (!resp.ok) return null

    const body = await resp.json()
    const result = body?.chart?.result?.[0]
    const meta = result?.meta
    const price = meta?.regularMarketPrice
    if (typeof price !== "number" || !isFinite(price)) return null

    const prevClose =
      typeof meta.chartPreviousClose === "number" ? meta.chartPreviousClose
      : typeof meta.previousClose === "number" ? meta.previousClose
      : price
    const change = price - prevClose
    const changePct = prevClose ? (change / prevClose) * 100 : 0

    // Prefer the session open from the candle data; fall back to prevClose.
    let open = prevClose
    const opens = result?.indicators?.quote?.[0]?.open
    if (Array.isArray(opens)) {
      const firstOpen = opens.find((v: unknown) => typeof v === "number")
      if (typeof firstOpen === "number") open = firstOpen
    }

    const exchange =
      kind === "crypto" ? "CRYPTO"
      : kind === "metal" ? "COMMODITY"
      : (meta.exchangeName ?? meta.fullExchangeName ?? "")

    const quote = {
      symbol: fmpSymbol.toUpperCase(),
      name: meta.longName ?? meta.shortName ?? fmpSymbol.toUpperCase(),
      price,
      changePercentage: changePct,
      change,
      volume: Math.round(typeof meta.regularMarketVolume === "number" ? meta.regularMarketVolume : 0),
      dayLow: typeof meta.regularMarketDayLow === "number" ? meta.regularMarketDayLow : Math.min(price, prevClose),
      dayHigh: typeof meta.regularMarketDayHigh === "number" ? meta.regularMarketDayHigh : Math.max(price, prevClose),
      yearHigh: typeof meta.fiftyTwoWeekHigh === "number" ? meta.fiftyTwoWeekHigh : price,
      yearLow: typeof meta.fiftyTwoWeekLow === "number" ? meta.fiftyTwoWeekLow : price,
      marketCap: null,
      priceAvg50: null,
      priceAvg200: null,
      exchange,
      open,
      previousClose: prevClose,
      timestamp: typeof meta.regularMarketTime === "number" ? meta.regularMarketTime : Math.floor(Date.now() / 1000),
    }

    return new Response(JSON.stringify([quote]), {
      status: 200,
      headers: { "Content-Type": "application/json", "X-Fallback-Source": "yahoo" },
    })
  } catch (_e) {
    return null
  }
}
