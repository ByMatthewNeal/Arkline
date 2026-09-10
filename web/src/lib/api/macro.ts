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
  MacroDashboardData,
  MacroDashIndicator,
  AssetTechnicalData,
  TechnicalTimeframeTrend,
  MarketBreadthDetailData,
  MarketBreadthPoint,
  FearGreedDetailData,
  RiskBand,
  RiskLevelItem,
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

  // Regime proxy: sign of the gei_composite indicator (Global Economic Index).
  // Risk-on when gei_composite >= 0, risk-off otherwise.
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
    | { composite_score: number; tier: string; recommendation: string; components: RiskComponentRow[]; recorded_date: string; btc_price: number; sp500_price: number; nasdaq_price: number }
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
    asOf: row.recorded_date,
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

/* ──────────────────────────────────────────────────────────────────────────
 * Macro Dashboard — regime + 4 key drivers (VIX, DXY, US Net Liquidity, CB Liq)
 * Source: indicator_snapshots (vix, dxy, net_liquidity, global_m2).
 * ────────────────────────────────────────────────────────────────────────── */
const REGIME_TEXT: Record<string, string> = {
  'Risk-On Disinflation': 'Economic growth with easing monetary conditions. Historically the best environment for crypto assets.',
  'Risk-On Inflation': 'Growth alongside rising inflation. Risk assets can work, but expect higher volatility and policy risk.',
  'Risk-Off Disinflation': 'Slowing growth with easing conditions. Defensive positioning is favored until growth signals improve.',
  'Risk-Off Inflation': 'Weak growth with sticky inflation (stagflation). Historically the toughest backdrop for risk assets.',
};

