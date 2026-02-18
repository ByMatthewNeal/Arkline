import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@17"

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2024-12-18.acacia",
})

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
    const { stripe_subscription_id, cancel_at_period_end } = await req.json()

    if (!stripe_subscription_id) {
      return jsonResponse({ error: "stripe_subscription_id is required" }, 400)
    }

    let result
    if (cancel_at_period_end) {
      result = await stripe.subscriptions.update(stripe_subscription_id, {
        cancel_at_period_end: true,
      })
    } else {
      result = await stripe.subscriptions.cancel(stripe_subscription_id)
    }

    // Update local DB
    const newStatus = cancel_at_period_end ? "active" : "canceled"
    await supabase
      .from("subscriptions")
      .update({ status: newStatus, updated_at: new Date().toISOString() })
      .eq("stripe_subscription_id", stripe_subscription_id)

    // Sync to profile
    const { data: sub } = await supabase
      .from("subscriptions")
      .select("user_id")
      .eq("stripe_subscription_id", stripe_subscription_id)
      .single()

    if (sub?.user_id) {
      await supabase
        .from("profiles")
        .update({ subscription_status: newStatus })
        .eq("id", sub.user_id)
    }

    console.log(`Subscription ${stripe_subscription_id} ${cancel_at_period_end ? "set to cancel at period end" : "canceled immediately"} by admin ${admin.id}`)

    return jsonResponse({ success: true })
  } catch (err) {
    console.error("cancel-subscription error:", err)
    return jsonResponse({ error: "Failed to cancel subscription" }, 500)
  }
})
