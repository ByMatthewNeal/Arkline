import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const FMP_BASE_URL = "https://financialmodelingprep.com/stable"

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

  // Parse request body
  let path: string
  let queryItems: Record<string, string>
  try {
    const body = await req.json()
    path = body.path
    queryItems = body.queryItems ?? {}
  } catch {
    return new Response(JSON.stringify({ error: "Invalid request body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  }

  if (!path || typeof path !== "string") {
    return new Response(JSON.stringify({ error: "Missing path parameter" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Get FMP API key from secrets
  const fmpApiKey = Deno.env.get("FMP_API_KEY")
  if (!fmpApiKey) {
    return new Response(JSON.stringify({ error: "FMP API key not configured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Build FMP URL
  const url = new URL(FMP_BASE_URL + path)
  for (const [key, value] of Object.entries(queryItems)) {
    url.searchParams.append(key, String(value))
  }

  // Forward to FMP
  const fmpResponse = await fetch(url.toString(), {
    headers: { "apikey": fmpApiKey },
  })

  const fmpData = await fmpResponse.text()

  return new Response(fmpData, {
    status: fmpResponse.status,
    headers: { "Content-Type": "application/json" },
  })
})
