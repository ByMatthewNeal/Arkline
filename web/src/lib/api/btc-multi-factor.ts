import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import {
  DEFAULT_WEIGHTS,
  computeComposite,
  normalizeRSI,
  normalizeSMAPosition,
  normalizeFundingRate,
  normalizeFearGreed,
  normalizeMacroRisk,
  normalizeOilRisk,
  normalizeBullMarketBands,
  type MultiFactorResult,
} from '@/lib/risk/multi-factor';

/**
 * Assembles the 8 raw inputs for the BTC multi-factor risk model (iOS
 * RiskFactorFetcher parity) from server-side tables, then runs the shared
 * math port. Regression risk comes from `crypto_risk_btc`; technicals
 * (RSI / 200 SMA / bull-market bands) from `technicals_snapshots`; funding
 * from the perp-premium cache; F&G, VIX, DXY, WTI from their tables.
 */
export interface BtcMultiFactor extends MultiFactorResult {
  regression: number; // the single-factor regression risk shown on Home
}

export async function fetchBtcMultiFactor(): Promise<BtcMultiFactor | null> {
  if (!isSupabaseConfigured()) return null;
  const supabase = createClient();

  const [techRes, indRes, fgRes, perpRes] = await Promise.all([
    supabase.from('technicals_snapshots').select('rsi, sma_200, bmsb_sma_20w, bmsb_ema_21w, current_price').eq('coin_id', 'btc').order('recorded_date', { ascending: false }).limit(1),
    supabase.from('indicator_snapshots').select('indicator, value').in('indicator', ['vix', 'dxy', 'crude_oil_wti', 'crypto_risk_btc']).order('recorded_date', { ascending: false }).limit(20),
    supabase.from('fear_greed_history').select('value').order('date', { ascending: false }).limit(1),
    supabase.from('market_data_cache').select('data').eq('cache_key', 'perp_premium').maybeSingle(),
  ]);

  const tech = techRes.data?.[0] as
    | { rsi: number | null; sma_200: number | null; bmsb_sma_20w: number | null; bmsb_ema_21w: number | null; current_price: number | null }
    | undefined;

  // First (newest) value per indicator.
  const ind = new Map<string, number>();
  for (const r of (indRes.data ?? []) as { indicator: string; value: number }[]) {
    if (!ind.has(r.indicator)) ind.set(r.indicator, Number(r.value));
  }

  const regression = ind.get('crypto_risk_btc') ?? null;
  if (regression == null) return null;

  const fearGreed = (fgRes.data?.[0] as { value: number } | undefined)?.value ?? null;

  let funding: number | null = null;
  try {
    const items = (perpRes.data?.data ?? []) as { symbol: string; funding_rate: number }[];
    const btc = Array.isArray(items) ? items.find((i) => i.symbol?.toUpperCase().includes('BTC')) : null;
    // Stored as percent (e.g. 0.05 = 0.05%) — the model expects a decimal rate.
    if (btc?.funding_rate != null) funding = Number(btc.funding_rate) / 100;
  } catch { /* funding unavailable */ }

  const price = tech?.current_price != null ? Number(tech.current_price) : null;
  const rsi = tech?.rsi != null ? Number(tech.rsi) : null;
  const sma200 = tech?.sma_200 != null ? Number(tech.sma_200) : null;
  const sma20w = tech?.bmsb_sma_20w != null ? Number(tech.bmsb_sma_20w) : null;
  const ema21w = tech?.bmsb_ema_21w != null ? Number(tech.bmsb_ema_21w) : null;

  const vix = ind.get('vix') ?? null;
  const dxy = ind.get('dxy') ?? null;
  const oil = ind.get('crude_oil_wti') ?? null;

  const fmtUsd = (v: number) => `$${v.toLocaleString('en-US', { maximumFractionDigits: 2 })}`;

  const factors = [
    {
      key: 'logRegression', name: 'Log Regression',
      value: regression,
      raw: regression.toFixed(3),
    },
    {
      key: 'rsi', name: 'RSI',
      value: rsi != null ? normalizeRSI(rsi) : null,
      raw: rsi != null ? rsi.toFixed(1) : '—',
    },
    {
      key: 'smaPosition', name: 'SMA Position',
      value: price != null && sma200 != null ? normalizeSMAPosition(price, sma200) : null,
      raw: price != null && sma200 != null ? (price >= sma200 ? 'Above 200 SMA' : 'Below 200 SMA') : '—',
    },
    {
      key: 'bullMarketBands', name: 'Bull Market Bands',
      value: price != null && sma20w != null && ema21w != null ? normalizeBullMarketBands(price, sma20w, ema21w) : null,
      raw: price != null && sma20w != null && ema21w != null
        ? `${((price - (sma20w + ema21w) / 2) / ((sma20w + ema21w) / 2) * 100).toFixed(1)}%`
        : '—',
    },
    {
      key: 'fundingRate', name: 'Funding Rate',
      value: funding != null ? normalizeFundingRate(funding) : null,
      raw: funding != null ? `${(funding * 100).toFixed(4)}%` : '—',
    },
    {
      key: 'fearGreed', name: 'Fear & Greed',
      value: fearGreed != null ? normalizeFearGreed(fearGreed) : null,
      raw: fearGreed != null ? String(Math.round(fearGreed)) : '—',
    },
    {
      key: 'macroRisk', name: 'Macro Risk',
      value: normalizeMacroRisk(vix, dxy),
      raw: vix != null ? vix.toFixed(1) : '—',
    },
    {
      key: 'oilRisk', name: 'Oil Risk',
      value: oil != null ? normalizeOilRisk(oil) : null,
      raw: oil != null ? fmtUsd(oil) : '—',
    },
  ];

  const weights = [
    DEFAULT_WEIGHTS.logRegression, DEFAULT_WEIGHTS.rsi, DEFAULT_WEIGHTS.smaPosition,
    DEFAULT_WEIGHTS.bullMarketBands, DEFAULT_WEIGHTS.fundingRate, DEFAULT_WEIGHTS.fearGreed,
    DEFAULT_WEIGHTS.macroRisk, DEFAULT_WEIGHTS.oilRisk,
  ];

  return { ...computeComposite(factors, weights), regression };
}
