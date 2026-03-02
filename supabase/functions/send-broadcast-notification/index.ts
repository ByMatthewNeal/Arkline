import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "https://web.arkline.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
}

interface NotificationRequest {
  broadcast_id: string
  title: string
  body: string
  target_audience?: {
    type: "all" | "premium" | "specific"
    user_ids?: string[]
  }
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

  // Auth: accept either cron secret (from auto-publish) or admin user token
  const cronSecret = req.headers.get("x-cron-secret")
  const expectedCronSecret = Deno.env.get("CRON_SECRET")
  const authHeader = req.headers.get("Authorization")

  let isAuthorized = false

  // Check cron secret
  if (expectedCronSecret && cronSecret === expectedCronSecret) {
    isAuthorized = true
  }

  // Check admin user
  if (!isAuthorized && authHeader) {
    const supabaseAuth = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    )
    const { data: { user } } = await supabaseAuth.auth.getUser()
    if (user) {
      const supabaseAdmin = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
      )
      const { data: profile } = await supabaseAdmin
        .from("profiles")
        .select("role")
        .eq("id", user.id)
        .single()
      if (profile?.role === "admin") {
        isAuthorized = true
      }
    }
  }

  if (!isAuthorized) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: corsHeaders,
    })
  }

  try {
    const { broadcast_id, title, body, target_audience } =
      (await req.json()) as NotificationRequest

    if (!broadcast_id || !title) {
      return new Response(JSON.stringify({ error: "Missing broadcast_id or title" }), {
        status: 400,
        headers: corsHeaders,
      })
    }

    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // Build device token query based on audience
    let deviceQuery = supabaseAdmin
      .from("user_devices")
      .select("device_token, user_id")
      .eq("platform", "ios")

    if (target_audience?.type === "premium") {
      // Get premium user IDs first
      const { data: premiumUsers } = await supabaseAdmin
        .from("profiles")
        .select("id")
        .or("role.in.(admin,premium),subscription_status.in.(active,trialing)")

      if (premiumUsers && premiumUsers.length > 0) {
        const premiumIds = premiumUsers.map((u: { id: string }) => u.id)
        deviceQuery = deviceQuery.in("user_id", premiumIds)
      } else {
        return new Response(
          JSON.stringify({ sent: 0, reason: "No premium users found" }),
          { headers: corsHeaders }
        )
      }
    } else if (target_audience?.type === "specific" && target_audience.user_ids) {
      deviceQuery = deviceQuery.in("user_id", target_audience.user_ids)
    }
    // type === "all" — no additional filter needed

    const { data: devices, error: deviceError } = await deviceQuery

    if (deviceError) {
      throw deviceError
    }

    if (!devices || devices.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, reason: "No device tokens found" }),
        { headers: corsHeaders }
      )
    }

    // TODO: Full APNs integration requires a .p8 auth key stored in Supabase secrets.
    // For now, log the intent and return the device count.
    // When APNs is configured, replace this block with actual push delivery:
    //
    // const apnsKey = Deno.env.get("APNS_AUTH_KEY")   // .p8 contents
    // const apnsKeyId = Deno.env.get("APNS_KEY_ID")
    // const apnsTeamId = Deno.env.get("APNS_TEAM_ID")
    // const apnsBundleId = Deno.env.get("APNS_BUNDLE_ID")
    //
    // For each device token, send via HTTP/2 to api.push.apple.com:
    //   POST /3/device/{token}
    //   Headers: authorization (bearer JWT), apns-topic (bundle id), apns-push-type (alert)
    //   Body: { aps: { alert: { title, body }, sound: "default", badge: 1 },
    //           broadcast_id }

    const tokens = devices.map((d: { device_token: string }) => d.device_token)

    console.log(
      `[send-broadcast-notification] Would send to ${tokens.length} devices for broadcast ${broadcast_id}`
    )

    return new Response(
      JSON.stringify({
        sent: tokens.length,
        broadcast_id,
        status: "pending_apns_setup",
      }),
      { headers: corsHeaders }
    )
  } catch (err) {
    console.error("send-broadcast-notification error:", err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: corsHeaders,
    })
  }
})
