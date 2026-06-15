import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import {
  demoMacroIndicators,
  demoRiskHistory,
  demoBriefing,
  demoArkLineScore,
  demoSupplyInProfit,
  demoAssetRiskLevels,
} from '@/lib/demo-data';
import type {
  MacroIndicator,
  RiskHistoryPoint,
  ArkLineScoreData,
  ArkLineScoreLevel,
  ArkLineScoreComponent,
  ArkLineScoreHistoryPoint,
  SupplyInProfitData,
  SupplyInProfitStatus,
  AssetRiskLevelData,
  AssetRiskCategory,
  RiskFactor,
  RiskFactorType,
} from '@/types';

function getSupabase() {
  return createClient();
}

function daysAgoISO(days: number): string {
  const d = new Date();
  d.setDate(d.getDate() - days);
  return d.toISOString().split('T')[0];
}

/* ── Macro indicators ──
 * Real source: indicator_snapshots (one row per indicator per day).
 * We surface the four drivers the Macro card renders (VIX, DXY, M2, WTI),
 * computing the latest value, 1-day % change, and a sparkline from history.
 */
const MACRO_INDICATORS: { db: string; name: string; scale?: number }[] = [
  { db: 'vix', name: 'VIX' },
  { db: 'dxy', name: 'DXY' },
  { db: 'global_m2', name: 'M2', scale: 1e12 }, // raw is absolute USD → trillions
  { db: 'crude_oil_wti', name: 'WTI' },
];

export async function fetchMacroIndicators(): Promise<MacroIndicator[]> {
  if (!isSupabaseConfigured()) return demoMacroIndicators;
  const supabase = getSupabase();

  const { data, error } = await supabase
    .from('indicator_snapshots')
    .select('indicator, value, recorded_date')
    .in('indicator', MACRO_INDICATORS.map((m) => m.db))
    .gte('recorded_date', daysAgoISO(45))
    .order('recorded_date', { ascending: true });

  if (error || !data?.length) return demoMacroIndicators;

  const byIndicator = new Map<string, { value: number; recorded_date: string }[]>();
  for (const row of data as { indicator: string; value: number; recorded_date: string }[]) {
    const arr = byIndicator.get(row.indicator) ?? [];
    arr.push({ value: Number(row.value), recorded_date: row.recorded_date });
    byIndicator.set(row.indicator, arr);
  }

  const out: MacroIndicator[] = [];
  for (const meta of MACRO_INDICATORS) {
    const series = byIndicator.get(meta.db);
    if (!series?.length) continue;
    const scale = meta.scale ?? 1;
    const values = series.map((s) => s.value / scale);
    const latest = values[values.length - 1];
    const prev = values.length > 1 ? values[values.length - 2] : latest;
    const change = latest - prev;
    const change_percentage = prev !== 0 ? (change / prev) * 100 : 0;
    out.push({
      name: meta.name,
      value: latest,
      change,
      change_percentage,
      sparkline: values.slice(-30),
    });
  }

  return out.length ? out : demoMacroIndicators;
}

/* ── BTC risk history (the risk chart) ──
 * Real source: model_portfolio_risk_history filtered to BTC.
 */
export async function fetchRiskHistory(days = 365): Promise<RiskHistoryPoint[]> {
  if (!isSupabaseConfigured()) return demoRiskHistory;
  const supabase = getSupabase();

  const { data, error } = await supabase
    .from('model_portfolio_risk_history')
    .select('risk_date, risk_level, price, fair_value, deviation')
    .eq('asset', 'BTC')
    .gte('risk_date', daysAgoISO(days))
    .order('risk_date', { ascending: true });

  if (error || !data?.length) return demoRiskHistory;

  return (data as {
    risk_date: string;
    risk_level: number;
    price: number;
    fair_value: number;
    deviation: number;
  }[]).map((r) => ({
    date: r.risk_date,
    risk_level: Number(r.risk_level),
    price: Number(r.price),
    fair_value: Number(r.fair_value),
    deviation: Number(r.deviation),
  }));
}

