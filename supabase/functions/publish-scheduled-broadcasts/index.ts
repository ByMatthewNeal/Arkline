import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// Publishes broadcasts whose scheduled_at has arrived. Invoked every minute by
// pg_cron with the shared x-cron-secret (no JWT — verify_jwt is pinned false in
// supabase/config.toml). Flips status scheduled -> published and fires the same
// push notification an immediate publish would, reusing send-broadcast-notification.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const CRON_SECRET = Deno.env.get("CRON_SECRET")!

function json(obj: unknown, status = 200): Response {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

Deno.serve(async (req) => {
  const provided = req.headers.get("x-cron-secret")
  if (!CRON_SECRET || provided !== CRON_SECRET) {
    return json({ error: "Unauthorized" }, 401)
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE)
  const nowIso = new Date().toISOString()

  // Due = scheduled and the publish time has passed.
  const { data: due, error } = await supabase
    .from("broadcasts")
    .select("id, title, target_audience, tags")
    .eq("status", "scheduled")
    .lte("scheduled_at", nowIso)
    .order("scheduled_at", { ascending: true })
    .limit(25)

  if (error) return json({ error: error.message }, 500)
  if (!due || due.length === 0) return json({ published: 0, checked: 0 })

  let published = 0
  const results: Array<Record<string, unknown>> = []

  for (const b of due) {
    // Atomic flip: only publish if it's *still* scheduled, so overlapping cron
    // runs can never double-publish or double-notify.
    const { data: updated, error: upErr } = await supabase
      .from("broadcasts")
      .update({ status: "published", published_at: nowIso, scheduled_at: null })
      .eq("id", b.id)
      .eq("status", "scheduled")
      .select("id")

    if (upErr) {
      results.push({ id: b.id, error: upErr.message })
      continue
    }
    if (!updated || updated.length === 0) {
      // Already published by a concurrent run — skip silently.
      continue
    }
    published++

    // Fire the same notification an immediate publish would.
    const tags: string[] = Array.isArray(b.tags) ? b.tags : []
    const isDeck = tags.includes("marketUpdate") || tags.includes("weekly")
    try {
      const resp = await fetch(`${SUPABASE_URL}/functions/v1/send-broadcast-notification`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-cron-secret": CRON_SECRET },
        body: JSON.stringify({
          broadcast_id: b.id,
          title: isDeck ? "Weekly Market Update" : "New Insight",
          body: b.title,
          event_type: isDeck ? "market_deck" : undefined,
          target_audience: b.target_audience ?? { type: "all" },
        }),
      })
      results.push({ id: b.id, notified: resp.ok, notify_status: resp.status })
    } catch (e) {
      results.push({ id: b.id, notify_error: String(e) })
    }
  }

  return json({ published, checked: due.length, results })
})