export async function fetchMacroDashboard(): Promise<MacroDashboardData | null> {
  if (!isSupabaseConfigured()) return null;
  const supabase = getSupabase();
  const keys = ['vix', 'dxy', 'net_liquidity', 'global_m2'];
  const { data, error } = await supabase
    .from('indicator_snapshots')
    .select('indicator, value, recorded_date')
    .in('indicator', keys)
    .gte('recorded_date', daysAgoISO(40))
    .order('recorded_date', { ascending: true });
  if (error || !data?.length) return null;

  const byInd = new Map<string, { value: number; date: string }[]>();
  for (const r of data as { indicator: string; value: number; recorded_date: string }[]) {
    const arr = byInd.get(r.indicator) ?? [];
    arr.push({ value: Number(r.value), date: r.recorded_date });
    byInd.set(r.indicator, arr);
  }
  // latest value + week-over-week change (vs value ~7 days back, else oldest)
  const latestOf = (k: string) => {
    const s = byInd.get(k);
    if (!s?.length) return null;
    const latest = s[s.length - 1];
    const weekAgo = s.find((p) => p.date <= daysAgoISO(7)) ?? s[0];
    const changePct = weekAgo.value !== 0 ? ((latest.value - weekAgo.value) / weekAgo.value) * 100 : 0;
    return { value: latest.value, changePct, date: latest.date, sparkline: s.slice(-24).map((p) => p.value) };
  };

  const vix = latestOf('vix');
  const dxy = latestOf('dxy');
  const netLiq = latestOf('net_liquidity');
  const cbLiq = latestOf('global_m2');
  if (!vix || !dxy || !netLiq || !cbLiq) return null;

  // Monthly change for the CB Liquidity signal (iOS uses a 30-day window).
  // Series is ascending, so scan from the end for the closest point ≤ 30d ago.
  const cbSeries = byInd.get('global_m2') ?? [];
  const monthAgo = [...cbSeries].reverse().find((p) => p.date <= daysAgoISO(30)) ?? cbSeries[0];
  const cbLiqMonthlyPct = monthAgo && monthAgo.value !== 0
    ? ((cbLiq.value - monthAgo.value) / monthAgo.value) * 100
    : 0;

  const indicators: MacroDashIndicator[] = [
    {
      key: 'vix', label: 'VIX', value: vix.value,
      formattedValue: vix.value.toFixed(1), changePct: vix.changePct,
      signal: vix.value < 20 ? 'bullish' : vix.value > 28 ? 'bearish' : 'neutral',
      signalLabel: vix.value < 20 ? 'Bullish' : vix.value > 28 ? 'Bearish' : 'Neutral',
      sparkline: vix.sparkline,
    },
    {
      key: 'dxy', label: 'DXY', value: dxy.value,
      formattedValue: dxy.value.toFixed(1), changePct: dxy.changePct,
      signal: dxy.value < 100 ? 'bullish' : dxy.value > 105 ? 'bearish' : 'neutral',
      signalLabel: dxy.value < 100 ? 'Bullish' : dxy.value > 105 ? 'Bearish' : 'Neutral',
      sparkline: dxy.sparkline,
    },
    {
      key: 'netLiquidity', label: 'US Net Liquidity', value: netLiq.value,
      formattedValue: `$${(netLiq.value / 1e12).toFixed(1)}T`, changePct: netLiq.changePct,
      signal: netLiq.changePct >= 0 ? 'bullish' : 'bearish',
      signalLabel: netLiq.changePct >= 0 ? 'Bullish' : 'Bearish',
      sparkline: netLiq.sparkline,
    },
    {
      key: 'cbLiquidity', label: 'CB Liquidity', value: cbLiq.value,
      formattedValue: `$${(cbLiq.value / 1e12).toFixed(1)}T`, changePct: cbLiqMonthlyPct,
      // iOS Global Liquidity signal: MONTHLY change with a ±0.3% neutral band —
      // a WoW zero-threshold flips to "Contracting" on noise the app calls Expanding.
      signal: cbLiqMonthlyPct > 0.3 ? 'expanding' : cbLiqMonthlyPct < -0.3 ? 'contracting' : 'neutral',
      signalLabel: cbLiqMonthlyPct > 0.3 ? 'Expanding' : cbLiqMonthlyPct < -0.3 ? 'Contracting' : 'Neutral',
      sparkline: cbLiq.sparkline,
    },
  ];

  const bullishCount = [vix.value < 20, dxy.value < 100, netLiq.changePct >= 0].filter(Boolean).length;
  const riskOn = bullishCount >= 2;
  const easing = cbLiqMonthlyPct >= 0; // expanding liquidity ≈ disinflationary/easing
  const regimeLabel = `${riskOn ? 'Risk-On' : 'Risk-Off'} ${easing ? 'Disinflation' : 'Inflation'}`;
  const insight = riskOn
    ? 'Macro indicators are aligned to the upside. Low fear, a weakening or stable dollar, and growing liquidity have historically supported risk assets like BTC.'
    : 'Macro indicators are pointed to the downside. Elevated fear, a strengthening dollar, or contracting liquidity have historically pressured risk assets like BTC.';

  return {
    regimeLabel,
    regimeDescription: REGIME_TEXT[regimeLabel] ?? '',
    regimeBullish: riskOn,
    asOf: vix.date,
    indicators,
    insight,
  };
}

/* ── Single macro indicator history (for the detail period toggles) ── */
export async function fetchIndicatorHistory(dbKey: string, days: number): Promise<{ date: string; value: number }[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('indicator_snapshots')
    .select('value, recorded_date')
    .eq('indicator', dbKey)
    .gte('recorded_date', daysAgoISO(days))
    .order('recorded_date', { ascending: true })
    .limit(500);
  if (error || !data) return [];
  return (data as { value: number; recorded_date: string }[]).map((r) => ({ date: r.recorded_date, value: Number(r.value) }));
}

/* ──────────────────────────────────────────────────────────────────────────
 * Risk Levels — full lists for Crypto & Stock (indicator_snapshots *_risk_*)
 * ────────────────────────────────────────────────────────────────────────── */
