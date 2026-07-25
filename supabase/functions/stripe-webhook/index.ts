import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import Stripe from "https://esm.sh/stripe@17"

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  apiVersion: "2024-12-18.acacia",
})

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
)

// Founding member price IDs (live mode)
const FOUNDING_PRICE_IDS = new Set([
  "price_1TXCJyPHuageZ7zbIGTJCHPl", // founding monthly ($39.99/mo)
  "price_1TXCOPPHuageZ7zb7d2HyeHc", // founding annual ($400/yr)
])

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
    // Return 200 to prevent Stripe retries for processing errors.
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

  if (!session.subscription) {
    console.log(`Checkout completed for ${email} with no subscription — ignoring`)
    return
  }

  const subscription = await stripe.subscriptions.retrieve(session.subscription as string)

  // Self-serve web checkout (create-self-checkout): the user already has an
  // account and is mid-onboarding. Link + activate now.
  if (session.metadata?.self_serve === "true") {
    await upsertSubscription(subscription, email)
    await syncProfileStatus(subscription.id, mapStripeStatus(subscription.status))
    console.log(`Self-serve checkout completed for ${email}`)
    return
  }

  // Organic web purchase (e.g. a Quick Share payment link). The buyer may not
  // have an Arkline account yet. upsertSubscription links by email if a profile
  // exists, otherwise stashes the email on the row (pending_email) so the signup
  // trigger links it the moment they create their account. No invite code —
  // invite codes are retired; access comes from the subscription row.
  await upsertSubscription(subscription, email)
  await sendWelcomeEmail(email)
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
  const priceId = subscription.items.data[0]?.price?.id ?? ""
  const plan = subscription.items.data[0]?.price?.recurring?.interval === "year"
    ? "annual"
    : "monthly"
  const tier = FOUNDING_PRICE_IDS.has(priceId) ? "founding" : "standard"
  const status = mapStripeStatus(subscription.status)

  // Try to find user_id by email (profile exists = they already have an account).
  let userId: string | null = null
  if (email) {
    const { data } = await supabase
      .from("profiles").select("id").eq("email", email).single()
    userId = data?.id ?? null
  }

  // If no email match, try to find by existing subscription record.
  if (!userId) {
    const { data } = await supabase
      .from("subscriptions").select("user_id").eq("stripe_subscription_id", subscription.id).single()
    userId = data?.user_id ?? null
  }

  const record: Record<string, unknown> = {
    stripe_customer_id: subscription.customer as string,
    stripe_subscription_id: subscription.id,
    source: "stripe",
    plan,
    tier,
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
    record.pending_email = null
  } else {
    // No account yet — stash the email so the signup trigger links this row when
    // the buyer creates their account with the same address.
    record.pending_email = email ?? null
  }

  const { error } = await supabase.from("subscriptions").upsert(record, {
    onConflict: "stripe_subscription_id",
  })
  if (error) console.error("[stripe-webhook] upsertSubscription error:", error)
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
    .select("user_id, trial_end, current_period_end")
    .eq("stripe_subscription_id", stripeSubId)
    .single()

  if (data?.user_id) {
    const profileUpdate: Record<string, unknown> = { subscription_status: status }
    if (data.trial_end) {
      profileUpdate.trial_end = data.trial_end
    } else if (status !== "trialing") {
      profileUpdate.trial_end = null
    }
    profileUpdate.current_period_end = data.current_period_end ?? null
    await supabase.from("profiles").update(profileUpdate).eq("id", data.user_id)
  }
}

// --- Email ---

// After a web purchase, tell the buyer to download the app and sign up with the
// SAME email — that's what links their subscription (via the signup trigger).
async function sendWelcomeEmail(email: string) {
  const resendKey = Deno.env.get("RESEND_API_KEY")
  if (!resendKey) {
    console.warn("RESEND_API_KEY not set — skipping welcome email")
    return
  }

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
        subject: "Welcome to Arkline — one step left",
        html: `
          <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 20px;">
            <div style="text-align: center; margin-bottom: 32px;">
              <h1 style="font-size: 28px; font-weight: 700; color: #1a1a1a; margin: 0;">Welcome to Arkline</h1>
              <p style="font-size: 16px; color: #666; margin-top: 8px;">Your payment was successful. One quick step to unlock it.</p>
            </div>

            <div style="background: #f8f9fa; border-radius: 12px; padding: 24px; margin-bottom: 24px;">
              <p style="font-size: 15px; color: #333; margin: 0 0 12px 0;"><strong>Download Arkline</strong> from the App Store, then <strong>sign up with this email:</strong></p>
              <p style="font-size: 18px; font-weight: 700; color: #3369FF; margin: 0; text-align: center; letter-spacing: 0.5px;">${email}</p>
            </div>

            <div style="text-align: center; margin-bottom: 32px;">
              <a href="https://arkline.io" style="display: inline-block; background: #3369FF; color: white; text-decoration: none; padding: 14px 32px; border-radius: 8px; font-size: 16px; font-weight: 600;">Get the App</a>
            </div>

            <div style="border-top: 1px solid #eee; padding-top: 20px;">
              <p style="font-size: 13px; color: #999; text-align: center; margin: 0;">
                As long as you sign up with the same email you paid with, your membership unlocks automatically — no code needed.
              </p>
            </div>
          </div>
        `,
      }),
    })

    if (res.ok) {
      console.log(`Welcome email sent to ${email}`)
    } else {
      console.error(`Failed to send welcome email: ${await res.text()}`)
    }
  } catch (err) {
    console.error("Error sending welcome email:", err)
  }
}
