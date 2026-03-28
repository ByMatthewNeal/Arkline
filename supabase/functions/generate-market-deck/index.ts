import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * generate-market-deck Edge Function
 *
 * Compiles a 10-12 slide weekly market update deck by:
 * 1. Querying existing Supabase tables for quantitative data
 * 2. Fetching live news via Tavily Search API for editorial context
 * 3. Using Claude Sonnet to generate deep analysis slides
 *
 * Runs Saturday 15:00 UTC (10am ET) via cron, or manually by admin.
 */

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

function getWeekRange(): { monday: string; friday: string; nextMonday: string; nextFriday: string } {
  const now = new Date()
  const dayOfWeek = now.getUTCDay()
  // Find most recent completed Mon-Fri week's Friday:
  // Sat(6)→1, Sun(0)→2, Mon(1)→3, Tue(2)→4, Wed(3)→5, Thu(4)→6, Fri(5)→7 (previous Friday)
  const daysBackToFriday = dayOfWeek === 6 ? 1 : dayOfWeek === 0 ? 2 : dayOfWeek + 2
  const friday = new Date(now)
  friday.setUTCDate(now.getUTCDate() - daysBackToFriday)
  const monday = new Date(friday)
  monday.setUTCDate(friday.getUTCDate() - 4)

  const nextMonday = new Date(friday)
  nextMonday.setUTCDate(friday.getUTCDate() + 3)
  const nextFriday = new Date(nextMonday)
  nextFriday.setUTCDate(nextMonday.getUTCDate() + 4)

  return {
    monday: monday.toISOString().split("T")[0],
    friday: friday.toISOString().split("T")[0],
    nextMonday: nextMonday.toISOString().split("T")[0],
    nextFriday: nextFriday.toISOString().split("T")[0],
  }
}

interface SlidePayload {
  type: string
  title: string
  data: {
    type: string
    payload: Record<string, unknown>
  }
}

// ── Tavily Search ───────────────────────────────────────────────────────────
async function tavilySearch(query: string, apiKey: string): Promise<string[]> {
  try {
    const response = await fetch("https://api.tavily.com/search", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        api_key: apiKey,
        query,
        search_depth: "advanced",
        max_results: 5,
        include_answer: true,
        days: 7,
      }),
    })

    if (!response.ok) {
      console.error(`Tavily search failed for "${query}": ${response.status}`)
      return []
    }

    const data = await response.json()
    const results: string[] = []

    if (data.answer) results.push(data.answer)
    for (const r of data.results ?? []) {
      if (r.content) results.push(r.content)
    }
    return results
  } catch (e) {
    console.error(`Tavily search error for "${query}":`, e)
    return []
  }
}

async function gatherWebResearch(tavilyKey: string, monday: string, friday: string): Promise<Record<string, string[]>> {
  // 3 focused searches to stay fast and within free tier limits
  const searches: Record<string, string> = {
    macro: `Federal Reserve FOMC interest rates US inflation CPI GDP economic data tariffs trade policy this week ${monday} to ${friday}`,
    global: `Bank of Japan ECB central bank global liquidity M2 money supply US dollar DXY treasury yields geopolitical risk ${monday} to ${friday}`,
    crypto: `bitcoin cryptocurrency ETF regulation institutional crypto market outlook this week ${monday} to ${friday}`,
  }

  const results: Record<string, string[]> = {}
  const entries = Object.entries(searches)
  const promises = entries.map(async ([key, query]) => {
    results[key] = await tavilySearch(query, tavilyKey)
  })
  await Promise.all(promises)
  return results
}

// ── Claude Sonnet: Generate Editorial Slides ────────────────────────────────
interface EditorialSlide {
  section_title: string
  section_subtitle?: string
  analysis_title: string
  category: string
  bullets: Array<{ text: string; detail?: string }>
}

async function generateEditorialSlides(
  anthropicKey: string,
  webResearch: Record<string, string[]>,
  dbContext: string,
  monday: string,
  friday: string,
  adminInsights?: string,
  imageUrls?: string[],
  feedbackHistory?: string,
): Promise<EditorialSlide[]> {
  const researchText = Object.entries(webResearch)
    .map(([cat, items]) => `=== ${cat.toUpperCase()} ===\n${items.join("\n\n")}`)
    .join("\n\n")

  const prompt = `You are a senior financial analyst writing a weekly market update for an investing app called Arkline. The update covers ${monday} to ${friday}.

Your audience ranges from intermediate investors building their knowledge to seasoned market participants. Write with authority and specificity — include exact numbers, percentages, and dates — but always explain WHY something matters in plain language. Avoid jargon without context. If you mention a metric, briefly explain what it signals. The goal is clarity: readers should finish each bullet understanding what happened, why it matters, and how it connects to their portfolio.

CRITICAL — CONNECT EVERYTHING TO RISK ASSETS:
Every bullet point MUST tie back to how the event or data affects risk assets (crypto, equities, growth stocks). Explain the transmission mechanism — e.g. "Higher real rates compress equity valuations and reduce appetite for speculative assets like crypto" or "A weaker dollar historically supports BTC and commodity prices." Don't just state what happened — tell the reader what it means for markets, stocks, and crypto. Help them see the cause-and-effect chain so they understand how to think about positioning.

Generate 4-6 editorial analysis sections based on what was MOST significant this week. Each section should have:
- A section title (short, punchy — e.g. "Fed Holds Steady", "Tariff Shock", "Liquidity Squeeze")
- A section subtitle (one line of context)
- An analysis title (more descriptive — e.g. "FOMC Meeting Aftermath & Rate Path")
- A category (one of: "fed", "inflation", "central banks", "geopolitics", "liquidity", "crypto", "economic")
- 4-6 bullet points of analysis, each with:
  - text: The main insight (1-3 sentences). State what happened with specific numbers, then explain what it means for risk assets and markets. Write so that someone with 1-2 years of investing experience can follow, while still being substantive enough for a veteran.
  - detail: Optional one-line source attribution or additional context

IMPORTANT:
- Only create sections for topics that had MEANINGFUL developments this week
- Skip topics where nothing notable happened
- Prioritize: Fed/FOMC > major economic data > geopolitics/tariffs > international central banks > liquidity/M2 > crypto-specific themes
- Each bullet should stand alone as a valuable insight
- Use specific numbers (e.g. "CPI rose 0.2% MoM to 2.8% YoY" not "inflation rose slightly")
- Always close the loop: data point → market impact → what it means for risk assets/crypto/stocks

${adminInsights ? `\n=== ADMIN INSIGHTS (CRITICAL — integrate these) ===\n${adminInsights}\nThe admin has provided additional context from external sources. Naturally weave this into the relevant sections.\n` : ""}
${feedbackHistory ? `\n=== PAST ADMIN FEEDBACK (learn from these — avoid repeating flagged issues) ===\n${feedbackHistory}\nApply these lessons to improve the quality of your output. If the admin previously flagged issues like being too vague, lacking numbers, or not connecting to risk assets — make sure to address those patterns.\n` : ""}
=== WEB RESEARCH FROM THIS WEEK ===
${researchText}

=== APP DATA CONTEXT ===
${dbContext}

Respond ONLY with a JSON array of editorial sections. No markdown, no code blocks, just the JSON array:
[
  {
    "section_title": "...",
    "section_subtitle": "...",
    "analysis_title": "...",
    "category": "...",
    "bullets": [
      { "text": "...", "detail": "..." }
    ]
  }
]`

  // Build message content — text + optional images
  const contentParts: Array<Record<string, unknown>> = []
  if (imageUrls?.length) {
    for (const imgUrl of imageUrls.slice(0, 4)) {
      contentParts.push({
        type: "image",
        source: { type: "url", url: imgUrl },
      })
    }
  }
  contentParts.push({ type: "text", text: prompt })

  try {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 4096,
        messages: [{ role: "user", content: contentParts }],
      }),
    })

    if (!response.ok) {
      console.error("Claude editorial generation failed:", await response.text())
      return []
    }

    const data = await response.json()
    const text = data.content?.[0]?.text ?? "[]"

    // Parse JSON — strip any markdown fencing if present
    const cleaned = text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim()
    return JSON.parse(cleaned)
  } catch (e) {
    console.error("Claude editorial generation error:", e)
    return []
  }
}

