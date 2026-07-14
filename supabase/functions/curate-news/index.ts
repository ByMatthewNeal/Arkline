import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * curate-news Edge Function
 *
 * Fetches Bloomberg + Google News RSS feeds, uses Claude to filter for
 * relevance and generate positioning takeaways, then upserts curated
 * articles into the curated_news table.
 *
 * Runs every 30 minutes via cron.
 */

// ─── RSS Feed URLs ───────────────────────────────────────────────────────────

// Bloomberg retired its public RSS feeds — feeds.bloomberg.com/markets/news.rss
// and /economics/news.rss both return a hard 404, so every fetch was failing and
// the curated pool was quietly running on Google News alone. Replaced with feeds
// verified live (CNBC, Reuters via Google News, MarketWatch).
const RSS_FEEDS = [
  {
    url: "https://search.cnbc.com/rs/search/combinedcms/view.xml?partnerId=wrss01&id=20910258",
    source: "CNBC",
    feed: "markets",
  },
  {
    url: "https://news.google.com/rss/search?q=when:1d+allinurl:reuters.com/markets&hl=en-US&gl=US&ceid=US:en",
    source: "Reuters",
    feed: "markets",
  },
  {
    url: "https://feeds.content.dowjones.io/public/rss/mw_topstories",
    source: "MarketWatch",
    feed: "economics",
  },
  {
    url: "https://news.google.com/rss/search?q=cryptocurrency+OR+bitcoin+OR+ethereum+OR+crypto+OR+defi&hl=en-US&gl=US&ceid=US:en",
    source: "Google News",
    feed: "crypto",
  },
  {
    url: "https://news.google.com/rss/search?q=federal+reserve+OR+interest+rates+OR+inflation+OR+tariffs+OR+geopolitics+OR+oil+OR+commodities&hl=en-US&gl=US&ceid=US:en",
    source: "Google News",
    feed: "macro",
  },
]

// ─── Claude Prompts ──────────────────────────────────────────────────────────

const FILTER_SYSTEM_PROMPT = `You are a senior financial analyst curating a news feed for crypto, macro, and equity investors.

Given the numbered headlines below, select ONLY the ones with direct positioning implications — news that would make a portfolio manager adjust exposure, hedge, or watch a specific level.

HIGH relevance (ACCEPT):
- Central bank actions, rate decisions, liquidity shifts
- Major earnings that move sectors or signal regime changes
- Crypto regulatory actions, ETF flows, on-chain signals
- Geopolitical events directly affecting risk assets or commodities
- Treasury/bond market moves, yield curve changes
- OPEC/energy supply decisions, commodity supply shocks
- Credit market stress signals (high-yield spreads, defaults)
- Major institutional positioning shifts (Berkshire cash, sovereign funds)

LOW relevance (REJECT): product launches, celebrity news, lifestyle, opinion without data, local news, generic market recaps, PR/earnings that don't move sectors, duplicate stories covering the same event.

Return ONLY a valid JSON array of objects: [{"index": 1, "score": 8, "category": "macro"}, ...]
Categories: crypto, macro, equities, geopolitics, commodities, credit
Target: 4-8 articles per batch. Quality over quantity. No markdown, no explanation.`

const ENRICH_SYSTEM_PROMPT = `You are a senior positioning analyst at ArkLine, a financial intelligence app for crypto and macro investors.

For each article, produce:
1. A rewritten headline: concise, positioning-oriented, states the fact and its market implication. Max 120 characters. No clickbait.
2. Three takeaway bullets (each 1-2 sentences, direct and assertive):
   - Bullet 1: Positioning implication — what this means for portfolios right now
   - Bullet 2: What to watch — specific metric, event, level, or threshold to monitor
   - Bullet 3: Cross-asset connection — how this links to other markets (crypto↔macro↔FX↔commodities)
3. A priority_reason (1 sentence): For articles with relevance_score >= 7, explain in one direct sentence why this article demands attention for positioning decisions right now. For articles with relevance_score < 7, return an empty string "".

Write like a Bloomberg terminal note. No hedging ("could", "might"). Be direct.

Return ONLY a valid JSON array:
[{"index": 0, "headline": "...", "takeaway_1": "...", "takeaway_2": "...", "takeaway_3": "...", "priority_reason": "..."}]
No markdown, no explanation.`

