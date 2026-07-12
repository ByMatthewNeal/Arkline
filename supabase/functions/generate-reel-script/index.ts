import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * generate-reel-script Edge Function
 *
 * Generates a 30-45 second Instagram Reel script for the founder.
 * Pulls from curated news + market data to create a timely, camera-ready script.
 *
 * Auto-runs Mon/Wed/Fri at 8 AM ET via cron.
 * Can also be triggered manually from the admin panel.
 */

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const supabase = createClient(supabaseUrl, supabaseKey)

  // Auth: cron secret or a VERIFIED admin JWT. (Previously this only checked
  // that an Authorization header existed, relying on the gateway's verify_jwt.
  // Now that verify_jwt is off so pg_cron can reach us, the JWT must be
  // validated here — same pattern as generate-market-deck.)
  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  const secret = req.headers.get("x-cron-secret") ?? ""
  const authHeader = req.headers.get("Authorization") ?? ""
  let isAuthorized = Boolean(cronSecret) && secret === cronSecret

  if (!isAuthorized && authHeader.startsWith("Bearer ")) {
    const jwt = authHeader.replace("Bearer ", "")
    const { data: userData, error: userError } = await supabase.auth.getUser(jwt)
    if (!userError && userData?.user) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("role")
        .eq("id", userData.user.id)
        .single()
      if (profile?.role === "admin") {
        isAuthorized = true
      }
    }
  }

  if (!isAuthorized) {
    return json({ error: "Unauthorized" }, 401)
  }

  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!anthropicKey) {
    return json({ error: "ANTHROPIC_API_KEY not set" }, 500)
  }

  // Check if we should force regenerate or use a custom topic
  let forceRegenerate = false
  let topicOverride = ""
  try {
    const body = await req.json()
    forceRegenerate = body?.regenerate === true
    topicOverride = body?.topic_override?.trim() ?? ""
  } catch { /* empty body is fine */ }

  // Use ET so script_date matches Matt's day
  const today = new Date(new Date().toLocaleString("en-US", { timeZone: "America/New_York" }))
    .toISOString().split("T")[0]

  // Skip if already generated today (unless regenerating)
  if (!forceRegenerate) {
    const { data: existing } = await supabase
      .from("reel_scripts")
      .select("id")
      .eq("script_date", today)
      .maybeSingle()

    if (existing) {
      return json({ message: "Script already generated for today", id: existing.id })
    }
  }

  // ── Gather context ──────────────────────────────────────────────────────

  // 1. Recent curated news (last 24h)
  const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
  const { data: newsRows } = await supabase
    .from("curated_news")
    .select("curated_title, takeaway_1, takeaway_2, takeaway_3, source, category")
    .gte("published_at", cutoff)
    .order("relevance_score", { ascending: false })
    .limit(8)

  const newsContext = (newsRows ?? []).map((n: any) =>
    `[${n.category}] ${n.curated_title}\n  - ${n.takeaway_1}\n  - ${n.takeaway_2}\n  - ${n.takeaway_3}`
  ).join("\n\n")

  // 2. Latest positioning signals (top movers)
  const { data: signalRows } = await supabase
    .from("positioning_signals")
    .select("asset, signal, trend_score, price, prev_signal, category")
    .eq("signal_date", today)
    .order("trend_score", { ascending: false })
    .limit(20)

  const signalChanges = (signalRows ?? [])
    .filter((s: any) => s.prev_signal && s.signal !== s.prev_signal)
    .map((s: any) => `${s.asset}: ${s.prev_signal} → ${s.signal} (score: ${s.trend_score})`)
    .join("\n")

  // 3. BTC price + Fear & Greed from market cache
  const { data: btcCache } = await supabase
    .from("market_data_cache")
    .select("data")
    .eq("key", "crypto_assets_1_100")
    .maybeSingle()

  let btcPrice = ""
  if (btcCache?.data) {
    try {
      const assets = typeof btcCache.data === "string" ? JSON.parse(btcCache.data) : btcCache.data
      const btc = assets.find((a: any) => a.id === "bitcoin")
      if (btc) {
        btcPrice = `BTC: $${btc.current_price?.toLocaleString() ?? "?"} (${btc.price_change_percentage_24h?.toFixed(1) ?? "?"}% 24h)`
      }
    } catch { /* skip */ }
  }

  // 4. Day of week for framing
  const dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
  const etNow = new Date(new Date().toLocaleString("en-US", { timeZone: "America/New_York" }))
  const dayOfWeek = dayNames[etNow.getDay()]

  // ── Generate script via Claude ──────────────────────────────────────────

  const marketContext = [
    topicOverride ? `⚡ PRIORITY TOPIC (build the script around this):\n${topicOverride}` : "",
    btcPrice ? `MARKET: ${btcPrice}` : "",
    signalChanges ? `SIGNAL CHANGES TODAY:\n${signalChanges}` : "No signal changes today.",
    newsContext ? `TOP NEWS:\n${newsContext}` : "No curated news available.",
  ].filter(Boolean).join("\n\n")

  const systemPrompt = `You are a content writer for Matt, the founder of ArkLine — a crypto and macro investing app that gives users positioning signals and market insight before the crowd moves. You write 30-45 second Instagram Reel scripts (80-120 words) that Matt reads into the camera.

PURPOSE: Educate AND update. Every script should teach the viewer something — break down a concept, explain why something matters, connect dots most people miss. Use plain language anyone can understand. No jargon without explanation. If you mention a term like "positioning" or "liquidity," explain what it means in one beat.

TONE: Casual educator. Like a smart friend breaking down what's happening over coffee. Not hype, not fear — just clarity. Think "so here's what's going on" not "BREAKING NEWS." Matt is approachable, knowledgeable, and direct.

STRUCTURE — return ONLY valid JSON with these three fields:
{
  "hook": "The first sentence (3 seconds). Must stop the scroll. Ask a question, state something surprising, or call out something everyone's thinking. Examples: 'Everyone's panicking about BTC but here's what they're missing.' / 'Three things happened this week that nobody's talking about.'",
  "body": "The insight (20-35 seconds). Pick ONE topic from the market context. Explain what happened, why it matters, and what it means for the average person's money. Be specific — use numbers, names, levels. But always explain the 'so what.' Speak in short, punchy sentences. This is for speaking out loud — use contractions, pauses, natural rhythm. Weave in how ArkLine spotted this signal early or how our data showed this shift before the headlines caught up.",
  "cta": "The close (5 seconds). Soft CTA. Don't say 'like and subscribe.' Instead: 'Follow if you want to see these signals before everyone else.' / 'Link in bio — ArkLine shows you this stuff before the crowd moves.' / 'That's your edge — see you Wednesday.'"
}

RULES:
- Total script must be 80-120 words (strict)
- Pick the single most interesting/important topic — don't try to cover everything
- Write for speaking, not reading — short sentences, natural pauses
- Educate: explain WHY something matters, not just WHAT happened
- Use plain English — if your grandma wouldn't understand a word, rephrase it
- Naturally highlight how ArkLine provides early signals/insight — we saw it coming, our data flagged it, etc. Don't be salesy, just factual
- Never say "in this video" or "today I want to talk about"
- Never give financial advice or say "buy" / "sell"
- Today is ${dayOfWeek}
- Return ONLY the JSON object, no markdown, no explanation`

  try {
    const resp = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-5",
        max_tokens: 500,
        system: systemPrompt,
        messages: [{ role: "user", content: `Generate a Reel script based on today's market context:\n\n${marketContext}` }],
      }),
    })

    if (!resp.ok) {
      const errText = await resp.text()
      console.error(`Claude API error: ${resp.status} ${errText}`)
      return json({ error: "Claude API failed" }, 502)
    }

    const claudeData = await resp.json()
    const rawText = claudeData.content?.[0]?.text ?? ""

    // Parse JSON response
    let cleaned = rawText.trim()
    if (cleaned.startsWith("```")) {
      cleaned = cleaned.replace(/^```(?:json)?\s*/, "").replace(/\s*```$/, "")
    }

    let script: { hook: string; body: string; cta: string }
    try {
      script = JSON.parse(cleaned)
    } catch {
      console.error(`Failed to parse script JSON: ${rawText.substring(0, 500)}`)
      return json({ error: "Failed to parse script" }, 500)
    }

    const fullScript = `${script.hook} ${script.body} ${script.cta}`
    const wordCount = fullScript.split(/\s+/).length

    // Determine topic — custom override takes priority
    const topNews = newsRows?.[0]
    const topic = topicOverride ? "pivot" : (topNews?.category ?? "market")

    // Source headlines used
    const sourceHeadlines = (newsRows ?? []).slice(0, 3).map((n: any) => n.curated_title)

    // Upsert (handles regeneration)
    const { data: saved, error: saveErr } = await supabase
      .from("reel_scripts")
      .upsert({
        hook: script.hook,
        body: script.body,
        cta: script.cta,
        topic,
        source_headlines: sourceHeadlines,
        word_count: wordCount,
        script_date: today,
        status: "fresh",
      }, { onConflict: "script_date" })
      .select()
      .single()

    if (saveErr) {
      console.error(`Save failed: ${saveErr.message}`)
      return json({ error: "Failed to save script" }, 500)
    }

    console.log(`Reel script generated: ${wordCount} words, topic: ${topic}`)
    return json({ id: saved.id, word_count: wordCount, topic, hook: script.hook })
  } catch (err) {
    console.error(`Script generation failed: ${err}`)
    return json({ error: "Script generation failed" }, 500)
  }
})

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
