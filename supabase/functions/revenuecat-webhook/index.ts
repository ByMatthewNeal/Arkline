// Arkline — RevenueCat Webhook Handler
//
// Receives subscription events from RevenueCat for Apple IAP purchases and
// keeps the public.subscriptions table in sync. Stripe subscriptions continue
// to be handled by the separate stripe-webhook function.
//
// Auth: RevenueCat sends an `Authorization` header with the value you set in
// the RevenueCat webhook dashboard. We verify it against the
// REVENUECAT_WEBHOOK_AUTH secret stored in Supabase function env.
//
// App User ID: when the iOS app initializes RevenueCat, it sets the app_user_id
// to the Supabase auth.users.id (UUID). So `app_user_id` in the payload IS the
// Supabase user_id.
//
// Handled events: INITIAL_PURCHASE, RENEWAL, CANCELLATION, UNCANCELLATION,
// EXPIRATION, BILLING_ISSUE, PRODUCT_CHANGE, REFUND, SUBSCRIPTION_EXTENDED.
// Unhandled events (TRANSFER, NON_RENEWING_PURCHASE, etc.) return 200 OK so
// RevenueCat doesn't retry; they're logged for observability.

import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'jsr:@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const REVENUECAT_WEBHOOK_AUTH = Deno.env.get('REVENUECAT_WEBHOOK_AUTH') ?? ''

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
})

interface RCEvent {
  type: string
  app_user_id: string
  original_app_user_id?: string
  product_id?: string
  original_transaction_id?: string
  transaction_id?: string
  purchased_at_ms?: number
  expiration_at_ms?: number
  event_timestamp_ms?: number
  cancel_reason?: string
  store?: string
  transferred_from?: string[]
  transferred_to?: string[]
  environment?: string // 'SANDBOX' or 'PRODUCTION'
  is_trial_period?: boolean
  period_type?: string // 'TRIAL' | 'INTRO' | 'NORMAL' | 'PROMOTIONAL'
}

interface RCPayload {
  api_version?: string
  event: RCEvent
}

function unauthorized(message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status: 401,
    headers: { 'Content-Type': 'application/json' },
  })
}

function ok(message: string, extra: Record<string, unknown> = {}) {
  return new Response(JSON.stringify({ ok: true, message, ...extra }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  })
}

function badRequest(message: string) {
  return new Response(JSON.stringify({ error: message }), {
    status: 400,
    headers: { 'Content-Type': 'application/json' },
  })
}

// Validate the user_id looks like a UUID. RevenueCat allows arbitrary strings,
// but we set app_user_id to the Supabase user UUID in the iOS app, so anything
// non-UUID is either an anonymous RC user or a misconfiguration — skip it.
function isUuid(str: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(str)
}

function toIso(ms?: number): string | null {
  if (!ms) return null
  return new Date(ms).toISOString()
}

// The subscriptions table constrains plan to 'monthly' | 'annual' and tier to
// 'founding' | 'standard'. Apple product ids are free-form (e.g.
// "arkline_pro_founding_monthly"), so map them here. The raw product id is kept
// separately in apple_product_id. Writing the raw id straight into `plan` was
// violating the CHECK constraint and 500-ing the insert.
function planFromProductId(productId?: string): 'monthly' | 'annual' {
  const p = (productId ?? '').toLowerCase()
  if (p.includes('annual') || p.includes('year') || p.includes('yr') || p.includes('12m')) {
    return 'annual'
  }
  return 'monthly'
}

function tierFromProductId(productId?: string): 'founding' | 'standard' {
  const p = (productId ?? '').toLowerCase()
  if (p.includes('standard')) return 'standard'
  return 'founding' // founding is the current early-customer default
}

function statusFromEventType(eventType: string, cancelReason?: string): string {
  switch (eventType) {
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
    case 'UNCANCELLATION':
    case 'PRODUCT_CHANGE':
    case 'SUBSCRIPTION_EXTENDED':
      return 'active'
    case 'CANCELLATION':
      // User cancelled but keeps access until current_period_end.
      // We treat this as 'active' until expiration — Apple sends EXPIRATION
      // separately when access actually ends.
      return cancelReason === 'BILLING_ERROR' ? 'past_due' : 'active'
    case 'EXPIRATION':
      return 'expired'
    case 'BILLING_ISSUE':
      return 'past_due'
    case 'REFUND':
      return 'canceled'
    default:
      return 'active'
  }
}