const RISK_ASSET_NAMES: Record<string, string> = {
  btc: 'Bitcoin', eth: 'Ethereum', sol: 'Solana', bnb: 'BNB', xrp: 'XRP', ada: 'Cardano', doge: 'Dogecoin',
  avax: 'Avalanche', dot: 'Polkadot', link: 'Chainlink', ltc: 'Litecoin', bch: 'Bitcoin Cash', atom: 'Cosmos',
  arb: 'Arbitrum', op: 'Optimism', imx: 'Immutable', ldo: 'Lido DAO', sui: 'Sui', uni: 'Uniswap', aave: 'Aave',
  algo: 'Algorand', etc: 'Ethereum Classic', fil: 'Filecoin', fet: 'Fetch.ai', hbar: 'Hedera', inj: 'Injective',
  jup: 'Jupiter', near: 'NEAR', ena: 'Ethena', ondo: 'Ondo', pepe: 'Pepe', shib: 'Shiba Inu', tao: 'Bittensor',
  tia: 'Celestia', trx: 'TRON', sei: 'Sei', render: 'Render', syrup: 'Maple', zec: 'Zcash', aster: 'Aster',
  // stocks
  aapl: 'Apple', amd: 'AMD', amzn: 'Amazon', asml: 'ASML', asts: 'AST SpaceMobile', axti: 'AXT',
  bitf: 'Bitfarms', bmnr: 'Bitmine', cifr: 'Cipher Mining', coin: 'Coinbase', dgxx: 'Digihost',
  googl: 'Alphabet', hood: 'Robinhood', iren: 'IREN', meta: 'Meta', mp: 'MP Materials', msft: 'Microsoft',
  mstr: 'MicroStrategy', mu: 'Micron', nbis: 'Nebius', nuai: 'Nuvve', nvda: 'NVIDIA', onds: 'Ondas',
  open: 'Opendoor', orcl: 'Oracle', pl: 'Planet Labs', qbts: 'D-Wave', qqq: 'Nasdaq 100 ETF', rdw: 'Redwire',
  rklb: 'Rocket Lab', satl: 'Satellogic', sidu: 'Sidus Space', sndk: 'SanDisk', spy: 'S&P 500 ETF',
  tsla: 'Tesla', tsm: 'TSMC', uber: 'Uber', wulf: 'TeraWulf',
};

function riskBand(v: number): RiskBand {
  if (v < 0.20) return 'Very Low';
  if (v < 0.40) return 'Low';
  if (v < 0.55) return 'Neutral';
  if (v < 0.70) return 'Elevated';
  return 'High';
}

// iOS AssetRiskConfig.cryptoConfigs — the authoritative crypto list for the
// Crypto Risk Levels screen. The crypto_risk_* indicator prefix also carries
// stocks added via the admin risk search, so an allowlist (not the prefix)
// decides what counts as crypto.
const CRYPTO_RISK_SYMBOLS = new Set([
  'btc', 'eth', 'sol',
  'bnb', 'ada', 'dot', 'avax', 'near', 'atom', 'sui', 'tao', 'hbar', 'algo',
  'arb', 'op', 'imx', 'mnt',
  'uni', 'aave', 'ldo', 'ena', 'jup', 'syrup',
  'link', 'render', 'fet',
  'xrp', 'ltc', 'zec', 'bch', 'etc', 'trx',
  'ondo', 'fil', 'inj', 'sei', 'tia', 'aster',
  'doge', 'shib', 'pepe',
]);

