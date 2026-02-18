import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@17"

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2024-12-18.acacia",
})

// Founding member price IDs
const FOUNDING_PRICE_IDS = new Set([
  "price_1T28pXIkKaS0zcmX7aKIiT2P", // founding monthly
  "price_1T28pXIkKaS0zcmXx8NpKPQr", // founding annual
])

// Matches iOS InviteCode.generateCode()
const CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
function generateCode(): string {
  return "ARK-" + Array.from({ length: 6 }, () =>
    CHARS[Math.floor(Math.random() * CHARS.length)]
  ).join("")
}

const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface CreateCheckoutRequest {
  email: string
  recipient_name?: string
  note?: string
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

  // Auth: JWT → verify user → check admin role
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
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: corsHeaders,
    })
  }

  const { data: profile } = await supabaseAuth
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single()

  if (profile?.role !== "admin") {
    return new Response(JSON.stringify({ error: "Admin access required" }), {
      status: 403,
      headers: corsHeaders,
    })
  }

  // Parse request
  const body: CreateCheckoutRequest = await req.json()

  if (!body.email || !body.email.includes("@")) {
    return new Response(JSON.stringify({ error: "Valid email required" }), {
      status: 400,
      headers: corsHeaders,
    })
  }

  if (!body.price_id) {
    return new Response(JSON.stringify({ error: "price_id required" }), {
      status: 400,
      headers: corsHeaders,
    })
  }

  // Use service role client for DB operations
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  )

  const tier = FOUNDING_PRICE_IDS.has(body.price_id) ? "founding" : "standard"

  const expiresAt = new Date()
  expiresAt.setDate(expiresAt.getDate() + 15)

  // 1. Generate a unique invite code
  let code = ""
  for (let attempt = 0; attempt < 5; attempt++) {
    code = generateCode()
    const { data } = await supabase
      .from("invite_codes")
      .select("id")
      .eq("code", code)
      .limit(1)
    if (!data || data.length === 0) break
  }

  // 2. Insert pending invite record
  const { data: invite, error: insertError } = await supabase
    .from("invite_codes")
    .insert({
      code,
      created_by: user.id,
      expires_at: expiresAt.toISOString(),
      email: body.email,
      recipient_name: body.recipient_name ?? null,
      note: body.note ?? null,
      payment_status: "pending_payment",
      tier,
    })
    .select("id")
    .single()

  if (insertError) {
    console.error("Failed to insert invite code:", insertError)
    return new Response(JSON.stringify({ error: insertError.message }), {
      status: 500,
      headers: corsHeaders,
    })
  }

  // 3. Create Stripe Checkout Session
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
  const planLabel = FOUNDING_PRICE_IDS.has(body.price_id) ? "founding" : "standard"
  const successUrl = `${supabaseUrl}/functions/v1/payment-success?plan=${planLabel}`

  let session: Stripe.Checkout.Session
  try {
    session = await stripe.checkout.sessions.create({
      mode: "subscription",
      customer_email: body.email,
      client_reference_id: invite.id,
      line_items: [{ price: body.price_id, quantity: 1 }],
      success_url: successUrl,
      cancel_url: "https://arkline.io",
      metadata: {
        invite_id: invite.id,
        recipient_name: body.recipient_name ?? "",
        admin_initiated: "true",
      },
    })
  } catch (err) {
    console.error("Failed to create Stripe checkout session:", err)
    // Clean up the invite record
    await supabase.from("invite_codes").delete().eq("id", invite.id)
    return new Response(JSON.stringify({ error: "Failed to create checkout session" }), {
      status: 500,
      headers: corsHeaders,
    })
  }

  // 4. Update invite with checkout URL and session ID
  await supabase
    .from("invite_codes")
    .update({
      stripe_checkout_session_id: session.id,
      checkout_url: session.url,
    })
    .eq("id", invite.id)

  console.log(`Created checkout session for ${body.email} (${tier}), invite ${invite.id}, code ${code}`)

  return new Response(JSON.stringify({
    success: true,
    checkout_url: session.url,
    invite_id: invite.id,
    code,
  }), {
    status: 200,
    headers: corsHeaders,
  })
})
