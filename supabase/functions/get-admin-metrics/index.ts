import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
)

// Subscription pricing in cents — keep in sync with Stripe Price IDs and
// the published Terms of Service. Env-var overrides allow ops to adjust
// without redeploying when promotional pricing is active.
const PRICES = {
  founding: {
    monthly: parseInt(Deno.env.get("FOUNDING_MONTHLY_CENTS") ?? "3999"),  // $39.99
    annual:  parseInt(Deno.env.get("FOUNDING_ANNUAL_CENTS")  ?? "40000"), // $400.00
  },
  standard: {
    monthly: parseInt(Deno.env.get("STANDARD_MONTHLY_CENTS") ?? "6999"),  // $69.99
    annual:  parseInt(Deno.env.get("STANDARD_ANNUAL_CENTS")  ?? "70000"), // $700.00
  },
} as const

type Tier = keyof typeof PRICES
type Plan = keyof typeof PRICES["founding"]

// Internal accounts — the founder's own logins and Apple's App Review reviewer
// accounts. These are excluded from every member and revenue metric so the
// dashboard reflects REAL external customers, not us and the reviewer. Override
// the personal-email list via env (comma-separated) without redeploying.
const INTERNAL_EMAILS = new Set(
  (Deno.env.get("INTERNAL_EMAILS") ??
    "mneal.jw@gmail.com,mneal.jw+customer@gmail.com,mattmneal1@gmail.com,neal.matthew@protonmail.com")
    .split(",")
    .map(e => e.trim().toLowerCase())
    .filter(Boolean)
)

function isInternalEmail(email: string | null | undefined): boolean {
  if (!email) return false
  const e = email.toLowerCase()
  if (e.endsWith("@arkline.io")) return true   // reviewer@, reviewer-expired@, etc.
  if (e.startsWith("mneal.jw+")) return true    // any gmail plus-alias of the founder
  return INTERNAL_EMAILS.has(e)
}