export async function fetchRiskLevels(kind: 'crypto' | 'stock'): Promise<RiskLevelItem[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();

  // stock symbols (used to exclude stocks from the crypto_risk_* prefix, which mixes both)
  const stockLatest = await supabase
    .from('indicator_snapshots')
    .select('indicator')
    .like('indicator', 'stock_risk_%')
    .gte('recorded_date', daysAgoISO(3))
    .limit(300);
  const stockSyms = new Set((stockLatest.data ?? []).map((r: { indicator: string }) => r.indicator.replace('stock_risk_', '')));

  const prefix = kind === 'stock' ? 'stock_risk_' : 'crypto_risk_';
  const since = daysAgoISO(200);

  // PostgREST caps each response at 1000 rows, so page through the history.
  const PAGE = 1000;
  const all: { indicator: string; value: number; recorded_date: string }[] = [];
  for (let offset = 0; offset < 40000; offset += PAGE) {
    const { data, error } = await supabase
      .from('indicator_snapshots')
      .select('indicator, value, recorded_date')
      .like('indicator', `${prefix}%`)
      .gte('recorded_date', since)
      .order('recorded_date', { ascending: true })
      .order('indicator', { ascending: true })
      .range(offset, offset + PAGE - 1);
    if (error) break;
    if (!data?.length) break;
    all.push(...(data as typeof all));
    if (data.length < PAGE) break;
  }
  if (!all.length) return [];

  const bySym = new Map<string, { value: number; date: string }[]>();
  for (const r of all) {
    const sym = r.indicator.replace(prefix, '');
    // Crypto list = iOS allowlist only (crypto_risk_* also carries admin-added stocks)
    if (kind === 'crypto' && !CRYPTO_RISK_SYMBOLS.has(sym.toLowerCase())) continue;
    if (kind === 'crypto' && stockSyms.has(sym)) continue; // belt-and-braces
    const arr = bySym.get(sym) ?? [];
    arr.push({ value: Number(r.value), date: r.recorded_date });
    bySym.set(sym, arr);
  }
  // each symbol's series must be chronological for change/days-at-level math
  for (const arr of bySym.values()) arr.sort((a, b) => a.date.localeCompare(b.date));

  const atOrBefore = (series: { value: number; date: string }[], targetISO: string) => {
    let v: number | undefined;
    for (const p of series) { if (p.date <= targetISO) v = p.value; else break; }
    return v;
  };

  const items: RiskLevelItem[] = [];
  for (const [sym, series] of bySym) {
    if (!series.length) continue;
    const current = series[series.length - 1].value;
    const band = riskBand(current);
    const v7 = atOrBefore(series, daysAgoISO(7)) ?? series[0].value;
    const v30 = atOrBefore(series, daysAgoISO(30)) ?? series[0].value;
    const last7 = series.slice(-7);
    const sevenDayAvg = last7.reduce((s, p) => s + p.value, 0) / last7.length;
    // days at current band (consecutive from latest)
    let daysAtLevel = 0;
    for (let i = series.length - 1; i >= 0; i--) { if (riskBand(series[i].value) === band) daysAtLevel++; else break; }
    items.push({
      symbol: sym.toUpperCase(),
      name: RISK_ASSET_NAMES[sym] ?? sym.toUpperCase(),
      value: current,
      band,
      change7d: current - v7,
      change30d: current - v30,
      daysAtLevel,
      sevenDayAvg,
    });
  }
  return items.sort((a, b) => a.value - b.value);
}

/* ──────────────────────────────────────────────────────────────────────────
 * Per-asset Core Technical detail (BTC / ETH / SOL)
 * Source: technicals_snapshots + market_snapshots.
 * ────────────────────────────────────────────────────────────────────────── */
const ASSET_META: Record<string, { coin: string; name: string; market: string }> = {
  BTC: { coin: 'btc', name: 'Bitcoin', market: 'bitcoin' },
  ETH: { coin: 'eth', name: 'Ethereum', market: 'ethereum' },
  SOL: { coin: 'sol', name: 'Solana', market: 'solana' },
};

/* Coinbase Exchange public candles (CORS-enabled). This is the same market the
 * iOS APITechnicalAnalysisService computes from, so every score matches the app
 * instead of drifting on a stale backend snapshot. */
type DailyCandle = { time: number; close: number };

async function fetchDailyCandles(pair: string): Promise<DailyCandle[]> {
  const res = await fetch(`https://api.exchange.coinbase.com/products/${pair}/candles?granularity=86400`);
  if (!res.ok) throw new Error(`Coinbase candles ${res.status}`);
  const rows = (await res.json()) as [number, number, number, number, number, number][];
  // newest-first [time, low, high, open, close, volume] → oldest-first
  return rows.slice().reverse().map((r) => ({ time: r[0], close: r[4] }));
}

const smaOf = (xs: number[]) => (xs.length ? xs.reduce((s, v) => s + v, 0) / xs.length : 0);

/** iOS calculateEMA — seeded with the first price, then standard smoothing. */
function emaOf(xs: number[], period: number): number {
  if (!xs.length) return 0;
  const k = 2 / (period + 1);
  let ema = xs[0];
  for (let i = 1; i < xs.length; i++) ema = (xs[i] - ema) * k + ema;
  return ema;
}

/** Weekly closes (Monday-start UTC weeks) from daily candles, excluding the
 * current incomplete week — mirrors iOS's ONE_WEEK candles + dropLast(). */
function weeklyClosesOf(candles: DailyCandle[]): number[] {
  const byWeek = new Map<number, number>();
  for (const c of candles) {
    const d = new Date(c.time * 1000);
    const sinceMonday = (d.getUTCDay() + 6) % 7;
    const weekStart = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() - sinceMonday);
    byWeek.set(weekStart, c.close); // oldest-first iteration → last close of each week wins
  }
  const weeks = [...byWeek.keys()].sort((a, b) => a - b);
  return weeks.slice(0, -1).map((w) => byWeek.get(w)!);
}

