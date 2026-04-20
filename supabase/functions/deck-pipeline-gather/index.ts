import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * deck-pipeline-gather Edge Function
 *
 * Step 1 of the deck pipeline:
 * - Creates or finds a deck_pipeline_runs row for the week
 * - Runs all DB queries: positioning_signals, fear_greed_history, economic_events, trade_signals, market_summaries
 * - Computes cross-market prices, macro data, signal distribution, regime
 * - Computes BTC/ETH/SOL log regression risk
 * - Assembles data-driven slides: cover, crossMarket, marketPulse, signalSnapshot
 * - Stores everything in output_gather_data JSONB
 * - Sets step_gather_data = 'completed'
 */

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

function getWeekRange(): { monday: string; friday: string; nextMonday: string; nextFriday: string } {
  const now = new Date()
  const dayOfWeek = now.getUTCDay()
  const daysBackToFriday = dayOfWeek === 6 ? 1 : dayOfWeek === 0 ? 2 : dayOfWeek + 2
  const friday = new Date(now)
  friday.setUTCDate(now.getUTCDate() - daysBackToFriday)
  const monday = new Date(friday)
  monday.setUTCDate(friday.getUTCDate() - 4)

  const nextMonday = new Date(friday)
  nextMonday.setUTCDate(friday.getUTCDate() + 3)
  const nextFriday = new Date(nextMonday)
  nextFriday.setUTCDate(nextMonday.getUTCDate() + 4)

  return {
    monday: monday.toISOString().split("T")[0],
    friday: friday.toISOString().split("T")[0],
    nextMonday: nextMonday.toISOString().split("T")[0],
    nextFriday: nextFriday.toISOString().split("T")[0],
  }
}

interface SlidePayload {
  type: string
  title: string
  data: {
    type: string
    payload: Record<string, unknown>
  }
}

// ── Log Regression Risk (matches iOS RiskCalculator + AssetRiskConfig) ──────

interface AssetRiskConfig {
  symbol: string
  fmpSymbol: string
  originDate: Date
  deviationBounds: [number, number]
}

const RISK_CONFIGS: AssetRiskConfig[] = [
  { symbol: "BTC", fmpSymbol: "BTCUSD", originDate: new Date("2009-01-03"), deviationBounds: [-0.8, 0.8] },
  { symbol: "ETH", fmpSymbol: "ETHUSD", originDate: new Date("2015-07-30"), deviationBounds: [-0.7, 0.7] },
  { symbol: "SOL", fmpSymbol: "SOLUSD", originDate: new Date("2020-04-10"), deviationBounds: [-0.6, 0.6] },
]

