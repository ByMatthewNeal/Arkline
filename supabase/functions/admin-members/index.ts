import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
)

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://web.arkline.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

// Internal accounts — founder logins, plus-aliases and Apple reviewer accounts.
// Shown LAST in the members list and flagged is_internal (metrics exclude them).
const INTERNAL_EMAILS = new Set(
  (Deno.env.get("INTERNAL_EMAILS") ??
    "mneal.jw@gmail.com,mneal.jw+customer@gmail.com,mattmneal1@gmail.com,neal.matthew@protonmail.com")
    .split(",")
    .map(e => e.trim().toLowerCase())
    .filter(Boolean)
)

function isInternalEmail(email: string | null | undefined): boolean {
  if (!email) return false
  const e = email.toLowerCase()
  if (e.endsWith("@arkline.io")) return true   // reviewer@, reviewer-expired@, etc.
  if (e.startsWith("mneal.jw+")) return true    // any gmail plus-alias of the founder
  return INTERNAL_EMAILS.has(e)
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  })
}

async function verifyAdmin(req: Request) {
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) return null

  const token = authHeader.replace("Bearer ", "")
  const { data: { user }, error } = await supabase.auth.getUser(token)
  if (error || !user) return null

  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single()

  if (profile?.role !== "admin") return null
  return user
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  const admin = await verifyAdmin(req)
  if (!admin) {
    return jsonResponse({ error: "Admin access required" }, 403)
  }

  try {
    const body = req.method === "POST" ? await req.json() : {}
    const search = body.search ?? null
    const status = body.status ?? null
    const page = body.page ?? 1
    const perPage = body.per_page ?? 50

    // Fetch profiles and subscriptions separately and join in code. The old
    // PostgREST embed `subscriptions(...)` requires a profiles<->subscriptions
    // foreign key, which no longer exists (subscriptions reference auth.users so
    // webhook/comp rows can precede the profile row).
    let query = supabase
      .from("profiles")
      .select("id, email, username, full_name, role, subscription_status, is_active, created_at")
      .order("created_at", { ascending: false })

    if (search) {
      // Sanitize: strip PostgREST filter metacharacters to prevent filter injection
      const sanitized = String(search).replace(/[,().\\%_]/g, "")
      if (sanitized.length > 0) {
        query = query.or(`email.ilike.%${sanitized}%,username.ilike.%${sanitized}%,full_name.ilike.%${sanitized}%`)
      }
    }

    const { data: rows, error } = await query

    if (error) {
      console.error("Query error:", error)
      return jsonResponse({ error: "Failed to fetch members" }, 500)
    }

    // Attach each user's subscriptions (manual join by user_id).
    const ids = (rows ?? []).map(r => r.id)
    // deno-lint-ignore no-explicit-any
    const subsByUser = new Map<string, any[]>()
    if (ids.length > 0) {
      const { data: subs, error: subsErr } = await supabase
        .from("subscriptions")
        .select("id, user_id, source, stripe_customer_id, stripe_subscription_id, plan, status, current_period_start, current_period_end, trial_end")
        .in("user_id", ids)
      if (subsErr) {
        console.error("Subscriptions query error:", subsErr)
        return jsonResponse({ error: "Failed to fetch members" }, 500)
      }
      for (const s of subs ?? []) {
        const list = subsByUser.get(s.user_id) ?? []
        list.push(s)
        subsByUser.set(s.user_id, list)
      }
    }

    // Real external members FIRST, internal accounts last, is_internal flagged.
    const tagged = (rows ?? []).map(r => ({
      ...r,
      subscriptions: subsByUser.get(r.id) ?? [],
      is_internal: isInternalEmail(r.email),
    }))

    // Source-aware filters reflecting the actual business states:
    //   paying   — valid (unexpired active/trialing) apple or stripe subscription
    //   comp     — valid comp subscription (the convertible pipeline)
    //   none     — no valid subscription of any kind ("No Access")
    //   active   — any valid subscription (paying or comp)
    //   canceled — had a subscription but nothing valid now
    // Any other value falls back to matching the profile status (legacy clients).
    const nowIso = new Date().toISOString()
    // deno-lint-ignore no-explicit-any
    const hasValid = (r: any, sources: string[] | null) =>
      r.subscriptions.some((s: any) =>
        (s.status === "active" || s.status === "trialing") &&
        (s.current_period_end === null || s.current_period_end > nowIso) &&
        (sources === null || sources.includes(s.source)))

    let filtered = tagged
    if (status && status !== "all") {
      switch (status) {
        case "paying":
          filtered = tagged.filter(r => hasValid(r, ["apple", "stripe"]))
          break
        case "comp":
          filtered = tagged.filter(r => hasValid(r, ["comp"]))
          break
        case "none":
          filtered = tagged.filter(r => !hasValid(r, null))
          break
        case "active":
          filtered = tagged.filter(r => hasValid(r, null))
          break
        case "canceled":
          // deno-lint-ignore no-explicit-any
          filtered = tagged.filter(r =>
            !hasValid(r, null) &&
            (r.subscription_status === "canceled" ||
             r.subscriptions.some((s: any) => s.status === "canceled")))
          break
        default:
          filtered = tagged.filter(r => r.subscription_status === status)
      }
    }

    const ordered = [...filtered.filter(r => !r.is_internal), ...filtered.filter(r => r.is_internal)]
    const offset = (page - 1) * perPage
    const paged = ordered.slice(offset, offset + perPage)

    return jsonResponse({
      members: paged,
      total: ordered.length,
      page,
      per_page: perPage,
    })
  } catch (err) {
    console.error("admin-members error:", err)
    return jsonResponse({ error: "Internal server error" }, 500)
  }
})
