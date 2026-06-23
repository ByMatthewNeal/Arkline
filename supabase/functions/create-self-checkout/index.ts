import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@17"

/**
 * create-self-checkout
 *
 * Self-serve subscription checkout for the WEB onboarding flow. Unlike the
 * admin-only create-checkout-session (which generates an invite to email out),
 * this lets an already-signed-up user start their own Stripe Checkout.
 *
 * The session carries the user's email, so the existing stripe-webhook links
 * the subscription to their profile by email (upsertSubscription) and activates
 * subscription_status on invoice.paid — no webhook changes required.
 */

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2024-12-18.acacia",
})

// Founding member price IDs (live mode) — same as create-checkout-session.
const ALLOWED_PRICE_IDS = new Set([
  "price_1TXCJyPHuageZ7zbIGTJCHPl", // founding monthly ($39.99/mo)
  "price_1TXCOPPHuageZ7zb7d2HyeHc", // founding annual ($400/yr)
])

const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "https://web.arkline.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface SelfCheckoutRequest {
  price_id: string
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: corsHeaders,
    })
  }

  // Auth: any authenticated user (no admin gate — this is self-serve).
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Missing authorization" }), {
      status: 401,
      headers: corsHeaders,
    })
  }

  const supabaseAuth = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user }, error: authError } = await supabaseAuth.auth.getUser()
  if (authError || !user || !user.email) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: corsHeaders,
    })
  }

  let body: SelfCheckoutRequest
  try {
    body = await req.json()
  } catch {
    return new Response(JSON.stringify({ error: "Invalid body" }), {
      status: 400,
      headers: corsHeaders,
    })
  }

  if (!ALLOWED_PRICE_IDS.has(body.price_id)) {
    return new Response(JSON.stringify({ error: "Invalid price_id" }), {
      status: 400,
      headers: corsHeaders,
    })
  }

  try {
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer_email: user.email,
      line_items: [{ price: body.price_id, quantity: 1 }],
      success_url: "https://arkline.io/onboarding?paid=1",
      cancel_url: "https://arkline.io/onboarding",
      metadata: { user_id: user.id, self_serve: "true" },
      subscription_data: { metadata: { user_id: user.id, self_serve: "true" } },
    })

    console.log(`Self-serve checkout created for ${user.email} (${body.price_id})`)

    return new Response(JSON.stringify({ checkout_url: session.url }), {
      status: 200,
      headers: corsHeaders,
    })
  } catch (err) {
    console.error("create-self-checkout error:", err)
    return new Response(JSON.stringify({ error: "Failed to create checkout session" }), {
      status: 500,
      headers: corsHeaders,
    })
  }
})
