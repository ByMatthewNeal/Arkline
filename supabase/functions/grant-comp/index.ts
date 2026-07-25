// Arkline — Admin Comp Grant / Remove (with pre-comp)
//
// Lets an admin give a person free access by email — forever or for N days —
// and revoke it. If the person already has an account we write the comp
// subscription row now. If they HAVEN'T signed up yet, we store a pending comp;
// a trigger on auth.users applies it automatically the moment they sign up
// (see migration pending_comps_and_signup_trigger). So you can comp someone at a
// dinner before they've downloaded the app.
//
// Access is gated by is_user_subscribed:
//   status IN ('active','trialing') AND (current_period_end IS NULL OR > now())
// A timed comp auto-expires; days = 0 means forever; revoke cancels immediately.
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

async function hasOtherActiveSub(userId: string, excludeId: string): Promise<boolean> {
  const nowIso = new Date().toISOString()
  const { data } = await supabase
    .from("subscriptions")
    .select("id, status, current_period_end")
    .eq("user_id", userId)
    .neq("id", excludeId)
  return (data ?? []).some(s =>
    (s.status === "active" || s.status === "trialing") &&
    (s.current_period_end === null || s.current_period_end > nowIso)
  )
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405)

  const admin = await verifyAdmin(req)
  if (!admin) return json({ error: "Admin access required" }, 403)

  let payload: { email?: string; tier?: string; plan?: string; days?: number; revoke?: boolean }
  try {
    payload = await req.json()
  } catch {
    return json({ error: "Invalid JSON body" }, 400)
  }

  const email = (payload.email ?? "").trim().toLowerCase()
  const tier = payload.tier ?? "founding"
  const plan = payload.plan ?? "monthly"
  const revoke = payload.revoke === true
  const days = Number.isFinite(payload.days) ? Math.floor(payload.days as number) : 0
  if (!email) return json({ error: "email is required" }, 400)
  if (!revoke) {
    if (tier !== "founding" && tier !== "standard") return json({ error: "tier must be founding or standard" }, 400)
    if (plan !== "monthly" && plan !== "annual") return json({ error: "plan must be monthly or annual" }, 400)
    if (days < 0 || days > 3650) return json({ error: "days must be 0–3650 (0 = forever)" }, 400)
  }

  const durationText = days > 0 ? `${days} day${days === 1 ? "" : "s"}` : "forever"

  // Is there already an account for this email?
  const { data: list, error: listErr } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1000 })
  if (listErr) {
    console.error("[grant-comp] listUsers error", listErr)
    return json({ error: "Lookup failed" }, 500)
  }
  const authUser = list.users.find(u => (u.email ?? "").toLowerCase() === email)
  const now = new Date()
  const nowIso = now.toISOString()

  // ─── No account yet: work with the pending_comps queue ───
  if (!authUser) {
    if (revoke) {
      const { data: pend } = await supabase
        .from("pending_comps").select("id").ilike("email", email).maybeSingle()
      if (!pend) return json({ ok: false, message: `${email} has no comp or pending comp to remove.` })
      await supabase.from("pending_comps").delete().eq("id", pend.id)
      return json({ ok: true, removed: true, message: `Removed the pending comp for ${email}.` })
    }
    // Store a pre-comp; the auth.users signup trigger applies it automatically.
    const { error: pErr } = await supabase.from("pending_comps").upsert({
      email, tier, plan, days, created_by: admin.id, redeemed_at: null, redeemed_user_id: null,
    }, { onConflict: "email" })
    if (pErr) {
      console.error("[grant-comp] pending upsert error", pErr)
      return json({ error: "Failed to save pre-comp" }, 500)
    }
    console.log(`[grant-comp] ${admin.id} pre-comped ${email} (${tier}/${plan}, ${durationText})`)
    return json({
      ok: true, pending: true,
      message: `Pre-comped ${email} — ${tier} ${plan}, ${durationText}. Applies automatically when they sign up.`,
    })
  }

  // ─── Account exists: write/cancel the comp row now ───
  const userId = authUser.id
  const { data: existing } = await supabase
    .from("subscriptions").select("id").eq("user_id", userId).eq("source", "comp").maybeSingle()

  if (revoke) {
    // Clear any leftover pending row too.
    await supabase.from("pending_comps").delete().ilike("email", email)
    if (!existing) return json({ ok: false, message: `${email} has no comp to remove.` })
    const { error: rErr } = await supabase.from("subscriptions").update({
      status: "canceled", current_period_end: nowIso, updated_at: nowIso,
    }).eq("id", existing.id)
    if (rErr) {
      console.error("[grant-comp] revoke error", rErr)
      return json({ error: "Failed to remove comp" }, 500)
    }
    if (!(await hasOtherActiveSub(userId, existing.id))) {
      await supabase.from("profiles").update({ subscription_status: "none" }).eq("id", userId)
    }
    console.log(`[grant-comp] ${admin.id} removed comp for ${email}`)
    return json({ ok: true, removed: true, message: `Removed comp for ${email}.`, user_id: userId })
  }

  const periodEnd = days > 0
    ? new Date(now.getTime() + days * 24 * 60 * 60 * 1000).toISOString()
    : null

  if (existing) {
    const { error: uErr } = await supabase.from("subscriptions").update({
      status: "active", tier, plan,
      current_period_start: nowIso, current_period_end: periodEnd, updated_at: nowIso,
    }).eq("id", existing.id)
    if (uErr) {
      console.error("[grant-comp] update error", uErr)
      return json({ error: "Failed to update comp" }, 500)
    }
  } else {
    const { error: iErr } = await supabase.from("subscriptions").insert({
      user_id: userId, source: "comp", status: "active", tier, plan,
      current_period_start: nowIso, current_period_end: periodEnd,
    })
    if (iErr) {
      console.error("[grant-comp] insert error", iErr)
      return json({ error: "Failed to create comp" }, 500)
    }
  }

  await supabase.from("profiles").update({ subscription_status: "active" }).eq("id", userId)

  console.log(`[grant-comp] ${admin.id} comped ${email} (${tier}/${plan}, ${durationText})`)
  return json({
    ok: true,
    message: `Comped ${email} — ${tier} ${plan}, ${durationText}.`,
    user_id: userId, tier, plan, days, expires_at: periodEnd,
  })
})