const corsHeaders = {
  // Production web app origin (the dashboard lives at arkline.io, not web.arkline.io)
  "Access-Control-Allow-Origin": "https://arkline.io",
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

/**
 * Convert a (tier, plan) pair to its monthly recurring revenue contribution
 * in cents. Annual subscriptions are amortized over 12 months.
 */
function monthlyRevenueCents(tier: Tier, plan: Plan): number {
  const priceCents = PRICES[tier][plan]
  return plan === "annual" ? priceCents / 12 : priceCents
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
    // Identify internal accounts (founder + Apple reviewer) so they can be
    // excluded from every count below.
    const { data: allProfiles } = await supabase
      .from("profiles")
      .select("id, email, subscription_status")
    const profilesList = allProfiles ?? []
    const internalIds = new Set(
      profilesList.filter(p => isInternalEmail(p.email)).map(p => p.id)
    )

    // Pull every subscription with the columns we need for revenue math, then
    // keep only subs belonging to a known EXTERNAL profile. Requiring a profile
    // (not just "not internal") matters: mid-onboarding test accounts have no
    // profiles row, so an exclusion list built from profiles can't catch them —
    // that's how a sandbox sub once made Active read 4 while Total read 3.
    const externalIds = new Set(
      profilesList.filter(p => !isInternalEmail(p.email)).map(p => p.id)
    )
    const { data: subscriptions, error: subsError } = await supabase
      .from("subscriptions")
      .select("user_id, plan, tier, status, source, updated_at, current_period_end, trial_end")

    if (subsError) throw subsError
    const subs = (subscriptions ?? []).filter(s => externalIds.has(s.user_id))

    // A subscription only grants access while its billing/trial period is still
    // open. The stored `status` string goes stale — a lapsed trial keeps reading
    // 'trialing' because no webhook updates the row after it ends — so every
    // count below must also check the date, matching `is_user_subscribed()`.
    // Without this, an expired trial (like a trial that ended weeks ago) still
    // inflates Active/trial counts and pipeline MRR.
    const nowMs = Date.now()
    // deno-lint-ignore no-explicit-any
    const isCurrent = (s: any) =>
      (s.status === "active" || s.status === "trialing") &&
      (!s.current_period_end || new Date(s.current_period_end).getTime() > nowMs)

    // ---- Active revenue computation ----
    // MRR is the sum of monthly contribution from every PAYING subscription whose
    // status is 'active' or 'trialing' (trialing customers will most likely
    // convert; including them gives a more useful forward-looking number).
    //
    // Comped subscriptions (source='comp') pay nothing today, so they must NOT
    // count toward MRR/ARR — including them overstates real cash. But they are
    // convertible pipeline (many comps will start paying later), so we track them
    // separately: how many there are and how much they WOULD contribute at their
    // current tier/plan if they convert.
    let mrrCents = 0
    let compedActive = 0
    let compedPotentialCents = 0
    let trialsActive = 0
    let trialPotentialCents = 0
    const breakdown = {
      founding_monthly: 0,
      founding_annual: 0,
      standard_monthly: 0,
      standard_annual: 0,
    }

    for (const s of subs) {
      // Skip subs that aren't currently granting access (includes lapsed trials
      // and expired paid periods that still read active/trialing in the row).
      if (!isCurrent(s)) continue
      const tier = (s.tier as Tier) ?? "standard"
      const plan = (s.plan as Plan) ?? "monthly"
      if (!(tier in PRICES) || !(plan in PRICES[tier])) continue

      const contributionCents = monthlyRevenueCents(tier, plan)

      if (s.source === "comp") {
        compedActive += 1
        compedPotentialCents += contributionCents
        continue
      }

      // Free trials haven't paid anything yet and may cancel — they are
      // pipeline (like comps), NOT MRR. They convert into MRR when Apple
      // bills them and the webhook flips status to 'active'.
      if (s.status === "trialing") {
        trialsActive += 1
        trialPotentialCents += contributionCents
        continue
      }

      mrrCents += contributionCents
      const key = `${tier}_${plan}` as keyof typeof breakdown
      breakdown[key] += 1
    }

    const mrr = mrrCents / 100
    const arr = mrr * 12
    const compedPotentialMrr = compedPotentialCents / 100
    const compedPotentialArr = compedPotentialMrr * 12
    const trialPotentialMrr = trialPotentialCents / 100

    // ---- Status counts ----
    // Active/trialing require the period to still be open (date-aware), so an
    // expired trial no longer inflates these. past_due/canceled/incomplete are
    // terminal states and stand on their own.
    const counts = {
      active: subs.filter(s => s.status === "active" && isCurrent(s)).length,
      trialing: subs.filter(s => s.status === "trialing" && isCurrent(s)).length,
      past_due: subs.filter(s => s.status === "past_due").length,
      canceled: subs.filter(s => s.status === "canceled").length,
      incomplete: subs.filter(s => s.status === "incomplete").length,
    }

    // ---- Total members ever (external accounts with any subscription activity) ----
    const totalMembers = profilesList.filter(
      p => !internalIds.has(p.id) && p.subscription_status && p.subscription_status !== "none"
    ).length

    // ---- 30-day churn rate ----
    // (canceled in last 30 days) / (active at start of period)
    // We approximate "active at start" as currently-active + recently-canceled.
    // Computed from the already-external-filtered subscription set.
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()
    const recentlyCanceled = subs.filter(
      s => s.status === "canceled" && s.updated_at && s.updated_at >= thirtyDaysAgo
    ).length

    const activeForChurn = counts.active + counts.trialing
    const churnRate = activeForChurn > 0
      ? (recentlyCanceled / (activeForChurn + recentlyCanceled)) * 100
      : 0

    // ---- Founding-member counts (capped at 150 in webhook) ----
    const { count: foundingClaimed } = await supabase
      .from("invite_codes")
      .select("id", { count: "exact", head: true })
      .eq("tier", "founding")
      .not("used_by", "is", null)

    const { count: foundingPending } = await supabase
      .from("invite_codes")
      .select("id", { count: "exact", head: true })
      .eq("tier", "founding")
      .eq("payment_status", "pending_payment")

    const FOUNDING_CAP = 150
    const foundingRemaining = Math.max(
      0,
      FOUNDING_CAP - (foundingClaimed ?? 0) - (foundingPending ?? 0),
    )

    return jsonResponse({
      // Revenue (paying subscriptions only — comps excluded)
      mrr: Math.round(mrr * 100) / 100,
      arr: Math.round(arr * 100) / 100,
      revenue_breakdown: breakdown,

      // Comped pipeline — active comps pay $0 now but many convert later. This is
      // the MRR/ARR they WOULD add at their current tier/plan if they start paying.
      comped_active: compedActive,
      comped_potential_mrr: Math.round(compedPotentialMrr * 100) / 100,
      comped_potential_arr: Math.round(compedPotentialArr * 100) / 100,

      // Free-trial pipeline — in trial now, becomes MRR only when Apple bills
      trials_active: trialsActive,
      trial_potential_mrr: Math.round(trialPotentialMrr * 100) / 100,

      // Member counts
      total_members: totalMembers ?? 0,
      active_members: counts.active,
      trialing_members: counts.trialing,
      past_due_members: counts.past_due,
      canceled_members: counts.canceled,
      incomplete_members: counts.incomplete,

      // Health
      churn_rate: Math.round(churnRate * 100) / 100,

      // Founding membership
      founding_members: foundingClaimed ?? 0,
      founding_pending: foundingPending ?? 0,
      founding_remaining: foundingRemaining,
      founding_cap: FOUNDING_CAP,
    })
  } catch (err) {
    console.error("get-admin-metrics error:", err)
    return jsonResponse({ error: "Internal server error" }, 500)
  }
})
