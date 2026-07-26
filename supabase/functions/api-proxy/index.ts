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

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Verify JWT
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing authorization" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    })
  }

  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
  if (userError || !user) {
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
  if (!upstreamResponse.ok) {
    console.error(
      `[api-proxy] upstream ${upstreamResponse.status} from ${service}${path} :: ${responseData.slice(0, 300)}`,
    )
  } else if (
    responseData.includes('"success":false') ||
    responseData.includes('"Error Message"')
  ) {
    // 200 OK carrying a vendor-level error payload. metals-api and FMP both do
    // this, and it is the single most confusing failure mode in this proxy:
    // the request log shows a healthy 200 while the feature is dead, because
    // the client can't decode an error shape and renders an empty list.
    //
    // Relay it as 502 so a vendor-side failure is never reported as success.
    // The body is passed through untouched, so clients that inspect it (e.g.
    // FMPService checking for "Limit Reach" / "Invalid API KEY") still see it.
    console.error(
      `[api-proxy] soft error from ${service}${path} :: ${responseData.slice(0, 300)}`,
    )
    return new Response(responseData, {
      status: 502,
      headers: { "Content-Type": "application/json", "X-Upstream-Soft-Error": service },
    })
  }

  return new Response(responseData, {
    status: upstreamResponse.status,
    headers: { "Content-Type": "application/json" },
  })
})