type TrendDir = 'strongUptrend' | 'uptrend' | 'sideways' | 'downtrend' | 'strongDowntrend';

/** iOS determineTrend — direction + strength from price vs the three SMAs. */
function determineTrendIOS(price: number, sma21: number, sma50: number, sma200: number): { dir: TrendDir; strength: 1 | 2 | 3 } {
  const aboveCount = [price > sma21, price > sma50, price > sma200].filter(Boolean).length;
  const higherHighs = price > sma21 && sma21 > sma50;
  const higherLows = sma50 > sma200;
  if (aboveCount === 3 && higherHighs && higherLows) return { dir: 'strongUptrend', strength: 3 };
  if (aboveCount >= 2 && higherHighs) return { dir: 'uptrend', strength: aboveCount === 3 ? 3 : 2 };
  if (aboveCount === 0 && !higherHighs && !higherLows) return { dir: 'strongDowntrend', strength: 3 };
  if (aboveCount <= 1 && !higherHighs) return { dir: 'downtrend', strength: aboveCount === 0 ? 3 : 2 };
  return { dir: 'sideways', strength: 1 };
}

const TREND_SHORT: Record<TrendDir, string> = {
  strongUptrend: 'Strong Up', uptrend: 'Up', sideways: 'Sideways', downtrend: 'Down', strongDowntrend: 'Strong Down',
};
const trendArrow = (d: TrendDir): 'up' | 'down' | 'flat' =>
  d === 'strongUptrend' || d === 'uptrend' ? 'up' : d === 'sideways' ? 'flat' : 'down';

