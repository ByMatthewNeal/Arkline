import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * compute-signal-analytics Edge Function
 *
 * Computes rolling performance analytics from closed trade signals and derives
 * adaptive parameters that feed back into the fibonacci-pipeline.
 *
 * Runs daily at 01:00 UTC via cron.
 * Stores results in market_data_cache key "signal_analytics".
 */

interface ClosedSignal {
  id: string
  asset: string
  signal_type: string
  outcome: string
  outcome_pct: number | null
  duration_hours: number | null
  best_price: number | null
  closed_at: string
  resolution_source: string | null
}

interface AssetStats {
  signal_count: number
  wins: number
  losses: number
  win_rate: number
  profit_factor: number
  avg_pnl: number
  avg_duration_hours: number
  long_count: number
  short_count: number
  long_win_rate: number
  short_win_rate: number
}

interface AdaptiveParams {
  paused_assets: string[]
  direction_bonus: Record<string, { long: number; short: number }>
  min_rr: number
  min_score: number
  state: string
  state_label: string
  reasons: string[]
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  const secret = req.headers.get("x-cron-secret") ?? ""
  if (!cronSecret || secret !== cronSecret) {
    return json({ error: "Unauthorized" }, 401)
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  )

  // Fetch all closed signals with automated resolution
  const { data: signals, error } = await supabase
    .from("trade_signals")
    .select("id, asset, signal_type, outcome, outcome_pct, duration_hours, best_price, closed_at, resolution_source")
    .in("status", ["target_hit", "invalidated"])
    .eq("timeframe", "4h")
    .gte("generated_at", "2026-03-24T00:00:00Z")
    .order("closed_at", { ascending: false })

  if (error) {
    console.error(`Failed to fetch signals: ${error.message}`)
    return json({ error: "Failed to fetch signals", detail: error.message }, 500)
  }

  const allSignals: ClosedSignal[] = signals ?? []
  console.log(`Processing ${allSignals.length} closed automated signals`)

  const now = new Date()
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 86400000)

  // Split into rolling 30d and all-time per asset
  const assetMap = new Map<string, ClosedSignal[]>()
  for (const sig of allSignals) {
    const list = assetMap.get(sig.asset) ?? []
    list.push(sig)
    assetMap.set(sig.asset, list)
  }

  // Compute per-asset stats
  const assets: Record<string, { rolling_30d: AssetStats; all_time: AssetStats }> = {}
  for (const [asset, sigs] of assetMap) {
    const recent = sigs.filter(s => new Date(s.closed_at) >= thirtyDaysAgo)
    assets[asset] = {
      rolling_30d: computeAssetStats(recent),
      all_time: computeAssetStats(sigs),
    }
  }

  // System-wide stats
  const recentAll = allSignals.filter(s => new Date(s.closed_at) >= thirtyDaysAgo)
  const system = {
    rolling_30d: computeAssetStats(recentAll),
    all_time: computeAssetStats(allSignals),
  }

  // Derive adaptive parameters
  const adaptive = deriveAdaptiveParams(system.rolling_30d, assets)

  const result = {
    computed_at: now.toISOString(),
    system,
    assets,
    adaptive,
  }

  // Store in market_data_cache
  const { error: upsertError } = await supabase
    .from("market_data_cache")
    .upsert({
      key: "signal_analytics",
      data: result,
      updated_at: now.toISOString(),
    }, { onConflict: "key" })

  if (upsertError) {
    console.error(`Cache upsert failed: ${upsertError.message}`)
    return json({ error: "Cache upsert failed", detail: upsertError.message }, 500)
  }

  console.log(`Signal analytics computed: ${allSignals.length} signals, ${Object.keys(assets).length} assets`)
  console.log(`Adaptive state: ${adaptive.state} — ${adaptive.state_label}`)
  if (adaptive.paused_assets.length > 0) {
    console.log(`Paused assets: ${adaptive.paused_assets.join(", ")}`)
  }
  if (adaptive.reasons.length > 0) {
    console.log(`Reasons: ${adaptive.reasons.join("; ")}`)
  }

  return json({ success: true, signal_count: allSignals.length, adaptive })
})

// ─── Stats Computation ────────────────────────────────────────────────────────

function computeAssetStats(signals: ClosedSignal[]): AssetStats {
  const wins = signals.filter(s => s.outcome === "win" || s.outcome === "partial").length
  const losses = signals.filter(s => s.outcome === "loss").length
  const total = wins + losses
  const winRate = total > 0 ? (wins / total) * 100 : 0

  const winPcts = signals.filter(s => s.outcome === "win" || s.outcome === "partial").map(s => s.outcome_pct ?? 0)
  const lossPcts = signals.filter(s => s.outcome === "loss").map(s => Math.abs(s.outcome_pct ?? 0))
  const totalWin = winPcts.reduce((a, b) => a + b, 0)
  const totalLoss = lossPcts.reduce((a, b) => a + b, 0)
  const profitFactor = totalLoss > 0 ? totalWin / totalLoss : totalWin > 0 ? 99 : 0

  const allPcts = signals.map(s => s.outcome_pct ?? 0)
  const avgPnl = allPcts.length > 0 ? allPcts.reduce((a, b) => a + b, 0) / allPcts.length : 0

  const durations = signals.map(s => s.duration_hours ?? 0).filter(d => d > 0)
  const avgDuration = durations.length > 0 ? Math.round(durations.reduce((a, b) => a + b, 0) / durations.length) : 0

  // Direction split
  const longs = signals.filter(s => s.signal_type === "buy" || s.signal_type === "strong_buy")
  const shorts = signals.filter(s => s.signal_type === "sell" || s.signal_type === "strong_sell")
  const longWins = longs.filter(s => s.outcome === "win" || s.outcome === "partial").length
  const shortWins = shorts.filter(s => s.outcome === "win" || s.outcome === "partial").length

  return {
    signal_count: total,
    wins,
    losses,
    win_rate: round2(winRate),
    profit_factor: round2(profitFactor),
    avg_pnl: round2(avgPnl),
    avg_duration_hours: avgDuration,
    long_count: longs.length,
    short_count: shorts.length,
    long_win_rate: longs.length > 0 ? round2((longWins / longs.length) * 100) : 0,
    short_win_rate: shorts.length > 0 ? round2((shortWins / shorts.length) * 100) : 0,
  }
}

