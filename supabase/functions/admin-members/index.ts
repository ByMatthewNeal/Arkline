import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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
    const offset = (page - 1) * perPage

    // Build query for profiles with joined subscriptions
    let query = supabase
      .from("profiles")
      .select("id, email, username, full_name, role, subscription_status, is_active, created_at, subscriptions(id, stripe_customer_id, stripe_subscription_id, plan, status, current_period_start, current_period_end, trial_end)", { count: "exact" })
      .order("created_at", { ascending: false })
      .range(offset, offset + perPage - 1)

    // Apply filters
    if (status && status !== "all") {
      query = query.eq("subscription_status", status)
    }

    if (search) {
      query = query.or(`email.ilike.%${search}%,username.ilike.%${search}%,full_name.ilike.%${search}%`)
    }

    const { data: members, count, error } = await query

    if (error) {
      console.error("Query error:", error)
      return jsonResponse({ error: "Failed to fetch members" }, 500)
    }

    return jsonResponse({
      members: members ?? [],
      total: count ?? 0,
      page,
      per_page: perPage,
    })
  } catch (err) {
    console.error("admin-members error:", err)
    return jsonResponse({ error: "Internal server error" }, 500)
  }
})
