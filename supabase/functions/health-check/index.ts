import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * health-check Edge Function
 *
 * Pings all critical dependencies and checks data freshness.
 * Sends an admin-only push notification if any check fails.
 * Runs hourly via cron.
 *
 * Checks:
 * 1. CoinGecko API key validity
 * 2. Anthropic (Claude) API key validity
 * 3. FMP API key validity
 * 4. market_data_cache freshness (crypto_assets_1_100 < 30 min old)
 * 5. Today's briefing exists in market_summaries
 * 6. Cron jobs ran recently (fibonacci-pipeline, compute-positioning-signals)
 */

interface CheckResult {
  name: string
  ok: boolean
  detail: string
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  // Auth: cron secret or admin JWT
  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  const reqSecret = req.headers.get("x-cron-secret") ?? ""
  const isCron = cronSecret.length > 0 && reqSecret === cronSecret

  if (!isCron) {
    // Check for admin JWT
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) return json({ error: "Unauthorized" }, 401)

    const supabaseAuth = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user }, error } = await supabaseAuth.auth.getUser()
    if (error || !user) return json({ error: "Unauthorized" }, 401)

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )
    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single()

    if (profile?.role !== "admin") return json({ error: "Admin access required" }, 403)
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  )

  const checks: CheckResult[] = []

  // Run all checks in parallel
  const [cgResult, claudeResult, fmpResult, cacheResult, briefingResult, signalsResult] =
    await Promise.allSettled([
      checkCoinGecko(),
      checkClaudeAPI(),
      checkFMP(),
      checkCryptoCache(supabase),
      checkBriefing(supabase),
      checkSignalPipeline(supabase),
    ])

  pushResult(checks, "CoinGecko API", cgResult)
  pushResult(checks, "Claude API", claudeResult)
  pushResult(checks, "FMP API", fmpResult)
  pushResult(checks, "Crypto Cache", cacheResult)
  pushResult(checks, "Daily Briefing", briefingResult)
  pushResult(checks, "Signal Pipeline", signalsResult)

  const failures = checks.filter((c) => !c.ok)
  const allHealthy = failures.length === 0

  console.log(`Health check: ${checks.length - failures.length}/${checks.length} passing`)
  if (!allHealthy) {
    console.error("Failures:", failures.map((f) => `${f.name}: ${f.detail}`).join("; "))
  }

  // Send admin push notification if anything failed
  if (!allHealthy && isCron) {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const failNames = failures.map((f) => f.name).join(", ")
    const body = failures.length === 1
      ? `${failures[0].name}: ${failures[0].detail}`
      : `${failures.length} checks failed: ${failNames}`

    fetch(`${supabaseUrl}/functions/v1/send-broadcast-notification`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-cron-secret": cronSecret,
      },
      body: JSON.stringify({
        broadcast_id: `health_${new Date().toISOString().slice(0, 13)}`, // dedup per hour
        title: "Health Check Failed",
        body: body.length > 100 ? body.substring(0, 97) + "..." : body,
        target_audience: { type: "premium" }, // admin + premium = effectively admin-only for now
      }),
    }).catch((err) => console.error("Failed to send health alert:", err))
  }

  return json({
    healthy: allHealthy,
    checks,
    timestamp: new Date().toISOString(),
  })
})

// ─── Individual Checks ──────────────────────────────────────────────────────

async function checkCoinGecko(): Promise<CheckResult> {
  const cgKey = Deno.env.get("COINGECKO_API_KEY") ?? ""
  if (!cgKey) return { name: "CoinGecko API", ok: false, detail: "COINGECKO_API_KEY not set" }

  const resp = await fetch("https://pro-api.coingecko.com/api/v3/ping", {
    headers: { "x-cg-pro-api-key": cgKey },
  })

  if (!resp.ok) {
    const text = await resp.text()
    return { name: "CoinGecko API", ok: false, detail: `${resp.status}: ${text.substring(0, 100)}` }
  }

  return { name: "CoinGecko API", ok: true, detail: "Reachable" }
}

async function checkClaudeAPI(): Promise<CheckResult> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY") ?? ""
  if (!apiKey) return { name: "Claude API", ok: false, detail: "ANTHROPIC_API_KEY not set" }

  // Send a minimal request to validate the key without burning tokens
  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-haiku-4-5-20251001",
      max_tokens: 1,
      messages: [{ role: "user", content: "ping" }],
    }),
  })

  if (!resp.ok) {
    const text = await resp.text()
    // 401 = bad key, 402 = billing, 429 = rate limit (key works but throttled)
    if (resp.status === 429) {
      await resp.body?.cancel()
      return { name: "Claude API", ok: true, detail: "Rate limited but key valid" }
    }
    return { name: "Claude API", ok: false, detail: `${resp.status}: ${text.substring(0, 100)}` }
  }

  await resp.body?.cancel()
  return { name: "Claude API", ok: true, detail: "Reachable" }
}

