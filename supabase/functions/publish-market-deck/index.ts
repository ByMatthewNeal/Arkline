// publish-market-deck
//
// Server-side publisher for the weekly market deck. Ports the Swift
// MarketDeckViewModel.publish() + createBroadcastFromDeck() flow so the
// Sunday delivery no longer requires a human tap:
//   1. Finds the latest deck (or a specific deck_id) and flips draft → published
//   2. Creates the companion "Weekly Market Update" broadcast (Insights feed)
//   3. Calls send-broadcast-notification with event_type "market_deck"
//      (deep-links the push to the deck viewer in the iOS app)
//
// Scheduling: pg_cron fires this twice every Sunday — 16:00 UTC and 17:00 UTC —
// each with body {"et_guard_hour": 12}. The guard below lets only the run where
// it is currently 12:00 in America/New_York proceed, so delivery is exactly
// 12pm ET year-round without manual DST cron edits.
//
// Auth: x-cron-secret (pg_cron) OR an admin JWT (manual invocation).
// Idempotent: a deck already published is a no-op, so a duplicate cron fire
// or manual re-run never double-posts or double-pushes.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "https://web.arkline.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders })
}

/** Current hour (0-23) in America/New_York, DST-aware. */
function etHour(date = new Date()): number {
  const hour = new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    hour: "numeric",
    hour12: false,
  }).format(date)
  return parseInt(hour, 10) % 24
}

/** "Mar 23–27" or "Mar 30 – Apr 3", mirroring the Swift weekLabel. */
function weekLabel(weekStart: string, weekEnd: string): string {
  const fmt = (d: Date, withMonth: boolean) => {
    const month = d.toLocaleDateString("en-US", { month: "short", timeZone: "UTC" })
    const day = d.getUTCDate()
    return withMonth ? `${month} ${day}` : `${day}`
  }
  const start = new Date(`${weekStart}T00:00:00Z`)
  const end = new Date(`${weekEnd}T00:00:00Z`)
  const sameMonth = start.getUTCMonth() === end.getUTCMonth()
  return sameMonth
    ? `${fmt(start, true)}–${fmt(end, false)}`
    : `${fmt(start, true)} – ${fmt(end, true)}`
}

// Slide JSON shape (matches Swift Slide/SlideData coding):
// { id, type: "weeklyOutlook" | "cover" | ..., title, data: { type, payload: {...} } }
// deno-lint-ignore no-explicit-any
type SlideRow = { type?: string; data?: { type?: string; payload?: any } }

