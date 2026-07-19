import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * compute-market-rotation Edge Function
 *
 * Daily cross-market verdict: is money favoring crypto, equities, or balanced?
 * Four transparent factors, each voting with a human-readable reason:
 *   1. BTC/SPY relative strength vs its 20-day average
 *   2. 30-day return differential (BTC vs SPY)
 *   3. Crypto internals (Arkline BTC risk model + positioning signal)
 *   4. Equity regime (index positioning signals)
 * Plus global liquidity direction as a fifth vote when available.
 *
 * The verdict AND the reasoning are stored — the app never shows a conclusion
 * without its evidence. Descriptive, never prescriptive.
 *
 * Runs daily at 23:00 UTC (cron: 20260714000006_market_rotation.sql).
 */

const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? ""

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

interface Factor {
  factor: string
  vote: "crypto" | "stocks" | "neutral"
  detail: string
}

async function fetchCloses(symbol: string, fmpKey: string): Promise<Array<{ date: string; close: number }> | null> {
  const url = `https://financialmodelingprep.com/stable/historical-price-eod/full?symbol=${symbol}&apikey=${fmpKey}`
  const resp = await fetch(url)
  if (!resp.ok) return null
  const data = await resp.json()
  if (!Array.isArray(data) || data.length === 0) return null
  // newest first → normalize ascending
  return data
    .map((r: any) => ({ date: r.date, close: parseFloat(r.close) }))
    .filter((r) => r.date && r.close > 0)
    .sort((a, b) => a.date.localeCompare(b.date))
}

/** Close at or before a given date. */
function closeAt(series: Array<{ date: string; close: number }>, d: string): number | null {
  for (let i = series.length - 1; i >= 0; i--) {
    if (series[i].date <= d) return series[i].close
  }
  return null
}

function daysAgo(n: number): string {
  return new Date(Date.now() - n * 86400000).toISOString().split("T")[0]
}