// ─── Main Handler ────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  const secret = req.headers.get("x-cron-secret") ?? ""
  if (!cronSecret || secret !== cronSecret) {
    return json({ error: "Unauthorized" }, 401)
  }

  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY")
  if (!anthropicKey) {
    return json({ error: "ANTHROPIC_API_KEY not set" }, 500)
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const supabase = createClient(supabaseUrl, supabaseKey)

  const stats = { fetched: 0, new: 0, filtered: 0, enriched: 0, inserted: 0, errors: [] as string[] }

  // ── Step 1: Fetch all RSS feeds in parallel ──────────────────────────────

  const feedResults = await Promise.allSettled(
    RSS_FEEDS.map((feed) => fetchRSSFeed(feed.url, feed.source, feed.feed))
  )

  let allArticles: RawArticle[] = []
  for (const result of feedResults) {
    if (result.status === "fulfilled") {
      allArticles.push(...result.value)
    } else {
      stats.errors.push(`Feed fetch failed: ${result.reason}`)
    }
  }
  stats.fetched = allArticles.length
  console.log(`Fetched ${allArticles.length} articles from ${RSS_FEEDS.length} feeds`)

  if (allArticles.length === 0) {
    return json({ ...stats, message: "No articles fetched" })
  }

  // ── Step 2: Deduplicate by URL hash ──────────────────────────────────────

  const seen = new Map<string, RawArticle>()
  for (const article of allArticles) {
    const hash = await hashURL(article.url)
    if (!seen.has(hash)) {
      seen.set(hash, { ...article, urlHash: hash })
    }
  }
  const deduped = Array.from(seen.values())

  // ── Step 3: Filter out articles already in DB ────────────────────────────

  const hashes = deduped.map((a) => a.urlHash!)
  const { data: existing } = await supabase
    .from("curated_news")
    .select("url_hash")
    .in("url_hash", hashes)

  const existingHashes = new Set((existing ?? []).map((r: { url_hash: string }) => r.url_hash))
  const newArticles = deduped.filter((a) => !existingHashes.has(a.urlHash!))
  stats.new = newArticles.length

  if (newArticles.length === 0) {
    console.log("No new articles to process")
    return json({ ...stats, message: "No new articles" })
  }

  console.log(`${newArticles.length} new articles after dedup + DB filter`)

  // ── Step 4: Claude filter for relevance ──────────────────────────────────

  // Sort by pubDate (newest first) and cap at 50 to keep Claude input manageable
  const sortedNew = [...newArticles].sort((a, b) => {
    const da = new Date(a.pubDate).getTime() || 0
    const db = new Date(b.pubDate).getTime() || 0
    return db - da
  })
  const candidates = sortedNew.slice(0, 50)

  const headlineList = candidates
    .map((a, i) => `${i + 1}. [${a.source}] ${a.title}`)
    .join("\n")

  console.log(`Sending ${candidates.length} headlines to Claude for filtering`)

  let accepted: FilterResult[] = []
  try {
    const filterResponse = await callClaude(
      anthropicKey,
      FILTER_SYSTEM_PROMPT,
      `Filter these headlines for positioning relevance:\n\n${headlineList}`,
      1000
    )
    console.log(`Claude filter raw response: ${filterResponse.substring(0, 500)}`)
    accepted = parseJSONResponse<FilterResult[]>(filterResponse) ?? []
    stats.filtered = accepted.length
    console.log(`Claude accepted ${accepted.length} of ${candidates.length} articles`)
  } catch (err) {
    stats.errors.push(`Filter call failed: ${err}`)
    console.error(`Claude filter failed: ${err}`)
    return json(stats)
  }

  if (accepted.length === 0) {
    console.log("Claude filtered out all articles")
    return json({ ...stats, message: "No articles passed relevance filter" })
  }

  // ── Step 5: Claude enrich accepted articles ──────────────────────────────

  // Map accepted indices back to articles
  const toEnrich = accepted
    .map((r) => {
      const article = candidates[r.index - 1] // Claude uses 1-based indices
      if (!article) return null
      return { article, score: r.score, category: r.category }
    })
    .filter((x): x is NonNullable<typeof x> => x !== null)

  // Batch enrich (up to 5 per call — keeps the JSON response well under max_tokens)
  const BATCH_SIZE = 5
  const enriched: EnrichedArticle[] = []

  for (let i = 0; i < toEnrich.length; i += BATCH_SIZE) {
    const batch = toEnrich.slice(i, i + BATCH_SIZE)
    const batchInput = batch
      .map(
        (item, idx) =>
          `[${idx}] Title: ${item.article.title}\nSource: ${item.article.source}\nRelevance Score: ${item.score}\nDescription: ${item.article.description || "N/A"}`
      )
      .join("\n\n")

    try {
      // 8000 tokens: ~5 articles × (headline + 3 bullets + reason) needs far
      // more than the old 2000, which truncated the JSON mid-array and made
      // every batch silently parse to null → 0 articles inserted.
      const enrichResponse = await callClaude(
        anthropicKey,
        ENRICH_SYSTEM_PROMPT,
        `Analyze and rewrite these articles:\n\n${batchInput}`,
        8000,
        "claude-sonnet-5"
      )
      const results = parseJSONResponse<EnrichResult[]>(enrichResponse)
      if (results === null) {
        // Surface parse failures instead of swallowing them as an empty batch
        throw new Error(`Enrich response was not valid JSON (len ${enrichResponse.length})`)
      }

      for (const result of results) {
        const item = batch[result.index]
        if (!item) continue
        enriched.push({
          original_title: item.article.title,
          curated_title: result.headline,
          source: item.article.source,
          source_url: item.article.url,
          published_at: item.article.pubDate,
          takeaway_1: result.takeaway_1,
          takeaway_2: result.takeaway_2,
          takeaway_3: result.takeaway_3,
          relevance_score: item.score,
          category: item.category,
          url_hash: item.article.urlHash!,
          priority_reason: result.priority_reason || "",
        })
      }
    } catch (err) {
      stats.errors.push(`Enrich batch ${i} failed: ${err}`)
      console.error(`Enrich batch failed: ${err}`)
    }

    // Small delay between batches
    if (i + BATCH_SIZE < toEnrich.length) {
      await new Promise((r) => setTimeout(r, 300))
    }
  }

  stats.enriched = enriched.length

  // ── Step 6: Upsert to curated_news ───────────────────────────────────────

  for (const article of enriched) {
    const { error } = await supabase
      .from("curated_news")
      .upsert(article, { onConflict: "url_hash" })

    if (error) {
      stats.errors.push(`Upsert failed: ${error.message}`)
      console.error(`Upsert failed for "${article.curated_title}": ${error.message}`)
    } else {
      stats.inserted++
    }
  }

  console.log(`Curate-news complete: ${JSON.stringify(stats)}`)
  return json(stats)
})

