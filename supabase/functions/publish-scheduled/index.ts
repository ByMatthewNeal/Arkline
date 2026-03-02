import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "https://web.arkline.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-cron-secret",
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  // Auth: cron secret (not user auth — this runs on a schedule)
  const cronSecret = req.headers.get("x-cron-secret")
  const expectedSecret = Deno.env.get("CRON_SECRET")

  if (!expectedSecret || cronSecret !== expectedSecret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: corsHeaders,
    })
  }

  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    )

    // Find broadcasts that are scheduled and past due
    const now = new Date().toISOString()
    const { data: scheduled, error: fetchError } = await supabaseAdmin
      .from("broadcasts")
      .select("id, title, target_audience")
      .eq("status", "scheduled")
      .lte("scheduled_at", now)

    if (fetchError) {
      throw fetchError
    }

    if (!scheduled || scheduled.length === 0) {
      return new Response(JSON.stringify({ published: 0 }), {
        headers: corsHeaders,
      })
    }

    let publishedCount = 0

    for (const broadcast of scheduled) {
      // Update status to published
      const { error: updateError } = await supabaseAdmin
        .from("broadcasts")
        .update({ status: "published", published_at: now })
        .eq("id", broadcast.id)

      if (updateError) {
        console.error(`Failed to publish broadcast ${broadcast.id}:`, updateError)
        continue
      }

      publishedCount++

      // Trigger push notification via the send-broadcast-notification function
      try {
        await supabaseAdmin.functions.invoke("send-broadcast-notification", {
          body: {
            broadcast_id: broadcast.id,
            title: "New Insight",
            body: broadcast.title,
            target_audience: broadcast.target_audience,
          },
          headers: { "x-cron-secret": cronSecret },
        })
      } catch (notifError) {
        // Non-fatal: broadcast is published even if notification fails
        console.error(`Notification failed for broadcast ${broadcast.id}:`, notifError)
      }
    }

    return new Response(
      JSON.stringify({ published: publishedCount, total_scheduled: scheduled.length }),
      { headers: corsHeaders }
    )
  } catch (err) {
    console.error("publish-scheduled error:", err)
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: corsHeaders,
    })
  }
})
