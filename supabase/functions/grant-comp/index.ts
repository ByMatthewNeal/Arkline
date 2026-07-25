// Arkline — Admin Comp Grant
//
// Lets an admin give a person free access by email. Writes an active
// source='comp' subscription row (no expiry), which is what is_user_subscribed
// checks — so the comped user sails past the onboarding paywall for free.
//
// This replaces comp-via-invite-code now that invite codes are retired. Comps,
// Stripe (web) and Apple (IAP) all live in the same subscriptions table, and
// is_user_subscribed is the single access gate.
//
// Auth: admin JWT only (profiles.role = 'admin').

import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
)

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

function json(body: unknown, status = 200) {
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
    .from("profiles").select("role").eq("id", user.id).single()
  if (profile?.role !== "admin") return null
  return user
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405)

  const admin = await verifyAdmin(req)
  if (!admin) return json({ error: "Admin access required" }, 403)

  let payload: { email?: string; tier?: string; plan?: string }
  try {
    payload = await req.json()
  } catch {
    return json({ error: "Invalid JSON body" }, 400)
  }

  const email = (payload.email ?? "").trim().toLowerCase()
  const tier = payload.tier ?? "founding"   // founding is the early-customer default
  const plan = payload.plan ?? "monthly"
  if (!email) return json({ error: "email is required" }, 400)
  if (tier !== "founding" && tier !== "standard") {
    return json({ error: "tier must be founding or standard" }, 400)
  }
  if (plan !== "monthly" && plan !== "annual") {
    return json({ error: "plan must be monthly or annual" }, 400)
  }

  // Find the user by email. profiles.email is populated at onboarding, so a real
  // account always has one. If we can't find them, they haven't signed up yet.
  const { data: profile, error: pErr } = await supabase
    .from("profiles").select("id, email").ilike("email", email).maybeSingle()
  if (pErr) {
    console.error("[grant-comp] lookup error", pErr)
    return json({ error: "Lookup failed" }, 500)
  }
  if (!profile) {
    return json({
      ok: false,
      notFound: true,
      message: `No Arkline account for ${email} yet. Ask them to sign up in the app first, then grant the comp.`,
    })
  }
  const userId = profile.id
  const now = new Date().toISOString()

  // Idempotent: update the user's existing comp row if they have one, else insert.
  const { data: existing } = await supabase
    .from("subscriptions").select("id").eq("user_id", userId).eq("source", "comp").maybeSingle()

  if (existing) {
    const { error: uErr } = await supabase.from("subscriptions").update({
      status: "active", tier, plan,
      current_period_start: now, current_period_end: null, updated_at: now,
    }).eq("id", existing.id)
    if (uErr) {
      console.error("[grant-comp] update error", uErr)
      return json({ error: "Failed to update comp" }, 500)
    }
  } else {
    const { error: iErr } = await supabase.from("subscriptions").insert({
      user_id: userId, source: "comp", status: "active", tier, plan,
      current_period_start: now, current_period_end: null,
    })
    if (iErr) {
      console.error("[grant-comp] insert error", iErr)
      return json({ error: "Failed to create comp" }, 500)
    }
  }

  // Keep the denormalized profile status consistent with the granted access.
  await supabase.from("profiles").update({ subscription_status: "active" }).eq("id", userId)

  console.log(`[grant-comp] ${admin.id} comped ${email} (${tier}/${plan})`)
  return json({ ok: true, message: `Comped ${email} — ${tier} ${plan}.`, user_id: userId, tier, plan })
})
