import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * deck-pipeline-context Edge Function
 *
 * Step 3 of the deck pipeline:
 * - Reads pipeline_run_id, admin_insights, attachments from body
 * - Stores in output_context
 * - Sets step_add_context = 'completed'
 * - Lightweight — just a DB write
 */

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

// ── Main Handler ────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const supabase = createClient(supabaseUrl, supabaseKey)

  // ── Admin JWT auth ──────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return jsonResponse({ error: "Authorization header required" }, 401)
  }
  const token = authHeader.replace("Bearer ", "")
  const { data: { user }, error: authError } = await supabase.auth.getUser(token)
  if (authError || !user) {
    return jsonResponse({ error: "Invalid or expired token" }, 401)
  }
  const { data: profile } = await supabase
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single()
  if (profile?.role !== "admin") {
    return jsonResponse({ error: "Admin access required" }, 403)
  }

  // ── Parse body ──────────────────────────────────────────────────────
  let body: Record<string, unknown> = {}
  if (req.headers.get("content-type")?.includes("application/json")) {
    try {
      body = await req.json()
    } catch { /* no body */ }
  }

  const url = new URL(req.url)
  const pipelineRunId = (body.pipeline_run_id as string) ?? url.searchParams.get("pipeline_run_id") ?? ""
  const adminInsights = body.admin_insights ? String(body.admin_insights).substring(0, 40000) : ""
  const attachments = (body.attachments as Array<Record<string, unknown>>) ?? []

  if (!pipelineRunId) {
    return jsonResponse({ error: "pipeline_run_id is required" }, 400)
  }

  console.log(`[context] Adding context to pipeline run ${pipelineRunId}`)

  try {
    // ── Verify pipeline run exists ────────────────────────────────────
    const { data: run, error: fetchErr } = await supabase
      .from("deck_pipeline_runs")
      .select("id, step_gather_data")
      .eq("id", pipelineRunId)
      .single()

    if (fetchErr || !run) {
      return jsonResponse({ error: `Pipeline run not found: ${fetchErr?.message}` }, 404)
    }

    // ── Store context ─────────────────────────────────────────────────
    const contextOutput = {
      admin_insights: adminInsights || null,
      attachments: attachments.length > 0 ? attachments : null,
      added_at: new Date().toISOString(),
    }

    const { error: updateErr } = await supabase
      .from("deck_pipeline_runs")
      .update({
        step_add_context: "completed",
        output_context: contextOutput,
        error_add_context: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", pipelineRunId)

    if (updateErr) {
      return jsonResponse({ error: `Failed to save context: ${updateErr.message}` }, 500)
    }

    console.log(`[context] Stored context for pipeline run ${pipelineRunId} (insights: ${adminInsights.length} chars, attachments: ${attachments.length})`)
    return jsonResponse({
      pipeline_run_id: pipelineRunId,
      step_add_context: "completed",
      insights_length: adminInsights.length,
      attachment_count: attachments.length,
    })
  } catch (e) {
    console.error("[context] error:", e)
    try {
      await supabase
        .from("deck_pipeline_runs")
        .update({
          step_add_context: "failed",
          error_add_context: String(e),
          updated_at: new Date().toISOString(),
        })
        .eq("id", pipelineRunId)
    } catch { /* best effort */ }
    return jsonResponse({ error: String(e) }, 500)
  }
})
