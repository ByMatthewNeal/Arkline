import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * compute-support-resistance Edge Function
 *
 * Daily cron. Computes algorithmic support/resistance for a fixed set of assets
 * and upserts them into support_resistance_levels, so the web app (and later iOS)
 * can read precomputed levels. This is a faithful port of the iOS SupportResistance
 * calculator (swing pivots + volume profile + range extremes + 200-SMA, merged
 * into zones and scored by touches + confluence).
 *
 *   Crypto (BTC, ETH, SOL) -> Coinbase daily candles (with volume)
 *   Metals (gold XAU, silver XAG) -> Yahoo daily futures (GC=F, SI=F); Yahoo may
 *   omit volume, in which case the volume-profile component is simply skipped.
 */

type Strength = "weak" | "moderate" | "strong"
interface SRBar { date: number; high: number; low: number; close: number; volume: number }
interface Level { price: number; kind: "support" | "resistance"; strength: Strength; touches: number }

const ASSETS: { asset: string; name: string; source: "coinbase" | "yahoo"; id: string }[] = [
  { asset: "BTC", name: "Bitcoin", source: "coinbase", id: "BTC-USD" },
  { asset: "ETH", name: "Ethereum", source: "coinbase", id: "ETH-USD" },
  { asset: "SOL", name: "Solana", source: "coinbase", id: "SOL-USD" },
  { asset: "XAU", name: "Gold", source: "yahoo", id: "GC=F" },
  { asset: "XAG", name: "Silver", source: "yahoo", id: "SI=F" },
]

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405)

  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  if ((req.headers.get("x-cron-secret") ?? "") !== cronSecret || !cronSecret) {
    return json({ error: "Unauthorized" }, 401)
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  )

  const today = new Date().toISOString().slice(0, 10)
  const out: { asset: string; ok: boolean; detail?: string }[] = []

  for (const a of ASSETS) {
    try {
      const bars = a.source === "coinbase"
        ? await fetchCoinbaseBars(a.id, 300)
        : await fetchYahooBars(a.id, "2y")

      if (bars.length < 30) { out.push({ asset: a.asset, ok: false, detail: `only ${bars.length} bars` }); continue }

      const currentPrice = bars[bars.length - 1].close
      const closes = bars.map((b) => b.close)
      const sma200 = closes.length >= 200
        ? closes.slice(-200).reduce((s, v) => s + v, 0) / 200
        : null

      const pair = computeSR(bars, currentPrice, sma200)
      if (!pair) { out.push({ asset: a.asset, ok: false, detail: "no levels" }); continue }

      const series = bars.slice(-120).map((b) => ({
        date: new Date(b.date * 1000).toISOString().slice(0, 10),
        close: round2(b.close),
      }))

      const { error } = await supabase.from("support_resistance_levels").upsert({
        asset: a.asset,
        name: a.name,
        current_price: round2(currentPrice),
        supports: pair.supports,
        resistances: pair.resistances,
        series,
        as_of: today,
        updated_at: new Date().toISOString(),
      }, { onConflict: "asset" })

      if (error) out.push({ asset: a.asset, ok: false, detail: error.message })
      else out.push({ asset: a.asset, ok: true })
    } catch (e) {
      out.push({ asset: a.asset, ok: false, detail: String(e) })
    }
  }

  return json({ date: today, results: out })
})

// ─── S/R algorithm (port of iOS SupportResistance.compute) ───────────────────

