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
    const { payment_intent_id, amount, reason } = await req.json()

    if (!payment_intent_id) {
      return jsonResponse({ error: "payment_intent_id is required" }, 400)
    }

    const refundParams: Stripe.RefundCreateParams = {
      payment_intent: payment_intent_id,
    }

    if (amount) refundParams.amount = amount
    if (reason) refundParams.reason = reason as Stripe.RefundCreateParams.Reason

    const refund = await stripe.refunds.create(refundParams)

    console.log(`Refund ${refund.id} created for payment ${payment_intent_id} by admin ${admin.id}`)

    return jsonResponse({
      success: true,
      refund: {
        id: refund.id,
        amount: refund.amount,
        status: refund.status,
      },
    })
  } catch (err) {
    console.error("refund-payment error:", err)
    return jsonResponse({ error: "Failed to create refund" }, 500)
  }
})
