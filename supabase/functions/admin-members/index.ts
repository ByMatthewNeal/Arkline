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
// Kept in sync with get-admin-metrics so the Members list matches the member
// counts on the dashboard/Revenue screens (real external members only).
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

    // Fetch matching profiles (no DB-side pagination — we filter out internal
    // accounts in code first so page counts stay correct; member volume is small).
    let query = supabase
      .from("profiles")
      .select("id, email, username, full_name, role, subscription_status, is_active, created_at, subscriptions(id, stripe_customer_id, stripe_subscription_id, plan, status, current_period_start, current_period_end, trial_end)")
      .order("created_at", { ascending: false })

    if (status && status !== "all") {
      query = query.eq("subscription_status", status)
    }

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

    // Show everyone, but real external members FIRST and internal accounts
    // (founder logins, test aliases, Apple reviewers) last — so actual members
    // aren't buried in internal noise. Each row carries is_internal so the UI
    // can badge them.
    const tagged = (rows ?? []).map(r => ({ ...r, is_internal: isInternalEmail(r.email) }))
    const ordered = [...tagged.filter(r => !r.is_internal), ...tagged.filter(r => r.is_internal)]
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