// ─── RSS Parsing ─────────────────────────────────────────────────────────────

interface RawArticle {
  title: string
  url: string
  pubDate: string
  source: string
  feed: string
  description: string
  urlHash?: string
}

async function fetchRSSFeed(
  feedUrl: string,
  source: string,
  feed: string
): Promise<RawArticle[]> {
  const resp = await fetch(feedUrl, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
      Accept: "application/rss+xml, application/xml, text/xml",
    },
    signal: AbortSignal.timeout(15_000),
  })

  if (!resp.ok) {
    throw new Error(`${source}/${feed} returned ${resp.status}`)
  }

  const xml = await resp.text()
  return parseRSSItems(xml, source, feed)
}

function parseRSSItems(xml: string, source: string, feed: string): RawArticle[] {
  const articles: RawArticle[] = []
  const itemRegex = /<item>([\s\S]*?)<\/item>/gi
  let match: RegExpExecArray | null

  while ((match = itemRegex.exec(xml)) !== null) {
    const itemXml = match[1]

    const title = extractTag(itemXml, "title")
    const link = extractTag(itemXml, "link")
    const pubDate = extractTag(itemXml, "pubDate")
    const description = extractTag(itemXml, "description")

    // Extract source from <source> tag (Google News) or use feed source
    const sourceTag = extractTag(itemXml, "source")
    const articleSource = sourceTag || source

    if (!title || !link) continue

    // Clean Google News title suffix (" - Source Name")
    let cleanTitle = title
    if (source === "Google News") {
      const dashIdx = title.lastIndexOf(" - ")
      if (dashIdx > 0) {
        cleanTitle = title.substring(0, dashIdx).trim()
      }
    }

    articles.push({
      title: decodeHTMLEntities(cleanTitle),
      url: link.trim(),
      pubDate: pubDate || new Date().toISOString(),
      source: decodeHTMLEntities(articleSource),
      feed,
      description: decodeHTMLEntities(description || ""),
    })
  }

  return articles
}