// deno-lint-ignore no-explicit-any
function buildBroadcastContent(deck: any): string {
  const slides: SlideRow[] = Array.isArray(deck.slides) ? deck.slides : []
  const parts: string[] = []

  const outlook = slides.find((s) => s.type === "weeklyOutlook")?.data?.payload
  if (outlook?.headline) parts.push(`**${outlook.headline}**`)
  if (outlook?.risk_asset_impact) parts.push(outlook.risk_asset_impact)

  const cover = slides.find((s) => s.type === "cover")?.data?.payload
  if (cover) {
    const stats: string[] = []
    if (typeof cover.btc_weekly_change === "number") {
      const sign = cover.btc_weekly_change >= 0 ? "+" : ""
      stats.push(`BTC ${sign}${cover.btc_weekly_change.toFixed(1)}%`)
    }
    if (cover.fear_greed_end != null) stats.push(`Fear & Greed: ${cover.fear_greed_end}`)
    if (cover.regime) stats.push(`Regime: ${cover.regime}`)
    if (stats.length > 0) parts.push(stats.join(" · "))
  }

  if (deck.admin_notes) parts.push(deck.admin_notes)

  parts.push(`Swipe through all ${slides.length} slides in the Weekly Market Update.`)
  return parts.join("\n\n")
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders })
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  const supabase = createClient(supabaseUrl, serviceKey)

  // ── Auth: admin JWT or cron secret (same pattern as generate-market-deck) ──
  const authHeader = req.headers.get("Authorization") ?? ""
  if (authHeader.startsWith("Bearer ")) {
    const jwt = authHeader.replace("Bearer ", "")
    const { data: userData, error: userError } = await supabase.auth.getUser(jwt)
    if (userError || !userData?.user) {
      return jsonResponse({ error: "Unauthorized" }, 401)
    }
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", userData.user.id)
      .single()
    if (profile?.role !== "admin") {
      return jsonResponse({ error: "Admin access required" }, 403)
    }
  } else {
    const secret = req.headers.get("x-cron-secret") ?? ""
    const expectedSecret = Deno.env.get("CRON_SECRET") ?? ""
    if (!expectedSecret || secret !== expectedSecret) {
      return jsonResponse({ error: "Unauthorized" }, 401)
    }
  }

  // deno-lint-ignore no-explicit-any
  let body: any = {}
  try {
    body = await req.json()
  } catch {
    // empty body is fine
  }

  // ── DST guard: dual cron entries both fire; only the true-noon one proceeds ──
  if (typeof body.et_guard_hour === "number" && etHour() !== body.et_guard_hour) {
    return jsonResponse({
      skipped: true,
      reason: `ET hour is ${etHour()}, guard requires ${body.et_guard_hour} (other DST cron entry will handle it)`,
    })
  }

  // ── Find the deck ──────────────────────────────────────────────────────────
  let deckQuery = supabase.from("market_update_decks").select("*")
  if (body.deck_id) {
    deckQuery = deckQuery.eq("id", body.deck_id)
  } else {
    deckQuery = deckQuery.order("week_start", { ascending: false }).limit(1)
  }
  const { data: decks, error: deckError } = await deckQuery
  if (deckError) return jsonResponse({ error: deckError.message }, 500)

  const deck = decks?.[0]
  if (!deck) {
    return jsonResponse({ skipped: true, reason: "No deck found to publish" })
  }
  if (deck.status === "published") {
    return jsonResponse({ skipped: true, reason: `Deck ${deck.id} already published` })
  }
  if (deck.status === "archived") {
    return jsonResponse({ skipped: true, reason: `Deck ${deck.id} is archived` })
  }

  // ── 1. Publish the deck ────────────────────────────────────────────────────
  const publishedAt = new Date().toISOString()
  const { error: updateError } = await supabase
    .from("market_update_decks")
    .update({ status: "published", published_at: publishedAt, updated_at: publishedAt })
    .eq("id", deck.id)
  if (updateError) return jsonResponse({ error: updateError.message }, 500)

  // ── 2. Create the companion broadcast (Insights feed post) ────────────────
  const { data: adminProfile } = await supabase
    .from("profiles")
    .select("id")
    .eq("role", "admin")
    .order("created_at", { ascending: true })
    .limit(1)
    .single()

  if (!adminProfile?.id) {
    return jsonResponse({
      published: true,
      deck_id: deck.id,
      warning: "Deck published but no admin profile found — broadcast + push skipped",
    })
  }

  const title = `Weekly Market Update — ${weekLabel(deck.week_start, deck.week_end)}`
  const { data: broadcast, error: broadcastError } = await supabase
    .from("broadcasts")
    .insert({
      title,
      content: buildBroadcastContent(deck),
      target_audience: { type: "all" },
      status: "published",
      published_at: publishedAt,
      tags: ["marketUpdate", "weekly"],
      author_id: adminProfile.id,
    })
    .select("id")
    .single()

  if (broadcastError) {
    return jsonResponse({
      published: true,
      deck_id: deck.id,
      warning: `Deck published but broadcast creation failed: ${broadcastError.message}`,
    })
  }

  // ── 3. Push notification (deep-links to the deck viewer via event_type) ───
  // Same invocation pattern as publish-scheduled: the service-role client's key
  // satisfies the gateway's verify_jwt, and x-cron-secret satisfies the
  // function's own auth check.
  let pushResult = "sent"
  try {
    const { error: pushError } = await supabase.functions.invoke("send-broadcast-notification", {
      body: {
        broadcast_id: broadcast.id,
        title: "Weekly Market Update",
        body: title,
        event_type: "market_deck",
        target_audience: { type: "all" },
      },
      headers: { "x-cron-secret": Deno.env.get("CRON_SECRET") ?? "" },
    })
    if (pushError) pushResult = `failed: ${pushError.message}`
  } catch (e) {
    pushResult = `failed: ${e instanceof Error ? e.message : String(e)}`
  }

  console.log(`Published deck ${deck.id}, broadcast ${broadcast.id}, push: ${pushResult}`)
  return jsonResponse({
    published: true,
    deck_id: deck.id,
    broadcast_id: broadcast.id,
    push: pushResult,
  })
})
