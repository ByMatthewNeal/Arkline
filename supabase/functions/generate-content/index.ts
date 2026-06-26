import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// generate-content
// The voice engine. Takes one spoken/typed note and produces content for a
// chosen platform — in the author's OWN voice. Learns that voice from their
// growing voice_notes library AND their published broadcasts.
//
// Auth: admin JWT required.
// Formats: broadcast | instagram | twitter_post | twitter_thread

const ANTHROPIC_MODEL = "claude-haiku-4-5-20251001"

type Format = "broadcast" | "instagram" | "twitter_post" | "twitter_thread"

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405)

  const authHeader = req.headers.get("Authorization")
  if (!authHeader) return json({ error: "Missing authorization" }, 401)

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } },
  )

  const { data: { user }, error: authErr } = await supabase.auth.getUser()
  if (authErr || !user) return json({ error: "Unauthorized" }, 401)

  const { data: profile } = await supabase
    .from("profiles").select("role").eq("id", user.id).single()
  if (profile?.role !== "admin") return json({ error: "Admin access required" }, 403)

  // --- Parse ---
  let transcript = ""
  let format: Format = "broadcast"
  let title = ""
  const validFormats: Format[] = ["broadcast", "instagram", "twitter_post", "twitter_thread"]
  try {
    const parsed = await req.json()
    transcript = String(parsed.transcript ?? "").trim()
    title = String(parsed.title ?? "").trim()
    if (validFormats.includes(parsed.format)) format = parsed.format
  } catch {
    return json({ error: "Invalid request body" }, 400)
  }

  if (!transcript) return json({ error: "Nothing to work with — say or type something first" }, 400)
  if (transcript.length > 12000) transcript = transcript.slice(0, 12000)

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!apiKey) {
    console.error("ANTHROPIC_API_KEY not set")
    return json({ error: "Content generation is not available right now" }, 500)
  }

  // --- Build voice examples from the library + published broadcasts ---
  let voiceExamples = ""
  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    const [notesRes, castsRes] = await Promise.all([
      admin.from("voice_notes")
        .select("transcript, created_at")
        .eq("author_id", user.id)
        .order("created_at", { ascending: false })
        .limit(6),
      admin.from("broadcasts")
        .select("content, published_at")
        .eq("author_id", user.id)
        .eq("status", "published")
        .order("published_at", { ascending: false })
        .limit(4),
    ])

    const samples: string[] = []
    for (const n of (notesRes.data ?? []) as { transcript?: string }[]) {
      const t = (n.transcript ?? "").trim()
      if (t.length > 40) samples.push(t)
    }
    for (const b of (castsRes.data ?? []) as { content?: string }[]) {
      const c = (b.content ?? "").trim()
      if (c.length > 40) samples.push(c)
    }

    const top = samples.slice(0, 5)
    if (top.length > 0) {
      voiceExamples = top
        .map((s, i) => `Example ${i + 1}:\n${s.slice(0, 1200)}`)
        .join("\n\n---\n\n")
    }
  } catch (e) {
    console.error("Voice-example fetch failed (continuing without):", e)
  }

  // --- Format directives ---
  const formatDirective: Record<Format, string> = {
    broadcast:
      "Write a polished market insight to publish to their members in-app. First person, conversational but tightened. Short paragraphs. Match the length and scope of what they said — do not pad. Light markdown is fine.",
    instagram:
      "Write an Instagram caption. Open with a strong one-line hook that stops the scroll. Then 2-4 short, punchy lines or a few sentences carrying the core idea in their voice. Friendly and direct — Instagram, not a research report. End with 3-6 relevant hashtags on their own line. Keep it well under 150 words.",
    twitter_post:
      "Write a single post for X (Twitter). It MUST be 280 characters or fewer including any cashtags. One sharp idea, their voice, no hashtag spam (0-2 cashtags/hashtags max). No 'thread' language. Make every character count.",
    twitter_thread:
      "Write a thread for X (Twitter). Start with a hook tweet that earns the open. Then break the thought into a numbered sequence. Number each tweet like '1/' '2/' etc. on its own line, each tweet under 280 characters, separated by a blank line. 3-7 tweets total. Their voice throughout. The last tweet lands the takeaway.",
  }

  const voiceBlock = voiceExamples
    ? `Here is how the author actually talks and writes — recent notes and posts of theirs. Mirror their voice, vocabulary, sentence rhythm, and personality. Do NOT copy the content, only the voice:\n\n${voiceExamples}\n\n`
    : ""

  const system = `You are the personal content voice-engine for the founder of ArkLine, a crypto and macro market app. You turn their raw spoken thoughts into ready-to-post content — but the single most important rule is that it must still sound unmistakably like THEM. You are sharpening their voice, never replacing it.

CRITICAL RULES:
- Preserve their identity and personality above all. Keep their idioms, cadence, slang, and the way they frame things. If in doubt, keep more of their original wording, not less. Better to under-polish and sound like them than over-polish and sound generic.
- First person, always. This is their content, in their voice.
- Keep every specific claim, price, level, ticker, opinion, and market call exactly as they made it. Never soften their convictions.
- NEVER invent facts, numbers, prices, predictions, or events they did not say. If they were vague, stay vague.
- Remove only filler, false starts, and rambling. Fix grammar and flow. Do not sanitize their character out.
- Output ONLY the finished content itself — no preamble, no "Here's your post", no labels, no explanation.

${voiceBlock}FORMAT FOR THIS REQUEST: ${formatDirective[format]}`

  const userContent = `${title ? `Topic: ${title}\n\n` : ""}Here is what I said:\n\n"""\n${transcript}\n"""\n\nCreate the content following the format instruction, in my voice.`

  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
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

    if (!res.ok) {
      const errorText = await res.text()
      console.error(`Claude API error: ${res.status} ${errorText}`)
      return json({ error: "Failed to generate — please try again" }, 502)
    }

    const data = await res.json()
    const content: string = (data.content?.[0]?.text ?? "").trim()
    if (!content) return json({ error: "Came back empty — please try again" }, 502)

    console.log(`Generated ${format} for ${user.id} (in=${transcript.length}, out=${content.length})`)
    return json({ content, format })
  } catch (e) {
    console.error("generate-content threw:", e)
    return json({ error: "Failed to generate — please try again" }, 500)
  }
})