function extractTag(xml: string, tag: string): string {
  // Handle CDATA sections
  const cdataRegex = new RegExp(`<${tag}[^>]*>\\s*<!\\[CDATA\\[([\\s\\S]*?)\\]\\]>\\s*</${tag}>`, "i")
  const cdataMatch = cdataRegex.exec(xml)
  if (cdataMatch) return cdataMatch[1].trim()

  // Handle regular content
  const regex = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, "i")
  const match = regex.exec(xml)
  return match ? match[1].trim() : ""
}

function decodeHTMLEntities(text: string): string {
  return text
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/<[^>]+>/g, "") // Strip any remaining HTML tags
}

// ─── URL Hashing ─────────────────────────────────────────────────────────────

async function hashURL(url: string): Promise<string> {
  // Normalize: lowercase, strip query params and trailing slashes
  let normalized: string
  try {
    const parsed = new URL(url)
    normalized = (parsed.origin + parsed.pathname).toLowerCase().replace(/\/+$/, "")
  } catch {
    normalized = url.toLowerCase().replace(/\/+$/, "")
  }

  const data = new TextEncoder().encode(normalized)
  const hashBuffer = await crypto.subtle.digest("SHA-256", data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("")
}

// ─── Claude API ──────────────────────────────────────────────────────────────

async function callClaude(
  apiKey: string,
  systemPrompt: string,
  userMessage: string,
  maxTokens: number,
  model: "claude-haiku-4-5-20251001" | "claude-sonnet-5" = "claude-haiku-4-5-20251001"
): Promise<string> {
  const resp = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model,
      max_tokens: maxTokens,
      system: systemPrompt,
      messages: [{ role: "user", content: userMessage }],
    }),
  })

  if (!resp.ok) {
    const errText = await resp.text()
    throw new Error(`Claude API ${resp.status}: ${errText}`)
  }

  const data = await resp.json()
  if (data.stop_reason === "max_tokens") {
    throw new Error(`Claude response truncated at max_tokens=${maxTokens} — increase budget or shrink batch`)
  }
  // Newer models may prepend non-text blocks (e.g. thinking) — collect every
  // text block rather than assuming content[0] is the text.
  const text = ((data.content ?? []) as { type: string; text?: string }[])
    .filter((b) => b.type === "text")
    .map((b) => b.text ?? "")
    .join("")
  if (!text) {
    throw new Error(`Claude returned no text (stop_reason=${data.stop_reason}, blocks=${(data.content ?? []).map((b: { type: string }) => b.type).join(",")})`)
  }
  return text
}

function parseJSONResponse<T>(text: string): T | null {
  // Strip markdown code fences if present
  let cleaned = text.trim()
  if (cleaned.startsWith("```")) {
    cleaned = cleaned.replace(/^```(?:json)?\s*/, "").replace(/\s*```$/, "")
  }

  try {
    return JSON.parse(cleaned) as T
  } catch (err) {
    console.error(`JSON parse failed: ${err}\nRaw text: ${text.substring(0, 500)}`)
    return null
  }
}

// ─── Types ───────────────────────────────────────────────────────────────────

interface FilterResult {
  index: number
  score: number
  category: string
}

interface EnrichResult {
  index: number
  headline: string
  takeaway_1: string
  takeaway_2: string
  takeaway_3: string
  priority_reason: string
}

interface EnrichedArticle {
  original_title: string
  curated_title: string
  source: string
  source_url: string
  published_at: string
  takeaway_1: string
  takeaway_2: string
  takeaway_3: string
  relevance_score: number
  category: string
  url_hash: string
  priority_reason: string
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