Deno.serve(async (req) => {
  const authHeader = req.headers.get("authorization") ?? ""
  const cronSecret = req.headers.get("x-cron-secret") ?? ""
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  const fmpKey = Deno.env.get("FMP_API_KEY") ?? ""

  if (cronSecret !== CRON_SECRET && authHeader !== `Bearer ${serviceRoleKey}`) {
    return jsonResponse({ error: "Unauthorized" }, 401)
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey)
  const today = new Date().toISOString().split("T")[0]
  const factors: Factor[] = []

  try {
    // ── Price series
    const [btc, spy] = await Promise.all([
      fetchCloses("BTCUSD", fmpKey),
      fetchCloses("SPY", fmpKey),
    ])
    if (!btc || !spy) return jsonResponse({ error: "Price history unavailable" }, 502)

    // ── Factor 1: BTC/SPY relative strength vs 20-day average
    {
      const recent = spy.slice(-20).map((s) => {
        const b = closeAt(btc, s.date)
        return b ? b / s.close : null
      }).filter((x): x is number => x !== null)

      if (recent.length >= 10) {
        const current = recent[recent.length - 1]
        const avg = recent.reduce((a, b) => a + b, 0) / recent.length
        const devPct = ((current / avg) - 1) * 100
        const vote = devPct > 1.5 ? "crypto" : devPct < -1.5 ? "stocks" : "neutral"
        factors.push({
          factor: "BTC/SPY relative strength",
          vote,
          detail: `BTC/SPY ratio is ${devPct >= 0 ? "+" : ""}${devPct.toFixed(1)}% vs its 20-day average — ${
            vote === "crypto" ? "crypto gaining vs equities" : vote === "stocks" ? "equities gaining vs crypto" : "no clear leader"
          }`,
        })
      }
    }

    // ── Factor 2: 30-day return differential
    {
      const btcNow = btc[btc.length - 1]?.close
      const spyNow = spy[spy.length - 1]?.close
      const btcPrev = closeAt(btc, daysAgo(30))
      const spyPrev = closeAt(spy, daysAgo(30))
      if (btcNow && spyNow && btcPrev && spyPrev) {
        const btcRet = ((btcNow / btcPrev) - 1) * 100
        const spyRet = ((spyNow / spyPrev) - 1) * 100
        const diff = btcRet - spyRet
        const vote = diff > 3 ? "crypto" : diff < -3 ? "stocks" : "neutral"
        factors.push({
          factor: "30-day returns",
          vote,
          detail: `BTC ${btcRet >= 0 ? "+" : ""}${btcRet.toFixed(1)}% vs SPY ${spyRet >= 0 ? "+" : ""}${spyRet.toFixed(1)}% over 30 days`,
        })
      }
    }

    // ── Factor 3: Crypto internals (Arkline risk model + BTC positioning signal)
    {
      const [{ data: riskRows }, { data: sigRows }] = await Promise.all([
        supabase.from("model_portfolio_risk_history")
          .select("risk_level, risk_date").eq("asset", "BTC")
          .order("risk_date", { ascending: false }).limit(1),
        supabase.from("positioning_signals")
          .select("signal, signal_date").eq("asset", "BTC")
          .order("signal_date", { ascending: false }).limit(1),
      ])
      const risk = riskRows?.[0]?.risk_level != null ? Number(riskRows[0].risk_level) : null
      const signal = sigRows?.[0]?.signal ?? null
      if (risk !== null || signal) {
        let vote: Factor["vote"] = "neutral"
        if (signal === "bullish" && (risk === null || risk < 0.70)) vote = "crypto"
        else if (signal === "bearish") vote = "stocks"
        const riskTxt = risk !== null ? `BTC risk level ${risk.toFixed(2)}` : "risk n/a"
        factors.push({
          factor: "Crypto internals",
          vote,
          detail: `BTC trend ${signal ?? "n/a"}, ${riskTxt} — ${
            vote === "crypto" ? "healthy trend with room to run" : vote === "stocks" ? "crypto trend weak" : "mixed picture"
          }`,
        })
      }
    }

    // ── Factor 4: Equity regime (index positioning signals, VIX inverted)
    {
      const { data } = await supabase
        .from("positioning_signals")
        .select("signal_date, asset, signal, category")
        .gte("signal_date", daysAgo(7))
        .or("category.eq.index,asset.eq.VIX")
        .order("signal_date", { ascending: false })
      const withIndex = (data ?? []).filter((r: any) => r.category === "index")
      if (withIndex.length > 0) {
        const latestDate = withIndex[0].signal_date
        const daySignals = (data ?? []).filter((r: any) => r.signal_date === latestDate)
        let bearish = 0, total = 0
        for (const s of daySignals) {
          if (s.asset === "VIX") { total++; if (s.signal === "bullish") bearish++ }
          else if (s.category === "index") { total++; if (s.signal === "bearish") bearish++ }
        }
        const riskOn = total > 0 && bearish / total < 0.5
        factors.push({
          factor: "Equity regime",
          vote: riskOn ? "stocks" : "neutral",
          detail: riskOn
            ? "US index signals risk-on — equity breadth supportive"
            : "US index signals risk-off — defensive backdrop, favors neither market",
        })
      }
    }

    // ── Factor 5: Global liquidity (defensive parse — vote only if trend is clear)
    {
      try {
        const { data: liqRow } = await supabase
          .from("market_data_cache")
          .select("data").eq("key", "global_liquidity_index").single()
        if (liqRow?.data) {
          const parsed = typeof liqRow.data === "string" ? JSON.parse(liqRow.data) : liqRow.data
          const obj = typeof parsed === "string" ? JSON.parse(parsed) : parsed
          // Look for a history/series array to derive direction
          const series = obj?.history ?? obj?.series ?? obj?.monthly ?? null
          if (Array.isArray(series) && series.length >= 2) {
            const last = series[series.length - 1]
            const prev = series[series.length - 2]
            const lastVal = last?.composite_liquidity_t ?? last?.value ?? null
            const prevVal = prev?.composite_liquidity_t ?? prev?.value ?? null
            if (lastVal != null && prevVal != null && prevVal > 0) {
              const chg = ((lastVal / prevVal) - 1) * 100
              const vote = chg > 0.3 ? "crypto" : chg < -0.3 ? "stocks" : "neutral"
              factors.push({
                factor: "Global liquidity",
                vote,
                detail: `Composite liquidity ${chg >= 0 ? "+" : ""}${chg.toFixed(1)}% m/m — ${
                  vote === "crypto" ? "expansion historically favors high-beta crypto" : vote === "stocks" ? "contraction favors quality equities and cash" : "flat"
                }`,
              })
            }
          }
        }
      } catch { /* liquidity factor unavailable — skip silently */ }
    }

    // ── Verdict
    const cryptoVotes = factors.filter((f) => f.vote === "crypto").length
    const stockVotes = factors.filter((f) => f.vote === "stocks").length
    const score = cryptoVotes - stockVotes
    const favored = score >= 1 ? "crypto" : score <= -1 ? "stocks" : "balanced"

    await supabase.from("market_rotation").upsert({
      rotation_date: today,
      favored,
      score,
      factors,
    }, { onConflict: "rotation_date" })

    console.log(`[rotation] ${today}: ${favored} (score ${score}, ${factors.length} factors)`)
    return jsonResponse({ success: true, date: today, favored, score, factors })
  } catch (err) {
    console.error("[rotation] Error:", err)
    return jsonResponse({ error: String(err) }, 500)
  }
})
