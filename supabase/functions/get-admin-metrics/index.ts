import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
)

const MONTHLY_PRICE_CENTS = parseInt(Deno.env.get("MONTHLY_PRICE_CENTS") ?? "1999")
const ANNUAL_PRICE_CENTS = parseInt(Deno.env.get("ANNUAL_PRICE_CENTS") ?? "14999")

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
    // Get all subscriptions
    const { data: subscriptions } = await supabase
      .from("subscriptions")
      .select("plan, status")

    const subs = subscriptions ?? []

    const activeMonthlySubs = subs.filter(s => s.status === "active" && s.plan === "monthly").length
    const activeAnnualSubs = subs.filter(s => s.status === "active" && s.plan === "annual").length
    const trialingSubs = subs.filter(s => s.status === "trialing").length
    const canceledSubs = subs.filter(s => s.status === "canceled").length
    const pastDueSubs = subs.filter(s => s.status === "past_due").length
    const pausedSubs = subs.filter(s => s.status === "paused").length

    // MRR = monthly revenue + annual revenue / 12
    const mrr = (activeMonthlySubs * MONTHLY_PRICE_CENTS / 100) +
                (activeAnnualSubs * ANNUAL_PRICE_CENTS / 100 / 12)
    const arr = mrr * 12

    // Total members (profiles with any subscription activity)
    const { count: totalMembers } = await supabase
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .neq("subscription_status", "none")

    // Churn rate: canceled in last 30 days / total active at start of period
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()
    const { count: recentlyCanceled } = await supabase
      .from("subscriptions")
      .select("id", { count: "exact", head: true })
      .eq("status", "canceled")
      .gte("updated_at", thirtyDaysAgo)

    const activeTotal = activeMonthlySubs + activeAnnualSubs + trialingSubs
    const churnRate = activeTotal > 0
      ? ((recentlyCanceled ?? 0) / (activeTotal + (recentlyCanceled ?? 0))) * 100
      : 0

    // Founding members
    const { count: foundingMembers } = await supabase
      .from("invite_codes")
      .select("id", { count: "exact", head: true })
      .eq("tier", "founding")
      .not("used_by", "is", null)

    return jsonResponse({
      mrr: Math.round(mrr * 100) / 100,
      arr: Math.round(arr * 100) / 100,
      total_members: totalMembers ?? 0,
      active_members: activeMonthlySubs + activeAnnualSubs,
      trialing_members: trialingSubs,
      canceled_members: canceledSubs,
      past_due_members: pastDueSubs,
      paused_members: pausedSubs,
      churn_rate: Math.round(churnRate * 100) / 100,
      founding_members: foundingMembers ?? 0,
    })
  } catch (err) {
    console.error("get-admin-metrics error:", err)
    return jsonResponse({ error: "Internal server error" }, 500)
  }
})
