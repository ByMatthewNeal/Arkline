import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * signal-monitor Edge Function
 *
 * Lightweight hourly monitor that checks current prices against open trade signals.
 * Does NOT generate new signals — only resolves existing ones faster.
 *
 * Runs every hour at :30 (offset from the 4H pipeline at :05).
 * Skips the 4H candle-close hours (0, 4, 8, 12, 16, 20 UTC) since the
 * full pipeline already handles resolution at those times.
 *
 * For each triggered signal:
 *   - Checks stop loss / target 1 hits using 1H candle high/low
 *   - Updates runner trailing stops
 *   - Resolves expired signals
 *   - Sends push notifications on resolution events
 */

const ASSETS = ["BTCUSDT", "ETHUSDT", "SOLUSDT", "SUIUSDT", "LINKUSDT", "ADAUSDT"]

const TICKER_MAP: Record<string, string> = {
  BTCUSDT: "BTC", ETHUSDT: "ETH", SOLUSDT: "SOL",
  SUIUSDT: "SUI", LINKUSDT: "LINK", ADAUSDT: "ADA",
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

  // Skip hours where the full pipeline runs (4H candle closes)
  const utcHour = new Date().getUTCHours()
  const pipelineHours = [0, 4, 8, 12, 16, 20]
  if (pipelineHours.includes(utcHour)) {
    return json({ skipped: true, reason: "Full pipeline runs this hour" })
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const supabase = createClient(supabaseUrl, supabaseKey)

  // Fetch all triggered signals in one query
  const { data: signals } = await supabase
    .from("trade_signals")
    .select("*")
    .eq("status", "triggered")

  // Also fetch active (not yet triggered) signals for proximity alerts
  const { data: activeSignals } = await supabase
    .from("trade_signals")
    .select("*")
    .eq("status", "active")
    .is("t1_hit_at", null)

  const allSignals = signals ?? []
  const proximitySignals = activeSignals ?? []

  if (allSignals.length === 0 && proximitySignals.length === 0) {
    return json({ resolved: 0, message: "No open signals" })
  }

  // Determine which assets have open signals
  const allAssetsNeeded = new Set([
    ...allSignals.map((s: any) => s.asset),
    ...proximitySignals.map((s: any) => s.asset),
  ])
  const symbolsToCheck = ASSETS.filter(sym => allAssetsNeeded.has(TICKER_MAP[sym]))

  if (symbolsToCheck.length === 0) {
    return json({ resolved: 0, message: "No assets to check" })
  }

  // Fetch 1H candles for relevant assets only
  const candles: Record<string, { high: number; low: number; close: number }> = {}
  for (const symbol of symbolsToCheck) {
    try {
      const resp = await fetch(
        `https://api.binance.com/api/v3/klines?symbol=${symbol}&interval=1h&limit=1`
      )
      if (resp.ok) {
        const data = await resp.json()
        if (data.length > 0) {
          candles[TICKER_MAP[symbol]] = {
            high: parseFloat(data[0][2]),
            low: parseFloat(data[0][3]),
            close: parseFloat(data[0][4]),
          }
        }
      }
    } catch (err) {
      console.error(`Failed to fetch ${symbol}: ${err}`)
    }
    // Small delay between requests
    await new Promise(r => setTimeout(r, 100))
  }

  const now = new Date()
  const stats = { resolved: 0, t1Hits: 0, runnerStops: 0, losses: 0, expired: 0, notifications: 0, proximityAlerts: 0 }

  for (const signal of allSignals) {
    const candle = candles[signal.asset]
    if (!candle) continue

    const isBuy = signal.signal_type === "buy" || signal.signal_type === "strong_buy"
    const entryMid = Number(signal.entry_price_mid)
    const t1 = signal.target_1 ? Number(signal.target_1) : null
    const sl = Number(signal.stop_loss)
    const risk1r = signal.risk_1r ? Number(signal.risk_1r) : Math.abs(entryMid - sl)
    const t1AlreadyHit = !!signal.t1_hit_at
    let bestPrice = signal.best_price ? Number(signal.best_price) : entryMid
    let runnerStop = signal.runner_stop ? Number(signal.runner_stop) : sl

    // --- Expiry check ---
    if (signal.expires_at && new Date(signal.expires_at) <= now) {
      const exitPrice = candle.close

      if (t1AlreadyHit) {
        const runnerPnl = isBuy
          ? ((exitPrice - entryMid) / entryMid) * 100
          : ((entryMid - exitPrice) / entryMid) * 100
        const t1Pnl = signal.t1_pnl_pct ? Number(signal.t1_pnl_pct) : 0
        const totalPnl = (t1Pnl + runnerPnl) / 2

        await supabase.from("trade_signals").update({
          status: totalPnl > 0 ? "target_hit" : "expired",
          outcome: totalPnl > 0 ? "win" : "loss",
          outcome_pct: round2(totalPnl),
          runner_exit_price: exitPrice,
          runner_pnl_pct: round2(runnerPnl),
          closed_at: now.toISOString(),
          duration_hours: hoursSince(signal.triggered_at, now),
        }).eq("id", signal.id)

        await notify(supabaseUrl, cronSecret, signal, totalPnl > 0 ? "expired_win" : "expired_loss", exitPrice)
      } else {
        const pnl = isBuy
          ? ((exitPrice - entryMid) / entryMid) * 100
          : ((entryMid - exitPrice) / entryMid) * 100

        await supabase.from("trade_signals").update({
          status: "expired",
          outcome: "loss",
          outcome_pct: round2(pnl),
          closed_at: now.toISOString(),
          duration_hours: hoursSince(signal.triggered_at, now),
        }).eq("id", signal.id)

        await notify(supabaseUrl, cronSecret, signal, "expired_loss", exitPrice)
      }

      stats.expired++
      stats.resolved++
      stats.notifications++
      continue
    }

    // --- LONG ---
    if (isBuy) {
      if (!t1AlreadyHit) {
        // Phase 1: check SL then T1
        if (candle.low <= sl) {
          const pnl = ((sl - entryMid) / entryMid) * 100
          await supabase.from("trade_signals").update({
            status: "invalidated",
            outcome: "loss",
            outcome_pct: round2(pnl),
            closed_at: now.toISOString(),
            duration_hours: hoursSince(signal.triggered_at, now),
          }).eq("id", signal.id)
          stats.losses++
          stats.resolved++
          await notify(supabaseUrl, cronSecret, signal, "stop_loss", sl)
          stats.notifications++
          continue
        }

        if (t1 && candle.high >= t1) {
          const t1Pnl = ((t1 - entryMid) / entryMid) * 100
          await supabase.from("trade_signals").update({
            t1_hit_at: now.toISOString(),
            t1_pnl_pct: round2(t1Pnl),
            best_price: candle.high,
            runner_stop: entryMid, // Move to breakeven
          }).eq("id", signal.id)
          stats.t1Hits++
          await notify(supabaseUrl, cronSecret, signal, "t1_hit", t1)
          stats.notifications++
        }
      } else {
        // Phase 2: Runner trailing stop
        bestPrice = Math.max(bestPrice, candle.high)
        runnerStop = Math.max(runnerStop, bestPrice - risk1r)

        if (candle.low <= runnerStop) {
          const runnerPnl = ((runnerStop - entryMid) / entryMid) * 100
          const t1Pnl = signal.t1_pnl_pct ? Number(signal.t1_pnl_pct) : 0
          const totalPnl = (t1Pnl + runnerPnl) / 2

          await supabase.from("trade_signals").update({
            status: totalPnl > 0 ? "target_hit" : "invalidated",
            outcome: totalPnl > 0 ? "win" : "loss",
            outcome_pct: round2(totalPnl),
            runner_exit_price: runnerStop,
            runner_pnl_pct: round2(runnerPnl),
            best_price: bestPrice,
            runner_stop: runnerStop,
            closed_at: now.toISOString(),
            duration_hours: hoursSince(signal.triggered_at, now),
          }).eq("id", signal.id)
          stats.runnerStops++
          stats.resolved++
          await notify(supabaseUrl, cronSecret, signal, totalPnl > 0 ? "runner_win" : "runner_loss", runnerStop)
          stats.notifications++
        } else {
          // Just update trailing values
          await supabase.from("trade_signals").update({
            best_price: bestPrice,
            runner_stop: runnerStop,
          }).eq("id", signal.id)
        }
      }
    } else {
      // --- SHORT ---
      if (!t1AlreadyHit) {
        if (candle.high >= sl) {
          const pnl = ((entryMid - sl) / entryMid) * 100
          await supabase.from("trade_signals").update({
            status: "invalidated",
            outcome: "loss",
            outcome_pct: round2(pnl),
            closed_at: now.toISOString(),
            duration_hours: hoursSince(signal.triggered_at, now),
          }).eq("id", signal.id)
          stats.losses++
          stats.resolved++
          await notify(supabaseUrl, cronSecret, signal, "stop_loss", sl)
          stats.notifications++
          continue
        }

        if (t1 && candle.low <= t1) {
          const t1Pnl = ((entryMid - t1) / entryMid) * 100
          await supabase.from("trade_signals").update({
            t1_hit_at: now.toISOString(),
            t1_pnl_pct: round2(t1Pnl),
            best_price: candle.low,
            runner_stop: entryMid,
          }).eq("id", signal.id)
          stats.t1Hits++
          await notify(supabaseUrl, cronSecret, signal, "t1_hit", t1)
          stats.notifications++
        }
      } else {
        bestPrice = Math.min(bestPrice, candle.low)
        runnerStop = Math.min(runnerStop, bestPrice + risk1r)

        if (candle.high >= runnerStop) {
          const runnerPnl = ((entryMid - runnerStop) / entryMid) * 100
          const t1Pnl = signal.t1_pnl_pct ? Number(signal.t1_pnl_pct) : 0
          const totalPnl = (t1Pnl + runnerPnl) / 2

          await supabase.from("trade_signals").update({
            status: totalPnl > 0 ? "target_hit" : "invalidated",
            outcome: totalPnl > 0 ? "win" : "loss",
            outcome_pct: round2(totalPnl),
            runner_exit_price: runnerStop,
            runner_pnl_pct: round2(runnerPnl),
            best_price: bestPrice,
            runner_stop: runnerStop,
            closed_at: now.toISOString(),
            duration_hours: hoursSince(signal.triggered_at, now),
          }).eq("id", signal.id)
          stats.runnerStops++
          stats.resolved++
          await notify(supabaseUrl, cronSecret, signal, totalPnl > 0 ? "runner_win" : "runner_loss", runnerStop)
          stats.notifications++
        } else {
          await supabase.from("trade_signals").update({
            best_price: bestPrice,
            runner_stop: runnerStop,
          }).eq("id", signal.id)
        }
      }
    }
  }

  // ─── Proximity Alerts ────────────────────────────────────────────────────
  // Alert users when price is within 2% of a triggered signal's entry zone
  // (where T1 hasn't been hit yet — user may not have set limit orders)
  const PROXIMITY_PCT = 2.0
  const PROXIMITY_COOLDOWN_MS = 4 * 3600000 // 4 hours between alerts

  for (const signal of proximitySignals) {
    const candle = candles[signal.asset]
    if (!candle) continue

    const entryMid = Number(signal.entry_price_mid)
    const entryLow = Number(signal.entry_zone_low)
    const entryHigh = Number(signal.entry_zone_high)
    const isBuy = signal.signal_type === "buy" || signal.signal_type === "strong_buy"

    // Check if price is approaching but hasn't fully entered the zone
    const approachPrice = isBuy ? candle.low : candle.high
    const zoneEdge = isBuy ? entryHigh : entryLow
    const distancePct = Math.abs((approachPrice - zoneEdge) / zoneEdge) * 100

    // Only alert if within proximity range and approaching from the right side
    const isApproaching = isBuy
      ? approachPrice > entryHigh && distancePct <= PROXIMITY_PCT
      : approachPrice < entryLow && distancePct <= PROXIMITY_PCT

    if (!isApproaching) continue

    // Dedup: skip if we already alerted recently
    if (signal.proximity_notified_at) {
      const lastNotified = new Date(signal.proximity_notified_at).getTime()
      if (now.getTime() - lastNotified < PROXIMITY_COOLDOWN_MS) continue
    }

    const direction = isBuy ? "Long" : "Short"
    const priceStr = formatPrice(candle.close)
    const entryStr = `${formatPrice(entryLow)} – ${formatPrice(entryHigh)}`
    const scoreStr = signal.composite_score ? ` (Score: ${signal.composite_score})` : ""

    try {
      await fetch(`${supabaseUrl}/functions/v1/send-broadcast-notification`, {
        method: "POST",
        headers: { "Content-Type": "application/json", "x-cron-secret": cronSecret },
        body: JSON.stringify({
          broadcast_id: signal.id,
          title: `🔔 ${signal.asset} approaching ${direction} entry zone`,
          body: `Price at ${priceStr} — ${distancePct.toFixed(1)}% from entry zone (${entryStr})${scoreStr}`,
          event_type: "signal_proximity",
          target_audience: { type: "premium" },
        }),
      })

      await supabase.from("trade_signals").update({
        proximity_notified_at: now.toISOString(),
      }).eq("id", signal.id)

      stats.proximityAlerts++
      stats.notifications++
    } catch (err) {
      console.error(`Proximity alert failed for ${signal.id}: ${err}`)
    }
  }

  console.log(`Signal monitor: ${JSON.stringify(stats)}`)
  return json(stats)
})

