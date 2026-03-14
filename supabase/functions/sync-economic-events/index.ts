import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * sync-economic-events Edge Function
 *
 * Fetches economic calendar data from FMP for yesterday/today/tomorrow,
 * upserts into economic_events, computes beat/miss, and triggers
 * Claude analysis for events with actual values.
 *
 * Runs every 30 minutes via cron.
 */

const ALLOWED_CURRENCIES = new Set(["USD", "JPY"])
const ALLOWED_IMPACTS = new Set(["High", "Medium"])

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  const secret = req.headers.get("x-cron-secret") ?? ""
  if (!cronSecret || secret !== cronSecret) {
    return json({ error: "Unauthorized" }, 401)
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const fmpKey = Deno.env.get("FMP_API_KEY")
  if (!fmpKey) {
    return json({ error: "FMP_API_KEY not set" }, 500)
  }

  const supabase = createClient(supabaseUrl, supabaseKey)

  // Date range: yesterday through 7 days ahead (covers weekends + next week)
  const now = new Date()
  const yesterday = new Date(now)
  yesterday.setDate(yesterday.getDate() - 1)
  const weekAhead = new Date(now)
  weekAhead.setDate(weekAhead.getDate() + 7)

  const fromDate = formatDate(yesterday)
  const toDate = formatDate(weekAhead)

  // Fetch FMP economic calendar
  let fmpEvents: FmpEvent[]
  try {
    const resp = await fetch(
      `https://financialmodelingprep.com/stable/economic-calendar?from=${fromDate}&to=${toDate}&apikey=${fmpKey}`
    )
    if (!resp.ok) {
      const text = await resp.text()
      console.error(`FMP API error: ${resp.status} ${text}`)
      return json({ error: "FMP API error" }, 502)
    }
    fmpEvents = await resp.json()
  } catch (err) {
    console.error(`FMP fetch failed: ${err}`)
    return json({ error: "FMP fetch failed" }, 502)
  }

  if (!Array.isArray(fmpEvents)) {
    console.error("FMP returned non-array:", typeof fmpEvents)
    return json({ error: "Unexpected FMP response" }, 502)
  }

  // Filter to relevant currencies and impact levels
  const filtered = fmpEvents.filter(
    (e) => ALLOWED_CURRENCIES.has(e.currency) && ALLOWED_IMPACTS.has(e.impact)
  )

  let synced = 0
  let analyzed = 0

  // Upsert each event
  for (const event of filtered) {
    const eventTime = parseEventDateTime(event.date)
    const eventDate = event.date.split(" ")[0] // YYYY-MM-DD portion

    const actualStr = event.actual != null ? String(event.actual) : null
    const forecastStr = event.estimate != null ? String(event.estimate) : null
    const previousStr = event.previous != null ? String(event.previous) : null

    const beatMiss = computeBeatMiss(actualStr, forecastStr)

    const { error: upsertErr } = await supabase
      .from("economic_events")
      .upsert(
        {
          title: event.event,
          country: event.country,
          currency: event.currency,
          event_date: eventDate,
          event_time: eventTime,
          impact: event.impact.toLowerCase(),
          forecast: forecastStr,
          previous: previousStr,
          actual: actualStr,
          beat_miss: beatMiss,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "title,event_date" }
      )

    if (upsertErr) {
      console.error(`Upsert failed for "${event.event}": ${upsertErr.message}`)
    } else {
      synced++
    }
  }

  // Find events with actual values that haven't been analyzed yet
  const { data: unanalyzed, error: queryErr } = await supabase
    .from("economic_events")
    .select("id")
    .not("actual", "is", null)
    .is("claude_analysis", null)
    .in("impact", ["high", "medium"])

  if (queryErr) {
    console.error(`Query for unanalyzed events failed: ${queryErr.message}`)
  }

  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? ""

  // Trigger analysis for each unanalyzed event
  for (const event of unanalyzed ?? []) {
    try {
      await fetch(`${supabaseUrl}/functions/v1/analyze-economic-event`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${anonKey}`,
          "x-cron-secret": cronSecret,
        },
        body: JSON.stringify({ event_id: event.id }),
      })
      analyzed++
    } catch (err) {
      console.error(`Analysis trigger failed for ${event.id}: ${err}`)
    }
    // Small delay between analysis calls
    await new Promise((r) => setTimeout(r, 200))
  }

  const stats = { synced, analyzed, total_fetched: fmpEvents.length, filtered: filtered.length }
  console.log(`Economic events sync: ${JSON.stringify(stats)}`)
  return json(stats)
})

// ─── Types ────────────────────────────────────────────────────────────────────

interface FmpEvent {
  date: string       // "2026-03-11 08:30:00"
  event: string      // "CPI (YoY)"
  country: string    // "US"
  currency: string   // "USD"
  actual: number | null
  estimate: number | null
  previous: number | null
  impact: string     // "High" | "Medium" | "Low"
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function formatDate(d: Date): string {
  return d.toISOString().split("T")[0]
}

/**
 * Parse FMP date string as America/New_York timezone.
 * FMP returns "2026-03-11 08:30:00" which is in ET.
 */
function parseEventDateTime(dateStr: string): string {
  const isoLike = dateStr.replace(" ", "T")

  // Use Intl to determine if ET is currently EDT (-04:00) or EST (-05:00)
  const testDate = new Date(isoLike + "Z")
  const etFormat = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    timeZoneName: "short",
  }).format(testDate)
  const isEdt = etFormat.includes("EDT")
  const offset = isEdt ? "-04:00" : "-05:00"

  return isoLike + offset
}

/**
 * Compute beat/miss by comparing actual vs estimate numerically.
 * Handles percentage strings (strips % and K/M/B suffixes).
 */
function computeBeatMiss(actual: string | null, estimate: string | null): string | null {
  if (actual == null || estimate == null) return null

  const actualNum = parseNumericValue(actual)
  const estimateNum = parseNumericValue(estimate)

  if (actualNum == null || estimateNum == null) return null

  const diff = actualNum - estimateNum
  if (diff > 0.01) return "beat"
  if (diff < -0.01) return "miss"
  return "inline"
}

/**
 * Parse a numeric value from a string, stripping %, K, M, B suffixes.
 */
function parseNumericValue(value: string): number | null {
  let cleaned = value.trim().replace(/%/g, "")

  let multiplier = 1
  if (cleaned.endsWith("B") || cleaned.endsWith("b")) {
    multiplier = 1_000_000_000
    cleaned = cleaned.slice(0, -1)
  } else if (cleaned.endsWith("M") || cleaned.endsWith("m")) {
    multiplier = 1_000_000
    cleaned = cleaned.slice(0, -1)
  } else if (cleaned.endsWith("K") || cleaned.endsWith("k")) {
    multiplier = 1_000
    cleaned = cleaned.slice(0, -1)
  }

  const num = parseFloat(cleaned)
  if (isNaN(num)) return null
  return num * multiplier
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
