// Arkline — public glance endpoint for the Even Hub glasses plugin.
//
// Drop this into the Next.js App Router at:  web/src/app/api/glance/route.ts
//
// Differs from /api/today.json (see today_api_spec.md):
//   1. NO auth — the .ehpk is extractable, so the glasses plugin can't carry a token.
//   2. Thin, glasses-shaped payload (BTC/ETH/SOL price + 24h change + risk, the BTC
//      composite + tier, fear/greed, 2 headlines, the daily summary, and the BTC
//      factor breakdown).
//   3. Returns CORS headers so the WebView can fetch it.
//
// Wired to the REAL Arkline schema (confirmed via information_schema + data peek):
//   market_data_cache(key, data jsonb)  → key 'crypto_assets_1_100' holds the live
//       CoinGecko top-100 array (current_price, price_change_percentage_24h per coin).
//   model_portfolio_risk_history(asset, risk_date, risk_level)  → BTC/ETH/SOL risk scores.
//   risk_snapshots(recorded_date, composite_score, tier, components jsonb)
//   fear_greed_history(date, value, classification)
//   curated_news(curated_title, source, published_at, …)
//   market_summaries(summary_date, summary, slot, generated_at)
//
// Note: BTC/ETH/SOL all have per-asset log-regression risk scores in model_portfolio_risk_history.
// Keep the existing authed /api/today.json for the content workflow.

import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

export const runtime = 'edge'
export const revalidate = 300 // 5 min cache

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
)

// CoinGecko ids/symbols as they appear in the crypto_assets_1_100 cache.
const ASSET_DEFS = [
  { symbol: 'BTC', id: 'bitcoin', sym: 'btc' },
  { symbol: 'ETH', id: 'ethereum', sym: 'eth' },
  { symbol: 'SOL', id: 'solana', sym: 'sol' },
]

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Cache-Control': 's-maxage=300, stale-while-revalidate=60',
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 204, headers: CORS })
}

// market_data_cache stores the CoinGecko array as a JSON *string* inside jsonb,
// so it may come back as a string that needs a second parse.
function parseCache(data: unknown): any[] {
  if (!data) return []
  let v: any = data
  if (typeof v === 'string') {
    try {
      v = JSON.parse(v)
    } catch {
      return []
    }
  }
  return Array.isArray(v) ? v : []
}

// risk_snapshots.components (jsonb) → [{ name, value, contribution }]. Shape is
// defensive: handles an array of objects OR a keyed object. If your components
// shape is different, tweak here.
function toFactors(components: unknown): { name: string; value: number; contribution: number }[] {
  if (!components) return []
  const num = (v: unknown) => (typeof v === 'number' ? v : Number(v) || 0)
  if (Array.isArray(components)) {
    return components.map((c: any) => ({
      name: String(c.name ?? c.label ?? c.key ?? '?'),
      value: num(c.value ?? c.score),
      contribution: num(c.contribution ?? c.weight),
    }))
  }
  return Object.entries(components as Record<string, any>).map(([k, v]) => {
    if (v && typeof v === 'object') {
      return { name: k, value: num(v.value ?? v.score), contribution: num(v.contribution ?? v.weight) }
    }
    return { name: k, value: num(v), contribution: 0 }
  })
}

export async function GET() {
  // Live prices (all 3) from the CoinGecko cache.
  const { data: cacheRow } = await supabase
    .from('market_data_cache')
    .select('data')
    .eq('key', 'crypto_assets_1_100')
    .single()
  const coins = parseCache(cacheRow?.data)
  const findCoin = (id: string, sym: string) =>
    coins.find((c) => c.id === id || String(c.symbol ?? '').toLowerCase() === sym)

  // Latest per-asset risk score from model_portfolio_risk_history (BTC, ETH, SOL).
  const { data: riskRows } = await supabase
    .from('model_portfolio_risk_history')
    .select('asset, risk_level, risk_date')
    .in('asset', ASSET_DEFS.map((d) => d.symbol))
    .order('risk_date', { ascending: false })
  const latestRisk = new Map<string, number>()
  for (const r of riskRows ?? []) {
    // rows are newest-first, so the first time we see an asset is its latest value
    if (!latestRisk.has(r.asset) && r.risk_level != null) {
      latestRisk.set(r.asset, Number(r.risk_level))
    }
  }

  const assets = ASSET_DEFS.map((d) => {
    const c = findCoin(d.id, d.sym)
    if (!c) return null
    return {
      symbol: d.symbol,
      price_usd: Number(c.current_price),
      change_pct_24h: Number(Number(c.price_change_percentage_24h ?? 0).toFixed(1)),
      risk_score: latestRisk.has(d.symbol) ? latestRisk.get(d.symbol)! : null,
      risk_zone: null as string | null,
    }
  }).filter(Boolean) as {
    symbol: string
    price_usd: number
    change_pct_24h: number
    risk_score: number | null
    risk_zone: string | null
  }[]

  if (!assets.length) {
    return NextResponse.json({ error: 'no_data' }, { status: 503, headers: CORS })
  }

  // BTC composite risk + tier + factor breakdown.
  const { data: snap } = await supabase
    .from('risk_snapshots')
    .select('composite_score, tier, components')
    .order('recorded_date', { ascending: false })
    .limit(1)
    .single()

  // Fear & Greed (latest + prior for the 1d change).
  const { data: fng } = await supabase
    .from('fear_greed_history')
    .select('value, classification, date')
    .order('date', { ascending: false })
    .limit(2)
  const fgToday = fng?.[0]
  const fgDelta = fng?.[1] ? (fgToday?.value ?? 0) - fng[1].value : 0

  // Daily briefing prose — latest market summary.
  const { data: summary } = await supabase
    .from('market_summaries')
    .select('summary, generated_at')
    .order('generated_at', { ascending: false })
    .limit(1)
    .single()

  // Top 2 macro/crypto headlines.
  const { data: news } = await supabase
    .from('curated_news')
    .select('curated_title')
    .order('published_at', { ascending: false })
    .limit(2)

  const body = {
    as_of: new Date().toISOString(),
    version: '2',
    assets,
    btc_risk: snap
      ? { score: snap.composite_score, tier: snap.tier }
      : null,
    // Regime is computed on-device today (today_api_spec.md "compute gap"); null until
    // the derived_signals table lands.
    macro: { regime: null as string | null, regime_days_in_state: null as number | null },
    sentiment: {
      fear_and_greed: {
        value: fgToday?.value ?? null,
        label: fgToday?.classification ?? null,
        change_1d: fgDelta,
      },
    },
    headlines: (news ?? []).map((n) => ({ title: n.curated_title })),
    briefing: summary?.summary ?? '',
    factors: toFactors(snap?.components),
  }

  return NextResponse.json(body, { headers: CORS })
}
