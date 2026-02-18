import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

interface GenerateInviteRequest {
  email?: string
  payment_status?: "paid" | "free_trial" | "none"
  stripe_checkout_session_id?: string
  trial_days?: number
  expiration_days?: number
  recipient_name?: string
  note?: string
  created_by?: string
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

  const { data: inviteCode, error: insertError } = await supabase
    .from("invite_codes")
    .insert({
      code,
      created_by: createdBy,
      expires_at: expiresAt.toISOString(),
      email: body.email ?? null,
      payment_status: body.payment_status ?? "none",
      stripe_checkout_session_id: body.stripe_checkout_session_id ?? null,
      trial_days: body.trial_days ?? null,
      recipient_name: body.recipient_name ?? null,
      note: body.note ?? null,
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