export async function fetchAssetTechnical(symbol: string): Promise<AssetTechnicalData | null> {
  const meta = ASSET_META[symbol.toUpperCase()];
  if (!meta) return null;

  // 300 daily Coinbase candles → SMAs, RSI, Bollinger, trend (iOS-identical)
  let candles: DailyCandle[];
  try {
    candles = await fetchDailyCandles(`${symbol.toUpperCase()}-USD`);
  } catch {
    return null;
  }
  if (candles.length < 21) return null;
  const closes = candles.map((c) => c.close);
  const price = closes[closes.length - 1];

  // 24h % — prefer the market snapshot (what iOS's asset header shows)
  let changePct24h = closes.length >= 2 ? ((price - closes[closes.length - 2]) / closes[closes.length - 2]) * 100 : 0;
  if (isSupabaseConfigured()) {
    const { data } = await getSupabase()
      .from('market_snapshots')
      .select('price_change_pct_24h')
      .eq('coin_id', meta.market)
      .order('recorded_date', { ascending: false })
      .limit(1);
    const v = (data?.[0] as { price_change_pct_24h?: number } | undefined)?.price_change_pct_24h;
    if (v != null) changePct24h = Number(v);
  }

  const sma21 = closes.length >= 21 ? smaOf(closes.slice(-21)) : 0;
  const sma50 = closes.length >= 50 ? smaOf(closes.slice(-50)) : 0;
  const sma200 = closes.length >= 200 ? smaOf(closes.slice(-200)) : 0;

  // Bollinger (20, 2σ population) on daily closes
  const bbCloses = closes.slice(-Math.min(closes.length, 20));
  const bbMid = smaOf(bbCloses);
  const bbStd = Math.sqrt(bbCloses.reduce((s, v) => s + (v - bbMid) ** 2, 0) / bbCloses.length);
  const bbU = bbMid + 2 * bbStd;
  const bbL = bbMid - 2 * bbStd;

  const trend = determineTrendIOS(price, sma21, sma50, sma200);

  // RSI(14) — iOS variant: simple average of the last 14 gains/losses
  let rsi = 50;
  if (closes.length >= 15) {
    const recent = closes.slice(-15);
    let gains = 0, losses = 0;
    for (let i = 1; i < recent.length; i++) {
      const ch = recent[i] - recent[i - 1];
      if (ch > 0) gains += ch; else losses -= ch;
    }
    const avgGain = gains / 14, avgLoss = losses / 14;
    rsi = avgLoss > 0 ? 100 - 100 / (1 + avgGain / avgLoss) : 100;
  }

  // Bull Market Support Bands from completed weekly closes
  const wCloses = weeklyClosesOf(candles);
  const sma20w = wCloses.length >= 20 ? smaOf(wCloses.slice(-20)) : price * 0.95;
  const ema21w = wCloses.length >= 21 ? emaOf(wCloses.slice(-21), 21) : price * 0.94;
  const aboveSma20w = price > sma20w;
  const aboveEma21w = price > ema21w;
  const bandPos: 'above' | 'in' | 'below' = aboveSma20w && aboveEma21w ? 'above' : !aboveSma20w && !aboveEma21w ? 'below' : 'in';

  // ── Trend Score — exact iOS trendScore (TechnicalAnalysis.swift) ──
  let ts = 50;
  ts += trend.dir === 'strongUptrend' ? 20 : trend.dir === 'uptrend' ? 10 : trend.dir === 'downtrend' ? -10 : trend.dir === 'strongDowntrend' ? -20 : 0;
  ts += price > sma21 ? 4 : -4;
  ts += price > sma50 ? 4 : -4;
  ts += price > sma200 ? 4 : -4;
  ts += bandPos === 'above' ? 8 : bandPos === 'in' ? 2 : -8;
  const trendScoreNum = Math.max(0, Math.min(100, ts));
  // iOS DualScoreCard trendLabel buckets
  const trendLabel = trendScoreNum < 25 ? 'Strong Down' : trendScoreNum < 40 ? 'Down' : trendScoreNum < 60 ? 'Sideways' : trendScoreNum < 75 ? 'Up' : 'Strong Up';
  const trendScore = trendScoreNum;

  // ── Valuation — exact iOS opportunityScore (TechnicalAnalysis.swift) ──
  // Start 50; RSI is the primary factor (±30), Bollinger %B confirms (±20).
  let val = 50;
  if (rsi < 20) val += 30;
  else if (rsi < 30) val += 20;
  else if (rsi < 40) val += 10;
  else if (rsi < 60) val += 0;
  else if (rsi < 70) val -= 10;
  else if (rsi < 80) val -= 20;
  else val -= 30;
  const bbRange = bbU - bbL;
  const pb = bbRange > 0 ? (price - bbL) / bbRange : 0.5; // %B
  val += pb > 1 ? -20 : pb > 0.8 ? -10 : pb > 0.2 ? 0 : pb > 0 ? 10 : 20;
  const valuationScore = Math.max(0, Math.min(100, val));
  // iOS TechnicalScoreCards valuationLabel bands
  const valuationLabel = valuationScore < 25 ? 'Overbought' : valuationScore < 40 ? 'Extended' : valuationScore < 60 ? 'Neutral' : valuationScore < 75 ? 'Oversold' : 'Deeply Oversold';

  // iOS determineBollingerPosition labels + signals (Price Position card)
  const posKey = pb > 1 ? 'aboveUpper' : pb > 0.8 ? 'nearUpper' : pb > 0.2 ? 'middle' : pb > 0 ? 'nearLower' : 'belowLower';
  const POS_LABEL = { aboveUpper: 'Overbought', nearUpper: 'Upper Band', middle: 'Mid Band', nearLower: 'Lower Band', belowLower: 'Oversold' } as const;
  const POS_SIGNAL = { aboveUpper: 'Potential reversal down', nearUpper: 'Resistance area', middle: 'Fair value zone', nearLower: 'Support area', belowLower: 'Potential reversal up' } as const;

  const goldenCross = sma50 > sma200; // iOS SMAAnalysis.goldenCross
  const above200 = price > sma200;
  const above50 = price > sma50;

  // ── Market Outlook — exact iOS determineSentiment (incl. "Strongly …" labels) ──
  const shortTerm = rsi > 70 ? { label: 'Strongly Bullish', direction: 'up' as const }
    : rsi > 55 ? { label: 'Bullish', direction: 'up' as const }
    : rsi < 30 ? { label: 'Strongly Bearish', direction: 'down' as const }
    : rsi < 45 ? { label: 'Bearish', direction: 'down' as const }
    : { label: 'Neutral', direction: 'flat' as const };
  const longTerm = above200 && goldenCross ? { label: 'Strongly Bullish', direction: 'up' as const }
    : above200 ? { label: 'Bullish', direction: 'up' as const }
    : !above200 && !goldenCross ? { label: 'Strongly Bearish', direction: 'down' as const }
    : { label: 'Bearish', direction: 'down' as const };

  // ── Trend Overview — 1D from daily trend; 1W/1M derived exactly like iOS ──
  const weeklyDir: TrendDir = above50 && above200
    ? (trend.dir === 'strongUptrend' ? 'strongUptrend' : 'uptrend')
    : !above50 && !above200
    ? (trend.dir === 'strongDowntrend' ? 'strongDowntrend' : 'downtrend')
    : 'sideways';
  const monthlyDir: TrendDir = above200 && goldenCross ? 'strongUptrend'
    : above200 ? 'uptrend'
    : !above200 && !goldenCross ? 'strongDowntrend'
    : 'downtrend';
  const timeframes: TechnicalTimeframeTrend[] = [
    { timeframe: '1D', label: TREND_SHORT[trend.dir], direction: trendArrow(trend.dir), strength: trend.strength },
    { timeframe: '1W', label: TREND_SHORT[weeklyDir], direction: trendArrow(weeklyDir), strength: trend.strength },
    { timeframe: '1M', label: TREND_SHORT[monthlyDir], direction: trendArrow(monthlyDir), strength: above200 === above50 ? 3 : 2 },
  ];

  // iOS RSIZone bands + descriptions (TechnicalAnalysis.swift)
  const rsiLabel = rsi < 30 ? 'Oversold' : rsi < 45 ? 'Weak' : rsi < 55 ? 'Neutral' : rsi < 70 ? 'Strong' : 'Overbought';
  const rsiNote = rsi < 30 ? 'Potential buy signal' : rsi < 45 ? 'Momentum weakening' : rsi < 55 ? 'No clear signal' : rsi < 70 ? 'Momentum building' : 'Potential sell signal';

  // ── Investment Insight — port of iOS generateInsight, same rule order ──
  const stBull = shortTerm.label.includes('Bullish');
  const stBear = shortTerm.label.includes('Bearish');
  const insight =
    rsi < 30 || (valuationScore >= 70 && trendScore >= 40)
      ? "Oversold conditions, historically a zone where bounces have formed, though the trend hasn't confirmed a turn yet."
      : rsi >= 70 && trendScore >= 60
      ? 'Trend is strong but price is stretched here, historically a spot where pullbacks have been more common.'
      : trendScore >= 60 && valuationScore >= 50 && stBull
      ? 'Momentum and valuation are both constructive, trend support and sentiment are aligned to the upside.'
      : trendScore <= 40 && valuationScore <= 40 && stBear
      ? 'Indicators are tilting cautious, trend, valuation, and sentiment are aligned to the downside for now.'
      : bandPos === 'above' && trendScore >= 50
      ? 'Price is holding above bull market support bands, the broader trend remains constructive.'
      : bandPos === 'below' && trendScore <= 50
      ? 'Price has broken below bull market support bands. Risk is elevated until support is reclaimed.'
      : 'Signals are mixed, no clear trend alignment right now.';

  return {
    symbol: symbol.toUpperCase(),
    name: meta.name,
    price,
    changePct24h,
    insight,
    trendScore,
    trendLabel,
    valuationScore,
    valuationLabel,
    shortTerm,
    longTerm,
    rsi,
    rsiLabel,
    rsiNote,
    timeframes,
    bmsb: {
      status: bandPos === 'above' ? 'Above Support' : bandPos === 'below' ? 'Below Support' : 'Testing Support',
      above: bandPos === 'above',
      band: bandPos,
      sma20w, ema21w,
      sma20wPct: sma20w ? ((price - sma20w) / sma20w) * 100 : 0,
      ema21wPct: ema21w ? ((price - ema21w) / ema21w) * 100 : 0,
    },
    keyLevels: [
      { label: '21 MA', value: sma21, above: price > sma21 },
      { label: '50 MA', value: sma50, above: above50 },
      { label: '200 MA', value: sma200, above: above200 },
    ],
    deathCross: sma50 < sma200,
    goldenCross,
    pricePosition: { percentB: pb, label: POS_LABEL[posKey], signal: POS_SIGNAL[posKey] },
  };
}