// ── Claude: Generate Weekly Outlook ──────────────────────────────────────────
interface WeeklyOutlook {
  headline: string
  risk_asset_impact: string
  look_ahead: string[]
  tone: string
}

async function generateWeeklyOutlook(
  anthropicKey: string,
  dbContext: string,
  webResearchText: string,
  monday: string,
  friday: string,
  feedbackHistory?: string,
): Promise<WeeklyOutlook | null> {
  const prompt = `You are a senior financial analyst at Arkline, a crypto & investing app. Based on the week of ${monday} to ${friday}, write a concise Weekly Outlook.

This slide appears right after the cover — it's the first substantive content the user sees. It should immediately ground them in the most important narrative of the week and help them understand: what happened, how it impacts their portfolio (crypto, stocks, risk assets), and what to watch next.

Write in a direct, confident tone. Use specific numbers and percentages. Connect everything to risk assets.

=== APP DATA ===
${dbContext}

${webResearchText ? `=== WEB RESEARCH ===\n${webResearchText}` : ""}
${feedbackHistory ? `\n=== PAST ADMIN FEEDBACK (learn from these patterns) ===\n${feedbackHistory}\n` : ""}
Respond ONLY with a JSON object (no markdown, no code blocks):
{
  "headline": "One punchy sentence summarizing the week's thesis for risk assets (max 15 words)",
  "risk_asset_impact": "2-3 sentences explaining how this week's developments affect crypto, equities, and risk assets. Be specific about transmission mechanisms.",
  "look_ahead": ["3-5 bullet points of what to watch in the coming week(s) — economic events, technical levels, catalysts, risks"],
  "tone": "bullish" | "bearish" | "cautious" | "neutral"
}`

  try {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 1024,
        messages: [{ role: "user", content: prompt }],
      }),
    })

    if (!response.ok) {
      console.error("Claude weekly outlook failed:", await response.text())
      return null
    }

    const data = await response.json()
    const text = data.content?.[0]?.text ?? ""
    const cleaned = text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim()
    return JSON.parse(cleaned)
  } catch (e) {
    console.error("Weekly outlook generation error:", e)
    return null
  }
}

// ── Process Admin Attachments ────────────────────────────────────────────────
interface Attachment {
  type: "image" | "pdf" | "url"
  storage_path?: string
  url?: string
  label?: string
  extracted_text?: string
}

async function processAttachments(
  attachments: Attachment[],
  supabaseUrl: string,
  supabaseKey: string
): Promise<{ textContext: string; imageUrls: string[] }> {
  const textParts: string[] = []
  const imageUrls: string[] = []

  for (const att of attachments) {
    if (att.type === "pdf" && att.extracted_text) {
      textParts.push(`=== PDF: ${att.label ?? "Document"} ===\n${att.extracted_text}`)
    } else if (att.type === "url" && att.url) {
      try {
        const resp = await fetch(att.url, {
          headers: { "User-Agent": "Arkline-Bot/1.0" },
          signal: AbortSignal.timeout(10000),
        })
        if (resp.ok) {
          const html = await resp.text()
          // Strip HTML tags, keep text content (rough extraction)
          const text = html
            .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "")
            .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, "")
            .replace(/<[^>]+>/g, " ")
            .replace(/\s+/g, " ")
            .trim()
            .slice(0, 5000)
          if (text.length > 100) {
            textParts.push(`=== URL: ${att.label ?? att.url} ===\n${text}`)
          }
        }
      } catch (e) {
        console.error(`Failed to fetch URL ${att.url}:`, e)
      }
    } else if (att.type === "image" && att.storage_path) {
      // Generate a signed URL for the image so Claude can see it
      const supabase = createClient(supabaseUrl, supabaseKey)
      const { data } = await supabase.storage
        .from("deck-attachments")
        .createSignedUrl(att.storage_path, 3600)
      if (data?.signedUrl) {
        imageUrls.push(data.signedUrl)
      }
    }
  }

  return { textContext: textParts.join("\n\n"), imageUrls }
}

// ── Claude: Generate Rundown Narrative ──────────────────────────────────────
async function generateRundownNarrative(
  anthropicKey: string,
  briefings: Array<{ summary_date: string; summary_text: string }>,
  editorialContext: string,
  monday: string,
  friday: string,
  adminInsights?: string,
  imageUrls?: string[]
): Promise<string> {
  const briefingTexts = briefings
    .map((b) => `### ${b.summary_date}\n${b.summary_text}`)
    .join("\n\n")

  const promptText = `You are a concise financial market analyst writing the weekly wrap-up for Arkline, an investing app. Week: ${monday} to ${friday}.

Synthesize everything into a polished weekly narrative — 3-4 paragraphs covering:
1. The dominant theme of the week and key market moves — what drove price action and sentiment
2. Macro/policy developments and how they ripple into risk assets (equities, crypto, growth stocks)
3. Crypto-specific highlights, positioning shifts, and what traditional market moves mean for digital assets
4. Forward-looking outlook: what to watch next week and how it could affect portfolios

Write with authority and specificity. Use exact numbers. No hedging or filler.

TONE: Confident but accessible. A reader with 1-2 years of investing experience should understand every sentence, while a veteran should find it substantive. When mentioning macro data or policy moves, always connect the dots to what it means for risk assets and markets. Don't just report — explain the "so what" so readers walk away with clarity on how the week's events shape their positioning.

${adminInsights ? `\n=== ADMIN INSIGHTS & ATTACHMENT CONTEXT (weave naturally into narrative) ===\n${adminInsights}\n` : ""}
${imageUrls?.length ? `\nThe admin has also attached ${imageUrls.length} image(s) with charts/data. Analyze them and incorporate relevant findings into the narrative.\n` : ""}

=== DAILY BRIEFINGS ===
${briefingTexts || "No daily briefings available."}

=== EDITORIAL CONTEXT FROM THIS WEEK'S SLIDES ===
${editorialContext}`

  // Build message content — text + optional images for multimodal
  const contentParts: Array<Record<string, unknown>> = []

  // Add images first if present
  if (imageUrls?.length) {
    for (const imgUrl of imageUrls.slice(0, 4)) {
      contentParts.push({
        type: "image",
        source: { type: "url", url: imgUrl },
      })
    }
  }

  contentParts.push({ type: "text", text: promptText })

  try {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 1500,
        messages: [{ role: "user", content: contentParts }],
      }),
    })

    if (response.ok) {
      const data = await response.json()
      return data.content?.[0]?.text ?? "Weekly narrative unavailable."
    }
    console.error("Narrative generation failed:", await response.text())
    return "Weekly narrative unavailable."
  } catch (e) {
    console.error("Narrative generation error:", e)
    return "Weekly narrative unavailable."
  }
}

