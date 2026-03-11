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
  event_type?: string  // e.g. "signal_new", "signal_t1_hit", "signal_stop_loss", "signal_runner_close", "signal_expiry"
  target_audience?: {
    type: "all" | "premium" | "specific"
    user_ids?: string[]
  }
}

// ─── APNs JWT Token ─────────────────────────────────────────────────────────

function base64UrlEncode(data: Uint8Array): string {
  let binary = ""
  for (const byte of data) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

async function createApnsJwt(keyPem: string, keyId: string, teamId: string): Promise<string> {
  // Strip PEM header/footer and decode
  const pemBody = keyPem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "")

  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0))

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  )

  const header = { alg: "ES256", kid: keyId }
  const now = Math.floor(Date.now() / 1000)
  const claims = { iss: teamId, iat: now }

  const encoder = new TextEncoder()
  const headerB64 = base64UrlEncode(encoder.encode(JSON.stringify(header)))
  const claimsB64 = base64UrlEncode(encoder.encode(JSON.stringify(claims)))
  const signingInput = `${headerB64}.${claimsB64}`

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    encoder.encode(signingInput)
  )

  // Convert DER signature to raw r||s (64 bytes) for ES256
  const sigBytes = new Uint8Array(signature)
  let r: Uint8Array, s: Uint8Array

  if (sigBytes.length === 64) {
    // Already raw format
    r = sigBytes.slice(0, 32)
    s = sigBytes.slice(32)
  } else {
    // DER format: 0x30 <len> 0x02 <rlen> <r> 0x02 <slen> <s>
    let offset = 2 // skip 0x30 <len>
    offset += 1 // skip 0x02
    const rLen = sigBytes[offset++]
    const rRaw = sigBytes.slice(offset, offset + rLen)
    offset += rLen
    offset += 1 // skip 0x02
    const sLen = sigBytes[offset++]
    const sRaw = sigBytes.slice(offset, offset + sLen)

    // Pad or trim to 32 bytes
    r = new Uint8Array(32)
    s = new Uint8Array(32)
    r.set(rRaw.length > 32 ? rRaw.slice(rRaw.length - 32) : rRaw, 32 - Math.min(rRaw.length, 32))
    s.set(sRaw.length > 32 ? sRaw.slice(sRaw.length - 32) : sRaw, 32 - Math.min(sRaw.length, 32))
  }

  const rawSig = new Uint8Array(64)
  rawSig.set(r, 0)
  rawSig.set(s, 32)

  return `${signingInput}.${base64UrlEncode(rawSig)}`
}

// ─── APNs Send ──────────────────────────────────────────────────────────────

async function sendApns(
  token: string,
  jwt: string,
  bundleId: string,
  payload: object,
  useSandbox: boolean
): Promise<{ token: string; success: boolean; status: number; reason?: string }> {
  const host = useSandbox
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com"

  try {
    const resp = await fetch(`${host}/3/device/${token}`, {
      method: "POST",
      headers: {
        "authorization": `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      body: JSON.stringify(payload),
    })

    if (resp.status === 200) {
      return { token, success: true, status: 200 }
    }

    const body = await resp.json().catch(() => ({}))
    return { token, success: false, status: resp.status, reason: body.reason ?? "unknown" }
  } catch (err) {
    return { token, success: false, status: 0, reason: String(err) }
  }
}

// ─── Main Handler ───────────────────────────────────────────────────────────

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
    const { broadcast_id, title, body, event_type, target_audience } =
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

    // Filter by per-user notification preferences if event_type is provided
    let filteredDevices = devices
    if (event_type) {
      const userIds = [...new Set(devices.map((d: { user_id: string }) => d.user_id))]
      const { data: profiles } = await supabaseAdmin
        .from("profiles")
        .select("id, notification_preferences")
        .in("id", userIds)

      if (profiles) {
        const blockedUsers = new Set<string>()
        for (const profile of profiles) {
          const prefs = profile.notification_preferences as Record<string, boolean> | null
          // null prefs = all enabled (default). Only block if explicitly set to false.
          if (prefs && prefs[event_type] === false) {
            blockedUsers.add(profile.id)
          }
        }
        if (blockedUsers.size > 0) {
          filteredDevices = devices.filter((d: { user_id: string }) => !blockedUsers.has(d.user_id))
        }
      }
    }

    if (filteredDevices.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, reason: "All users opted out of this event type", event_type }),
        { headers: corsHeaders }
      )
    }

    // ─── APNs Push ────────────────────────────────────────────────────────

    const apnsKey = Deno.env.get("APNS_AUTH_KEY")
    const apnsKeyId = Deno.env.get("APNS_KEY_ID")
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID")
    const apnsBundleId = "com.arkline.app"
    // Use sandbox for TestFlight/development, production for App Store
    const useSandbox = Deno.env.get("APNS_USE_SANDBOX") !== "false"

    if (!apnsKey || !apnsKeyId || !apnsTeamId) {
      // APNs not configured — log and return
      const tokens = filteredDevices.map((d: { device_token: string }) => d.device_token)
      console.log(
        `[send-broadcast-notification] APNs not configured. Would send to ${tokens.length} devices for broadcast ${broadcast_id}`
      )
      return new Response(
        JSON.stringify({ sent: 0, reason: "APNs credentials not configured", devices_found: tokens.length }),
        { headers: corsHeaders }
      )
    }

    // Generate APNs JWT (valid for ~1 hour, but we generate fresh each invocation)
    const jwt = await createApnsJwt(apnsKey, apnsKeyId, apnsTeamId)

    const payload = {
      aps: {
        alert: { title, body: body || "" },
        sound: "default",
        badge: 1,
        "mutable-content": 1,
      },
      broadcast_id,
      event_type: event_type || "general",
    }

    const tokens = filteredDevices.map((d: { device_token: string }) => d.device_token)

    // Send to all devices concurrently
    const results = await Promise.all(
      tokens.map((token) => sendApns(token, jwt, apnsBundleId, payload, useSandbox))
    )

    const succeeded = results.filter((r) => r.success).length
    const failed = results.filter((r) => !r.success)

    // Remove invalid tokens (gone, unregistered)
    const badTokenReasons = new Set(["BadDeviceToken", "Unregistered", "DeviceTokenNotForTopic"])
    const tokensToRemove = failed
      .filter((r) => badTokenReasons.has(r.reason ?? ""))
      .map((r) => r.token)

    if (tokensToRemove.length > 0) {
      await supabaseAdmin
        .from("user_devices")
        .delete()
        .in("device_token", tokensToRemove)
      console.log(`[send-broadcast-notification] Removed ${tokensToRemove.length} invalid tokens`)
    }

    if (failed.length > 0) {
      console.log(
        `[send-broadcast-notification] ${succeeded}/${tokens.length} sent, failures:`,
        failed.map((f) => `${f.status}:${f.reason}`).join(", ")
      )
    }

    return new Response(
      JSON.stringify({
        sent: succeeded,
        failed: failed.length,
        broadcast_id,
        sandbox: useSandbox,
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