Deno.serve(async (req: Request) => {
  // Webhook endpoints only accept POST.
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  // Auth: RevenueCat sends our configured header value verbatim.
  const auth = req.headers.get('Authorization') ?? ''
  if (!REVENUECAT_WEBHOOK_AUTH || auth !== REVENUECAT_WEBHOOK_AUTH) {
    console.warn('[revenuecat-webhook] auth failure', {
      hasSecret: !!REVENUECAT_WEBHOOK_AUTH,
      receivedAuth: auth ? '(present)' : '(missing)',
    })
    return unauthorized('Invalid webhook auth')
  }

  let payload: RCPayload
  try {
    payload = await req.json()
  } catch (_err) {
    return badRequest('Invalid JSON body')
  }

  const event = payload?.event
  if (!event || !event.type) {
    return badRequest('Missing event.type')
  }

  // TRANSFER events describe purchases moving between app user ids and carry
  // `transferred_from` / `transferred_to` arrays INSTEAD of `app_user_id`.
  // They used to fall into the check below and 400, which made RevenueCat
  // retry the event six times for nothing. Acknowledge them; the follow-up
  // RENEWAL/INITIAL_PURCHASE for the destination user carries the state we
  // actually persist.
  if (event.type === 'TRANSFER') {
    console.log('[revenuecat-webhook] TRANSFER acknowledged', {
      from: event.transferred_from,
      to: event.transferred_to,
    })
    return ok('Transfer acknowledged', { type: event.type })
  }

  if (!event.app_user_id) {
    return badRequest('Missing event.app_user_id')
  }

  // Apple-only webhook — Stripe events come via the separate stripe-webhook fn.
  if (event.store && event.store !== 'APP_STORE') {
    console.log('[revenuecat-webhook] ignoring non-Apple event', { store: event.store, type: event.type })
    return ok('Non-Apple event ignored', { type: event.type })
  }

  // Filter out anonymous RC users — the app should always set app_user_id to the
  // Supabase user UUID on sign-in. If we see a non-UUID app_user_id, the user
  // hasn't been linked yet; skip cleanly.
  if (!isUuid(event.app_user_id)) {
    console.warn('[revenuecat-webhook] non-UUID app_user_id, skipping', { app_user_id: event.app_user_id, type: event.type })
    return ok('Anonymous user, skipped', { type: event.type })
  }

  const userId = event.app_user_id
  // Free-trial purchases arrive with period_type TRIAL. Record them as
  // 'trialing' (not 'active') so revenue metrics can distinguish "in trial"
  // from "paying" — access is identical (is_user_subscribed accepts both).
  // When Apple converts the trial (first paid RENEWAL), status becomes active
  // and trial_end clears.
  const isTrial = event.period_type === "TRIAL"
  const baseStatus = statusFromEventType(event.type, event.cancel_reason)
  const newStatus = (isTrial && baseStatus === "active") ? "trialing" : baseStatus
  const expiresAt = toIso(event.expiration_at_ms)
  const purchasedAt = toIso(event.purchased_at_ms)
  const originalTxId = event.original_transaction_id ?? null
  const productId = event.product_id ?? null
  const plan = planFromProductId(productId ?? undefined)
  const tier = tierFromProductId(productId ?? undefined)

  // Resolve which row this event belongs to.
  //
  // apple_original_transaction_id is the stable identity of the APPLE
  // subscription, and it legitimately moves between Arkline accounts: a user
  // reinstalls and signs up with a new email, taps Restore Purchases while
  // signed into a different account, or receives it via Family Sharing.
  // `subscriptions` has a UNIQUE index on that column, so looking up only by
  // (user_id, source) meant those cases fell through to INSERT and died on
  // 23505 duplicate key — a 500 that RevenueCat retries six times and then
  // gives up on. The user has paid Apple and has no access, permanently, with
  // nothing in our DB to show for it.
  //
  // So: find the row by transaction id FIRST and re-point it at the current
  // user (that is what a transfer means), and only fall back to the per-user
  // lookup when we have no transaction id to key on.
  let existing: { id: string; user_id: string } | null = null

  if (originalTxId) {
    const { data, error } = await supabase
      .from('subscriptions')
      .select('id, user_id')
      .eq('apple_original_transaction_id', originalTxId)
      .maybeSingle()

    if (error) {
      console.error('[revenuecat-webhook] lookup-by-txid error', error)
      return new Response(JSON.stringify({
        error: 'DB lookup failed', detail: error.message, code: error.code,
      }), { status: 500 })
    }
    existing = data
    if (existing && existing.user_id !== userId) {
      console.log('[revenuecat-webhook] transferring apple subscription', {
        originalTxId, from: existing.user_id, to: userId,
      })
    }
  }

  if (!existing) {
    const { data, error } = await supabase
      .from('subscriptions')
      .select('id, user_id')
      .eq('user_id', userId)
      .eq('source', 'apple')
      .maybeSingle()

    if (error) {
      console.error('[revenuecat-webhook] lookup error', error)
      return new Response(JSON.stringify({
        error: 'DB lookup failed', detail: error.message, code: error.code,
      }), { status: 500 })
    }
    existing = data
  }

  if (existing) {
    // UPDATE the existing Apple subscription row.
    const { error: updateErr } = await supabase
      .from('subscriptions')
      .update({
        // user_id is re-asserted so a transferred Apple subscription follows
        // the account that now owns it instead of stranding on the old one.
        user_id: userId,
        status: newStatus,
        plan,
        tier,
        apple_original_transaction_id: originalTxId,
        apple_product_id: productId,
        revenuecat_subscriber_id: userId,
        current_period_end: expiresAt,
        trial_end: newStatus === "trialing" ? expiresAt : null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', existing.id)

    if (updateErr) {
      console.error('[revenuecat-webhook] update error', updateErr)
      return new Response(JSON.stringify({
        error: 'DB update failed',
        detail: updateErr.message,
        code: updateErr.code,
        hint: updateErr.hint,
      }), { status: 500 })
    }

    console.log('[revenuecat-webhook] updated', { userId, type: event.type, newStatus, expiresAt })
    return ok('Subscription updated', { type: event.type, status: newStatus })
  }

  // INSERT a new Apple subscription row.
  // Only do this for events that imply a new active subscription. EXPIRATION/REFUND
  // for a non-existent row is a no-op (logged).
  if (event.type !== 'INITIAL_PURCHASE' && event.type !== 'PRODUCT_CHANGE' && event.type !== 'RENEWAL') {
    console.log('[revenuecat-webhook] event for unknown user, ignoring', { userId, type: event.type })
    return ok('No existing subscription, event ignored', { type: event.type })
  }

  const { error: insertErr } = await supabase
    .from('subscriptions')
    .insert({
      user_id: userId,
      source: 'apple',
      status: newStatus,
      apple_original_transaction_id: originalTxId,
      apple_product_id: productId,
      revenuecat_subscriber_id: userId,
      plan,
      tier,
      current_period_start: purchasedAt,
      current_period_end: expiresAt,
      trial_end: newStatus === "trialing" ? expiresAt : null,
    })

  if (insertErr) {
    // Echo the Postgres error back to RevenueCat. Its delivery log is the only
    // place we can read this from — Supabase edge logs surface request lines,
    // not console output, so a bare "DB insert failed" is undebuggable.
    console.error('[revenuecat-webhook] insert error', insertErr)
    return new Response(JSON.stringify({
      error: 'DB insert failed',
      detail: insertErr.message,
      code: insertErr.code,
      hint: insertErr.hint,
    }), { status: 500 })
  }

  console.log('[revenuecat-webhook] inserted', { userId, type: event.type, productId, plan, tier, expiresAt })
  return ok('Subscription created', { type: event.type, status: newStatus })
})