// ── Main Handler ────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  const url = new URL(req.url)
  const isManual = url.searchParams.get("manual") === "true"
  const isRegenerateNarrative = url.searchParams.get("regenerate_narrative") === "true"
  const deckId = url.searchParams.get("deck_id") ?? ""
  const adminInsights = url.searchParams.get("admin_insights") ?? ""

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const supabase = createClient(supabaseUrl, supabaseKey)

  if (isManual) {
    // Verify admin JWT for manual triggers
    const authHeader = req.headers.get("Authorization")
    if (!authHeader) {
      return jsonResponse({ error: "Authorization header required" }, 401)
    }
    const token = authHeader.replace("Bearer ", "")
    const { data: { user }, error: authError } = await supabase.auth.getUser(token)
    if (authError || !user) {
      return jsonResponse({ error: "Invalid or expired token" }, 401)
    }
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single()
    if (profile?.role !== "admin") {
      return jsonResponse({ error: "Admin access required" }, 403)
    }
  } else {
    // Verify cron secret for automated triggers
    const secret = req.headers.get("x-cron-secret") ?? ""
    const expectedSecret = Deno.env.get("CRON_SECRET") ?? ""
    if (!expectedSecret || secret !== expectedSecret) {
      return jsonResponse({ error: "Unauthorized" }, 401)
    }
  }
  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY") ?? ""
  const tavilyKey = Deno.env.get("TAVILY_API_KEY") ?? ""

  // ── Narrative-only regeneration path ──────────────────────────────────
  if (isRegenerateNarrative && deckId) {
    console.log(`Regenerating narrative for deck ${deckId}`)
    try {
      const { data: existingDeck, error: fetchErr } = await supabase
        .from("market_update_decks")
        .select("*")
        .eq("id", deckId)
        .single()

      if (fetchErr || !existingDeck) {
        return jsonResponse({ error: `Deck not found: ${fetchErr?.message}` }, 404)
      }

      const slides = existingDeck.slides ?? []
      // Build context from editorial slides
      const editorialContext = slides
        .filter((s: SlidePayload) => s.type === "editorial")
        .map((s: SlidePayload) => {
          const bullets = (s.data?.payload?.bullets as Array<{ text: string }>) ?? []
          return `${s.title}:\n${bullets.map((b) => `- ${b.text}`).join("\n")}`
        })
        .join("\n\n")

      const { data: briefings } = await supabase
        .from("market_summaries")
        .select("summary_text, summary_date")
        .gte("summary_date", existingDeck.week_start)
        .lte("summary_date", existingDeck.week_end)
        .order("summary_date", { ascending: true })
        .limit(10)

      // Process admin attachments if present
      let attachmentContext = ""
      let attachmentImageUrls: string[] = []
      const adminContext = existingDeck.admin_context
      if (adminContext?.attachments?.length) {
        console.log(`Processing ${adminContext.attachments.length} admin attachments...`)
        const processed = await processAttachments(
          adminContext.attachments,
          supabaseUrl,
          supabaseKey
        )
        attachmentContext = processed.textContext
        attachmentImageUrls = processed.imageUrls
      }

      const fullInsights = [
        adminInsights,
        attachmentContext,
      ].filter(Boolean).join("\n\n")

      const narrative = anthropicKey
        ? await generateRundownNarrative(
            anthropicKey,
            briefings ?? [],
            editorialContext,
            existingDeck.week_start,
            existingDeck.week_end,
            fullInsights || undefined,
            attachmentImageUrls
          )
        : "Narrative generation requires an API key."

      const updatedSlides = slides.map((s: SlidePayload) => {
        if (s.type === "rundown") {
          return { ...s, data: { type: "rundown", payload: { narrative } } }
        }
        return s
      })

      const { data: updatedDeck, error: updateErr } = await supabase
        .from("market_update_decks")
        .update({ slides: updatedSlides, updated_at: new Date().toISOString() })
        .eq("id", deckId)
        .select()
        .single()

      if (updateErr) return jsonResponse({ error: updateErr.message }, 500)
      return jsonResponse(updatedDeck)
    } catch (e) {
      console.error("regenerate-narrative error:", e)
      return jsonResponse({ error: String(e) }, 500)
    }
  }

  // ── Single-slide regeneration path ────────────────────────────────────
  const isRegenerateSlide = url.searchParams.get("regenerate_slide") === "true"
  const slideType = url.searchParams.get("slide_type") ?? ""
  const slideFeedback = url.searchParams.get("slide_feedback") ?? ""
  const slideIndexParam = url.searchParams.get("slide_index")

  if (isRegenerateSlide && deckId && slideType) {
    console.log(`Regenerating slide "${slideType}" for deck ${deckId} with feedback: ${slideFeedback}`)
    try {
      const { data: existingDeck, error: fetchErr } = await supabase
        .from("market_update_decks")
        .select("*")
        .eq("id", deckId)
        .single()

      if (fetchErr || !existingDeck) {
        return jsonResponse({ error: `Deck not found: ${fetchErr?.message}` }, 404)
      }

      if (!anthropicKey) {
        return jsonResponse({ error: "ANTHROPIC_API_KEY required for regeneration" }, 500)
      }

      const slides = existingDeck.slides ?? []
      const monday = existingDeck.week_start
      const friday = existingDeck.week_end

      // Build context from all existing slides for coherence
      const slideContext = slides
        .map((s: SlidePayload) => {
          if (s.type === "editorial") {
            const bullets = (s.data?.payload?.bullets as Array<{ text: string }>) ?? []
            return `[${s.type}] ${s.title}: ${bullets.map((b) => b.text).join("; ")}`
          }
          if (s.type === "weeklyOutlook") {
            const p = s.data?.payload as Record<string, unknown>
            return `[weeklyOutlook] ${p?.headline ?? ""} — ${p?.risk_asset_impact ?? ""}`
          }
          return `[${s.type}] ${s.title}`
        })
        .join("\n")

      // Fetch recent feedback history for learning context
      const { data: recentFeedback } = await supabase
        .from("deck_slide_feedback")
        .select("slide_type, rating, feedback")
        .eq("rating", false)
        .not("feedback", "is", null)
        .order("created_at", { ascending: false })
        .limit(20)

      const feedbackHistory = (recentFeedback ?? [])
        .filter((f: { slide_type: string }) => f.slide_type === slideType || f.slide_type.includes("editorial"))
        .map((f: { slide_type: string; feedback: string }) => `- [${f.slide_type}]: ${f.feedback}`)
        .join("\n")

      // Find the current slide to regenerate
      // Use slide_index if provided to target a specific slide (especially for editorials where there are multiple)
      const slideIndex = slideIndexParam != null ? parseInt(slideIndexParam, 10) : null
      const currentSlide = slideIndex != null && slideIndex >= 0 && slideIndex < slides.length
        ? slides[slideIndex]
        : slides.find((s: SlidePayload) => s.type === slideType)

      if (!currentSlide) {
        return jsonResponse({ error: `Slide type "${slideType}" not found in deck` }, 404)
      }

      let regeneratedSlide: SlidePayload | null = null

      if (slideType === "editorial" || slideType === "sectionTitle") {
        // Regenerate a specific editorial slide
        const currentBullets = (currentSlide.data?.payload?.bullets as Array<{ text: string; detail?: string }>) ?? []
        const currentCategory = (currentSlide.data?.payload as Record<string, unknown>)?.category ?? "general"

        const prompt = `You are a senior financial analyst rewriting a single editorial slide for Arkline's weekly market update (${monday} to ${friday}).

The admin reviewed this slide and wants it improved. Here is their specific feedback:
"${slideFeedback}"

${feedbackHistory ? `\nPast admin feedback on similar slides (learn from these patterns):\n${feedbackHistory}\n` : ""}

CURRENT SLIDE TITLE: ${currentSlide.title}
CURRENT CATEGORY: ${currentCategory}
CURRENT CONTENT:
${currentBullets.map((b) => `- ${b.text}${b.detail ? ` (${b.detail})` : ""}`).join("\n")}

CONTEXT FROM OTHER SLIDES IN THIS DECK:
${slideContext}

Rewrite this slide following the admin's feedback. Keep the same category. Write with authority — use specific numbers, dates, percentages. Connect everything to risk assets.

Respond ONLY with a JSON object (no markdown):
{
  "analysis_title": "...",
  "category": "${currentCategory}",
  "bullets": [
    { "text": "...", "detail": "..." }
  ]
}`

        const response = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": anthropicKey,
            "anthropic-version": "2023-06-01",
          },
          body: JSON.stringify({
            model: "claude-sonnet-4-20250514",
            max_tokens: 2048,
            messages: [{ role: "user", content: prompt }],
          }),
        })

        if (!response.ok) {
          const errText = await response.text()
          console.error("Claude slide regen failed:", errText)
          return jsonResponse({ error: "AI generation failed" }, 500)
        }

        const data = await response.json()
        const text = data.content?.[0]?.text ?? "{}"
        const cleaned = text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim()
        const result = JSON.parse(cleaned)

        regeneratedSlide = {
          type: "editorial",
          title: result.analysis_title || currentSlide.title,
          data: {
            type: "editorial",
            payload: {
              bullets: result.bullets,
              category: result.category || currentCategory,
            },
          },
        }
      } else if (slideType === "weeklyOutlook") {
        // Regenerate weekly outlook
        const currentPayload = currentSlide.data?.payload as Record<string, unknown>

        const prompt = `You are a senior financial analyst rewriting the Weekly Outlook slide for Arkline's weekly market update (${monday} to ${friday}).

The admin reviewed this slide and wants it improved. Their feedback:
"${slideFeedback}"

${feedbackHistory ? `\nPast admin feedback on outlook slides:\n${feedbackHistory}\n` : ""}

CURRENT CONTENT:
Headline: ${currentPayload?.headline ?? ""}
Risk Asset Impact: ${currentPayload?.risk_asset_impact ?? ""}
Look Ahead: ${JSON.stringify(currentPayload?.look_ahead ?? [])}
Tone: ${currentPayload?.tone ?? "neutral"}

CONTEXT FROM OTHER SLIDES:
${slideContext}

Rewrite following the admin's feedback. Be specific with numbers/levels. Connect to risk assets.

Respond ONLY with JSON (no markdown):
{
  "headline": "One punchy sentence (max 15 words)",
  "risk_asset_impact": "2-3 sentences on how this week affects crypto/equities/risk assets",
  "look_ahead": ["3-5 bullet points of what to watch"],
  "tone": "bullish" | "bearish" | "cautious" | "neutral"
}`

        const response = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": anthropicKey,
            "anthropic-version": "2023-06-01",
          },
          body: JSON.stringify({
            model: "claude-sonnet-4-20250514",
            max_tokens: 1024,
            messages: [{ role: "user", content: prompt }],
          }),
        })

        if (!response.ok) {
          return jsonResponse({ error: "AI generation failed" }, 500)
        }

        const data = await response.json()
        const text = data.content?.[0]?.text ?? "{}"
        const cleaned = text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim()
        const result = JSON.parse(cleaned)

        regeneratedSlide = {
          type: "weeklyOutlook",
          title: "Weekly Outlook",
          data: { type: "weeklyOutlook", payload: result },
        }
      } else if (slideType === "cover") {
        // Cover: admin might want regime label or framing changed
        const currentPayload = currentSlide.data?.payload as Record<string, unknown>
        // For cover, we just note the feedback — can't regenerate data, but can adjust regime
        const prompt = `The admin wants to adjust the cover slide of a weekly market update (${monday} to ${friday}).

Their feedback: "${slideFeedback}"

Current cover data:
- Regime: ${currentPayload?.regime}
- BTC weekly change: ${currentPayload?.btc_weekly_change}%
- Fear & Greed: ${currentPayload?.fear_greed_end}

Based on the feedback, what should the regime label be? Options: "Risk-On", "Risk-Off", "Mixed"

Respond ONLY with JSON: { "regime": "..." }`

        const response = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": anthropicKey,
            "anthropic-version": "2023-06-01",
          },
          body: JSON.stringify({
            model: "claude-sonnet-4-20250514",
            max_tokens: 256,
            messages: [{ role: "user", content: prompt }],
          }),
        })

        if (response.ok) {
          const data = await response.json()
          const text = data.content?.[0]?.text ?? "{}"
          const cleaned = text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim()
          const result = JSON.parse(cleaned)

          regeneratedSlide = {
            ...currentSlide,
            data: {
              type: "cover",
              payload: { ...currentPayload, regime: result.regime || currentPayload?.regime },
            },
          }
        }
      }

      if (!regeneratedSlide) {
        return jsonResponse({ error: `Slide type "${slideType}" cannot be regenerated` }, 400)
      }

      // Replace the slide in the deck
      const updatedSlides = slides.map((s: SlidePayload, i: number) => {
        // Use index if provided for precise targeting, otherwise match by type + title
        if (slideIndex != null) {
          return i === slideIndex ? regeneratedSlide : s
        }
        if (s.type === currentSlide.type && s.title === currentSlide.title) {
          return regeneratedSlide
        }
        return s
      })

      const { data: updatedDeck, error: updateErr } = await supabase
        .from("market_update_decks")
        .update({ slides: updatedSlides, updated_at: new Date().toISOString() })
        .eq("id", deckId)
        .select()
        .single()

      if (updateErr) return jsonResponse({ error: updateErr.message }, 500)
      console.log(`Slide "${slideType}" regenerated successfully`)
      return jsonResponse(updatedDeck)
    } catch (e) {
      console.error("regenerate-slide error:", e)
      return jsonResponse({ error: String(e) }, 500)
    }
  }

  // ── Full deck generation ──────────────────────────────────────────────
  // Support custom week range via query params (for generating past weeks)
  const customWeekStart = url.searchParams.get("week_start")
  const customWeekEnd = url.searchParams.get("week_end")

  let monday: string, friday: string, nextMonday: string, nextFriday: string

  if (customWeekStart && customWeekEnd) {
    monday = customWeekStart
    friday = customWeekEnd
    // Calculate next week from custom friday
    const customFri = new Date(customWeekEnd + "T00:00:00Z")
    const nMon = new Date(customFri)
    nMon.setUTCDate(customFri.getUTCDate() + 3)
    const nFri = new Date(nMon)
    nFri.setUTCDate(nMon.getUTCDate() + 4)
    nextMonday = nMon.toISOString().split("T")[0]
    nextFriday = nFri.toISOString().split("T")[0]
  } else {
    ({ monday, friday, nextMonday, nextFriday } = getWeekRange())
  }

  console.log(`Generating market deck for ${monday} to ${friday}`)

  const slides: SlidePayload[] = []

  try {
    // ── Step 1: Gather ALL data from Supabase in parallel ─────────────

    const TOP_ASSETS = ["BTC", "ETH", "SOL", "BNB", "SUI", "XRP", "LINK", "AVAX"]

    // Fire all DB queries at once
    const [
      { data: latestSignals },
      { data: mondaySignals },
      { data: fgEndData },
      { data: fgWeekData },
      { data: mondayPrices },
      { data: fridayPrices },
      { data: weekSparklines },
      { data: signalChanges },
      { data: thisWeekEvents },
      { data: nextWeekEvents },
      { data: weekSignals },
      { data: briefings },
    ] = await Promise.all([
      // Latest signals: get the most recent day's 54 signals within the week range
      supabase.from("positioning_signals").select("asset, signal, trend_score, price, category").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(54),
      // BTC open price: earliest available day in the week (not necessarily Monday)
      supabase.from("positioning_signals").select("asset, price").gte("signal_date", monday).lte("signal_date", friday).eq("asset", "BTC").order("signal_date", { ascending: true }).limit(1),
      supabase.from("fear_greed_history").select("value").gte("date", monday).lte("date", friday).order("date", { ascending: false }).limit(1),
      supabase.from("fear_greed_history").select("value").gte("date", monday).lte("date", friday).order("date", { ascending: true }),
      // Open prices: earliest available day per asset (falls back from Monday if data starts mid-week)
      supabase.from("positioning_signals").select("asset, price, signal_date").gte("signal_date", monday).lte("signal_date", friday).in("asset", TOP_ASSETS).order("signal_date", { ascending: true }).limit(80),
      // Close prices: latest available day per asset
      supabase.from("positioning_signals").select("asset, price, signal_date").gte("signal_date", monday).lte("signal_date", friday).in("asset", TOP_ASSETS).order("signal_date", { ascending: false }).limit(80),
      supabase.from("positioning_signals").select("asset, price, signal_date").gte("signal_date", monday).lte("signal_date", friday).in("asset", TOP_ASSETS).order("signal_date", { ascending: true }),
      supabase.from("positioning_signals").select("asset, category, signal, prev_signal, signal_date").gte("signal_date", monday).lte("signal_date", friday).not("prev_signal", "is", null).order("signal_date", { ascending: false }),
      supabase.from("economic_events").select("title, event_date, actual, forecast, impact").gte("event_date", monday).lte("event_date", friday).in("impact", ["high", "medium"]).order("event_date", { ascending: true }).limit(15),
      supabase.from("economic_events").select("title, event_date, forecast, impact").gte("event_date", nextMonday).lte("event_date", nextFriday).in("impact", ["high", "medium"]).order("event_date", { ascending: true }).limit(10),
      supabase.from("trade_signals").select("asset, direction, entry_price, status, outcome_pnl, timeframe").gte("created_at", `${monday}T00:00:00Z`).lte("created_at", `${friday}T23:59:59Z`).eq("timeframe", "4h").order("created_at", { ascending: false }).limit(20),
      supabase.from("market_summaries").select("summary_text, summary_date").gte("summary_date", monday).lte("summary_date", friday).order("summary_date", { ascending: true }).limit(10),
    ])

    // Also fetch VIX/DXY + cross-market assets in parallel
    const CROSS_MARKET_ASSETS = ["VIX", "DXY", "TLT", "GOLD", "SILVER", "OIL", "COPPER", "SPY", "QQQ", "DIA", "IWM"]
    const [
      { data: vixMon }, { data: vixFri }, { data: dxyMon }, { data: dxyFri },
      { data: crossMonday }, { data: crossLatest },
    ] = await Promise.all([
      // VIX/DXY: earliest available as open, latest as close
      supabase.from("positioning_signals").select("price").eq("asset", "VIX").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: true }).limit(1),
      supabase.from("positioning_signals").select("price").eq("asset", "VIX").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(1),
      supabase.from("positioning_signals").select("price").eq("asset", "DXY").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: true }).limit(1),
      supabase.from("positioning_signals").select("price").eq("asset", "DXY").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(1),
      // Cross-market open prices: earliest available per asset
      supabase.from("positioning_signals").select("asset, price").gte("signal_date", monday).lte("signal_date", friday).in("asset", CROSS_MARKET_ASSETS).order("signal_date", { ascending: true }).limit(55),
      // Fetch up to 5 days * 11 assets = 55 rows, then deduplicate per asset (takes most recent)
      supabase.from("positioning_signals").select("asset, price, signal, signal_date").in("asset", CROSS_MARKET_ASSETS).gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(55),
    ])

    // Process Cover data
    const btcSignal = latestSignals?.find((s: { asset: string }) => s.asset === "BTC")
    const btcPrice = btcSignal?.price ?? null
    const btcMonday = mondaySignals?.[0]?.price ?? null
    const btcWeeklyChange = btcPrice != null && btcMonday != null ? ((btcPrice - btcMonday) / btcMonday) * 100 : null

    const bullishCount = latestSignals?.filter((s: { signal: string }) => s.signal === "bullish").length ?? 0
    const bearishCount = latestSignals?.filter((s: { signal: string }) => s.signal === "bearish").length ?? 0
    const regime = bullishCount > bearishCount * 1.5 ? "Risk-On" : bearishCount > bullishCount * 1.5 ? "Risk-Off" : "Mixed"

    // Fear & Greed from historical table (date-bounded to the week)
    const fearGreedEnd: number | null = fgEndData?.[0]?.value ?? null
    const fearGreedStart: number | null = fgWeekData?.[0]?.value ?? null

    // Process Market Pulse data — deduplicate to earliest (open) and latest (close) per asset
    const mondayMap = new Map<string, number>()
    for (const r of (mondayPrices ?? []) as { asset: string; price: number }[]) {
      if (!mondayMap.has(r.asset)) mondayMap.set(r.asset, r.price)  // first = earliest (asc order)
    }
    const fridayMap = new Map<string, number>()
    for (const r of (fridayPrices ?? []) as { asset: string; price: number }[]) {
      if (!fridayMap.has(r.asset)) fridayMap.set(r.asset, r.price)  // first = latest (desc order)
    }

    const assetData = TOP_ASSETS.map((ticker) => {
      const weekOpen = mondayMap.get(ticker) ?? null
      const weekClose = fridayMap.get(ticker) ?? latestSignals?.find((s: { asset: string }) => s.asset === ticker)?.price ?? null
      const sparkline = (weekSparklines ?? []).filter((s: { asset: string }) => s.asset === ticker).map((s: { price: number }) => s.price)
      return {
        symbol: ticker, name: ticker, week_open: weekOpen, week_close: weekClose,
        week_change: weekOpen != null && weekClose != null ? Math.round(((weekClose - weekOpen) / weekOpen) * 10000) / 100 : 0,
        sparkline,
      }
    })

    // Process Macro data
    const macroData: Record<string, { value: number | null; change: number | null }> = {
      VIX: {
        value: vixFri?.[0]?.price ?? null,
        change: vixMon?.[0]?.price != null && vixFri?.[0]?.price != null ? Math.round(((vixFri[0].price - vixMon[0].price) / vixMon[0].price) * 10000) / 100 : null,
      },
      DXY: {
        value: dxyFri?.[0]?.price ?? null,
        change: dxyMon?.[0]?.price != null && dxyFri?.[0]?.price != null ? Math.round(((dxyFri[0].price - dxyMon[0].price) / dxyMon[0].price) * 10000) / 100 : null,
      },
    }

    // Process signal changes
    const actualChanges = (signalChanges ?? []).filter(
      (s: { signal: string; prev_signal: string | null }) => s.prev_signal && s.signal !== s.prev_signal
    )

    // Distribution from latest signals
    const catCounts: Record<string, { bullish: number; neutral: number; bearish: number }> = {}
    for (const s of latestSignals ?? []) {
      const cat = s.category ?? "crypto"
      if (!catCounts[cat]) catCounts[cat] = { bullish: 0, neutral: 0, bearish: 0 }
      if (s.signal === "bullish") catCounts[cat].bullish++
      else if (s.signal === "bearish") catCounts[cat].bearish++
      else catCounts[cat].neutral++
    }

    // Process trade signals
    const triggered = weekSignals?.length ?? 0
    const resolved = weekSignals?.filter((s: { status: string }) => ["won", "lost", "stopped"].includes(s.status)).length ?? 0
    const wins = weekSignals?.filter((s: { status: string }) => s.status === "won").length ?? 0
    const winRate = resolved > 0 ? (wins / resolved) * 100 : null
    const pnls = weekSignals?.filter((s: { outcome_pnl: number | null }) => s.outcome_pnl != null).map((s: { outcome_pnl: number }) => s.outcome_pnl) ?? []
    const avgPnl = pnls.length > 0 ? pnls.reduce((a: number, b: number) => a + b, 0) / pnls.length : null

    // ── Step 2: Web research via Tavily ─────────────────────────────────
    let webResearch: Record<string, string[]> = {}
    if (tavilyKey) {
      console.log("Fetching web research via Tavily...")
      webResearch = await gatherWebResearch(tavilyKey, monday, friday)
      console.log(`Web research complete: ${Object.values(webResearch).flat().length} results`)
    } else {
      console.log("No TAVILY_API_KEY — skipping web research")
    }

    // ── Step 3: Generate editorial slides via Claude Sonnet ─────────────
    const dbContext = [
      `Market regime: ${regime}. BTC: $${btcPrice?.toLocaleString() ?? "N/A"} (${btcWeeklyChange ? btcWeeklyChange.toFixed(1) + "%" : "N/A"} weekly).`,
      `Fear & Greed: ${fearGreedEnd ?? "N/A"}.`,
      `VIX: ${macroData["VIX"]?.value ?? "N/A"} (${macroData["VIX"]?.change ?? "N/A"}% weekly). DXY: ${macroData["DXY"]?.value ?? "N/A"} (${macroData["DXY"]?.change ?? "N/A"}% weekly).`,
      `Signal distribution: ${Object.entries(catCounts).map(([c, d]) => `${c}: ${d.bullish}B/${d.neutral}N/${d.bearish}Be`).join(", ")}`,
      `Signal changes this week: ${actualChanges.slice(0, 10).map((s: Record<string, string>) => `${s.asset}: ${s.prev_signal}→${s.signal}`).join(", ")}`,
      `Trade signals: ${triggered} triggered, ${resolved} resolved, ${winRate ? winRate.toFixed(0) + "% WR" : "N/A"}, ${avgPnl ? avgPnl.toFixed(1) + "% avg P&L" : "N/A"}`,
      `Economic events this week: ${(thisWeekEvents ?? []).map((e: Record<string, string>) => e.title).join(", ")}`,
    ].join("\n")

    // ── Fetch past slide feedback for learning context ──────────────
    let feedbackContext = ""
    try {
      const { data: recentFeedback } = await supabase
        .from("deck_slide_feedback")
        .select("slide_type, rating, feedback")
        .eq("rating", false)
        .not("feedback", "is", null)
        .order("created_at", { ascending: false })
        .limit(30)

      if (recentFeedback?.length) {
        const editorialFb = recentFeedback
          .filter((f: { slide_type: string }) => f.slide_type === "editorial" || f.slide_type === "sectionTitle")
          .map((f: { feedback: string }) => `- ${f.feedback}`)
          .join("\n")
        const outlookFb = recentFeedback
          .filter((f: { slide_type: string }) => f.slide_type === "weeklyOutlook")
          .map((f: { feedback: string }) => `- ${f.feedback}`)
          .join("\n")
        const generalFb = recentFeedback
          .filter((f: { slide_type: string }) => !["editorial", "sectionTitle", "weeklyOutlook"].includes(f.slide_type))
          .map((f: { slide_type: string; feedback: string }) => `- [${f.slide_type}]: ${f.feedback}`)
          .join("\n")

        feedbackContext = [
          editorialFb ? `Editorial feedback:\n${editorialFb}` : "",
          outlookFb ? `Outlook feedback:\n${outlookFb}` : "",
          generalFb ? `General feedback:\n${generalFb}` : "",
        ].filter(Boolean).join("\n\n")

        console.log(`Loaded ${recentFeedback.length} past feedback items for learning context`)
      }
    } catch (e) {
      console.error("Failed to fetch feedback history (non-fatal):", e)
    }

    let editorialSlides: EditorialSlide[] = []
    let weeklyOutlook: WeeklyOutlook | null = null
    if (anthropicKey) {
      const hasWebResearch = Object.values(webResearch).flat().length > 0
      const hasBriefings = (briefings?.length ?? 0) > 0
      console.log(`Generating editorial + outlook via Claude Sonnet (web: ${hasWebResearch}, briefings: ${hasBriefings})...`)

      const researchText = Object.entries(webResearch)
        .map(([cat, items]) => `=== ${cat.toUpperCase()} ===\n${items.join("\n\n")}`)
        .join("\n\n")

      // Generate editorials and weekly outlook in parallel
      const [editorials, outlook] = await Promise.all([
        generateEditorialSlides(
          anthropicKey, webResearch, dbContext, monday, friday, adminInsights || undefined, undefined, feedbackContext || undefined
        ),
        generateWeeklyOutlook(anthropicKey, dbContext, researchText, monday, friday, feedbackContext || undefined),
      ])
      editorialSlides = editorials
      weeklyOutlook = outlook
      console.log(`Generated ${editorialSlides.length} editorial sections, outlook: ${outlook ? "yes" : "no"}`)
    } else {
      console.log("No ANTHROPIC_API_KEY — skipping editorial + outlook generation")
    }

    // ── Step 4: Assemble slides ─────────────────────────────────────────

    // 1. Cover
    slides.push({
      type: "cover",
      title: "Cover",
      data: {
        type: "cover",
        payload: {
          regime,
          fear_greed_start: fearGreedStart,
          fear_greed_end: fearGreedEnd,
          btc_weekly_change: btcWeeklyChange != null ? Math.round(btcWeeklyChange * 100) / 100 : null,
          btc_price: btcPrice,
        },
      },
    })

    // 2. Weekly Outlook (AI-generated)
    if (weeklyOutlook) {
      slides.push({
        type: "weeklyOutlook",
        title: "Weekly Outlook",
        data: {
          type: "weeklyOutlook",
          payload: weeklyOutlook,
        },
      })
    }

    // 3. Cross-Market Correlation (data-driven)
    // Deduplicate to earliest per asset (results ordered asc, first entry = earliest)
    const crossMondayMap = new Map<string, number>()
    for (const r of (crossMonday ?? []) as { asset: string; price: number }[]) {
      if (!crossMondayMap.has(r.asset)) crossMondayMap.set(r.asset, r.price)
    }
    // Deduplicate: keep only the most recent entry per asset (results are ordered desc by date)
    const crossLatestMap = new Map<string, { asset: string; price: number; signal: string }>()
    for (const r of (crossLatest ?? []) as { asset: string; price: number; signal: string }[]) {
      if (!crossLatestMap.has(r.asset)) {
        crossLatestMap.set(r.asset, r)
      }
    }

    function buildCorrelationAsset(symbol: string): { symbol: string; week_change: number | null; signal: string | null; price: number | null } {
      const monPrice = crossMondayMap.get(symbol) ?? null
      const latest = crossLatestMap.get(symbol)
      const latPrice = latest?.price ?? null
      const change = monPrice != null && latPrice != null ? Math.round(((latPrice - monPrice) / monPrice) * 10000) / 100 : null
      return { symbol, week_change: change, signal: latest?.signal ?? null, price: latPrice }
    }

    // Also pull crypto from already-computed assetData
    const cryptoCorrelation = ["BTC", "ETH", "SOL", "BNB"].map((sym) => {
      const asset = assetData.find((a: { symbol: string }) => a.symbol === sym)
      const sig = latestSignals?.find((s: { asset: string }) => s.asset === sym)
      return {
        symbol: sym,
        week_change: asset?.week_change ?? null,
        signal: sig?.signal ?? null,
        price: asset?.week_close ?? null,
      }
    })

    const correlationGroups = [
      { group: "Crypto", assets: cryptoCorrelation },
      { group: "Equities", assets: ["SPY", "QQQ", "DIA", "IWM"].map(buildCorrelationAsset) },
      { group: "Commodities", assets: ["GOLD", "SILVER", "OIL", "COPPER"].map(buildCorrelationAsset) },
      { group: "Macro", assets: ["VIX", "DXY", "TLT"].map(buildCorrelationAsset) },
    ]

    // Determine correlation narrative
    const cryptoAvg = cryptoCorrelation.reduce((s, a) => s + (a.week_change ?? 0), 0) / cryptoCorrelation.length
    const equityAvg = ["SPY", "QQQ"].reduce((s, sym) => {
      const a = buildCorrelationAsset(sym)
      return s + (a.week_change ?? 0)
    }, 0) / 2
    const sameDirection = (cryptoAvg >= 0 && equityAvg >= 0) || (cryptoAvg < 0 && equityAvg < 0)
    const corrNarrative = sameDirection
      ? "Crypto and equities moved in sync this week — risk appetite is consistent across asset classes."
      : "Crypto and equities diverged this week — watch for a convergence play or structural decoupling."

    slides.push({
      type: "correlation",
      title: "Cross-Market View",
      data: {
        type: "correlation",
        payload: {
          groups: correlationGroups,
          narrative: corrNarrative,
        },
      },
    })

    // 4. Editorial sections (section title + analysis pairs)
    for (const editorial of editorialSlides) {
      // Section title slide
      slides.push({
        type: "sectionTitle",
        title: editorial.section_title,
        data: {
          type: "sectionTitle",
          payload: { subtitle: editorial.section_subtitle ?? null },
        },
      })

      // Analysis slide
      slides.push({
        type: "editorial",
        title: editorial.analysis_title,
        data: {
          type: "editorial",
          payload: {
            bullets: editorial.bullets,
            category: editorial.category,
          },
        },
      })
    }

    // 3. Market Pulse (data-driven)
    slides.push({
      type: "marketPulse",
      title: "Market Pulse",
      data: { type: "marketPulse", payload: { assets: assetData } },
    })

    // 4. Arkline Snapshot — risk levels, equities, sentiment, supply in profit
    // Fetch additional data in parallel
    const [
      { data: spyMon }, { data: spyFri },
      { data: qqqMon }, { data: qqqFri },
      { data: supplyData },
      { data: weekTrendScores },
    ] = await Promise.all([
      // SPY/QQQ: earliest available as open, latest as close
      supabase.from("positioning_signals").select("price").eq("asset", "SPY").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: true }).limit(1),
      supabase.from("positioning_signals").select("price, signal, trend_score").eq("asset", "SPY").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(1),
      supabase.from("positioning_signals").select("price").eq("asset", "QQQ").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: true }).limit(1),
      supabase.from("positioning_signals").select("price, signal, trend_score").eq("asset", "QQQ").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(1),
      supabase.from("supply_in_profit").select("value").gte("date", monday).lte("date", friday).order("date", { ascending: false }).limit(1),
      supabase.from("positioning_signals").select("asset, trend_score, signal, signal_date").gte("signal_date", monday).lte("signal_date", friday).in("asset", ["BTC", "ETH", "SOL"]).order("signal_date", { ascending: true }),
    ])

    // SPY & QQQ weekly performance + trend signals (bounded to week range)
    const spyMonPrice = spyMon?.[0]?.price ?? null
    const spyFriPrice = spyFri?.[0]?.price ?? null
    const spyWeekChange = spyMonPrice != null && spyFriPrice != null ? Math.round(((spyFriPrice - spyMonPrice) / spyMonPrice) * 10000) / 100 : null
    const spySignal = spyFri?.[0]?.signal ?? null

    const qqqMonPrice = qqqMon?.[0]?.price ?? null
    const qqqFriPrice = qqqFri?.[0]?.price ?? null
    const qqqWeekChange = qqqMonPrice != null && qqqFriPrice != null ? Math.round(((qqqFriPrice - qqqMonPrice) / qqqMonPrice) * 10000) / 100 : null
    const qqqSignal = qqqFri?.[0]?.signal ?? null

    // BTC Supply in Profit
    const btcSupplyInProfit = supplyData?.[0]?.value ?? null

    // Sentiment regime: derive from bullish/bearish ratio + F&G
    const totalSignals = (latestSignals ?? []).length
    const bullishPct = totalSignals > 0 ? (bullishCount / totalSignals) * 100 : 50
    const emotionScore = fearGreedEnd ?? 50
    const engagementHigh = bullishPct > 60 || bullishPct < 30
    let sentimentRegime = "Apathy"
    if (emotionScore >= 55 && engagementHigh) sentimentRegime = "FOMO"
    else if (emotionScore >= 55 && !engagementHigh) sentimentRegime = "Complacency"
    else if (emotionScore < 45 && engagementHigh) sentimentRegime = "Panic"
    else if (emotionScore < 45 && !engagementHigh) sentimentRegime = "Apathy"
    else sentimentRegime = bullishCount > bearishCount ? "Complacency" : "Apathy"

    // Compute regression risk levels — use trend_score mapped to 0-1 decimal
    // Use end-of-week (Friday) data from weekTrendScores, NOT latestSignals (which is today's data)
    const SNAPSHOT_ASSETS = ["BTC", "ETH", "SOL"]
    const assetRisks = SNAPSHOT_ASSETS.map((symbol) => {
      const weekEntries = (weekTrendScores ?? []).filter((s: { asset: string }) => s.asset === symbol)
      const weekScores = weekEntries.map((s: { trend_score: number }) => s.trend_score ?? 50)

      // Use the last entry in the week (Friday or latest available day) for the "current" score
      const fridayEntry = weekEntries.length > 0 ? weekEntries[weekEntries.length - 1] : null
      // trend_score is 0-100: higher = more bullish = lower risk
      const currentScore = fridayEntry?.trend_score ?? 50
      // Map to 0-1 risk: 100 → ~0.0, 0 → ~1.0
      const riskLevel = Math.max(0, Math.min(1, 1 - (currentScore / 100)))

      // 7-day average risk
      let weekAverage: number | null = null
      if (weekScores.length >= 2) {
        const avgScore = weekScores.reduce((a: number, b: number) => a + b, 0) / weekScores.length
        weekAverage = Math.round(Math.max(0, Math.min(1, 1 - (avgScore / 100))) * 1000) / 1000
      }

      // Signal from end-of-week positioning
      const signal = fridayEntry?.signal ?? "neutral"

      // Approximate days at level by counting consecutive days with same risk label
      let daysAtLevel: number | null = null
      if (weekEntries.length >= 2) {
        // Count from end of week how many days had similar risk
        let count = 0
        for (let i = weekEntries.length - 1; i >= 0; i--) {
          const score = weekEntries[i].trend_score ?? 50
          const r = 1 - (score / 100)
          const sameZone = Math.abs(r - riskLevel) < 0.15
          if (sameZone) count++
          else break
        }
        daysAtLevel = count > 0 ? count : null
      }

      let riskLabel = "Moderate Risk"
      if (riskLevel < 0.2) riskLabel = "Very Low Risk"
      else if (riskLevel < 0.4) riskLabel = "Low Risk"
      else if (riskLevel < 0.55) riskLabel = "Moderate Risk"
      else if (riskLevel < 0.7) riskLabel = "Elevated Risk"
      else if (riskLevel < 0.9) riskLabel = "High Risk"
      else riskLabel = "Extreme Risk"

      return {
        symbol,
        risk_level: Math.round(riskLevel * 1000) / 1000, // 3 decimal places
        week_average: weekAverage,
        risk_label: riskLabel,
        signal,
        days_at_level: daysAtLevel,
      }
    })

    // Compute weekly average F&G from all days in the week
    const fgValues = (fgWeekData ?? []).map((r: { value: number }) => r.value).filter((v: number) => v != null)
    const fearGreedAvg = fgValues.length > 0 ? Math.round(fgValues.reduce((a: number, b: number) => a + b, 0) / fgValues.length) : fearGreedEnd

    slides.push({
      type: "snapshot",
      title: "Arkline Snapshot",
      data: {
        type: "snapshot",
        payload: {
          asset_risks: assetRisks,
          risk_type: "regression",
          fear_greed_avg: fearGreedAvg,
          fear_greed_end: fearGreedEnd,
          sentiment_regime: sentimentRegime,
          spy_week_change: spyWeekChange,
          qqq_week_change: qqqWeekChange,
          spy_price: spyFriPrice,
          qqq_price: qqqFriPrice,
          spy_signal: spySignal,
          qqq_signal: qqqSignal,
          btc_supply_in_profit: btcSupplyInProfit,
        },
      },
    })

    // Economic Calendar slide — this week's results + next week's upcoming events
    slides.push({
      type: "economic",
      title: "Economic Calendar",
      data: {
        type: "economic",
        payload: {
          this_week: (thisWeekEvents ?? []).map((e: Record<string, unknown>) => ({
            title: e.title,
            event_date: e.event_date,
            actual: e.actual ?? null,
            forecast: e.forecast ?? null,
            impact: e.impact,
          })),
          next_week: (nextWeekEvents ?? []).map((e: Record<string, unknown>) => ({
            title: e.title,
            event_date: e.event_date,
            forecast: e.forecast ?? null,
            impact: e.impact,
          })),
        },
      },
    })

    // ── Generate rundown narrative as the final slide ──────────────────
    if (anthropicKey) {
      const editorialContext = slides
        .filter((s: SlidePayload) => s.type === "editorial")
        .map((s: SlidePayload) => {
          const bullets = (s.data?.payload?.bullets as Array<{ text: string }>) ?? []
          return `${s.title}:\n${bullets.map((b) => `- ${b.text}`).join("\n")}`
        })
        .join("\n\n")

      const narrative = await generateRundownNarrative(
        anthropicKey,
        briefings ?? [],
        editorialContext,
        monday,
        friday,
        adminInsights || undefined,
      )

      slides.push({
        type: "rundown",
        title: "Weekly Rundown",
        data: { type: "rundown", payload: { narrative } },
      })
    }

    // ── Upsert deck ───────────────────────────────────────────────────────
    const { data: deck, error: upsertError } = await supabase
      .from("market_update_decks")
      .upsert(
        {
          week_start: monday,
          week_end: friday,
          status: "draft",
          slides,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "week_start" }
      )
      .select()
      .single()

    if (upsertError) {
      console.error("Upsert error:", upsertError)
      return jsonResponse({ error: upsertError.message }, 500)
    }

    console.log(`Market deck generated: ${monday} to ${friday}, ${slides.length} slides`)
    return jsonResponse(deck)
  } catch (e) {
    console.error("generate-market-deck error:", e)
    return jsonResponse({ error: String(e) }, 500)
  }
})
