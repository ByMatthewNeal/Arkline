import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@17"

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2024-12-18.acacia",
})

// Founding member price IDs (live mode)
const FOUNDING_PRICE_IDS = new Set([
  "price_1TXCJyPHuageZ7zbIGTJCHPl", // founding monthly ($39.99/mo)
  "price_1TXCOPPHuageZ7zb7d2HyeHc", // founding annual ($400/yr)
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
  "Access-Control-Allow-Origin": "https://web.arkline.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface CreateCheckoutRequest {
  email: string
  recipient_name?: string
  note?: string
  price_id: string
  trial_days?: number
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
      trial_days: body.trial_days ?? null,
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
  const planLabel = FOUNDING_PRICE_IDS.has(body.price_id) ? "founding" : "standard"
  const successUrl = `https://arkline.io/payment-success?plan=${planLabel}`

  let session: Stripe.Checkout.Session
  try {
    const checkoutParams: Stripe.Checkout.SessionCreateParams = {
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
        is_trial: body.trial_days ? "true" : "false",
      },
    }

    // Add trial period if specified
    if (body.trial_days && body.trial_days > 0) {
      checkoutParams.subscription_data = {
        trial_period_days: body.trial_days,
      }
    }

    session = await stripe.checkout.sessions.create(checkoutParams)
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

  // 5. Email the checkout link to the recipient (best-effort, doesn't block response)
  const emailSent = await sendCheckoutInviteEmail({
    email: body.email,
    recipientName: body.recipient_name,
    note: body.note,
    checkoutUrl: session.url ?? "",
    trialDays: body.trial_days,
  })

  const trialLabel = body.trial_days ? ` with ${body.trial_days}-day trial` : ""
  console.log(`Created checkout session for ${body.email} (${tier}${trialLabel}), invite ${invite.id}, code ${code}, email_sent=${emailSent}`)

  return new Response(JSON.stringify({
    success: true,
    checkout_url: session.url,
    invite_id: invite.id,
    code,
    email_sent: emailSent,
  }), {
    status: 200,
    headers: corsHeaders,
  })
})

// --- Email Helper ---

interface CheckoutEmailParams {
  email: string
  recipientName?: string
  note?: string
  checkoutUrl: string
  trialDays?: number
}

async function sendCheckoutInviteEmail(params: CheckoutEmailParams): Promise<boolean> {
  const resendKey = Deno.env.get("RESEND_API_KEY")
  if (!resendKey) {
    console.warn("RESEND_API_KEY not set — skipping checkout invite email")
    return false
  }
  if (!params.checkoutUrl) {
    console.warn("No checkout URL — skipping email")
    return false
  }

  const isTrial = !!(params.trialDays && params.trialDays > 0)
  const firstName = (params.recipientName ?? "").trim().split(/\s+/)[0] || ""
  const greeting = firstName ? `Hi ${firstName},` : "Hi there,"

  const subject = isTrial
    ? `Your Arkline ${params.trialDays}-day free trial is ready`
    : "Your Arkline membership is ready to activate"

  const headline = isTrial
    ? `Start your ${params.trialDays}-day free trial`
    : "Activate your Arkline membership"

  const subtitle = isTrial
    ? `Tap below to start your trial. Your card won't be charged until day ${(params.trialDays ?? 10) + 1}.`
    : "Tap below to complete checkout and get instant access."

  const noteBlock = params.note && params.note.trim().length > 0
    ? `<div style="background: #f8f9fa; border-radius: 8px; padding: 16px; margin-bottom: 24px; font-size: 14px; color: #555;">
         <p style="margin: 0;">${escapeHtml(params.note.trim())}</p>
       </div>`
    : ""

  const footer = isTrial
    ? "This invite link is unique to you and expires in 15 days. After your free trial, your membership will renew automatically unless you cancel."
    : "This invite link is unique to you and expires in 15 days."

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${resendKey}`,
      },
      body: JSON.stringify({
        from: "Arkline <onboarding@resend.dev>",
        to: [params.email],
        subject,
        html: `
          <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 20px;">
            <div style="text-align: center; margin-bottom: 32px;">
              <h1 style="font-size: 28px; font-weight: 700; color: #1a1a1a; margin: 0;">${headline}</h1>
              <p style="font-size: 16px; color: #666; margin-top: 8px;">${greeting}</p>
              <p style="font-size: 16px; color: #666; margin-top: 8px;">${subtitle}</p>
            </div>

            ${noteBlock}

            <div style="text-align: center; margin-bottom: 32px;">
              <a href="${params.checkoutUrl}" style="display: inline-block; background: #3369FF; color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-size: 16px; font-weight: 600;">Complete checkout</a>
            </div>

            <div style="border-top: 1px solid #eee; padding-top: 20px;">
              <p style="font-size: 13px; color: #999; text-align: center; margin: 0;">
                ${footer}
              </p>
            </div>
          </div>
        `,
      }),
    })

    if (res.ok) {
      console.log(`Checkout invite email sent to ${params.email} (trial: ${isTrial})`)
      return true
    }

    const errText = await res.text()
    console.error(`Failed to send checkout invite email: ${errText}`)
    return false
  } catch (err) {
    console.error("Error sending checkout invite email:", err)
    return false
  }
}

function escapeHtml(str: string): string {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
}
