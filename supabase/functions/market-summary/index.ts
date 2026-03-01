import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

Deno.serve(async (req) => {
  const ok = (body: Record<string, unknown>) =>
    new Response(JSON.stringify(body), { status: 200, headers: { "Content-Type": "application/json" } })

  if (req.method !== "POST") {
    return ok({ error: "Method not allowed" })
  }

  // Parse request payload
  let payload: Record<string, unknown>
  try {
    payload = await req.json()
  } catch {
    return ok({ error: "Invalid request body" })
  }

  // Admin: clear cache for today if requested
  if (payload.clearCache === true) {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const sb = createClient(supabaseUrl, supabaseKey)
    const today = new Date().toISOString().split("T")[0]
    await sb.from("market_summaries").delete().eq("summary_date", today)
    console.log(`Cleared cache for ${today}`)
    return ok({ cleared: true })
  }

  // Determine current slot based on EST time
  // Morning: generated at 10:00 AM EST (valid until evening)
  // Evening: generated at 4:30 PM EST (valid until next morning)
  const now = new Date()
  const estHour = getESTHour(now)
  const slot = estHour >= 16 ? "evening" : "morning"
  const todayUTC = now.toISOString().split("T")[0]

  console.log(`Slot: ${slot}, EST hour: ${estHour}, date: ${todayUTC}`)

  // Check cache for current slot
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const supabase = createClient(supabaseUrl, supabaseKey)

  const { data: cached, error: cacheError } = await supabase
    .from("market_summaries")
    .select("summary, generated_at")
    .eq("summary_date", todayUTC)
    .eq("slot", slot)
    .maybeSingle()

  if (cacheError) {
    console.error("Cache lookup error:", cacheError.message)
  }

  if (cached) {
    console.log(`Returning cached ${slot} summary for ${todayUTC}`)
    return ok({ summary: cached.summary, generatedAt: cached.generated_at })
  }

  // No cache — build prompt and call Claude
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!apiKey) {
    console.error("ANTHROPIC_API_KEY not set")
    return ok({ error: "Summary service unavailable" })
  }

  // Build market data context
  const lines: string[] = []

  // Equities
  if (payload.sp500Price) {
    lines.push(`S&P 500: ${formatPrice(payload.sp500Price)} (${formatChange(payload.sp500Change)})`)
  }
  if (payload.nasdaqPrice) {
    lines.push(`Nasdaq: ${formatPrice(payload.nasdaqPrice)} (${formatChange(payload.nasdaqChange)})`)
  }

  // Crypto
  if (payload.btcPrice) {
    lines.push(`BTC: $${Number(payload.btcPrice).toLocaleString()} (${formatChange(payload.btcChange24h)})`)
  }
  if (payload.ethPrice) {
    lines.push(`ETH: $${Number(payload.ethPrice).toLocaleString()} (${formatChange(payload.ethChange24h)})`)
  }
  if (payload.solPrice) {
    lines.push(`SOL: $${Number(payload.solPrice).toLocaleString()} (${formatChange(payload.solChange24h)})`)
  }

  // Sentiment & Risk
  if (payload.fearGreedValue != null) {
    lines.push(`Crypto Fear & Greed Index: ${payload.fearGreedValue} (${payload.fearGreedClassification ?? "N/A"})`)
  }
  if (payload.riskScore != null) {
    lines.push(`ArkLine Risk Score: ${payload.riskScore}/100 (${payload.riskTier ?? "N/A"})`)
  }

  // Macro indicators
  if (payload.vixValue != null) {
    lines.push(`VIX: ${payload.vixValue}${payload.vixSignal ? ` — ${payload.vixSignal}` : ""}`)
  }
  if (payload.dxyValue != null) {
    lines.push(`DXY: ${payload.dxyValue}${payload.dxySignal ? ` — ${payload.dxySignal}` : ""}`)
  }
  if (payload.netLiquiditySignal) {
    lines.push(`US Net Liquidity: ${payload.netLiquiditySignal}`)
  }

  // Economic events (with optional times)
  if (Array.isArray(payload.economicEvents) && payload.economicEvents.length > 0) {
    const events = payload.economicEvents.map((e: any) => {
      if (e.time) return `${e.title} (${e.time})`
      return e.title
    }).join("; ")
    lines.push(`Today's high-impact events: ${events}`)
  }

  // News headlines
  if (Array.isArray(payload.newsHeadlines) && payload.newsHeadlines.length > 0) {
    const headlines = payload.newsHeadlines.join("; ")
    lines.push(`Headlines: ${headlines}`)
  }

  const marketContext = lines.join("\n")
  const timeLabel = slot === "morning" ? "morning (post-market-open)" : "evening (post-market-close)"
  console.log(`Market context for Claude (${timeLabel}):\n${marketContext}`)

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
        max_tokens: 700,
        system: `You are a market analyst writing a ${timeLabel} briefing for ArkLine, a crypto and macro tracking app.

Write a structured briefing using exactly these section headers on their own line, prefixed with "##":

## Posture
A single short phrase describing the overall market stance. Use exactly one of: "risk-on", "risk-off", or "neutral". Example: "Risk-on — equities and crypto rallying on liquidity tailwinds." Keep to one sentence max.

## What Moved
1-2 sentences on what happened in markets. Cover equities (S&P 500, Nasdaq) and crypto (BTC, ETH, SOL) with specific prices and percentage moves. If a high-impact economic event occurred (Fed decision, CPI, jobs report), mention it with its scheduled time if provided. Be factual.

## What It Means
1-2 sentences interpreting the moves. Connect VIX, DXY, Fear & Greed, ArkLine Risk Score, and net liquidity to explain why markets moved. Focus on the narrative — what's driving sentiment and what to watch.

Rules:
- Be direct and cite specific numbers
- Connect data points — don't just list them
- Never start any section with "Today" or "The market"
- Never give investment advice or suggest buying/selling
- Keep total length under 120 words`,
        messages: [
          {
            role: "user",
            content: `Here is the latest market data:\n\n${marketContext}\n\nWrite the structured ${timeLabel} market briefing.`,
          },
        ],
      }),
    })

    if (!claudeResponse.ok) {
      const errorText = await claudeResponse.text()
      console.error(`Claude API error: ${claudeResponse.status} ${errorText}`)
      return ok({ error: "Failed to generate summary" })
    }

    const claudeData = await claudeResponse.json()
    let summary: string = claudeData.content?.[0]?.text ?? ""
    summary = summary.trim()

    if (!summary) {
      return ok({ error: "Empty summary generated" })
    }

    console.log(`Generated ${slot} summary (${summary.length} chars)`)

    // Cache in DB
    const { error: insertError } = await supabase
      .from("market_summaries")
      .upsert({
        summary_date: todayUTC,
        slot: slot,
        summary: summary,
        generated_at: new Date().toISOString(),
      }, { onConflict: "summary_date,slot" })

    if (insertError) {
      console.error("Failed to cache summary:", insertError.message)
    }

    return ok({ summary, generatedAt: new Date().toISOString() })
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err)
    console.error("Claude API call failed:", errMsg)
    return ok({ error: "Summary generation failed" })
  }
})