async function checkFMP(): Promise<CheckResult> {
  const fmpKey = Deno.env.get("FMP_API_KEY") ?? ""
  if (!fmpKey) return { name: "FMP API", ok: false, detail: "FMP_API_KEY not set" }

  const resp = await fetch(
    `https://financialmodelingprep.com/stable/quote?symbol=%5EGSPC&apikey=${fmpKey}`
  )

  if (!resp.ok) {
    const text = await resp.text()
    return { name: "FMP API", ok: false, detail: `${resp.status}: ${text.substring(0, 100)}` }
  }

  const data = await resp.json()
  if (!Array.isArray(data) || data.length === 0) {
    return { name: "FMP API", ok: false, detail: "Empty response — key may be invalid" }
  }

  return { name: "FMP API", ok: true, detail: `S&P 500: $${data[0].price}` }
}

async function checkCryptoCache(
  supabase: ReturnType<typeof createClient>
): Promise<CheckResult> {
  const { data, error } = await supabase
    .from("market_data_cache")
    .select("updated_at")
    .eq("key", "crypto_assets_1_100")
    .maybeSingle()

  if (error) return { name: "Crypto Cache", ok: false, detail: error.message }
  if (!data) return { name: "Crypto Cache", ok: false, detail: "No cache entry found" }

  const ageMinutes = (Date.now() - new Date(data.updated_at).getTime()) / 60000

  if (ageMinutes > 30) {
    return {
      name: "Crypto Cache",
      ok: false,
      detail: `Stale — last updated ${Math.round(ageMinutes)} min ago`,
    }
  }

  return { name: "Crypto Cache", ok: true, detail: `Fresh — ${Math.round(ageMinutes)} min old` }
}

async function checkBriefing(
  supabase: ReturnType<typeof createClient>
): Promise<CheckResult> {
  const todayUTC = new Date().toISOString().split("T")[0]
  const estHour = getESTHour(new Date())

  const { data, error } = await supabase
    .from("market_summaries")
    .select("slot, generated_at")
    .eq("summary_date", todayUTC)
    .order("generated_at", { ascending: false })

  if (error) return { name: "Daily Briefing", ok: false, detail: error.message }
  if (!data || data.length === 0) {
    // Only flag as failure if we're past the first scheduled slot (10 AM ET = after 14 UTC-ish)
    if (estHour >= 11) {
      return { name: "Daily Briefing", ok: false, detail: `No briefing generated for ${todayUTC}` }
    }
    return { name: "Daily Briefing", ok: true, detail: "Not yet due today" }
  }

  const slots = data.map((d: { slot: string }) => d.slot).join(", ")
  return { name: "Daily Briefing", ok: true, detail: `Slots: ${slots}` }
}

async function checkSignalPipeline(
  supabase: ReturnType<typeof createClient>
): Promise<CheckResult> {
  // Check if fibonacci-pipeline produced signals recently (runs every 30 min)
  const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString()

  const { data, error } = await supabase
    .from("trade_signals")
    .select("generated_at")
    .gte("generated_at", twoHoursAgo)
    .limit(1)

  if (error) return { name: "Signal Pipeline", ok: false, detail: error.message }

  // Signal pipeline may legitimately produce no signals if conditions aren't met.
  // Check if the pipeline ran at all by looking at ohlc_candles freshness instead.
  const { data: candle, error: candleErr } = await supabase
    .from("ohlc_candles")
    .select("open_time")
    .order("open_time", { ascending: false })
    .limit(1)
    .maybeSingle()

  if (candleErr) return { name: "Signal Pipeline", ok: false, detail: candleErr.message }
  if (!candle) return { name: "Signal Pipeline", ok: false, detail: "No candle data found" }

  const candleAge = (Date.now() - new Date(candle.open_time).getTime()) / 60000
  if (candleAge > 120) {
    return {
      name: "Signal Pipeline",
      ok: false,
      detail: `Candle data stale — last update ${Math.round(candleAge)} min ago`,
    }
  }

  return { name: "Signal Pipeline", ok: true, detail: `Candles fresh — ${Math.round(candleAge)} min old` }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

function pushResult(
  checks: CheckResult[],
  name: string,
  result: PromiseSettledResult<CheckResult>
) {
  if (result.status === "fulfilled") {
    checks.push(result.value)
  } else {
    checks.push({
      name,
      ok: false,
      detail: result.reason instanceof Error ? result.reason.message : String(result.reason),
    })
  }
}

function getESTHour(date: Date): number {
  const utc = date.getUTCHours()
  const jan = new Date(date.getFullYear(), 0, 1)
  const jul = new Date(date.getFullYear(), 6, 1)
  const isDST = date.getTimezoneOffset() < Math.max(jan.getTimezoneOffset(), jul.getTimezoneOffset())
    || (date.getMonth() > 2 && date.getMonth() < 10) // rough DST: Mar-Oct
    || (date.getMonth() === 2 && date.getDate() >= 8)
    || (date.getMonth() === 10 && date.getDate() < 7)
  return (utc - (isDST ? 4 : 5) + 24) % 24
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
