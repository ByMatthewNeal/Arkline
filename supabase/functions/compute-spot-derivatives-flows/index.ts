import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// Spot vs derivatives flows for BTC, from Coinalyze free data.
// Spot CVD = cumulative taker (buy - sell) notional across major spot venues.
// Compared against perp open interest (USD) and funding rate, so you can see
// whether moves are spot-led (organic) or leverage-led (fragile).

const SPOT = ["BTCUSD.A", "BTCUSD.C", "BTCUSDT.K"] // Binance, Coinbase, Kraken
const PERP = "BTCUSDT_PERP.A"
const LOOKBACK_DAYS = 120

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405)
  const key = Deno.env.get("COINALYZE_API_KEY") ?? ""
  if (!key) return json({ error: "COINALYZE_API_KEY not set" }, 503)

  const now = Math.floor(Date.now() / 1000)
  const from = now - LOOKBACK_DAYS * 86400
  const H = { api_key: key }
  const base = "https://api.coinalyze.net/v1"
  const q = `interval=daily&from=${from}&to=${now}`

  async function get(path: string) {
    const r = await fetch(`${base}/${path}`, { headers: H })
    if (!r.ok) throw new Error(`Coinalyze ${r.status} on ${path.split("?")[0]}`)
    return await r.json()
  }

  let spotArr, oiArr, fundArr
  try {
    spotArr = await get(`ohlcv-history?symbols=${SPOT.join(",")}&${q}`)
    oiArr = await get(`open-interest-history?symbols=${PERP}&${q}&convert_to_usd=true`)
    fundArr = await get(`funding-rate-history?symbols=${PERP}&${q}`)
  } catch (e) {
    console.error(e)
    return json({ error: String(e) }, 502)
  }

  // Per-day aggregated spot delta notional (USD) and a reference close.
  type Row = { t: number; o: number; h: number; l: number; c: number; v: number; bv: number }
  const deltaByDay = new Map<number, number>()
  const closeByDay = new Map<number, number>()
  let refSymbolSeen = false
  for (const series of (spotArr as Array<{ symbol: string; history: Row[] }>)) {
    const isRef = series.symbol === SPOT[0]
    for (const r of series.history) {
      const deltaBtc = 2 * r.bv - r.v // taker buy - taker sell, in BTC
      const prev = deltaByDay.get(r.t) ?? 0
      deltaByDay.set(r.t, prev + deltaBtc * r.c)
      if (isRef) { closeByDay.set(r.t, r.c); refSymbolSeen = true }
    }
  }
  if (!refSymbolSeen) return json({ error: "No spot reference data" }, 502)

  const oiHist: Array<{ t: number; c: number }> = (oiArr?.[0]?.history ?? [])
  const fundHist: Array<{ t: number; c: number }> = (fundArr?.[0]?.history ?? [])
  const oiByDay = new Map(oiHist.map((r) => [r.t, r.c]))
  const fundByDay = new Map(fundHist.map((r) => [r.t, r.c]))

  // Master timeline = sorted days that have a reference spot close.
  const days = [...closeByDay.keys()].sort((a, b) => a - b)
  if (days.length < 10) return json({ error: "Not enough data" }, 502)

  const closes: number[] = []
  const spotCvdM: number[] = [] // cumulative, $M
  const oiB: number[] = [] // $B
  const fundPct: number[] = []
  let cum = 0
  let lastOi = oiHist[0]?.c ?? 0
  let lastFund = fundHist[0]?.c ?? 0
  for (const t of days) {
    cum += deltaByDay.get(t) ?? 0
    closes.push(Math.round(closeByDay.get(t)!))
    spotCvdM.push(Math.round(cum / 1e6))
    lastOi = oiByDay.get(t) ?? lastOi
    oiB.push(Math.round((lastOi / 1e9) * 100) / 100)
    lastFund = fundByDay.get(t) ?? lastFund
    fundPct.push(Math.round(lastFund * 10000) / 10000)
  }

  const n = days.length
  const i7 = Math.max(0, n - 8)
  const cvd7 = spotCvdM[n - 1] - spotCvdM[i7]
  const oi7pct = oiB[i7] > 0 ? Math.round(((oiB[n - 1] - oiB[i7]) / oiB[i7]) * 1000) / 10 : 0
  const fundNow = fundPct[n - 1]

  const spotUp = cvd7 > 0
  const oiUp = oi7pct > 1
  const oiDown = oi7pct < -1
  let regime = "Mixed"
  let note = "No clear lead between spot and derivatives this week."
  if (spotUp && !oiUp) { regime = "Spot-led bid"; note = "Spot buying is leading and leverage is not chasing it. Higher quality demand." }
  else if (spotUp && oiUp) { regime = "Broad risk-on"; note = "Spot buying and rising open interest together. Momentum, but watch the leverage." }
  else if (!spotUp && oiUp) { regime = "Leverage-driven"; note = "Open interest is rising without spot support. Moves are leverage led and more fragile." }
  else if (!spotUp && oiDown) { regime = "Deleveraging"; note = "Spot selling with falling open interest. Positions are unwinding." }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  )
  const { error } = await supabase.from("spot_derivatives_flows").upsert({
    asset: "BTC",
    current_price: closes[n - 1],
    days,
    closes,
    spot_cvd: spotCvdM,
    oi_usd: oiB,
    funding_pct: fundPct,
    cvd_7d: cvd7,
    oi_7d_pct: oi7pct,
    funding_now: fundNow,
    regime,
    regime_note: note,
    as_of: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }, { onConflict: "asset" })
  if (error) { console.error(error.message); return json({ error: error.message }, 500) }

  return json({ ok: true, days: n, regime, cvd_7d: cvd7, oi_7d_pct: oi7pct, funding_now: fundNow })
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })
}