function computeSR(
  bars: SRBar[],
  currentPrice: number,
  sma200: number | null,
  maxPerSide = 3,
): { supports: Level[]; resistances: Level[] } | null {
  if (bars.length < 30 || currentPrice <= 0) return null
  const tol = currentPrice * 0.01      // 1% cluster / touch tolerance
  const atPrice = currentPrice * 0.003 // ignore anything basically at price

  const candidates: number[] = []

  // 1. Swing pivots.
  const w = 4
  if (bars.length > 2 * w) {
    for (let i = w; i < bars.length - w; i++) {
      const hi = bars[i].high
      const lo = bars[i].low
      let isPivotHigh = true
      let isPivotLow = true
      for (let j = i - w; j <= i + w; j++) {
        if (j === i) continue
        if (bars[j].high > hi) isPivotHigh = false
        if (bars[j].low < lo) isPivotLow = false
      }
      if (isPivotHigh) candidates.push(hi)
      if (isPivotLow) candidates.push(lo)
    }
  }

  // Range extremes.
  candidates.push(Math.max(...bars.map((b) => b.high)))
  candidates.push(Math.min(...bars.map((b) => b.low)))

  // 2. Volume-profile nodes.
  const closes = bars.map((b) => b.close)
  const lo = Math.min(...closes)
  const hi = Math.max(...closes)
  if (hi > lo) {
    const binCount = 40
    const binSize = (hi - lo) / binCount
    const bins = new Array(binCount).fill(0)
    for (const b of bars) {
      const idx = Math.min(binCount - 1, Math.max(0, Math.floor((b.close - lo) / binSize)))
      bins[idx] += b.volume
    }
    const topIdx = bins.map((v, i) => [v, i] as [number, number])
      .sort((x, y) => y[0] - x[0]).slice(0, 3).map((p) => p[1])
    for (const idx of topIdx) candidates.push(lo + (idx + 0.5) * binSize)
  }

  // 3. 200-SMA.
  if (sma200 && sma200 > 0) candidates.push(sma200)

  if (candidates.length === 0) return null

  // 4. Merge into zones.
  const sorted = [...candidates].sort((a, b) => a - b)
  const zones: number[][] = []
  for (const price of sorted) {
    const anchor = zones.length ? zones[zones.length - 1][0] : null
    if (anchor !== null && price - anchor <= tol) zones[zones.length - 1].push(price)
    else zones.push([price])
  }

  // 5. Score each zone.
  const touchCount = (level: number) =>
    bars.reduce((acc, b) => acc + ((Math.abs(b.high - level) <= tol || Math.abs(b.low - level) <= tol) ? 1 : 0), 0)
  const strengthOf = (touches: number, members: number): Strength => {
    const score = touches + Math.max(0, members - 1) * 1.5
    if (score >= 8) return "strong"
    if (score >= 4) return "moderate"
    return "weak"
  }

  const supports: Level[] = []
  const resistances: Level[] = []
  for (const grp of zones) {
    const price = grp.reduce((a, b) => a + b, 0) / grp.length
    if (Math.abs(price - currentPrice) <= atPrice) continue
    const t = touchCount(price)
    const lvl: Level = {
      price: round2(price),
      kind: price < currentPrice ? "support" : "resistance",
      strength: strengthOf(t, grp.length),
      touches: t,
    }
    if (lvl.kind === "support") supports.push(lvl)
    else resistances.push(lvl)
  }

  supports.sort((a, b) => b.price - a.price)    // nearest below first
  resistances.sort((a, b) => a.price - b.price) // nearest above first
  if (!supports.length && !resistances.length) return null
  return { supports: supports.slice(0, maxPerSide), resistances: resistances.slice(0, maxPerSide) }
}

// ─── Candle fetchers ─────────────────────────────────────────────────────────

async function fetchCoinbaseBars(productId: string, days: number): Promise<SRBar[]> {
  const now = Math.floor(Date.now() / 1000)
  const start = now - 86400 * days
  const url = `https://api.coinbase.com/api/v3/brokerage/market/products/${productId}/candles?start=${start}&end=${now}&granularity=ONE_DAY`
  const resp = await fetch(url)
  if (!resp.ok) throw new Error(`Coinbase ${productId} ${resp.status}`)
  const data = await resp.json()
  const candles: Array<{ start: string; low: string; high: string; close: string; volume: string }> = data.candles ?? []
  // Coinbase returns newest first — reverse to chronological.
  return candles
    .map((c) => ({
      date: parseInt(c.start, 10),
      high: parseFloat(c.high),
      low: parseFloat(c.low),
      close: parseFloat(c.close),
      volume: parseFloat(c.volume),
    }))
    .filter((b) => b.close > 0)
    .reverse()
}

async function fetchYahooBars(symbol: string, range: string): Promise<SRBar[]> {
  const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=${range}`
  const resp = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0" } })
  if (!resp.ok) throw new Error(`Yahoo ${symbol} ${resp.status}`)
  const data = await resp.json()
  const result = data?.chart?.result?.[0]
  const ts: number[] = result?.timestamp ?? []
  const q = result?.indicators?.quote?.[0] ?? {}
  const bars: SRBar[] = []
  for (let i = 0; i < ts.length; i++) {
    const high = q.high?.[i]
    const low = q.low?.[i]
    const close = q.close?.[i]
    const volume = q.volume?.[i] ?? 0
    if (high != null && low != null && close != null && close > 0) {
      bars.push({ date: ts[i], high, low, close, volume: volume ?? 0 })
    }
  }
  return bars
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function round2(n: number): number {
  // Preserve precision for small-priced assets while trimming float noise.
  const p = Math.abs(n) >= 100 ? 100 : 10000
  return Math.round(n * p) / p
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
