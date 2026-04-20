import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * deck-pipeline-research Edge Function
 *
 * Step 2 of the deck pipeline:
 * - Reads pipeline_run_id from params
 * - Verifies step_gather_data is completed
 * - Calls Tavily API with 3 searches (macro, global, crypto)
 * - Stores results in output_web_research
 * - Sets step_web_research = 'completed'
 */

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

// ── Tavily Search ───────────────────────────────────────────────────────────
async function tavilySearch(query: string, apiKey: string, days = 7): Promise<string[]> {
  try {
    const response = await fetch("https://api.tavily.com/search", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        api_key: apiKey,
        query,
        search_depth: "advanced",
        max_results: 5,
        include_answer: true,
        days,
      }),
    })

    if (!response.ok) {
      console.error(`Tavily search failed for "${query}": ${response.status}`)
      return []
    }

    const data = await response.json()
    const results: string[] = []

    if (data.answer) results.push(data.answer)
    for (const r of data.results ?? []) {
      if (r.content) results.push(r.content)
    }
    return results
  } catch (e) {
    console.error(`Tavily search error for "${query}":`, e)
    return []
  }
}

async function gatherWebResearch(tavilyKey: string, monday: string, friday: string): Promise<Record<string, string[]>> {
  // Calculate days lookback from today to the Monday of the target week (+ buffer)
  const daysBack = Math.ceil((Date.now() - new Date(monday).getTime()) / 86400000) + 2
  const searchDays = Math.min(Math.max(daysBack, 7), 14) // 7-14 day window

  // 3 focused searches scoped to the target week
  const searches: Record<string, string> = {
    macro: `Federal Reserve FOMC interest rates US inflation CPI GDP economic data tariffs trade policy week of ${monday} to ${friday}`,
    global: `Bank of Japan ECB central bank global liquidity M2 money supply US dollar DXY treasury yields geopolitical risk week of ${monday} to ${friday}`,
    crypto: `bitcoin cryptocurrency ETF regulation institutional crypto market outlook week of ${monday} to ${friday}`,
  }

  const results: Record<string, string[]> = {}
  const entries = Object.entries(searches)
  const promises = entries.map(async ([key, query]) => {
    results[key] = await tavilySearch(query, tavilyKey, searchDays)
  })
  await Promise.all(promises)
  return results
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

  // ── Parse params ────────────────────────────────────────────────────
  const url = new URL(req.url)
  const pipelineRunId = url.searchParams.get("pipeline_run_id") ?? ""

  if (!pipelineRunId) {
    return jsonResponse({ error: "pipeline_run_id is required" }, 400)
  }

  const tavilyKey = Deno.env.get("TAVILY_API_KEY") ?? ""
  if (!tavilyKey) {
    return jsonResponse({ error: "TAVILY_API_KEY is not configured" }, 500)
  }

  console.log(`[research] Starting web research for pipeline run ${pipelineRunId}`)

  try {
    // ── Load pipeline run ─────────────────────────────────────────────
    const { data: run, error: fetchErr } = await supabase
      .from("deck_pipeline_runs")
      .select("*")
      .eq("id", pipelineRunId)
      .single()

    if (fetchErr || !run) {
      return jsonResponse({ error: `Pipeline run not found: ${fetchErr?.message}` }, 404)
    }

    if (run.step_gather_data !== "completed") {
      return jsonResponse({ error: `step_gather_data must be completed first (current: ${run.step_gather_data})` }, 400)
    }

    // Mark as running
    await supabase
      .from("deck_pipeline_runs")
      .update({
        step_web_research: "running",
        error_web_research: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", pipelineRunId)

    // ── Run Tavily searches ─────────────────────────────────────────
    const gatherData = run.output_gather_data
    const monday = gatherData.monday
    const friday = gatherData.friday

    console.log(`[research] Fetching web research via Tavily for ${monday} to ${friday}...`)
    const webResearch = await gatherWebResearch(tavilyKey, monday, friday)
    const totalResults = Object.values(webResearch).flat().length
    console.log(`[research] Web research complete: ${totalResults} results`)

    // ── Store output ────────────────────────────────────────────────
    const { error: updateErr } = await supabase
      .from("deck_pipeline_runs")
      .update({
        step_web_research: "completed",
        output_web_research: webResearch,
        error_web_research: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", pipelineRunId)

    if (updateErr) {
      return jsonResponse({ error: `Failed to save research output: ${updateErr.message}` }, 500)
    }

    console.log(`[research] Completed for pipeline run ${pipelineRunId}`)
    return jsonResponse({
      pipeline_run_id: pipelineRunId,
      step_web_research: "completed",
      total_results: totalResults,
    })
  } catch (e) {
    console.error("[research] error:", e)
    try {
      await supabase
        .from("deck_pipeline_runs")
        .update({
          step_web_research: "failed",
          error_web_research: String(e),
          updated_at: new Date().toISOString(),
        })
        .eq("id", pipelineRunId)
    } catch { /* best effort */ }
    return jsonResponse({ error: String(e) }, 500)
  }
})