// ─── Adaptive Parameter Derivation ──────────────────────────────────────────

function deriveAdaptiveParams(
  systemStats: AssetStats,
  assets: Record<string, { rolling_30d: AssetStats; all_time: AssetStats }>
): AdaptiveParams {
  const reasons: string[] = []

  // --- Asset Pause: 30d PF < 1.0 with >= 5 signals ---
  let pausedAssets: string[] = []
  const assetPFs: { asset: string; pf: number; count: number }[] = []

  for (const [asset, data] of Object.entries(assets)) {
    const s = data.rolling_30d
    assetPFs.push({ asset, pf: s.profit_factor, count: s.signal_count })
    if (s.signal_count >= 5 && s.profit_factor < 1.0) {
      pausedAssets.push(asset)
      reasons.push(`${asset} paused: 30d PF ${s.profit_factor} with ${s.signal_count} signals`)
    }
  }

  // Safety rail: never pause more than total_assets - 3
  const totalAssets = Object.keys(assets).length
  const maxPaused = Math.max(totalAssets - 3, 0)
  if (pausedAssets.length > maxPaused) {
    // Keep only the worst performers paused
    const sorted = pausedAssets
      .map(a => ({ asset: a, pf: assets[a].rolling_30d.profit_factor }))
      .sort((a, b) => a.pf - b.pf)
    pausedAssets = sorted.slice(0, maxPaused).map(a => a.asset)
  }

  // --- Direction Bonus: per-asset long vs short WR delta ---
  const directionBonus: Record<string, { long: number; short: number }> = {}

  for (const [asset, data] of Object.entries(assets)) {
    const s = data.rolling_30d
    if (s.long_count < 3 || s.short_count < 3) continue
    const delta = s.long_win_rate - s.short_win_rate

    let bonus = 0
    if (Math.abs(delta) > 20) bonus = 5
    else if (Math.abs(delta) > 10) bonus = 3

    if (bonus > 0) {
      const longBonus = clamp(delta > 0 ? bonus : -bonus, -8, 8)
      const shortBonus = -longBonus
      directionBonus[asset] = { long: longBonus, short: shortBonus }
      const preferred = longBonus > 0 ? "long" : "short"
      reasons.push(`${asset} ${preferred}-biased: long WR ${s.long_win_rate}% vs short WR ${s.short_win_rate}%`)
    }
  }

  // --- System-wide R:R floor ---
  let minRR = 1.0
  if (systemStats.signal_count >= 10) {
    if (systemStats.win_rate < 50) {
      minRR = 1.5
      reasons.push(`Min R:R raised to 1.5: system WR ${systemStats.win_rate}% < 50%`)
    } else if (systemStats.win_rate < 55) {
      minRR = 1.2
      reasons.push(`Min R:R raised to 1.2: system WR ${systemStats.win_rate}% < 55%`)
    }
  }

  // --- System-wide score threshold ---
  let minScore = 60
  if (systemStats.signal_count >= 10) {
    if (systemStats.profit_factor < 1.0) {
      minScore = 70
      reasons.push(`Min score raised to 70: system PF ${systemStats.profit_factor} < 1.0`)
    } else if (systemStats.profit_factor < 1.5) {
      minScore = 65
      reasons.push(`Min score raised to 65: system PF ${systemStats.profit_factor} < 1.5`)
    } else if (systemStats.profit_factor >= 2.5) {
      minScore = 55
      reasons.push(`Min score lowered to 55: system PF ${systemStats.profit_factor} >= 2.5`)
    }
  }

  // --- State determination ---
  let state = "normal"
  let stateLabel = "System operating normally"

  if (systemStats.signal_count >= 10) {
    if (systemStats.profit_factor >= 2.0 && systemStats.win_rate >= 60) {
      state = "hot"
      stateLabel = "System running hot"
    } else if (systemStats.profit_factor < 1.0 || systemStats.win_rate < 45) {
      state = "cold"
      stateLabel = "Filters tightened — low performance"
    } else if (systemStats.profit_factor < 1.5 || systemStats.win_rate < 50) {
      state = "cautious"
      stateLabel = "Filters tightened slightly"
    }
  } else {
    state = "learning"
    stateLabel = `Learning (${systemStats.signal_count}/10 signals)`
  }

  return {
    paused_assets: pausedAssets,
    direction_bonus: directionBonus,
    min_rr: minRR,
    min_score: minScore,
    state,
    state_label: stateLabel,
    reasons,
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function round2(n: number): number {
  return Math.round(n * 100) / 100
}

function clamp(n: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, n))
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