function formatChange(value: unknown): string {
  if (value == null) return "N/A"
  const num = Number(value)
  if (isNaN(num)) return "N/A"
  const sign = num >= 0 ? "+" : ""
  return `${sign}${num.toFixed(2)}%`
}

function formatPrice(value: unknown): string {
  if (value == null) return "N/A"
  const num = Number(value)
  if (isNaN(num)) return "N/A"
  return num.toLocaleString("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 2 })
}

function getESTHour(date: Date): number {
  // Convert UTC to EST (UTC-5) or EDT (UTC-4)
  // Simple DST check: March second Sunday to November first Sunday
  const year = date.getUTCFullYear()
  const marchSecondSunday = nthSunday(year, 2, 2) // March, 2nd Sunday
  const novFirstSunday = nthSunday(year, 10, 1) // November, 1st Sunday

  const isDST = date >= marchSecondSunday && date < novFirstSunday
  const offset = isDST ? 4 : 5
  return (date.getUTCHours() - offset + 24) % 24
}

function nthSunday(year: number, month: number, n: number): Date {
  const date = new Date(Date.UTC(year, month, 1, 7, 0, 0)) // 7 UTC = ~2-3 AM EST
  let count = 0
  while (count < n) {
    if (date.getUTCDay() === 0) count++
    if (count < n) date.setUTCDate(date.getUTCDate() + 1)
  }
  return date
}