/* ──────────────────────────────────────────────────────────────────────────
 * Market Breadth detail — current trend, recent signals, multi-line history.
 * Source: market_breadth.
 * ────────────────────────────────────────────────────────────────────────── */
export async function fetchMarketBreadthDetail(days = 365): Promise<MarketBreadthDetailData | null> {
  if (!isSupabaseConfigured()) return null;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('market_breadth')
    .select('signal_date, total_tokens, trending_tokens, breadth_pct, ema_12, ema_21, trend, crossover, btc_price')
    .gte('signal_date', daysAgoISO(days))
    .order('signal_date', { ascending: true })
    .limit(400);
  if (error || !data?.length) return null;
  type Row = { signal_date: string; total_tokens: number; trending_tokens: number; breadth_pct: number; ema_12: number; ema_21: number; trend: string; crossover: string | null; btc_price: number };
  const rows = data as Row[];
  const latest = rows[rows.length - 1];

  const history: MarketBreadthPoint[] = rows.map((r) => ({
    date: r.signal_date,
    breadth: Number(r.breadth_pct),
    ema12: Number(r.ema_12),
    ema21: Number(r.ema_21),
    btc: Number(r.btc_price),
    crossover: r.crossover,
  }));

  const recentSignals = rows
    .filter((r) => r.crossover === 'bullish_crossover' || r.crossover === 'bearish_crossover')
    .slice(-6)
    .reverse()
    .map((r) => ({ type: (r.crossover === 'bullish_crossover' ? 'bullish' : 'bearish') as 'bullish' | 'bearish', date: r.signal_date }));

  return {
    breadthPct: Number(latest.breadth_pct),
    trend: latest.trend,
    ema12: Number(latest.ema_12),
    ema21: Number(latest.ema_21),
    trendingTokens: Number(latest.trending_tokens),
    totalTokens: Number(latest.total_tokens),
    btcPrice: Number(latest.btc_price),
    asOf: latest.signal_date,
    recentSignals,
    history,
  };
}