// ─── Notification Helper ────────────────────────────────────────────────────

type EventType = "stop_loss" | "t1_hit" | "runner_win" | "runner_loss" | "expired_win" | "expired_loss"

async function notify(
  supabaseUrl: string,
  cronSecret: string,
  signal: any,
  event: EventType,
  price: number,
) {
  const ticker = signal.asset
  const isBuy = signal.signal_type === "buy" || signal.signal_type === "strong_buy"
  const direction = isBuy ? "Long" : "Short"
  const priceStr = formatPrice(price)

  let emoji: string
  let title: string
  let body: string

  switch (event) {
    case "stop_loss":
      emoji = "🛑"
      title = `${emoji} ${ticker} ${direction} — Stop Loss Hit`
      body = `Closed at ${priceStr}. ${formatPnl(signal, price)}`
      break
    case "t1_hit":
      emoji = "🎯"
      title = `${emoji} ${ticker} ${direction} — Target 1 Hit!`
      body = `T1 at ${priceStr} reached. 50% locked, runner trailing with BE stop.`
      break
    case "runner_win":
      emoji = "✅"
      title = `${emoji} ${ticker} ${direction} — Runner Closed (Win)`
      body = `Trailing stop hit at ${priceStr}. ${formatOutcome(signal)}`
      break
    case "runner_loss":
      emoji = "📉"
      title = `${emoji} ${ticker} ${direction} — Runner Closed`
      body = `Trailing stop hit at ${priceStr}. ${formatOutcome(signal)}`
      break
    case "expired_win":
      emoji = "⏰"
      title = `${emoji} ${ticker} ${direction} — Expired (Profit)`
      body = `Signal expired at ${priceStr}. ${formatOutcome(signal)}`
      break
    case "expired_loss":
      emoji = "⏰"
      title = `${emoji} ${ticker} ${direction} — Expired`
      body = `Signal expired at ${priceStr}. No target reached.`
      break
  }

  // Map event to preference key
  const eventTypeMap: Record<EventType, string> = {
    stop_loss: "signal_stop_loss",
    t1_hit: "signal_t1_hit",
    runner_win: "signal_runner_close",
    runner_loss: "signal_runner_close",
    expired_win: "signal_expiry",
    expired_loss: "signal_expiry",
  }

  try {
    await fetch(`${supabaseUrl}/functions/v1/send-broadcast-notification`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-cron-secret": cronSecret,
      },
      body: JSON.stringify({
        broadcast_id: signal.id,
        title,
        body,
        event_type: eventTypeMap[event],
        target_audience: { type: "premium" },
      }),
    })
  } catch (err) {
    console.error(`Notification failed for ${signal.id}: ${err}`)
  }
}

function formatPrice(price: number): string {
  if (price > 1000) return `$${Math.round(price).toLocaleString()}`
  if (price > 1) return `$${price.toFixed(2)}`
  return `$${price.toFixed(4)}`
}

function formatPnl(signal: any, exitPrice: number): string {
  const entry = Number(signal.entry_price_mid)
  const isBuy = signal.signal_type === "buy" || signal.signal_type === "strong_buy"
  const pnl = isBuy
    ? ((exitPrice - entry) / entry) * 100
    : ((entry - exitPrice) / entry) * 100
  return `PnL: ${pnl >= 0 ? "+" : ""}${pnl.toFixed(2)}%`
}

function formatOutcome(signal: any): string {
  const t1Pnl = signal.t1_pnl_pct ? Number(signal.t1_pnl_pct) : 0
  return `T1: +${t1Pnl.toFixed(2)}%`
}

// ─── Utilities ──────────────────────────────────────────────────────────────

function round2(n: number): number {
  return Math.round(n * 100) / 100
}

function hoursSince(from: string, to: Date): number {
  return Math.round((to.getTime() - new Date(from).getTime()) / 3600000)
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
