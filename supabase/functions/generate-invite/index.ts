import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

interface GenerateInviteRequest {
  email?: string
  payment_status?: "paid" | "free_trial" | "none" | "comped"
  stripe_checkout_session_id?: string
  trial_days?: number
  expiration_days?: number
  recipient_name?: string
  note?: string
  created_by?: string
  comped?: boolean
  send_email?: boolean
  tier?: string
}

// Matches iOS InviteCode.generateCode() — excludes ambiguous 0/O, 1/I/L
const CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

function generateCode(): string {
  const random = Array.from({ length: 6 }, () =>
    CHARS[Math.floor(Math.random() * CHARS.length)]
  ).join("")
  return `ARK-${random}`
}

const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-service-call, content-type",
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

  const isServiceCall = req.headers.get("X-Service-Call") === "true"
  const authHeader = req.headers.get("Authorization") ?? ""

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    isServiceCall
      ? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
      : Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    isServiceCall ? {} : { global: { headers: { Authorization: authHeader } } }
  )

  // Verify admin if not a service call (from stripe-webhook)
  if (!isServiceCall) {
    const { data: { user }, error } = await supabase.auth.getUser()
    if (error || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: corsHeaders,
      })
    }

    const { data: profile } = await supabase
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
  }

  const body: GenerateInviteRequest = await req.json()
  const expirationDays = body.expiration_days ?? 7

  // Generate unique code with collision retry
  let code: string = ""
  for (let attempt = 0; attempt < 5; attempt++) {
    code = generateCode()
    const { data } = await supabase
      .from("invite_codes")
      .select("id")
      .eq("code", code)
      .limit(1)
    if (!data || data.length === 0) break
  }

  const expiresAt = new Date()
  expiresAt.setDate(expiresAt.getDate() + expirationDays)

  const createdBy = body.created_by ?? Deno.env.get("SYSTEM_ADMIN_UUID") ?? ""

  // Determine payment_status: comped flag overrides
  const paymentStatus = body.comped ? "comped" : (body.payment_status ?? "none")

  const { data: inviteCode, error: insertError } = await supabase
    .from("invite_codes")
    .insert({
      code,
      created_by: createdBy,
      expires_at: expiresAt.toISOString(),
      email: body.email ?? null,
      payment_status: paymentStatus,
      stripe_checkout_session_id: body.stripe_checkout_session_id ?? null,
      trial_days: body.trial_days ?? null,
      recipient_name: body.recipient_name ?? null,
      note: body.note ?? null,
      tier: body.tier ?? "standard",
    })
    .select()
    .single()

  if (insertError) {
    console.error("Failed to insert invite code:", insertError)
    return new Response(JSON.stringify({ error: insertError.message }), {
      status: 500,
      headers: corsHeaders,
    })
  }

  // Send email if requested
  if (body.send_email && body.email) {
    await sendInviteEmail(body.email, code, body.recipient_name)
  }

  return new Response(JSON.stringify({
    success: true,
    code,
    deep_link: `arkline://invite?code=${code}`,
    invite: inviteCode,
  }), {
    status: 200,
    headers: corsHeaders,
  })
})

// --- Email ---

async function sendInviteEmail(email: string, code: string, name?: string) {
  const resendKey = Deno.env.get("RESEND_API_KEY")
  if (!resendKey) {
    console.warn("RESEND_API_KEY not set — skipping invite email")
    return
  }

  const deepLink = `arkline://invite?code=${code}`
  const greeting = name ? `Hi ${name},` : "Hi there,"

  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${resendKey}`,
      },
      body: JSON.stringify({
        from: "Arkline <onboarding@resend.dev>",
        to: [email],
        subject: "You're Invited to Arkline",
        html: `
          <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 20px;">
            <div style="text-align: center; margin-bottom: 32px;">
              <h1 style="font-size: 28px; font-weight: 700; color: #1a1a1a; margin: 0;">You're Invited</h1>
              <p style="font-size: 16px; color: #666; margin-top: 8px;">${greeting} you've been given complimentary access to Arkline.</p>
            </div>

            <div style="background: #f8f9fa; border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 24px;">
              <p style="font-size: 14px; color: #888; margin: 0 0 8px 0; text-transform: uppercase; letter-spacing: 1px;">Your Invite Code</p>
              <p style="font-size: 36px; font-weight: 700; color: #3369FF; margin: 0; letter-spacing: 3px;">${code}</p>
            </div>

            <div style="text-align: center; margin-bottom: 32px;">
              <a href="${deepLink}" style="display: inline-block; background: #3369FF; color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-size: 16px; font-weight: 600;">Open in Arkline</a>
            </div>

            <div style="border-top: 1px solid #eee; padding-top: 20px;">
              <p style="font-size: 13px; color: #999; text-align: center; margin: 0;">
                Enter this code in the Arkline app to activate your account.<br>
                This code expires in 15 days.
              </p>
            </div>
          </div>
        `,
      }),
    })

    if (res.ok) {
      console.log(`Comped invite email sent to ${email}`)
    } else {
      const err = await res.text()
      console.error(`Failed to send invite email: ${err}`)
    }
  } catch (err) {
    console.error("Error sending invite email:", err)
  }
}