/* ── AI daily briefing ──
 * Real source: market_summaries (latest by generated_at). We lightly strip
 * markdown header markers so the plain-text card reads cleanly.
 */
function cleanBriefing(md: string): string {
  // Keep the "## Section" headers so the UI can render labeled sections like the
  // iOS app; just strip inline bold/code markers.
  return md
    .replace(/\*\*(.*?)\*\*/g, '$1') // bold
    .replace(/`/g, '')
    .trim();
}

export async function fetchMarketBriefing(): Promise<string | null> {
  if (!isSupabaseConfigured()) return demoBriefing;
  const supabase = getSupabase();

  const { data, error } = await supabase
    .from('market_summaries')
    .select('summary, generated_at')
    .order('generated_at', { ascending: false })
    .limit(1);

  if (error || !data?.[0]?.summary) return null;
  return cleanBriefing(data[0].summary as string);
}

/* ── Sentiment / regime ──
 * No dedicated table in the current schema (regime is computed on-device today,
 * per today_api_spec.md "compute gap"). Return null so the UI degrades
 * gracefully (the regime badge simply hides) until a derived_signals table lands.
 */
export async function fetchSentimentData(): Promise<Record<string, unknown> | null> {
  return null;
}

/* ── Macro regime badge ──
 * Prefers the derived_signals table (server-side port of the on-device regime
 * classifier — see supabase/migrations). Until that table is populated it falls
 * back to a live proxy: the sign of the gei_composite indicator (Global Economic
 * Index). Risk-on when gei_composite > 0, risk-off otherwise.
 */
const REGIME_BADGE: Record<string, { regime: string; regime_label: string; regime_description: string }> = {
  'risk-on': { regime: 'risk-on', regime_label: 'Risk On', regime_description: 'Conditions favor risk assets.' },
  'risk-off': { regime: 'risk-off', regime_label: 'Risk Off', regime_description: 'Conditions favor caution.' },
};

export async function fetchRegimeData(): Promise<{
  regime: string;
  regime_label?: string;
  regime_description?: string;
} | null> {
  if (!isSupabaseConfigured()) return null;
  const supabase = getSupabase();

  // 1) Prefer derived_signals if the table exists and has a row.
  const derived = await supabase
    .from('derived_signals')
    .select('macro_regime, regime_days_in_state')
    .order('as_of', { ascending: false })
    .limit(1);
  const macroRegime = derived.data?.[0]?.macro_regime as string | undefined;
  if (!derived.error && macroRegime) {
    const key = macroRegime.toLowerCase().includes('off') ? 'risk-off' : 'risk-on';
    return REGIME_BADGE[key];
  }

  // 2) Fallback proxy: sign of gei_composite.
  const gei = await supabase
    .from('indicator_snapshots')
    .select('value')
    .eq('indicator', 'gei_composite')
    .order('recorded_date', { ascending: false })
    .limit(1);
  const v = gei.data?.[0]?.value;
  if (gei.error || v == null) return null;
  return REGIME_BADGE[Number(v) >= 0 ? 'risk-on' : 'risk-off'];
}

/* ── ArkLine composite score + factor breakdown ──
 * Real source: risk_snapshots (latest). composite_score is 0-100; components is
 * an array of { name, value (0-1), signal, weight (0-1) }.
 */
function scoreToLevel(score: number): ArkLineScoreLevel {
  if (score < 30) return 'Low Risk';
  if (score < 50) return 'Moderate';
  if (score < 70) return 'Elevated';
  return 'High Risk';
}

interface RiskComponentRow {
  name: string;
  value: number;
  signal?: string;
  weight: number;
}

export async function fetchArkLineScore(): Promise<ArkLineScoreData> {
  if (!isSupabaseConfigured()) return demoArkLineScore;
  const supabase = getSupabase();

  const { data, error } = await supabase
    .from('risk_snapshots')
    .select('composite_score, tier, recommendation, components, recorded_date, btc_price, sp500_price, nasdaq_price')
    .order('recorded_date', { ascending: false })
    .limit(1);

  const row = data?.[0] as
    | { composite_score: number; tier: string; recommendation: string; components: RiskComponentRow[]; btc_price: number; sp500_price: number; nasdaq_price: number }
    | undefined;
  if (error || !row) return demoArkLineScore;

  const score = Number(row.composite_score);
  const components: ArkLineScoreComponent[] = Array.isArray(row.components)
    ? row.components.map((c) => ({
        name: c.name,
        value: Math.round(Number(c.value) * 100), // 0-1 → 0-100
        weight: Math.round(Number(c.weight) * 100), // 0-1 → percentage
        signal: c.signal,
        icon: '',
      }))
    : [];

  return {
    score,
    level: scoreToLevel(score),
    tier: row.tier ?? scoreToLevel(score),
    recommendation: row.recommendation ?? '',
    btcPrice: row.btc_price != null ? Number(row.btc_price) : undefined,
    sp500Price: row.sp500_price != null ? Number(row.sp500_price) : undefined,
    nasdaqPrice: row.nasdaq_price != null ? Number(row.nasdaq_price) : undefined,
    components,
  };
}

export async function fetchArkLineScoreHistory(): Promise<ArkLineScoreHistoryPoint[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('risk_snapshots')
    .select('recorded_date, composite_score, tier, btc_price, sp500_price, nasdaq_price')
    .order('recorded_date', { ascending: true })
    .limit(400);
  if (error || !data) return [];
  return (data as Array<{ recorded_date: string; composite_score: number; tier: string; btc_price: number; sp500_price: number; nasdaq_price: number }>).map((r) => ({
    date: r.recorded_date,
    score: Number(r.composite_score),
    tier: r.tier,
    btcPrice: r.btc_price != null ? Number(r.btc_price) : undefined,
    sp500Price: r.sp500_price != null ? Number(r.sp500_price) : undefined,
    nasdaqPrice: r.nasdaq_price != null ? Number(r.nasdaq_price) : undefined,
  }));
}

/* ── Per-asset risk history ── (model_portfolio_risk_history; powers the
 * Crypto Risk Levels detail period selector: 7D/30D/90D/1Y/ALL). */
export async function fetchAssetRiskHistory(
  asset: string,
  days: number,
): Promise<{ date: string; risk_level: number }[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('model_portfolio_risk_history')
    .select('risk_date, risk_level')
    .eq('asset', asset)
    .gte('risk_date', daysAgoISO(days))
    .order('risk_date', { ascending: true })
    .limit(1000);
  if (error || !data) return [];
  return (data as { risk_date: string; risk_level: number }[]).map((r) => ({
    date: r.risk_date,
    risk_level: Number(r.risk_level),
  }));
}

/* ── BTC supply in profit ──
 * Real source: indicator_snapshots 'supply_in_profit' (kept current; the legacy
 * supply_in_profit table is stale). value is a percentage.
 */
function supplyStatus(pct: number): SupplyInProfitStatus {
  if (pct < 50) return 'Buy Zone';
  if (pct < 75) return 'Normal';
  if (pct < 90) return 'Elevated';
  return 'Overheated';
}

export async function fetchSupplyInProfit(): Promise<SupplyInProfitData> {
  if (!isSupabaseConfigured()) return demoSupplyInProfit;
  const supabase = getSupabase();

  const { data, error } = await supabase
    .from('indicator_snapshots')
    .select('value, recorded_date')
    .eq('indicator', 'supply_in_profit')
    .gte('recorded_date', daysAgoISO(120))
    .order('recorded_date', { ascending: true });

  if (error || !data?.length) return demoSupplyInProfit;

  const rows = data as { value: number; recorded_date: string }[];
  const latest = rows[rows.length - 1];
  return {
    percentage: Number(latest.value),
    status: supplyStatus(Number(latest.value)),
    date: latest.recorded_date,
    history: rows.map((r) => ({ date: r.recorded_date, value: Number(r.value) })),
  };
}

/* ── Per-asset risk levels (BTC / ETH / SOL) ──
 * Real source: model_portfolio_risk_history (0-1 risk_level per asset/day).
 * NOTE: the per-asset 7-factor breakdown is computed on-device in the app and is
 * not persisted, so `factors` is empty here until that logic moves server-side.
 */
const ASSET_NAMES: Record<string, string> = {
  BTC: 'Bitcoin',
  ETH: 'Ethereum',
  SOL: 'Solana',
};

function riskCategory(value: number): AssetRiskCategory {
  if (value < 0.3) return 'Low';
  if (value < 0.5) return 'Moderate';
  if (value < 0.7) return 'Elevated';
  return 'Critical';
}

export async function fetchAssetRiskLevels(): Promise<AssetRiskLevelData[]> {
  if (!isSupabaseConfigured()) return demoAssetRiskLevels;
  const supabase = getSupabase();

  const symbols = Object.keys(ASSET_NAMES);
  const { data, error } = await supabase
    .from('model_portfolio_risk_history')
    .select('asset, risk_date, risk_level')
    .in('asset', symbols)
    .gte('risk_date', daysAgoISO(60))
    .order('risk_date', { ascending: false });

  if (error || !data?.length) return demoAssetRiskLevels;

  const rows = data as { asset: string; risk_date: string; risk_level: number }[];

  // Optional per-asset factor breakdown from derived asset_risk_factors table.
  // The table may not exist yet; if the query errors we simply omit factors.
  const factorsByAsset = new Map<string, RiskFactor[]>();
  const fres = await supabase
    .from('asset_risk_factors')
    .select('asset, recorded_date, factor, raw_value, normalized_value, weight')
    .in('asset', symbols)
    .order('recorded_date', { ascending: false })
    .limit(200);
  if (!fres.error && fres.data?.length) {
    const latestDateByAsset = new Map<string, string>();
    for (const f of fres.data as { asset: string; recorded_date: string }[]) {
      if (!latestDateByAsset.has(f.asset)) latestDateByAsset.set(f.asset, f.recorded_date);
    }
    for (const f of fres.data as {
      asset: string;
      recorded_date: string;
      factor: string;
      raw_value: number | null;
      normalized_value: number | null;
      weight: number | null;
    }[]) {
      if (f.recorded_date !== latestDateByAsset.get(f.asset)) continue;
      const arr = factorsByAsset.get(f.asset) ?? [];
      arr.push({
        type: f.factor as RiskFactorType,
        raw_value: f.raw_value ?? undefined,
        normalized_value: f.normalized_value ?? undefined,
        weight: Number(f.weight ?? 0),
      });
      factorsByAsset.set(f.asset, arr);
    }
  }

  const out: AssetRiskLevelData[] = [];

  for (const symbol of symbols) {
    const series = rows.filter((r) => r.asset === symbol);
    if (!series.length) continue;
    const risk_value = Number(series[0].risk_level); // newest first
    const level = riskCategory(risk_value);

    const last7 = series.slice(0, 7).map((r) => Number(r.risk_level));
    const seven_day_avg = last7.reduce((a, b) => a + b, 0) / last7.length;

    // Consecutive most-recent days in the same category.
    let days_at_level = 0;
    for (const r of series) {
      if (riskCategory(Number(r.risk_level)) === level) days_at_level += 1;
      else break;
    }

    out.push({
      symbol,
      name: ASSET_NAMES[symbol],
      risk_value,
      level,
      days_at_level,
      seven_day_avg,
      factors: factorsByAsset.get(symbol) ?? [],
    });
  }

  return out.length ? out : demoAssetRiskLevels;
}
