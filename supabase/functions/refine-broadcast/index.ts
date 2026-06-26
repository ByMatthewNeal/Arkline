import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// refine-broadcast
// Takes a raw spoken transcript (or typed draft) and rewrites it into a
// polished, written market insight in the author's OWN first-person voice.
// It does NOT transcribe verbatim — it captures intent and tone and produces
// an editorial-quality draft the admin then edits before publishing.
//
// Auth: admin JWT required (only admins author broadcasts).
// Style learning: the author's recent published broadcasts are fed to the
// model as voice examples so the output sounds like them.

const ANTHROPIC_MODEL = "claude-haiku-4-5-20251001"

type Style = "polished" | "brief" | "takeaways"

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  // --- Auth: verify JWT ---
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return json({ error: "Missing authorization" }, 401)
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } },
  )

  const { data: { user }, error: authErr } = await supabase.auth.getUser()
  if (authErr || !user) {
    return json({ error: "Unauthorized" }, 401)
  }

  // --- Authorize: admin only ---
  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single()
  if (profile?.role !== "admin") {
    return json({ error: "Admin access required" }, 403)
  }

  // --- Parse request ---
  let transcript = ""
  let style: Style = "polished"
  let title = ""
  try {
    const parsed = await req.json()
    transcript = String(parsed.transcript ?? "").trim()
    title = String(parsed.title ?? "").trim()
    if (parsed.style === "brief" || parsed.style === "takeaways" || parsed.style === "polished") {
      style = parsed.style
    }
  } catch {
    return json({ error: "Invalid request body" }, 400)
  }

  if (!transcript) {
    return json({ error: "Nothing to refine — transcript is empty" }, 400)
  }
  if (transcript.length > 12000) {
    transcript = transcript.slice(0, 12000)
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!apiKey) {
    console.error("ANTHROPIC_API_KEY not set")
    return json({ error: "Refinement is not available right now" }, 500)
  }

  // --- Fetch the author's recent published broadcasts as voice examples ---
  // Use a service-role client so RLS doesn't hide rows.
  let voiceExamples = ""
  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )
    const { data: past } = await admin
      .from("broadcasts")
      .select("content, published_at")
      .eq("author_id", user.id)
      .eq("status", "published")
      .order("published_at", { ascending: false })
      .limit(4)

    const samples = (past ?? [])
      .map((b: { content?: string }) => (b.content ?? "").trim())
      .filter((c: string) => c.length > 40)
      .slice(0, 3)

    if (samples.length > 0) {
      voiceExamples = samples
        .map((s: string, i: number) => `Example ${i + 1}:\n${s.slice(0, 1400)}`)
        .join("\n\n---\n\n")
    }
  } catch (e) {
    console.error("Voice-example fetch failed (continuing without):", e)
  }

  // --- Build the prompt ---
  const styleDirective: Record<Style, string> = {
    polished:
      "Rewrite it as a clean, well-structured written post in the author's own first-person voice. Keep it conversational but tightened — the way they'd write it if they sat down and edited their own spoken words. Use short paragraphs. Match the LENGTH and scope of what they said: a short note stays short, a longer riff becomes a fuller post. Do not pad.",
    brief:
      "Condense it hard into a few tight sentences — the single core point and the 'so what'. First-person voice. No preamble, no filler. This should be noticeably shorter than the input.",
    takeaways:
      "Restructure it into a one or two sentence intro in the author's voice, followed by 2-5 punchy bullet points (use markdown '- '). Each bullet is one clear idea. Keep their phrasing and tone.",
  }

  const voiceBlock = voiceExamples
    ? `Here are recent posts the author has published, so you can match their voice, vocabulary, and rhythm. Mirror this style — do NOT copy their content, only their tone:\n\n${voiceExamples}\n\n`
    : ""

  const system = `You are the writing assistant for ArkLine, a crypto and macro market app. Your job is to turn a market commentator's spoken voice memo (or rough typed draft) into a polished written insight that will be published to their community.

CRITICAL RULES:
- Write in the author's OWN first-person voice. This is THEIR insight, not a report about them. Never write in third person, never refer to "the author".
- Preserve the substance exactly. Keep every specific claim, price, level, ticker, opinion, and market call they made. Their views and convictions are the whole point — never soften, hedge, or neuter them.
- NEVER invent facts, numbers, prices, levels, predictions, or events that are not in what they said. If they were vague, stay vague. Do not add data.
- Remove filler, false starts, repetition, and rambling. Fix grammar and flow. Make it read like polished writing, not a transcript.
- Keep their personality, idioms, and tone. It should sound like them on a good day, not like a generic newsletter.
- Do not add a sign-off, title, or "In conclusion". Just the refined body.
- Output plain text / light markdown only. No preamble like "Here's your refined post" — output ONLY the refined insight itself.

${voiceBlock}STYLE FOR THIS REQUEST: ${styleDirective[style]}`

  const userContent = `${title ? `Working title: ${title}\n\n` : ""}Here is what I said (raw transcript / draft):\n\n"""\n${transcript}\n"""\n\nRefine it into my published insight following the style instruction.`

  try {
    const claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: ANTHROPIC_MODEL,
        max_tokens: 1600,
        system,
        messages: [{ role: "user", content: userContent }],
      }),
    })

    if (!claudeResponse.ok) {
      const errorText = await claudeResponse.text()
      console.error(`Claude API error: ${claudeResponse.status} ${errorText}`)
      return json({ error: "Failed to refine — please try again" }, 502)
    }

    const claudeData = await claudeResponse.json()
    const refined: string = (claudeData.content?.[0]?.text ?? "").trim()

    if (!refined) {
      return json({ error: "Refinement came back empty — please try again" }, 502)
    }

    console.log(`Refined broadcast for ${user.id} (style=${style}, in=${transcript.length}, out=${refined.length})`)
    return json({ refined, style })
  } catch (e) {
    console.error("Refine request threw:", e)
    return json({ error: "Failed to refine — please try again" }, 500)
  }
})
