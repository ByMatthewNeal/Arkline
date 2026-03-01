import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Verify authorization header exists
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing authorization" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Parse request payload
  let payload: Record<string, unknown>
  try {
    payload = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: "Invalid request body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Check cache first (today's summary in UTC)
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const supabase = createClient(supabaseUrl, supabaseKey)

  const todayUTC = new Date().toISOString().split("T")[0]

  const { data: cached, error: cacheError } = await supabase
    .from("market_summaries")
    .select("summary, generated_at")
    .eq("summary_date", todayUTC)
    .maybeSingle()

  if (cacheError) {
    console.error("Cache lookup error:", cacheError.message)
  }

  if (cached) {
    console.log(`Returning cached summary for ${todayUTC}`)
    return new Response(
      JSON.stringify({ summary: cached.summary, generatedAt: cached.generated_at }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  }

  // No cache — build prompt from payload and call Claude
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!apiKey) {
    console.error("ANTHROPIC_API_KEY not set")
    return new Response(
      JSON.stringify({ error: "Summary service unavailable" }),
      { status: 503, headers: { "Content-Type": "application/json" } }
    )
  }

  // Build the market data context from the payload
  const lines: string[] = []

  if (payload.btcPrice) {
    lines.push(`BTC: $${Number(payload.btcPrice).toLocaleString()} (${formatChange(payload.btcChange24h)})`)
  }
  if (payload.ethPrice) {
    lines.push(`ETH: $${Number(payload.ethPrice).toLocaleString()} (${formatChange(payload.ethChange24h)})`)
  }
  if (payload.solPrice) {
    lines.push(`SOL: $${Number(payload.solPrice).toLocaleString()} (${formatChange(payload.solChange24h)})`)
  }
  if (payload.fearGreedValue != null) {
    lines.push(`Fear & Greed Index: ${payload.fearGreedValue} (${payload.fearGreedClassification ?? "N/A"})`)
  }
  if (payload.riskScore != null) {
    lines.push(`ArkLine Risk Score: ${payload.riskScore}/100 (${payload.riskTier ?? "N/A"})`)
  }
  if (payload.vixValue != null) {
    lines.push(`VIX: ${payload.vixValue}${payload.vixSignal ? ` — ${payload.vixSignal}` : ""}`)
  }
  if (payload.dxyValue != null) {
    lines.push(`DXY: ${payload.dxyValue}${payload.dxySignal ? ` — ${payload.dxySignal}` : ""}`)
  }
  if (payload.m2Signal) {
    lines.push(`Global M2: ${payload.m2Signal}`)
  }

  // Top gainers/losers
  if (Array.isArray(payload.topGainers) && payload.topGainers.length > 0) {
    const gainers = payload.topGainers.map((g: any) => `${g.symbol} ${formatChange(g.change)}`).join(", ")
    lines.push(`Top gainers: ${gainers}`)
  }
  if (Array.isArray(payload.topLosers) && payload.topLosers.length > 0) {
    const losers = payload.topLosers.map((l: any) => `${l.symbol} ${formatChange(l.change)}`).join(", ")
    lines.push(`Top losers: ${losers}`)
  }

  // Economic events
  if (Array.isArray(payload.economicEvents) && payload.economicEvents.length > 0) {
    const events = payload.economicEvents.map((e: any) => e.title).join("; ")
    lines.push(`Today's events: ${events}`)
  }

  // News headlines
  if (Array.isArray(payload.newsHeadlines) && payload.newsHeadlines.length > 0) {
    const headlines = payload.newsHeadlines.join("; ")
    lines.push(`Headlines: ${headlines}`)
  }

  const marketContext = lines.join("\n")
  console.log(`Market context for Claude:\n${marketContext}`)

  try {
    const claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 300,
        system: "You are a market analyst writing a daily briefing for ArkLine, a crypto and macro tracking app. Write exactly 3-4 sentences summarizing today's market conditions. Be direct, mention specific numbers, highlight what's notable. No headers, no bullets — just flowing prose. Never start with 'Today' or 'The market'.",
        messages: [
          {
            role: "user",
            content: `Here is today's market data:\n\n${marketContext}\n\nWrite a concise daily market briefing.`,
          },
        ],
      }),
    })

    if (!claudeResponse.ok) {
      const errorText = await claudeResponse.text()
      console.error(`Claude API error: ${claudeResponse.status} ${errorText}`)
      return new Response(
        JSON.stringify({ error: "Failed to generate summary" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      )
    }

    const claudeData = await claudeResponse.json()
    let summary: string = claudeData.content?.[0]?.text ?? ""
    summary = summary.trim()

    if (!summary) {
      return new Response(
        JSON.stringify({ error: "Empty summary generated" }),
        { status: 502, headers: { "Content-Type": "application/json" } }
      )
    }

    console.log(`Generated summary (${summary.length} chars)`)

    // Cache in DB
    const { error: insertError } = await supabase
      .from("market_summaries")
      .upsert({
        summary_date: todayUTC,
        summary: summary,
        generated_at: new Date().toISOString(),
      }, { onConflict: "summary_date" })

    if (insertError) {
      console.error("Failed to cache summary:", insertError.message)
      // Still return the summary even if caching failed
    }

    return new Response(
      JSON.stringify({ summary, generatedAt: new Date().toISOString() }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err)
    console.error("Claude API call failed:", errMsg)
    return new Response(
      JSON.stringify({ error: "Summary generation failed" }),
      { status: 502, headers: { "Content-Type": "application/json" } }
    )
  }
})

function formatChange(value: unknown): string {
  if (value == null) return "N/A"
  const num = Number(value)
  if (isNaN(num)) return "N/A"
  const sign = num >= 0 ? "+" : ""
  return `${sign}${num.toFixed(1)}%`
}
