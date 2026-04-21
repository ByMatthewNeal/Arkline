import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * deck-pipeline-generate Edge Function
 *
 * Step 4 of the deck pipeline:
 * - Reads pipeline_run_id from params
 * - Reads output_gather_data, output_web_research, output_context from the pipeline run
 * - Calls Claude Sonnet to generate editorial slides + weekly outlook in parallel
 * - Assembles all slides in correct order
 * - Upserts into market_update_decks with status='draft'
 * - Updates deck_pipeline_runs.deck_id
 * - Sets step_generate_slides = 'completed'
 */

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

interface SlidePayload {
  type: string
  title: string
  data: {
    type: string
    payload: Record<string, unknown>
  }
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
- ONLY include events and data from ${monday} to ${friday}. Do NOT reference anything from earlier weeks — if the research mentions older events, ignore them
- Only create sections for topics that had MEANINGFUL developments THIS specific week
- Skip topics where nothing notable happened this week
- Prioritize: Fed/FOMC > major economic data > geopolitics/tariffs > international central banks > liquidity/M2 > crypto-specific themes
- Each bullet should stand alone as a valuable insight
- Use specific numbers (e.g. "CPI rose 0.2% MoM to 2.8% YoY" not "inflation rose slightly")
- Always close the loop: data point → market impact → what it means for risk assets/crypto/stocks

${imageUrls?.length ? `\n=== ATTACHED IMAGES (analyze these carefully) ===\nThe admin has attached ${imageUrls.length} image(s) above. These may contain charts, screenshots, market data, positioning tables, or analysis. You MUST:\n- Read and extract ALL data, numbers, and key takeaways from each image\n- Identify what the chart/screenshot shows and what it implies for markets\n- Synthesize these visual insights into your editorial analysis in your OWN words\n- Do NOT describe what the image looks like — extract the MEANING and DATA from it\n- Treat image content the same as text insights: rephrase, never reproduce labels verbatim\n` : ""}
${adminInsights ? `\n=== ADMIN INSIGHTS (CRITICAL — synthesize, do NOT copy) ===\n${adminInsights}\n\nIMPORTANT: The above is raw context from the admin (may include transcripts, notes, or external analysis). You MUST:\n- Extract the KEY IDEAS and DATA POINTS only\n- Completely REPHRASE everything in your own words and Arkline's voice\n- NEVER use the same titles, headings, or phrasing from the source\n- NEVER quote or closely paraphrase — fully rewrite with original analysis\n- Treat this as background research, not copy to reproduce\n` : ""}
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
        model: "claude-haiku-4-5-20251001",
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
        // SSRF protection: reject private IPs and non-HTTPS URLs
        const urlObj = new URL(att.url)
        const hostname = urlObj.hostname.toLowerCase()
        if (
          hostname === "localhost" ||
          hostname.startsWith("127.") ||
          hostname.startsWith("10.") ||
          hostname.startsWith("172.") ||
          hostname.startsWith("192.168.") ||
          hostname === "0.0.0.0" ||
          hostname.endsWith(".internal") ||
          hostname.includes("metadata") ||
          urlObj.protocol !== "https:"
        ) {
          console.warn(`[generate] Blocked SSRF attempt: ${att.url}`)
          continue
        }
        const resp = await fetch(att.url, {
          headers: { "User-Agent": "Arkline-Bot/1.0" },
          signal: AbortSignal.timeout(10000),
        })
        if (resp.ok) {
          const html = await resp.text()
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

// ── Main Handler ────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const supabase = createClient(supabaseUrl, supabaseKey)

  // ── Admin JWT auth ──────────────────────────────────────────────────
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

  // ── Parse params ────────────────────────────────────────────────────
  const url = new URL(req.url)
  const pipelineRunId = url.searchParams.get("pipeline_run_id") ?? ""

  if (!pipelineRunId) {
    return jsonResponse({ error: "pipeline_run_id is required" }, 400)
  }

  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY") ?? ""
  if (!anthropicKey) {
    return jsonResponse({ error: "ANTHROPIC_API_KEY is not configured" }, 500)
  }

  console.log(`[generate] Starting slide generation for pipeline run ${pipelineRunId}`)

  try {
    // ── Load pipeline run ─────────────────────────────────────────────
    const { data: run, error: fetchErr } = await supabase
      .from("deck_pipeline_runs")
      .select("*")
      .eq("id", pipelineRunId)
      .single()

    if (fetchErr || !run) {
      return jsonResponse({ error: `Pipeline run not found: ${fetchErr?.message}` }, 404)
    }

    if (run.step_gather_data !== "completed") {
      return jsonResponse({ error: `step_gather_data must be completed first (current: ${run.step_gather_data})` }, 400)
    }

    // Mark as running
    await supabase
      .from("deck_pipeline_runs")
      .update({
        step_generate_slides: "running",
        error_generate_slides: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", pipelineRunId)

    // ── Read outputs from previous steps ──────────────────────────────
    const gatherData = run.output_gather_data
    const researchData = run.output_web_research
    const contextData = run.output_context

    const monday = gatherData.monday
    const friday = gatherData.friday
    const dbContext = gatherData.dbContext
    const briefings = gatherData.briefings ?? []

    // Web research (may be null if step was skipped)
    const webResearch: Record<string, string[]> = researchData ?? {}

    // Admin context (may be null if step was skipped)
    const adminInsights = contextData?.admin_insights ?? ""
    const attachments: Attachment[] = contextData?.attachments ?? []

    // Process attachments if present
    let attachmentContext = ""
    let attachmentImageUrls: string[] = []
    if (attachments.length > 0) {
      console.log(`[generate] Processing ${attachments.length} admin attachments...`)
      const processed = await processAttachments(attachments, supabaseUrl, supabaseKey)
      attachmentContext = processed.textContext
      attachmentImageUrls = processed.imageUrls
      console.log(`[generate] Processed: ${attachmentImageUrls.length} image URLs, ${attachmentContext.length} chars text`)
    }

    const fullInsights = [adminInsights, attachmentContext].filter(Boolean).join("\n\n")

    // ── Fetch past slide feedback for learning context ────────────────
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

        console.log(`[generate] Loaded ${recentFeedback.length} past feedback items for learning context`)
      }
    } catch (e) {
      console.error("Failed to fetch feedback history (non-fatal):", e)
    }

    // ── Generate editorial slides + weekly outlook in parallel ────────
    const hasWebResearch = Object.values(webResearch).flat().length > 0
    console.log(`[generate] Generating editorial + outlook via Claude Sonnet (web: ${hasWebResearch}, insights: ${fullInsights.length > 0})...`)

    const researchText = Object.entries(webResearch)
      .map(([cat, items]) => `=== ${cat.toUpperCase()} ===\n${items.join("\n\n")}`)
      .join("\n\n")

    // Combine image URLs from attachments for editorial generation
    const imageUrlsForEditorial = attachmentImageUrls.length > 0 ? attachmentImageUrls : undefined

    const [editorialSlides, weeklyOutlook] = await Promise.all([
      generateEditorialSlides(
        anthropicKey, webResearch, dbContext, monday, friday,
        fullInsights || undefined, imageUrlsForEditorial, feedbackContext || undefined
      ),
      generateWeeklyOutlook(anthropicKey, dbContext, researchText, monday, friday, feedbackContext || undefined),
    ])

    console.log(`[generate] Generated ${editorialSlides.length} editorial sections, outlook: ${weeklyOutlook ? "yes" : "no"}`)

    // ── Assemble all slides in correct order ──────────────────────────
    const slides: SlidePayload[] = []

    // 1. Cover (from gather data)
    slides.push(gatherData.slides.cover)

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

    // 3. Cross-Market Correlation (from gather data)
    slides.push(gatherData.slides.correlation)

    // 4. Editorial sections (section title + analysis pairs)
    for (const editorial of editorialSlides) {
      slides.push({
        type: "sectionTitle",
        title: editorial.section_title,
        data: {
          type: "sectionTitle",
          payload: { subtitle: editorial.section_subtitle ?? null },
        },
      })
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

    // 5. Market Pulse (from gather data)
    slides.push(gatherData.slides.marketPulse)

    // 6. Arkline Snapshot (from gather data)
    slides.push(gatherData.slides.snapshot)

    // ── Upsert deck ──────────────────────────────────────────────────
    const adminContext = (fullInsights || attachments.length > 0) ? {
      admin_insights: adminInsights || null,
      attachments: attachments.length > 0 ? attachments : null,
    } : undefined

    const upsertPayload: Record<string, unknown> = {
      week_start: monday,
      week_end: friday,
      status: "draft",
      slides,
      updated_at: new Date().toISOString(),
    }
    if (adminContext) {
      upsertPayload.admin_context = adminContext
    }

    const { data: deck, error: upsertError } = await supabase
      .from("market_update_decks")
      .upsert(upsertPayload, { onConflict: "week_start" })
      .select()
      .single()

    if (upsertError) {
      console.error("Upsert error:", upsertError)
      return jsonResponse({ error: upsertError.message }, 500)
    }

    // ── Update pipeline run ──────────────────────────────────────────
    const { error: updateErr } = await supabase
      .from("deck_pipeline_runs")
      .update({
        step_generate_slides: "completed",
        deck_id: deck.id,
        output_generate_slides: {
          slide_count: slides.length,
          editorial_count: editorialSlides.length,
          has_outlook: !!weeklyOutlook,
          generated_at: new Date().toISOString(),
        },
        error_generate_slides: null,
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", pipelineRunId)

    if (updateErr) {
      console.error("Pipeline run update error (non-fatal):", updateErr)
    }

    console.log(`[generate] Market deck generated: ${monday} to ${friday}, ${slides.length} slides, deck_id=${deck.id}`)
    return jsonResponse({
      pipeline_run_id: pipelineRunId,
      deck_id: deck.id,
      step_generate_slides: "completed",
      slide_count: slides.length,
      deck,
    })
  } catch (e) {
    console.error("[generate] error:", e)
    try {
      await supabase
        .from("deck_pipeline_runs")
        .update({
          step_generate_slides: "failed",
          error_generate_slides: String(e),
          updated_at: new Date().toISOString(),
        })
        .eq("id", pipelineRunId)
    } catch { /* best effort */ }
    return jsonResponse({ error: String(e) }, 500)
  }
})
