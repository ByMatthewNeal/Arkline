import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * analyze-economic-event Edge Function
 *
 * Called by sync-economic-events after an event has actual data.
 * Uses Claude API to generate a concise economic analysis.
 *
 * Expects POST body: { event_id: string }
 * Auth: x-cron-secret header (system-to-system call)
 */

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405)
  }

  const secret = req.headers.get("x-cron-secret") ?? ""
  const expectedSecret = Deno.env.get("CRON_SECRET") ?? ""
  if (!expectedSecret || secret !== expectedSecret) {
    return jsonResponse({ error: "Unauthorized" }, 401)
  }

  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!anthropicKey) {
    return jsonResponse({ error: "ANTHROPIC_API_KEY not set" }, 500)
  }

  let eventId: string
  try {
    const body = await req.json()
    eventId = body.event_id
  } catch {
    return jsonResponse({ error: "Invalid request body" }, 400)
  }

  if (!eventId) {
    return jsonResponse({ error: "Missing event_id" }, 400)
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )

  // Fetch the event
  const { data: event, error: fetchErr } = await supabase
    .from("economic_events")
    .select("*")
    .eq("id", eventId)
    .single()

  if (fetchErr || !event) {
    return jsonResponse({ error: "Event not found" }, 404)
  }

  const eventData = `
- Title: ${event.title}
- Country: ${event.country}
- Actual: ${event.actual}
- Forecast: ${event.forecast ?? "N/A"}
- Previous: ${event.previous ?? "N/A"}
- Beat/Miss: ${event.beat_miss ?? "N/A"}
- Impact: ${event.impact}
`.trim()

  try {
    const claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 500,
        system: `You are a senior macro analyst writing for crypto traders. Given an economic data release, write an insightful analysis (150-200 words) in this structure:

**Result**: One sentence on whether it beat, missed, or matched expectations and by how much.

**Market Impact**: How this data typically moves traditional markets (equities, bonds, dollar). Reference how similar prints have historically affected markets — e.g. "The last 3 times CPI came in below expectations, the S&P rallied within 48 hours."

**Crypto Angle**: What this means specifically for Bitcoin and the broader crypto market. Connect it to Fed rate expectations, liquidity conditions, and risk appetite.

**Watch Next**: Point the reader to 1-2 things to monitor now — e.g. "Watch the 10Y yield reaction and Fed speaker commentary this week for confirmation."

Write in a direct, conversational tone. No disclaimers. No hedging language like "could" or "might" — be confident and specific. Use plain English that a retail trader can understand.`,
        messages: [
          {
            role: "user",
            content: `Analyze this economic data release:\n\n${eventData}`,
          },
        ],
      }),
    })

    if (!claudeResponse.ok) {
      const errorText = await claudeResponse.text()
      console.error(`Claude API error: ${claudeResponse.status} ${errorText}`)
      return jsonResponse({ error: "Analysis generation failed" }, 502)
    }

    const claudeData = await claudeResponse.json()
    const analysis: string = claudeData.content?.[0]?.text ?? ""

    // Update the event with analysis
    const { error: updateErr } = await supabase
      .from("economic_events")
      .update({
        claude_analysis: analysis,
        analyzed_at: new Date().toISOString(),
      })
      .eq("id", eventId)

    if (updateErr) {
      console.error("Failed to save analysis:", updateErr.message)
      return jsonResponse({ error: "Failed to save analysis" }, 500)
    }

    return jsonResponse({ success: true, event_id: eventId })
  } catch (err) {
    console.error("Analysis generation failed:", String(err))
    return jsonResponse({ error: "Internal error" }, 500)
  }
})

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
