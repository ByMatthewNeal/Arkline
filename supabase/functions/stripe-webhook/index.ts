import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@17"

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2024-12-18.acacia",
})

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
)

// Matches iOS InviteCode.generateCode()
const CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
function generateCode(): string {
  return "ARK-" + Array.from({ length: 6 }, () =>
    CHARS[Math.floor(Math.random() * CHARS.length)]
  ).join("")
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 })
  }

  const body = await req.text()
  const signature = req.headers.get("stripe-signature") ?? ""
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? ""

  let event: Stripe.Event
  try {
    event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret)
  } catch (err) {
    console.error("Webhook signature verification failed:", err)
    return new Response(JSON.stringify({ error: "Invalid signature" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    })
  }

  console.log(`Processing Stripe event: ${event.type}`)

  try {
    switch (event.type) {
      case "checkout.session.completed":
        await handleCheckoutCompleted(event.data.object as Stripe.Checkout.Session)
        break
      case "invoice.paid":
        await handleInvoicePaid(event.data.object as Stripe.Invoice)
        break
      case "invoice.payment_failed":
        await handleInvoicePaymentFailed(event.data.object as Stripe.Invoice)
        break
      case "customer.subscription.deleted":
        await handleSubscriptionDeleted(event.data.object as Stripe.Subscription)
        break
      case "customer.subscription.updated":
        await handleSubscriptionUpdated(event.data.object as Stripe.Subscription)
        break
      default:
        console.log(`Unhandled event type: ${event.type}`)
    }
  } catch (err) {
    console.error(`Error handling ${event.type}:`, err)
    // Return 200 to prevent Stripe retries for processing errors
    // Stripe will retry on 5xx but not on 2xx
  }

  return new Response(JSON.stringify({ received: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  })
})

// --- Event Handlers ---

async function handleCheckoutCompleted(session: Stripe.Checkout.Session) {
  const email = session.customer_email ?? session.customer_details?.email
  if (!email) {
    console.error("No email found in checkout session")
    return
  }

  // Generate a unique invite code
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

  const expiresAt = new Date()
  expiresAt.setDate(expiresAt.getDate() + 30) // 30 days to redeem

  const { error } = await supabase.from("invite_codes").insert({
    code,
    created_by: Deno.env.get("SYSTEM_ADMIN_UUID"),
    expires_at: expiresAt.toISOString(),
    email,
    payment_status: "paid",
    stripe_checkout_session_id: session.id,
  })

  if (error) {
    console.error("Failed to create invite code:", error)
    return
  }

  console.log(`Generated invite code ${code} for ${email}`)

  // Create/update subscription record if this is a subscription checkout
  if (session.subscription) {
    const subscription = await stripe.subscriptions.retrieve(session.subscription as string)
    await upsertSubscription(subscription, email)
  }

  // TODO: Send invite code email via Resend/SendGrid
  // For now, admin can view codes in the management panel
}

async function handleInvoicePaid(invoice: Stripe.Invoice) {
  if (!invoice.subscription) return

  const subscription = await stripe.subscriptions.retrieve(invoice.subscription as string)
  await updateSubscriptionStatus(subscription.id, "active")
  await syncProfileStatus(subscription.id, "active")

  console.log(`Subscription ${subscription.id} marked active (invoice paid)`)
}

async function handleInvoicePaymentFailed(invoice: Stripe.Invoice) {
  if (!invoice.subscription) return

  await updateSubscriptionStatus(invoice.subscription as string, "past_due")
  await syncProfileStatus(invoice.subscription as string, "past_due")

  console.log(`Subscription ${invoice.subscription} marked past_due (payment failed)`)
}

async function handleSubscriptionDeleted(subscription: Stripe.Subscription) {
  await updateSubscriptionStatus(subscription.id, "canceled")
  await syncProfileStatus(subscription.id, "canceled")

  console.log(`Subscription ${subscription.id} canceled`)
}

async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  await upsertSubscription(subscription)

  const status = mapStripeStatus(subscription.status)
  await syncProfileStatus(subscription.id, status)

  console.log(`Subscription ${subscription.id} updated to ${status}`)
}

// --- Helpers ---

function mapStripeStatus(stripeStatus: string): string {
  switch (stripeStatus) {
    case "active": return "active"
    case "trialing": return "trialing"
    case "past_due": return "past_due"
    case "canceled":
    case "unpaid":
    case "incomplete_expired":
      return "canceled"
    default: return "active"
  }
}

async function upsertSubscription(subscription: Stripe.Subscription, email?: string) {
  const plan = subscription.items.data[0]?.price?.recurring?.interval === "year"
    ? "annual"
    : "monthly"
  const status = mapStripeStatus(subscription.status)

  // Try to find user_id by email
  let userId: string | null = null
  if (email) {
    const { data } = await supabase
      .from("profiles")
      .select("id")
      .eq("email", email)
      .single()
    userId = data?.id ?? null
  }

  // If no email match, try to find by existing subscription record
  if (!userId) {
    const { data } = await supabase
      .from("subscriptions")
      .select("user_id")
      .eq("stripe_subscription_id", subscription.id)
      .single()
    userId = data?.user_id ?? null
  }

  const record: Record<string, unknown> = {
    stripe_customer_id: subscription.customer as string,
    stripe_subscription_id: subscription.id,
    plan,
    status,
    current_period_start: new Date(subscription.current_period_start * 1000).toISOString(),
    current_period_end: new Date(subscription.current_period_end * 1000).toISOString(),
    trial_end: subscription.trial_end
      ? new Date(subscription.trial_end * 1000).toISOString()
      : null,
    updated_at: new Date().toISOString(),
  }

  if (userId) {
    record.user_id = userId
  }

  await supabase.from("subscriptions").upsert(record, {
    onConflict: "stripe_subscription_id",
  })
}

async function updateSubscriptionStatus(stripeSubId: string, status: string) {
  await supabase
    .from("subscriptions")
    .update({ status, updated_at: new Date().toISOString() })
    .eq("stripe_subscription_id", stripeSubId)
}

async function syncProfileStatus(stripeSubId: string, status: string) {
  const { data } = await supabase
    .from("subscriptions")
    .select("user_id")
    .eq("stripe_subscription_id", stripeSubId)
    .single()

  if (data?.user_id) {
    await supabase
      .from("profiles")
      .update({ subscription_status: status })
      .eq("id", data.user_id)
  }
}
