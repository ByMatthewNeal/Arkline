import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// Simple HTML-to-text extraction
function extractText(html: string): string {
  // Remove script and style blocks
  let text = html.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "")
  text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, "")

  // Remove nav, header, footer, aside elements (boilerplate)
  text = text.replace(/<(nav|header|footer|aside)[^>]*>[\s\S]*?<\/\1>/gi, "")

  // Convert <p>, <br>, <li>, <h*> to newlines for readability
  text = text.replace(/<br\s*\/?>/gi, "\n")
  text = text.replace(/<\/?(p|div|li|h[1-6]|blockquote|tr)[^>]*>/gi, "\n")

  // Strip all remaining HTML tags
  text = text.replace(/<[^>]+>/g, "")

  // Decode common HTML entities
  text = text.replace(/&amp;/g, "&")
  text = text.replace(/&lt;/g, "<")
  text = text.replace(/&gt;/g, ">")
  text = text.replace(/&quot;/g, '"')
  text = text.replace(/&#39;/g, "'")
  text = text.replace(/&nbsp;/g, " ")
  text = text.replace(/&#\d+;/g, "")

  // Collapse whitespace
  text = text.replace(/[ \t]+/g, " ")
  text = text.replace(/\n\s*\n/g, "\n\n")
  text = text.trim()

  return text
}

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

  // Parse request
  let url: string
  let title: string
  try {
    const parsed = await req.json()
    url = parsed.url
    title = parsed.title ?? ""
  } catch {
    return new Response(JSON.stringify({ error: "Invalid request body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  }

  if (!url) {
    return new Response(JSON.stringify({ error: "Missing url parameter" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Fetch article HTML (follow redirects — Google News URLs redirect)
  let articleText: string
  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
      },
      redirect: "follow",
    })

    if (!response.ok) {
      return new Response(
        JSON.stringify({ error: "Could not fetch article", summary: "Unable to load this article for summarization. Try opening it in your browser for the full story." }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    }

    const html = await response.text()
    articleText = extractText(html)

    // Truncate to ~4000 chars to keep Claude costs low
    if (articleText.length > 4000) {
      articleText = articleText.substring(0, 4000) + "..."
    }
  } catch {
    return new Response(
      JSON.stringify({ error: "fetch_failed", summary: "Unable to load this article for summarization. Try opening it in your browser for the full story." }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  }

  // Check if we got meaningful content
  if (articleText.length < 100) {
    return new Response(
      JSON.stringify({ error: "insufficient_content", summary: "This article couldn't be summarized — it may require JavaScript to load. Tap below to read the full article in your browser." }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  }

  // Call Claude API for summarization
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "not_configured", summary: "Article summaries are temporarily unavailable. Tap below to read the full article in your browser." }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  }

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
        system: "You summarize news articles for a financial app called ArkLine. Write a 2-3 sentence summary that captures the key facts and any implications for investors. Be direct, factual, and concise. Do not start with phrases like 'This article discusses' — jump straight into the substance.",
        messages: [
          {
            role: "user",
            content: `Article title: ${title}\n\nArticle content:\n${articleText}`,
          },
        ],
      }),
    })

    if (!claudeResponse.ok) {
      const errorText = await claudeResponse.text()
      console.error("Claude API error:", claudeResponse.status, errorText)
      return new Response(
        JSON.stringify({ error: "ai_error", summary: "Summary temporarily unavailable. Tap below to read the full article in your browser." }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    }

    const claudeData = await claudeResponse.json()
    const summary = claudeData.content?.[0]?.text ?? ""

    if (!summary) {
      return new Response(
        JSON.stringify({ error: "empty_response", summary: "Could not generate a summary for this article. Tap below to read it in your browser." }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    }

    return new Response(
      JSON.stringify({ summary }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  } catch (err) {
    console.error("Claude API call failed:", err)
    return new Response(
      JSON.stringify({ error: "ai_error", summary: "Summary temporarily unavailable. Tap below to read the full article in your browser." }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  }
})
