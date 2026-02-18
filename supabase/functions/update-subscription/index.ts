import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@17"

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2024-12-18.acacia",
})

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
)

// Price IDs for plan changes
const PRICE_IDS: Record<string, string> = {
  monthly: Deno.env.get("STANDARD_MONTHLY_PRICE") ?? "price_1T28pYIkKaS0zcmX5iNFEZxi",
  annual: Deno.env.get("STANDARD_ANNUAL_PRICE") ?? "price_1T28pZIkKaS0zcmXOsgwiMH5",
}

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
    const { stripe_subscription_id, new_plan } = await req.json()

    if (!stripe_subscription_id || !new_plan) {
      return jsonResponse({ error: "stripe_subscription_id and new_plan are required" }, 400)
    }

    const newPriceId = PRICE_IDS[new_plan]
    if (!newPriceId) {
      return jsonResponse({ error: "Invalid plan. Use 'monthly' or 'annual'" }, 400)
    }

    // Get current subscription to find the item ID
    const subscription = await stripe.subscriptions.retrieve(stripe_subscription_id)
    const itemId = subscription.items.data[0]?.id

    if (!itemId) {
      return jsonResponse({ error: "No subscription items found" }, 400)
    }

    // Update the subscription plan
    await stripe.subscriptions.update(stripe_subscription_id, {
      items: [{ id: itemId, price: newPriceId }],
      proration_behavior: "create_prorations",
    })

    // Update local DB
    await supabase
      .from("subscriptions")
      .update({ plan: new_plan, updated_at: new Date().toISOString() })
      .eq("stripe_subscription_id", stripe_subscription_id)

    console.log(`Subscription ${stripe_subscription_id} changed to ${new_plan} by admin ${admin.id}`)

    return jsonResponse({ success: true })
  } catch (err) {
    console.error("update-subscription error:", err)
    return jsonResponse({ error: "Failed to update subscription" }, 500)
  }
})
