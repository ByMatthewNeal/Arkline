import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * collect-trends Edge Function
 *
 * Fetches Wikipedia pageviews for "Bitcoin" (last 90 days), normalizes to a
 * 0-100 search interest index, and upserts into the google_trends_history table.
 *
 * Invocation: POST with Authorization header containing the COLLECT_TRENDS_SECRET.
 */

interface WikiPageviewItem {
  article: string
  timestamp: string // "2025010100"
  views: number
}

interface WikiPageviewResponse {
  items: WikiPageviewItem[]
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    })
  }

  // Verify shared secret
  const authHeader = req.headers.get("Authorization") ?? ""
  const expectedSecret = Deno.env.get("COLLECT_TRENDS_SECRET") ?? ""

  if (!expectedSecret || !authHeader.includes(expectedSecret)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    })
  }

  try {
    // Calculate date range (90 days ago to yesterday)
    const now = new Date()
    const end = new Date(now)
    end.setDate(end.getDate() - 1) // Yesterday (today's data may not be complete)

    const start = new Date(end)
    start.setDate(start.getDate() - 89) // 90 days total

    const startStr = formatDate(start)
    const endStr = formatDate(end)

    // Fetch Wikipedia pageviews for "Bitcoin"
    const wikiUrl =
      `https://wikimedia.org/api/rest_v1/metrics/pageviews/per-article/en.wikipedia/all-access/user/Bitcoin/daily/${startStr}/${endStr}`

    const wikiRes = await fetch(wikiUrl, {
      headers: {
        "User-Agent": "ArkLine/1.0 (https://arkline.app; contact@arkline.app)",
      },
    })

    if (!wikiRes.ok) {
      const errorText = await wikiRes.text()
      return new Response(
        JSON.stringify({ error: "Wikipedia API error", status: wikiRes.status, detail: errorText }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      )
    }

    const wikiData: WikiPageviewResponse = await wikiRes.json()
    const items = wikiData.items

    if (!items || items.length === 0) {
      return new Response(
        JSON.stringify({ error: "No pageview data returned" }),
        { status: 502, headers: { "Content-Type": "application/json" } },
      )
    }

    // Find min/max for normalization
    const views = items.map((i) => i.views)
    const minViews = Math.min(...views)
    const maxViews = Math.max(...views)
    const range = maxViews - minViews || 1 // Avoid division by zero

    // Normalize to 0-100 index and prepare records
    const records = items.map((item) => {
      const index = Math.round(((item.views - minViews) / range) * 100)
      const date = parseWikiTimestamp(item.timestamp)
      return {
        search_index: index,
        recorded_date: date,
        btc_price: null, // Edge function doesn't fetch BTC price
      }
    })

    // Upsert into Supabase using service role key
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    )

    let inserted = 0
    let updated = 0
    let skipped = 0

    for (const record of records) {
      // Check if record exists for this date
      const { data: existing } = await supabase
        .from("google_trends_history")
        .select("id, search_index")
        .eq("recorded_date", record.recorded_date)
        .limit(1)

      if (!existing || existing.length === 0) {
        // Insert new record
        const { error } = await supabase
          .from("google_trends_history")
          .insert(record)

        if (!error) inserted++
      } else if (existing[0].search_index !== record.search_index) {
        // Update if value changed
        const { error } = await supabase
          .from("google_trends_history")
          .update({ search_index: record.search_index })
          .eq("id", existing[0].id)

        if (!error) updated++
      } else {
        skipped++
      }
    }

    const latestRecord = records[records.length - 1]

    return new Response(
      JSON.stringify({
        success: true,
        days_processed: records.length,
        inserted,
        updated,
        skipped,
        latest_date: latestRecord?.recorded_date,
        latest_index: latestRecord?.search_index,
        min_views: minViews,
        max_views: maxViews,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: "Internal error", detail: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    )
  }
})

/** Format Date as "YYYYMMDD" for Wikipedia API */
function formatDate(d: Date): string {
  const y = d.getUTCFullYear()
  const m = String(d.getUTCMonth() + 1).padStart(2, "0")
  const day = String(d.getUTCDate()).padStart(2, "0")
  return `${y}${m}${day}`
}

/** Parse Wikipedia timestamp "2025010100" → "2025-01-01" */
function parseWikiTimestamp(ts: string): string {
  return `${ts.slice(0, 4)}-${ts.slice(4, 6)}-${ts.slice(6, 8)}`
}
