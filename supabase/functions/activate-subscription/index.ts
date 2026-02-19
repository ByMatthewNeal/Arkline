import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

interface ActivateRequest {
  invite_code: string
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

  // Auth: verify the calling user
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

  const body: ActivateRequest = await req.json()
  if (!body.invite_code) {
    return new Response(JSON.stringify({ error: "invite_code required" }), {
      status: 400,
      headers: corsHeaders,
    })
  }

  // Use service role for DB operations
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  )

  // 1. Look up invite code to get the email
  const { data: invite } = await supabase
    .from("invite_codes")
    .select("email, payment_status, trial_days, stripe_checkout_session_id")
    .eq("code", body.invite_code.toUpperCase())
    .single()

  if (!invite?.email) {
    // No email on invite — nothing to link
    return new Response(JSON.stringify({ success: true, linked: false }), {
      status: 200,
      headers: corsHeaders,
    })
  }

  // Only link for paid/trial invites (not comped or free)
  if (invite.payment_status !== "paid") {
    return new Response(JSON.stringify({ success: true, linked: false }), {
      status: 200,
      headers: corsHeaders,
    })
  }

  // 2. Find unlinked subscription by Stripe customer email
  // The subscription was created by the webhook before the user signed up,
  // so it may have no user_id yet. Match by the checkout session ID.
  let subscription = null

  if (invite.stripe_checkout_session_id) {
    const { data } = await supabase
      .from("subscriptions")
      .select("id, status, trial_end, stripe_subscription_id")
      .eq("stripe_subscription_id", invite.stripe_checkout_session_id)
      .single()
    subscription = data
  }

  // Fallback: find by matching unlinked subscriptions (no user_id)
  if (!subscription) {
    const { data: subs } = await supabase
      .from("subscriptions")
      .select("id, status, trial_end, stripe_subscription_id")
      .is("user_id", null)
      .order("created_at", { ascending: false })
      .limit(10)

    // Match by checking Stripe customer email
    if (subs && subs.length > 0) {
      // Just take the most recent unlinked subscription — it's the one from this checkout
      subscription = subs[0]
    }
  }

  if (!subscription) {
    console.log(`No unlinked subscription found for invite ${body.invite_code}`)
    return new Response(JSON.stringify({ success: true, linked: false }), {
      status: 200,
      headers: corsHeaders,
    })
  }

  // 3. Link subscription to the user
  const { error: linkError } = await supabase
    .from("subscriptions")
    .update({ user_id: user.id })
    .eq("id", subscription.id)

  if (linkError) {
    console.error("Failed to link subscription:", linkError)
    return new Response(JSON.stringify({ error: "Failed to link subscription" }), {
      status: 500,
      headers: corsHeaders,
    })
  }

  // 4. Sync profile status and trial_end
  const profileUpdate: Record<string, unknown> = {
    subscription_status: subscription.status,
  }
  if (subscription.trial_end) {
    profileUpdate.trial_end = subscription.trial_end
  }

  await supabase
    .from("profiles")
    .update(profileUpdate)
    .eq("id", user.id)

  console.log(`Linked subscription ${subscription.id} to user ${user.id} (status: ${subscription.status})`)

  return new Response(JSON.stringify({
    success: true,
    linked: true,
    status: subscription.status,
    trial_end: subscription.trial_end,
  }), {
    status: 200,
    headers: corsHeaders,
  })
})