/* ──────────────────────────────────────────────────────────────────────────
 * Fear & Greed detail — current + yesterday/last week/last month + 90d history.
 * Source: fear_greed_history.
 * ────────────────────────────────────────────────────────────────────────── */
export async function fetchFearGreedDetail(): Promise<FearGreedDetailData | null> {
  if (!isSupabaseConfigured()) return null;
  const supabase = getSupabase();
  const since = daysAgoISO(95);
  const [fgRes, priceRes] = await Promise.all([
    supabase.from('fear_greed_history').select('date, value, classification').gte('date', since).order('date', { ascending: true }).limit(120),
    supabase.from('risk_snapshots').select('recorded_date, btc_price, sp500_price, nasdaq_price').gte('recorded_date', since).order('recorded_date', { ascending: true }).limit(200),
  ]);
  if (fgRes.error || !fgRes.data?.length) return null;

  // price map by date (carry forward the last known price for gaps)
  const priceRows = (priceRes.data ?? []) as { recorded_date: string; btc_price: number; sp500_price: number; nasdaq_price: number }[];
  const priceByDate = new Map(priceRows.map((p) => [p.recorded_date, p]));
  const sortedPriceDates = priceRows.map((p) => p.recorded_date);
  const nearestPrice = (date: string) => {
    if (priceByDate.has(date)) return priceByDate.get(date)!;
    let last: typeof priceRows[number] | undefined;
    for (const d of sortedPriceDates) { if (d <= date) last = priceByDate.get(d); else break; }
    return last;
  };

  const rows = (fgRes.data as { date: string; value: number; classification: string }[]).map((r) => {
    const p = nearestPrice(r.date);
    return {
      date: r.date,
      value: Number(r.value),
      classification: r.classification,
      btcPrice: p?.btc_price != null ? Number(p.btc_price) : undefined,
      sp500Price: p?.sp500_price != null ? Number(p.sp500_price) : undefined,
      nasdaqPrice: p?.nasdaq_price != null ? Number(p.nasdaq_price) : undefined,
    };
  });
  const latest = rows[rows.length - 1];
  const at = (back: number) => rows[rows.length - 1 - back]?.value;
  return {
    value: latest.value,
    classification: latest.classification,
    yesterday: at(1),
    lastWeek: at(7),
    lastMonth: at(30),
    history: rows,
  };
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
    // Full year of history so the detail view can offer 1M–1Y ranges.
    .gte('recorded_date', daysAgoISO(365))
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
