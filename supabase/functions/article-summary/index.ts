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

// Extract the actual article URL from a Google News redirect page
function extractRedirectURL(html: string): string | null {
  // Google News pages contain a data-url attribute or a redirect URL in various formats
  const patterns = [
    /data-n-au="([^"]+)"/,
    /<a[^>]+href="(https?:\/\/(?!news\.google\.com)[^"]+)"[^>]*>/,
    /window\.location\.replace\("([^"]+)"\)/,
    /http-equiv="refresh"[^>]+url=([^">\s]+)/i,
    /canonical"[^>]+href="(https?:\/\/(?!news\.google\.com)[^"]+)"/,
  ]

  for (const pattern of patterns) {
    const match = html.match(pattern)
    if (match?.[1]) {
      return match[1]
    }
  }
  return null
}

// Fetch HTML from a URL with browser-like headers
async function fetchHTML(targetUrl: string): Promise<{ html: string; finalUrl: string; error?: string } | null> {
  try {
    console.log(`fetchHTML: fetching ${targetUrl}`)
    const response = await fetch(targetUrl, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
      },
      redirect: "follow",
    })

    console.log(`fetchHTML: status=${response.status}, redirected=${response.redirected}, finalUrl=${response.url}`)

    if (!response.ok) {
      console.error(`Fetch failed: ${response.status} for ${targetUrl}`)
      return null
    }

    const html = await response.text()
    console.log(`fetchHTML: got ${html.length} chars of HTML`)
    return { html, finalUrl: response.url }
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err)
    console.error(`fetchHTML error for ${targetUrl}: ${errMsg}`)
    return { html: "", finalUrl: targetUrl, error: errMsg }
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Verify authorization header exists (Supabase infrastructure validates the JWT)
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing authorization" }), {
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

  console.log(`Processing article: ${url}`)

  // Fetch article HTML (follow redirects — Google News URLs redirect)
  let articleText: string
  try {
    let result = await fetchHTML(url)
    if (!result || result.error) {
      return new Response(
        JSON.stringify({ summary: "Unable to load this article for summarization. Try opening it in your browser for the full story."}),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    }

    let { html, finalUrl } = result
    console.log(`Fetched URL resolved to: ${finalUrl}, HTML length: ${html.length}`)

    // If we landed on a Google News redirect page, try to extract the real article URL
    if (finalUrl.includes("news.google.com") || html.length < 5000) {
      const realUrl = extractRedirectURL(html)
      if (realUrl) {
        console.log(`Extracted real article URL: ${realUrl}`)
        const realResult = await fetchHTML(realUrl)
        if (realResult) {
          html = realResult.html
          finalUrl = realResult.finalUrl
          console.log(`Real article fetched, HTML length: ${html.length}`)
        }
      }
    }

    articleText = extractText(html)
    console.log(`Extracted text length: ${articleText.length}`)

    // Truncate to ~4000 chars to keep Claude costs low
    if (articleText.length > 4000) {
      articleText = articleText.substring(0, 4000) + "..."
    }
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err)
    console.error("Article fetch failed:", errMsg)
    return new Response(
      JSON.stringify({ summary: "Unable to load this article for summarization. Try opening it in your browser for the full story."}),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  }

  // Check if we got meaningful content
  if (articleText.length < 100) {
    console.log(`Insufficient content (${articleText.length} chars), falling back to title-based summary`)
    // If we have a title and description from Google News, summarize from that
    if (title.length > 20) {
      articleText = title
    } else {
      return new Response(
        JSON.stringify({ summary: "This article couldn't be summarized — it may require JavaScript to load. Tap below to read the full article in your browser." }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    }
  }

  // Call Claude API for summarization
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!apiKey) {
    console.error("ANTHROPIC_API_KEY not set")
    return new Response(
      JSON.stringify({ summary: "Article summaries are temporarily unavailable. Tap below to read the full article in your browser." }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  }

  try {
    console.log("Calling Claude API...")
    const claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 500,
        system: "You summarize news articles for a financial app called ArkLine. Write a 4-6 sentence summary (about 120-150 words) that captures the key facts, context, and any implications for investors. Be direct, factual, and concise. Jump straight into the substance — never include headers, labels, markdown formatting, or phrases like 'Summary:', '# Summary', 'This article discusses', or 'Here is a summary'. Just write the plain text summary.",
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
      console.error(`Claude API error: ${claudeResponse.status} ${errorText}`)
      return new Response(
        JSON.stringify({ summary: "Summary temporarily unavailable. Tap below to read the full article in your browser."}),
        { status: 200, headers: { "Content-Type": "application/json" } }
      )
    }

    const claudeData = await claudeResponse.json()
    let summary = claudeData.content?.[0]?.text ?? ""
    // Strip any markdown formatting Claude might add
    summary = summary.replace(/^#+\s*Summary:?\s*/i, "")
    summary = summary.replace(/^\*{1,2}Summary:?\*{1,2}\s*/i, "")
    summary = summary.replace(/^Summary:?\s*/i, "")
    summary = summary.trim()
    console.log(`Claude returned summary (${summary.length} chars)`)

    if (!summary) {
      return new Response(
        JSON.stringify({ summary: "Could not generate a summary for this article. Tap below to read it in your browser." }),
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
      JSON.stringify({ summary: "Summary temporarily unavailable. Tap below to read the full article in your browser." }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  }
})