async function computeAssetRisk(fmpKey: string, config: AssetRiskConfig): Promise<{
  risk_level: number
  price: number
  category: string
} | null> {
  try {
    const url = `https://financialmodelingprep.com/stable/historical-price-eod/full?symbol=${config.fmpSymbol}&apikey=${fmpKey}`
    const resp = await fetch(url)
    if (!resp.ok) return null
    const data = await resp.json()
    if (!Array.isArray(data) || data.length < 50) return null

    const sorted = [...data].sort((a: any, b: any) => a.date.localeCompare(b.date))
    const originTime = config.originDate.getTime()
    let n = 0, sumX = 0, sumY = 0, sumXX = 0, sumXY = 0
    let lastPrice = 0

    for (const row of sorted) {
      const d = new Date(row.date)
      const days = Math.round((d.getTime() - originTime) / 86400000)
      const price = parseFloat(row.close)
      if (days <= 0 || price <= 0) continue
      const x = Math.log10(days)
      const y = Math.log10(price)
      sumX += x; sumY += y; sumXX += x * x; sumXY += x * y
      n++
      lastPrice = price
    }

    const denom = n * sumXX - sumX * sumX
    if (Math.abs(denom) < 1e-10) return null

    const b = (n * sumXY - sumX * sumY) / denom
    const a = (sumY - b * sumX) / n
    const todayDays = Math.round((Date.now() - originTime) / 86400000)
    const logFair = a + b * Math.log10(todayDays)
    const fairValue = Math.pow(10, logFair)

    const deviation = Math.log10(lastPrice) - Math.log10(fairValue)
    const [low, high] = config.deviationBounds
    const clamped = Math.max(low, Math.min(high, deviation))
    const riskLevel = (clamped - low) / (high - low)

    let category: string
    if (riskLevel < 0.20) category = "Very Low Risk"
    else if (riskLevel < 0.40) category = "Low Risk"
    else if (riskLevel < 0.55) category = "Neutral"
    else if (riskLevel < 0.70) category = "Elevated Risk"
    else if (riskLevel < 0.90) category = "High Risk"
    else category = "Extreme Risk"

    return {
      risk_level: Math.round(riskLevel * 1000) / 1000,
      price: lastPrice,
      category,
    }
  } catch (e) {
    console.error(`${config.symbol} risk computation error:`, e)
    return null
  }
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
  const customWeekStart = url.searchParams.get("week_start")
  const customWeekEnd = url.searchParams.get("week_end")
  const fmpKey = Deno.env.get("FMP_API_KEY") ?? ""

  let monday: string, friday: string, nextMonday: string, nextFriday: string

  if (customWeekStart && customWeekEnd) {
    monday = customWeekStart
    friday = customWeekEnd
    const customFri = new Date(customWeekEnd + "T00:00:00Z")
    const nMon = new Date(customFri)
    nMon.setUTCDate(customFri.getUTCDate() + 3)
    const nFri = new Date(nMon)
    nFri.setUTCDate(nMon.getUTCDate() + 4)
    nextMonday = nMon.toISOString().split("T")[0]
    nextFriday = nFri.toISOString().split("T")[0]
  } else {
    ({ monday, friday, nextMonday, nextFriday } = getWeekRange())
  }

  console.log(`[gather] Starting data gather for ${monday} to ${friday}`)

  try {
    // ── Create or find pipeline run ─────────────────────────────────
    const { data: existingRun } = await supabase
      .from("deck_pipeline_runs")
      .select("*")
      .eq("week_start", monday)
      .eq("week_end", friday)
      .single()

    let pipelineRunId: string

    if (existingRun) {
      pipelineRunId = existingRun.id
      // Reset gather step
      await supabase
        .from("deck_pipeline_runs")
        .update({
          step_gather_data: "running",
          error_gather_data: null,
          started_at: existingRun.started_at ?? new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("id", pipelineRunId)
      console.log(`[gather] Reusing pipeline run ${pipelineRunId}`)
    } else {
      const { data: newRun, error: insertErr } = await supabase
        .from("deck_pipeline_runs")
        .insert({
          week_start: monday,
          week_end: friday,
          step_gather_data: "running",
          started_at: new Date().toISOString(),
        })
        .select()
        .single()

      if (insertErr || !newRun) {
        return jsonResponse({ error: `Failed to create pipeline run: ${insertErr?.message}` }, 500)
      }
      pipelineRunId = newRun.id
      console.log(`[gather] Created pipeline run ${pipelineRunId}`)
    }

    // ── Step 1: Gather ALL data from Supabase in parallel ─────────────

    const TOP_ASSETS = ["BTC", "ETH", "SOL", "BNB", "SUI", "XRP", "LINK", "AVAX"]

    const [
      { data: latestSignals },
      { data: mondaySignals },
      { data: fgEndData },
      { data: fgWeekData },
      { data: mondayPrices },
      { data: fridayPrices },
      { data: weekSparklines },
      { data: signalChanges },
      { data: thisWeekEvents },
      { data: nextWeekEvents },
      { data: weekSignals },
      { data: briefings },
    ] = await Promise.all([
      supabase.from("positioning_signals").select("asset, signal, trend_score, price, category").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(54),
      supabase.from("positioning_signals").select("asset, price").gte("signal_date", monday).lte("signal_date", friday).eq("asset", "BTC").order("signal_date", { ascending: true }).limit(1),
      supabase.from("fear_greed_history").select("value").gte("date", monday).lte("date", friday).order("date", { ascending: false }).limit(1),
      supabase.from("fear_greed_history").select("value").gte("date", monday).lte("date", friday).order("date", { ascending: true }),
      supabase.from("positioning_signals").select("asset, price, signal_date").gte("signal_date", monday).lte("signal_date", friday).in("asset", TOP_ASSETS).order("signal_date", { ascending: true }).limit(80),
      supabase.from("positioning_signals").select("asset, price, signal_date").gte("signal_date", monday).lte("signal_date", friday).in("asset", TOP_ASSETS).order("signal_date", { ascending: false }).limit(80),
      supabase.from("positioning_signals").select("asset, price, signal_date").gte("signal_date", monday).lte("signal_date", friday).in("asset", TOP_ASSETS).order("signal_date", { ascending: true }),
      supabase.from("positioning_signals").select("asset, category, signal, prev_signal, signal_date").gte("signal_date", monday).lte("signal_date", friday).not("prev_signal", "is", null).order("signal_date", { ascending: false }),
      supabase.from("economic_events").select("title, event_date, actual, forecast, impact").gte("event_date", monday).lte("event_date", friday).in("impact", ["high", "medium"]).order("event_date", { ascending: true }).limit(15),
      supabase.from("economic_events").select("title, event_date, forecast, impact").gte("event_date", nextMonday).lte("event_date", nextFriday).in("impact", ["high", "medium"]).order("event_date", { ascending: true }).limit(10),
      supabase.from("trade_signals").select("asset, direction, entry_price, status, outcome_pnl, timeframe").gte("created_at", `${monday}T00:00:00Z`).lte("created_at", `${friday}T23:59:59Z`).eq("timeframe", "4h").order("created_at", { ascending: false }).limit(20),
      supabase.from("market_summaries").select("summary_text, summary_date").gte("summary_date", monday).lte("summary_date", friday).order("summary_date", { ascending: true }).limit(10),
    ])

    // Also fetch VIX/DXY + cross-market assets in parallel
    const CROSS_MARKET_ASSETS = ["VIX", "DXY", "TLT", "GOLD", "SILVER", "OIL", "COPPER", "SPY", "QQQ", "DIA", "IWM"]
    const [
      { data: vixMon }, { data: vixFri }, { data: dxyMon }, { data: dxyFri },
      { data: crossMonday }, { data: crossLatest },
    ] = await Promise.all([
      supabase.from("positioning_signals").select("price").eq("asset", "VIX").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: true }).limit(1),
      supabase.from("positioning_signals").select("price").eq("asset", "VIX").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(1),
      supabase.from("positioning_signals").select("price").eq("asset", "DXY").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: true }).limit(1),
      supabase.from("positioning_signals").select("price").eq("asset", "DXY").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(1),
      supabase.from("positioning_signals").select("asset, price").gte("signal_date", monday).lte("signal_date", friday).in("asset", CROSS_MARKET_ASSETS).order("signal_date", { ascending: true }).limit(55),
      supabase.from("positioning_signals").select("asset, price, signal, signal_date").in("asset", CROSS_MARKET_ASSETS).gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(55),
    ])

    // Process Cover data
    const btcSignal = latestSignals?.find((s: { asset: string }) => s.asset === "BTC")
    const btcPrice = btcSignal?.price ?? null
    const btcMonday = mondaySignals?.[0]?.price ?? null
    const btcWeeklyChange = btcPrice != null && btcMonday != null ? ((btcPrice - btcMonday) / btcMonday) * 100 : null

    const bullishCount = latestSignals?.filter((s: { signal: string }) => s.signal === "bullish").length ?? 0
    const bearishCount = latestSignals?.filter((s: { signal: string }) => s.signal === "bearish").length ?? 0
    const regime = bullishCount > bearishCount * 1.5 ? "Risk-On" : bearishCount > bullishCount * 1.5 ? "Risk-Off" : "Mixed"

    // Fear & Greed
    const fearGreedEnd: number | null = fgEndData?.[0]?.value ?? null
    const fearGreedStart: number | null = fgWeekData?.[0]?.value ?? null

    // Process Market Pulse data
    const mondayMap = new Map<string, number>()
    for (const r of (mondayPrices ?? []) as { asset: string; price: number }[]) {
      if (!mondayMap.has(r.asset)) mondayMap.set(r.asset, r.price)
    }
    const fridayMap = new Map<string, number>()
    for (const r of (fridayPrices ?? []) as { asset: string; price: number }[]) {
      if (!fridayMap.has(r.asset)) fridayMap.set(r.asset, r.price)
    }

    const assetData = TOP_ASSETS.map((ticker) => {
      const weekOpen = mondayMap.get(ticker) ?? null
      const weekClose = fridayMap.get(ticker) ?? latestSignals?.find((s: { asset: string }) => s.asset === ticker)?.price ?? null
      const sparkline = (weekSparklines ?? []).filter((s: { asset: string }) => s.asset === ticker).map((s: { price: number }) => s.price)
      return {
        symbol: ticker, name: ticker, week_open: weekOpen, week_close: weekClose,
        week_change: weekOpen != null && weekClose != null ? Math.round(((weekClose - weekOpen) / weekOpen) * 10000) / 100 : 0,
        sparkline,
      }
    })

    // Process Macro data
    const macroData: Record<string, { value: number | null; change: number | null }> = {
      VIX: {
        value: vixFri?.[0]?.price ?? null,
        change: vixMon?.[0]?.price != null && vixFri?.[0]?.price != null ? Math.round(((vixFri[0].price - vixMon[0].price) / vixMon[0].price) * 10000) / 100 : null,
      },
      DXY: {
        value: dxyFri?.[0]?.price ?? null,
        change: dxyMon?.[0]?.price != null && dxyFri?.[0]?.price != null ? Math.round(((dxyFri[0].price - dxyMon[0].price) / dxyMon[0].price) * 10000) / 100 : null,
      },
    }

    // Process signal changes
    const actualChanges = (signalChanges ?? []).filter(
      (s: { signal: string; prev_signal: string | null }) => s.prev_signal && s.signal !== s.prev_signal
    )

    // Distribution from latest signals
    const catCounts: Record<string, { bullish: number; neutral: number; bearish: number }> = {}
    for (const s of latestSignals ?? []) {
      const cat = s.category ?? "crypto"
      if (!catCounts[cat]) catCounts[cat] = { bullish: 0, neutral: 0, bearish: 0 }
      if (s.signal === "bullish") catCounts[cat].bullish++
      else if (s.signal === "bearish") catCounts[cat].bearish++
      else catCounts[cat].neutral++
    }

    // Process trade signals
    const triggered = weekSignals?.length ?? 0
    const resolved = weekSignals?.filter((s: { status: string }) => ["won", "lost", "stopped"].includes(s.status)).length ?? 0
    const wins = weekSignals?.filter((s: { status: string }) => s.status === "won").length ?? 0
    const winRate = resolved > 0 ? (wins / resolved) * 100 : null
    const pnls = weekSignals?.filter((s: { outcome_pnl: number | null }) => s.outcome_pnl != null).map((s: { outcome_pnl: number }) => s.outcome_pnl) ?? []
    const avgPnl = pnls.length > 0 ? pnls.reduce((a: number, b: number) => a + b, 0) / pnls.length : null

    // Build dbContext string for use by later steps
    const dbContext = [
      `Market regime: ${regime}. BTC: $${btcPrice?.toLocaleString() ?? "N/A"} (${btcWeeklyChange ? btcWeeklyChange.toFixed(1) + "%" : "N/A"} weekly).`,
      `Fear & Greed: ${fearGreedEnd ?? "N/A"}.`,
      `VIX: ${macroData["VIX"]?.value ?? "N/A"} (${macroData["VIX"]?.change ?? "N/A"}% weekly). DXY: ${macroData["DXY"]?.value ?? "N/A"} (${macroData["DXY"]?.change ?? "N/A"}% weekly).`,
      `Signal distribution: ${Object.entries(catCounts).map(([c, d]) => `${c}: ${d.bullish}B/${d.neutral}N/${d.bearish}Be`).join(", ")}`,
      `Signal changes this week: ${actualChanges.slice(0, 10).map((s: Record<string, string>) => `${s.asset}: ${s.prev_signal}→${s.signal}`).join(", ")}`,
      `Trade signals: ${triggered} triggered, ${resolved} resolved, ${winRate ? winRate.toFixed(0) + "% WR" : "N/A"}, ${avgPnl ? avgPnl.toFixed(1) + "% avg P&L" : "N/A"}`,
      `Economic events this week: ${(thisWeekEvents ?? []).map((e: Record<string, string>) => e.title).join(", ")}`,
    ].join("\n")

    // ── Build data-driven slides ──────────────────────────────────────

    // Cover slide
    const coverSlide: SlidePayload = {
      type: "cover",
      title: "Cover",
      data: {
        type: "cover",
        payload: {
          regime,
          fear_greed_start: fearGreedStart,
          fear_greed_end: fearGreedEnd,
          btc_weekly_change: btcWeeklyChange != null ? Math.round(btcWeeklyChange * 100) / 100 : null,
          btc_price: btcPrice,
        },
      },
    }

    // Cross-Market Correlation slide
    const crossMondayMap = new Map<string, number>()
    for (const r of (crossMonday ?? []) as { asset: string; price: number }[]) {
      if (!crossMondayMap.has(r.asset)) crossMondayMap.set(r.asset, r.price)
    }
    const crossLatestMap = new Map<string, { asset: string; price: number; signal: string }>()
    for (const r of (crossLatest ?? []) as { asset: string; price: number; signal: string }[]) {
      if (!crossLatestMap.has(r.asset)) {
        crossLatestMap.set(r.asset, r)
      }
    }

    function buildCorrelationAsset(symbol: string): { symbol: string; week_change: number | null; signal: string | null; price: number | null } {
      const monPrice = crossMondayMap.get(symbol) ?? null
      const latest = crossLatestMap.get(symbol)
      const latPrice = latest?.price ?? null
      const change = monPrice != null && latPrice != null ? Math.round(((latPrice - monPrice) / monPrice) * 10000) / 100 : null
      return { symbol, week_change: change, signal: latest?.signal ?? null, price: latPrice }
    }

    const cryptoCorrelation = ["BTC", "ETH", "SOL", "BNB"].map((sym) => {
      const asset = assetData.find((a: { symbol: string }) => a.symbol === sym)
      const sig = latestSignals?.find((s: { asset: string }) => s.asset === sym)
      return {
        symbol: sym,
        week_change: asset?.week_change ?? null,
        signal: sig?.signal ?? null,
        price: asset?.week_close ?? null,
      }
    })

    const correlationGroups = [
      { group: "Crypto", assets: cryptoCorrelation },
      { group: "Equities", assets: ["SPY", "QQQ", "DIA", "IWM"].map(buildCorrelationAsset) },
      { group: "Commodities", assets: ["GOLD", "SILVER", "OIL", "COPPER"].map(buildCorrelationAsset) },
      { group: "Macro", assets: ["VIX", "DXY", "TLT"].map(buildCorrelationAsset) },
    ]

    const cryptoAvg = cryptoCorrelation.reduce((s, a) => s + (a.week_change ?? 0), 0) / cryptoCorrelation.length
    const equityAvg = ["SPY", "QQQ"].reduce((s, sym) => {
      const a = buildCorrelationAsset(sym)
      return s + (a.week_change ?? 0)
    }, 0) / 2
    const sameDirection = (cryptoAvg >= 0 && equityAvg >= 0) || (cryptoAvg < 0 && equityAvg < 0)
    const corrNarrative = sameDirection
      ? "Crypto and equities moved in sync this week — risk appetite is consistent across asset classes."
      : "Crypto and equities diverged this week — watch for a convergence play or structural decoupling."

    const correlationSlide: SlidePayload = {
      type: "correlation",
      title: "Cross-Market View",
      data: {
        type: "correlation",
        payload: {
          groups: correlationGroups,
          narrative: corrNarrative,
        },
      },
    }

    // Market Pulse slide
    const marketPulseSlide: SlidePayload = {
      type: "marketPulse",
      title: "Market Pulse",
      data: { type: "marketPulse", payload: { assets: assetData } },
    }

    // Snapshot slide — fetch additional data
    const [
      { data: spyMon }, { data: spyFri },
      { data: qqqMon }, { data: qqqFri },
      { data: supplyData },
      { data: weekTrendScores },
    ] = await Promise.all([
      supabase.from("positioning_signals").select("price").eq("asset", "SPY").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: true }).limit(1),
      supabase.from("positioning_signals").select("price, signal, trend_score").eq("asset", "SPY").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(1),
      supabase.from("positioning_signals").select("price").eq("asset", "QQQ").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: true }).limit(1),
      supabase.from("positioning_signals").select("price, signal, trend_score").eq("asset", "QQQ").gte("signal_date", monday).lte("signal_date", friday).order("signal_date", { ascending: false }).limit(1),
      supabase.from("supply_in_profit").select("value").gte("date", monday).lte("date", friday).order("date", { ascending: false }).limit(1),
      supabase.from("positioning_signals").select("asset, trend_score, signal, signal_date").gte("signal_date", monday).lte("signal_date", friday).in("asset", ["BTC", "ETH", "SOL"]).order("signal_date", { ascending: true }),
    ])

    const spyMonPrice = spyMon?.[0]?.price ?? null
    const spyFriPrice = spyFri?.[0]?.price ?? null
    const spyWeekChange = spyMonPrice != null && spyFriPrice != null ? Math.round(((spyFriPrice - spyMonPrice) / spyMonPrice) * 10000) / 100 : null
    const spySignal = spyFri?.[0]?.signal ?? null

    const qqqMonPrice = qqqMon?.[0]?.price ?? null
    const qqqFriPrice = qqqFri?.[0]?.price ?? null
    const qqqWeekChange = qqqMonPrice != null && qqqFriPrice != null ? Math.round(((qqqFriPrice - qqqMonPrice) / qqqMonPrice) * 10000) / 100 : null
    const qqqSignal = qqqFri?.[0]?.signal ?? null

    const btcSupplyInProfit = supplyData?.[0]?.value ?? null

    const totalSignals = (latestSignals ?? []).length
    const bullishPct = totalSignals > 0 ? (bullishCount / totalSignals) * 100 : 50
    const emotionScore = fearGreedEnd ?? 50
    const engagementHigh = bullishPct > 60 || bullishPct < 30
    let sentimentRegime = "Apathy"
    if (emotionScore >= 55 && engagementHigh) sentimentRegime = "FOMO"
    else if (emotionScore >= 55 && !engagementHigh) sentimentRegime = "Complacency"
    else if (emotionScore < 45 && engagementHigh) sentimentRegime = "Panic"
    else if (emotionScore < 45 && !engagementHigh) sentimentRegime = "Apathy"
    else sentimentRegime = bullishCount > bearishCount ? "Complacency" : "Apathy"

    const SNAPSHOT_ASSETS = ["BTC", "ETH", "SOL"]
    const assetRisks = SNAPSHOT_ASSETS.map((symbol) => {
      const weekEntries = (weekTrendScores ?? []).filter((s: { asset: string }) => s.asset === symbol)
      const weekScores = weekEntries.map((s: { trend_score: number }) => s.trend_score ?? 50)
      const fridayEntry = weekEntries.length > 0 ? weekEntries[weekEntries.length - 1] : null
      const currentScore = fridayEntry?.trend_score ?? 50
      const riskLevel = Math.max(0, Math.min(1, 1 - (currentScore / 100)))

      let weekAverage: number | null = null
      if (weekScores.length >= 2) {
        const avgScore = weekScores.reduce((a: number, b: number) => a + b, 0) / weekScores.length
        weekAverage = Math.round(Math.max(0, Math.min(1, 1 - (avgScore / 100))) * 1000) / 1000
      }

      const signal = fridayEntry?.signal ?? "neutral"

      let daysAtLevel: number | null = null
      if (weekEntries.length >= 2) {
        let count = 0
        for (let i = weekEntries.length - 1; i >= 0; i--) {
          const score = weekEntries[i].trend_score ?? 50
          const r = 1 - (score / 100)
          const sameZone = Math.abs(r - riskLevel) < 0.15
          if (sameZone) count++
          else break
        }
        daysAtLevel = count > 0 ? count : null
      }

      let riskLabel = "Moderate Risk"
      if (riskLevel < 0.2) riskLabel = "Very Low Risk"
      else if (riskLevel < 0.4) riskLabel = "Low Risk"
      else if (riskLevel < 0.55) riskLabel = "Moderate Risk"
      else if (riskLevel < 0.7) riskLabel = "Elevated Risk"
      else if (riskLevel < 0.9) riskLabel = "High Risk"
      else riskLabel = "Extreme Risk"

      return {
        symbol,
        risk_level: Math.round(riskLevel * 1000) / 1000,
        week_average: weekAverage,
        risk_label: riskLabel,
        signal,
        days_at_level: daysAtLevel,
      }
    })

    const fgValues = (fgWeekData ?? []).map((r: { value: number }) => r.value).filter((v: number) => v != null)
    const fearGreedAvg = fgValues.length > 0 ? Math.round(fgValues.reduce((a: number, b: number) => a + b, 0) / fgValues.length) : fearGreedEnd

    // Override with real log regression risk
    if (fmpKey) {
      const riskResults = await Promise.all(
        RISK_CONFIGS.map(async (config) => {
          try {
            const result = await computeAssetRisk(fmpKey, config)
            if (result) {
              console.log(`[gather] ${config.symbol} log regression risk: ${result.risk_level} (${result.category})`)
            }
            return { symbol: config.symbol, result }
          } catch (e) {
            console.error(`Failed to compute ${config.symbol} regression risk:`, e)
            return { symbol: config.symbol, result: null }
          }
        })
      )
      for (const { symbol, result } of riskResults) {
        if (!result) continue
        const idx = assetRisks.findIndex((a: { symbol: string }) => a.symbol === symbol)
        if (idx >= 0) {
          assetRisks[idx] = {
            ...assetRisks[idx],
            risk_level: result.risk_level,
            risk_label: result.category,
          }
        }
      }
    }

    const snapshotSlide: SlidePayload = {
      type: "snapshot",
      title: "Arkline Snapshot",
      data: {
        type: "snapshot",
        payload: {
          asset_risks: assetRisks,
          risk_type: "regression",
          fear_greed_avg: fearGreedAvg,
          fear_greed_end: fearGreedEnd,
          sentiment_regime: sentimentRegime,
          spy_week_change: spyWeekChange,
          qqq_week_change: qqqWeekChange,
          spy_price: spyFriPrice,
          qqq_price: qqqFriPrice,
          spy_signal: spySignal,
          qqq_signal: qqqSignal,
          btc_supply_in_profit: btcSupplyInProfit,
        },
      },
    }

    // ── Store output ──────────────────────────────────────────────────
    const gatherOutput = {
      monday,
      friday,
      nextMonday,
      nextFriday,
      dbContext,
      slides: {
        cover: coverSlide,
        correlation: correlationSlide,
        marketPulse: marketPulseSlide,
        snapshot: snapshotSlide,
      },
      briefings: briefings ?? [],
      thisWeekEvents: thisWeekEvents ?? [],
      nextWeekEvents: nextWeekEvents ?? [],
    }

    const { error: updateErr } = await supabase
      .from("deck_pipeline_runs")
      .update({
        step_gather_data: "completed",
        output_gather_data: gatherOutput,
        error_gather_data: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", pipelineRunId)

    if (updateErr) {
      return jsonResponse({ error: `Failed to save gather output: ${updateErr.message}` }, 500)
    }

    console.log(`[gather] Completed for ${monday} to ${friday}`)
    return jsonResponse({
      pipeline_run_id: pipelineRunId,
      week_start: monday,
      week_end: friday,
      step_gather_data: "completed",
    })
  } catch (e) {
    console.error("[gather] error:", e)
    // Try to mark step as failed
    try {
      await supabase
        .from("deck_pipeline_runs")
        .update({
          step_gather_data: "failed",
          error_gather_data: String(e),
          updated_at: new Date().toISOString(),
        })
        .eq("week_start", monday)
        .eq("week_end", friday)
    } catch { /* best effort */ }
    return jsonResponse({ error: String(e) }, 500)
  }
})
