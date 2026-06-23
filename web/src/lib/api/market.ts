import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import {
  demoCryptoAssets,
  demoGlobalMarket,
  demoFearGreed,
  demoNews,
  demoEvents,
  demoCryptoPositioning,
  demoTraditionalMarkets,
  demoSentiment,
  demoAltcoinScanner,
} from '@/lib/demo-data';
import type {
  CryptoAsset,
  FearGreedIndex,
  GlobalMarketData,
  NewsItem,
  EconomicEvent,
  FedWatchData,
  CryptoPositioningData,
  MomentumMapData,
  MomentumPair,
  MomentumQuadrant,
  TraditionalMarketAsset,
  TrendSignal,
  MarketSentimentData,
  AltcoinScannerEntry,
  PositioningSignal,
  RegimeQuadrant,
  AssetPositioning,
  MacroInput,
  MacroInputSignal,
  MarketBreadthData,
  SignalChangeItem,
  QpsSignal,
  StockRiskItem,
  TradeSignalItem,
  RotationData,
  ModelPortfolioUpdate,
  WeeklyDeck,
  USFuturesItem,
  PerpPremiumItem,
  DeckSlide,
} from '@/types';

function getSupabase() {
  return createClient();
}

/* Read a blob out of market_data_cache by key. The CoinGecko payloads are
 * sometimes stored as a JSON *string* inside the jsonb column, so parse
 * defensively. Returns null when the key is missing. */
async function readCache<T>(key: string): Promise<T | null> {
  const { data, error } = await getSupabase()
    .from('market_data_cache')
    .select('data')
    .eq('key', key)
    .maybeSingle();
  if (error || !data) return null;
  let v: unknown = (data as { data: unknown }).data;
  if (typeof v === 'string') {
    try {
      v = JSON.parse(v);
    } catch {
      return null;
    }
  }
  return v as T;
}

export async function fetchCryptoAssets(page = 1, perPage = 50): Promise<CryptoAsset[]> {
  if (!isSupabaseConfigured()) return demoCryptoAssets.slice(0, perPage);
  const coins = await readCache<CryptoAsset[]>('crypto_assets_1_100');
  if (!coins?.length) return demoCryptoAssets.slice(0, perPage);
  const start = (page - 1) * perPage;
  return coins.slice(start, start + perPage);
}

export async function fetchGlobalMarketData(): Promise<GlobalMarketData> {
  if (!isSupabaseConfigured()) return demoGlobalMarket;
  const wrapped = await readCache<{ data: Record<string, unknown> }>('global_market_data');
  const d = wrapped?.data;
  if (!d) return demoGlobalMarket;
  return {
    total_market_cap: (d.total_market_cap as Record<string, number>)?.usd ?? 0,
    total_volume: (d.total_volume as Record<string, number>)?.usd ?? 0,
    btc_dominance: (d.market_cap_percentage as Record<string, number>)?.btc ?? 0,
    eth_dominance: (d.market_cap_percentage as Record<string, number>)?.eth ?? 0,
    market_cap_change_percentage_24h: (d.market_cap_change_percentage_24h_usd as number) ?? 0,
  };
}

export async function fetchFearGreedIndex(): Promise<FearGreedIndex> {
  if (!isSupabaseConfigured()) return demoFearGreed;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('fear_greed_history')
    .select('value, classification, date')
    .order('date', { ascending: false })
    .limit(1);
  const item = data?.[0] as { value: number; classification: string; date: string } | undefined;
  if (error || !item) return demoFearGreed;
  return {
    value: Number(item.value),
    value_classification: item.classification ?? 'Neutral',
    timestamp: item.date,
  };
}

export async function fetchNews(limit = 20): Promise<NewsItem[]> {
  if (!isSupabaseConfigured()) return demoNews.slice(0, limit);
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('curated_news')
    .select('id, curated_title, source, source_url, published_at, category')
    .order('published_at', { ascending: false })
    .limit(limit);
  if (error || !data?.length) return demoNews.slice(0, limit);
  return (data as {
    id: string;
    curated_title: string;
    source: string;
    source_url: string;
    published_at: string;
    category: string | null;
  }[]).map((n) => ({
    id: n.id,
    title: n.curated_title,
    url: n.source_url,
    source: n.source,
    published_at: n.published_at,
    categories: n.category ? [n.category] : undefined,
  }));
}

export async function fetchEconomicEvents(): Promise<EconomicEvent[]> {
  if (!isSupabaseConfigured()) return demoEvents;
  const supabase = getSupabase();
  const todayISO = new Date().toISOString().split('T')[0];
  // Pull a window around today so the feed has both upcoming and just-released
  // events (released ones carry actual + analysis).
  const sinceISO = new Date(Date.now() - 7 * 86_400_000).toISOString().split('T')[0];
  const { data, error } = await supabase
    .from('economic_events')
    .select('id, title, country, currency, event_date, event_time, impact, forecast, previous, actual, beat_miss, claude_analysis')
    .gte('event_date', sinceISO)
    .order('event_date', { ascending: true })
    .limit(40);
  if (error || !data?.length) return demoEvents;
  return (data as {
    id: string;
    title: string;
    country: string;
    event_date: string;
    event_time: string | null;
    impact: string | null;
    forecast: string | null;
    previous: string | null;
    actual: string | null;
    beat_miss: string | null;
    claude_analysis: string | null;
  }[]).map((e) => {
    const impact = (['low', 'medium', 'high'].includes(e.impact ?? '') ? e.impact : 'medium') as
      | 'low'
      | 'medium'
      | 'high';
    return {
      id: e.id,
      title: e.title,
      date: e.event_date,
      time: e.event_time
        ? new Date(e.event_time).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' })
        : undefined,
      impact,
      country: e.country,
      actual: e.actual ?? undefined,
      forecast: e.forecast ?? undefined,
      previous: e.previous ?? undefined,
      beat_miss: e.beat_miss ?? undefined,
      analysis: e.claude_analysis ?? undefined,
    };
  });
}

// Fed Watch — written by the refresh-market-extras edge cron as
// { rate, meetings: FedWatchData[] }. Tolerates a bare array too.
export async function fetchFedWatchData(): Promise<FedWatchData[]> {
  if (!isSupabaseConfigured()) return [];
  const raw = await readCache<FedWatchData[] | { meetings?: FedWatchData[] }>('fed_watch');
  if (!raw) return [];
  if (Array.isArray(raw)) return raw;
  return raw.meetings ?? [];
}

// US Futures (ES/YM/NQ) — written by the edge cron under 'us_futures'.
export async function fetchUSFutures(): Promise<USFuturesItem[]> {
  if (!isSupabaseConfigured()) return [];
  return (await readCache<USFuturesItem[]>('us_futures')) ?? [];
}

// Perp Premium (BTC/ETH funding) — written by the edge cron under 'perp_premium'.
export async function fetchPerpPremiumData(): Promise<PerpPremiumItem[]> {
  if (!isSupabaseConfigured()) return [];
  return (await readCache<PerpPremiumItem[]>('perp_premium')) ?? [];
}

interface PositioningRow {
  asset: string;
  signal: PositioningSignal;
  trend_score: number | null;
  rsi: number | null;
  risk_level: number | null;
  category: string | null;
  bmsb_status: string | null;
  signal_date: string;
}

const REGIME_INFO: Record<RegimeQuadrant, { label: string; description: string }> = {
  'risk-on-disinflation': {
    label: 'Risk-On / Disinflation',
    description:
      'Growth is firming while inflation cools — historically the most favorable backdrop for risk assets.',
  },
  'risk-on-inflation': {
    label: 'Risk-On / Inflation',
    description:
      'Growth and inflation are both rising — risk assets can work, but volatility and policy risk increase.',
  },
  'risk-off-inflation': {
    label: 'Risk-Off / Inflation',
    description:
      'Weak growth with sticky inflation (stagflationary) — the toughest regime for risk assets.',
  },
  'risk-off-disinflation': {
    label: 'Risk-Off / Disinflation',
    description:
      'Growth is slowing and inflation is falling — defensive posture until liquidity or policy turns.',
  },
};

const MACRO_ICONS: Record<string, string> = {
  VIX: 'bar-chart-3',
  DXY: 'dollar-sign',
  TLT: 'trending-up',
  GOLD: 'diamond',
  SILVER: 'diamond',
  OIL: 'droplet',
  COPPER: 'droplet',
};

function cap(s: string): MacroInputSignal {
  return (s.charAt(0).toUpperCase() + s.slice(1)) as MacroInputSignal;
}

// NOTE: growth/inflation scores and the regime quadrant are derived here as a
// transparent proxy from the live positioning_signals (share of bullish signals
// among growth- vs. inflation-sensitive assets). Once the on-device regime
// classifier is ported into the derived_signals table, prefer that instead.
export async function fetchCryptoPositioning(): Promise<CryptoPositioningData> {
  if (!isSupabaseConfigured()) return demoCryptoPositioning;
  const supabase = getSupabase();

  const latest = await supabase
    .from('positioning_signals')
    .select('signal_date')
    .order('signal_date', { ascending: false })
    .limit(1);
  const latestDate = latest.data?.[0]?.signal_date;
  if (!latestDate) return demoCryptoPositioning;

  const { data, error } = await supabase
    .from('positioning_signals')
    .select('asset, signal, trend_score, rsi, risk_level, category, bmsb_status, signal_date')
    .eq('signal_date', latestDate);
  if (error || !data?.length) return demoCryptoPositioning;

  const rows = data as PositioningRow[];
  const bullishShare = (subset: PositioningRow[]) =>
    subset.length ? subset.filter((r) => r.signal === 'bullish').length / subset.length : 0.5;

  const crypto = rows.filter((r) => r.category === 'crypto');
  const commodity = rows.filter((r) => r.category === 'commodity');
  const macro = rows.filter((r) => r.category === 'macro' || r.category === 'commodity');

  const growth_score = Math.round(bullishShare(crypto) * 100);
  const inflation_score = Math.round(bullishShare(commodity) * 100);
  const regime: RegimeQuadrant = `${growth_score >= 50 ? 'risk-on' : 'risk-off'}-${
    inflation_score >= 50 ? 'inflation' : 'disinflation'
  }` as RegimeQuadrant;

  const signal_counts = {
    bullish: rows.filter((r) => r.signal === 'bullish').length,
    neutral: rows.filter((r) => r.signal === 'neutral').length,
    bearish: rows.filter((r) => r.signal === 'bearish').length,
  };

  const macro_inputs: MacroInput[] = macro.slice(0, 8).map((r) => ({
    id: r.asset,
    name: r.asset,
    value: Number(r.trend_score ?? 0),
    formatted_value: r.trend_score != null ? `Trend ${Math.round(Number(r.trend_score))}` : '—',
    signal: cap(r.signal),
    icon: MACRO_ICONS[r.asset] ?? 'globe',
  }));

  const assets: AssetPositioning[] = crypto
    .sort((a, b) => Number(b.trend_score ?? 0) - Number(a.trend_score ?? 0))
    .slice(0, 12)
    .map((r) => {
      const target_allocation = r.signal === 'bullish' ? 100 : r.signal === 'neutral' ? 25 : 0;
      const trend =
        r.signal === 'bullish' ? 'Uptrend intact' : r.signal === 'bearish' ? 'In a downtrend' : 'Consolidating';
      const bmsb = r.bmsb_status && r.bmsb_status !== 'unknown' ? `, ${r.bmsb_status} bull-market band` : '';
      return {
        symbol: r.asset,
        name: r.asset,
        signal: r.signal,
        regime_fit: Number(r.trend_score ?? 0) / 100,
        target_allocation,
        is_dca_opportunity: r.signal === 'neutral',
        risk_level: r.risk_level ?? undefined,
        interpretation: `${trend}${r.rsi != null ? `, RSI ${Math.round(Number(r.rsi))}` : ''}${bmsb}.`,
      };
    });

  return {
    regime,
    regime_label: REGIME_INFO[regime].label,
    regime_description: REGIME_INFO[regime].description,
    growth_score,
    inflation_score,
    signal_counts,
    extreme_move: false,
    macro_inputs,
    assets,
  };
}

/* ── Momentum Map ── (pairs each asset's USD positioning signal with its /BTC
   signal for the latest day, then sorts into alignment quadrants). */

const MOMENTUM_REAL_BTC_PAIRS = new Set([
  'ETH', 'SOL', 'LINK', 'AVAX', 'DOGE', 'BCH', 'UNI', 'AAVE',
]);

const MOMENTUM_QUADRANT_ORDER: MomentumQuadrant[] = [
  'momentum', 'outperforming_btc', 'usd_leading', 'mixed', 'both_bearish',
];

function classifyMomentumQuadrant(usd: PositioningSignal, btc: PositioningSignal): MomentumQuadrant {
  const usdBull = usd === 'bullish';
  const btcBull = btc === 'bullish';
  if (usdBull && btcBull) return 'momentum';
  if (btcBull && !usdBull) return 'outperforming_btc';
  if (usdBull && !btcBull) return 'usd_leading';
  if (usd === 'bearish' && btc === 'bearish') return 'both_bearish';
  return 'mixed';
}

export async function fetchMomentumMap(): Promise<MomentumMapData> {
  const empty: MomentumMapData = { as_of: null, groups: [], momentum_count: 0 };
  if (!isSupabaseConfigured()) return empty;
  const supabase = getSupabase();

  const latest = await supabase
    .from('positioning_signals')
    .select('signal_date')
    .order('signal_date', { ascending: false })
    .limit(1);
  const latestDate = latest.data?.[0]?.signal_date;
  if (!latestDate) return empty;

  const { data, error } = await supabase
    .from('positioning_signals')
    .select('asset, signal, trend_score, category, signal_date')
    .eq('signal_date', latestDate);
  if (error || !data?.length) return empty;

  const rows = data as { asset: string; signal: PositioningSignal; trend_score: number | null; category: string | null }[];

  const usdByAsset = new Map<string, { signal: PositioningSignal; score: number }>();
  const btcByAsset = new Map<string, { signal: PositioningSignal; score: number }>();
  for (const r of rows) {
    const score = Math.round(Number(r.trend_score ?? 0));
    if (r.asset.includes('/BTC')) {
      btcByAsset.set(r.asset.replace('/BTC', ''), { signal: r.signal, score });
    } else if (r.category === 'crypto') {
      usdByAsset.set(r.asset, { signal: r.signal, score });
    }
  }

  const pairs: MomentumPair[] = [];
  for (const [asset, usd] of usdByAsset) {
    const btc = btcByAsset.get(asset);
    if (!btc) continue;
    pairs.push({
      asset,
      usd_signal: usd.signal,
      usd_score: usd.score,
      btc_signal: btc.signal,
      btc_score: btc.score,
      is_real_btc_pair: MOMENTUM_REAL_BTC_PAIRS.has(asset),
      quadrant: classifyMomentumQuadrant(usd.signal, btc.signal),
    });
  }

  const groups = MOMENTUM_QUADRANT_ORDER
    .map((quadrant) => ({
      quadrant,
      pairs: pairs
        .filter((p) => p.quadrant === quadrant)
        .sort((a, b) => (b.usd_score + b.btc_score) - (a.usd_score + a.btc_score)),
    }))
    .filter((g) => g.pairs.length > 0);

  return {
    as_of: latestDate,
    groups,
    momentum_count: pairs.filter((p) => p.quadrant === 'momentum').length,
  };
}

// Traditional markets from live history: equities (S&P 500, Nasdaq) from
// risk_snapshots; gold + WTI crude from indicator_snapshots.
export async function fetchTraditionalMarkets(): Promise<TraditionalMarketAsset[]> {
  if (!isSupabaseConfigured()) return demoTraditionalMarkets;
  const supabase = getSupabase();
  const sinceISO = new Date(Date.now() - 30 * 86_400_000).toISOString().split('T')[0];

  const [rsRes, indRes] = await Promise.all([
    supabase
      .from('risk_snapshots')
      .select('recorded_date, sp500_price, nasdaq_price')
      .gte('recorded_date', sinceISO)
      .order('recorded_date', { ascending: true }),
    supabase
      .from('indicator_snapshots')
      .select('indicator, value, recorded_date')
      .in('indicator', ['gold_xau', 'crude_oil_wti'])
      .gte('recorded_date', sinceISO)
      .order('recorded_date', { ascending: true }),
  ]);

  const build = (
    id: string,
    symbol: string,
    name: string,
    values: (number | null)[],
  ): TraditionalMarketAsset | null => {
    const clean = values.filter((v): v is number => v != null && !Number.isNaN(v));
    if (clean.length < 2) return null;
    const current = clean[clean.length - 1];
    const prev = clean[clean.length - 2];
    const first = clean[0];
    const change_24h = current - prev;
    const pct = prev ? (change_24h / prev) * 100 : 0;
    const windowPct = first ? (current / first - 1) * 100 : 0;
    const trend_signal: TrendSignal = windowPct > 1 ? 'Bullish' : windowPct < -1 ? 'Bearish' : 'Neutral';
    return {
      id,
      symbol,
      name,
      current_price: current,
      price_change_24h: change_24h,
      price_change_percentage_24h: pct,
      trend_signal,
      sparkline: clean.slice(-30),
    };
  };

  const rs = (rsRes.data ?? []) as { sp500_price: number | null; nasdaq_price: number | null }[];
  const sp = build('sp500', 'SPX', 'S&P 500', rs.map((r) => r.sp500_price));
  const ndx = build('nasdaq', 'NDX', 'Nasdaq', rs.map((r) => r.nasdaq_price));

  const indBy = new Map<string, number[]>();
  for (const r of (indRes.data ?? []) as { indicator: string; value: number }[]) {
    const a = indBy.get(r.indicator) ?? [];
    a.push(Number(r.value));
    indBy.set(r.indicator, a);
  }
  const gold = build('gold', 'XAU', 'Gold', indBy.get('gold_xau') ?? []);
  const oil = build('wti', 'WTI', 'Crude Oil', indBy.get('crude_oil_wti') ?? []);

  const out = [sp, ndx, gold, oil].filter((x): x is TraditionalMarketAsset => x !== null);
  return out.length ? out : demoTraditionalMarkets;
}

// Headline fields (fear/greed, dominance, market cap, altcoin season, funding) are
// sourced live. The modeled sub-views (emotion/engagement trajectory, retail
// sentiment, per-asset risk strip, market-cap sparkline) remain on demo values
// until that sentiment model is persisted server-side.
export async function fetchMarketSentiment(): Promise<MarketSentimentData> {
  if (!isSupabaseConfigured()) return demoSentiment;
  const supabase = getSupabase();

  const [fgRes, indRes] = await Promise.all([
    supabase
      .from('fear_greed_history')
      .select('value, classification, date')
      .order('date', { ascending: false })
      .limit(1),
    supabase
      .from('indicator_snapshots')
      .select('indicator, value, recorded_date')
      .in('indicator', ['btc_dominance', 'total_market_cap', 'altcoin_season', 'funding_rate'])
      .order('recorded_date', { ascending: false })
      .limit(40),
  ]);

  const fg = fgRes.data?.[0] as { value: number; classification: string } | undefined;
  const latestInd = new Map<string, number>();
  for (const r of (indRes.data ?? []) as { indicator: string; value: number }[]) {
    if (!latestInd.has(r.indicator)) latestInd.set(r.indicator, Number(r.value));
  }

  const result: MarketSentimentData = { ...demoSentiment };
  if (fg) {
    result.fear_greed = Number(fg.value);
    result.fear_greed_label = fg.classification;
  }
  if (latestInd.has('btc_dominance')) result.btc_dominance = latestInd.get('btc_dominance')!;
  if (latestInd.has('total_market_cap')) result.total_market_cap = latestInd.get('total_market_cap')!;
  if (latestInd.has('altcoin_season')) {
    const season = latestInd.get('altcoin_season')!;
    result.season_index = season;
    result.season = season >= 75 ? 'altcoin' : 'bitcoin';
  }
  if (latestInd.has('funding_rate')) {
    const rate = latestInd.get('funding_rate')!;
    result.funding_rate = {
      rate,
      sentiment: rate >= 0 ? 'Longs pay shorts' : 'Shorts pay longs',
      annualized_rate: rate * 3 * 365, // 8h funding → daily ×3 → annualized
      exchange: 'Aggregate',
    };
  }
  return result;
}

// Altcoin scanner: 7/30/90-day returns (and vs-BTC) computed from the daily
// market_snapshots price history; display metadata from the cached coin list.
export async function fetchAltcoinScanner(): Promise<AltcoinScannerEntry[]> {
  if (!isSupabaseConfigured()) return demoAltcoinScanner;
  const supabase = getSupabase();

  const coins = (await readCache<CryptoAsset[]>('crypto_assets_1_100')) ?? [];
  const meta = new Map<string, CryptoAsset>();
  for (const c of coins) meta.set(c.id, c);

  const latest = await supabase
    .from('market_snapshots')
    .select('recorded_date')
    .order('recorded_date', { ascending: false })
    .limit(1);
  const maxDate = latest.data?.[0]?.recorded_date as string | undefined;
  if (!maxDate) return demoAltcoinScanner;

  const base = new Date(maxDate + 'T00:00:00Z');
  const iso = (n: number) => {
    const d = new Date(base);
    d.setUTCDate(d.getUTCDate() - n);
    return d.toISOString().split('T')[0];
  };
  const dNow = maxDate;
  const d7 = iso(7);
  const d30 = iso(30);
  const d90 = iso(90);

  const { data, error } = await supabase
    .from('market_snapshots')
    .select('coin_id, recorded_date, current_price, market_cap')
    .in('recorded_date', [dNow, d7, d30, d90]);
  if (error || !data?.length) return demoAltcoinScanner;

  const px = new Map<string, Record<string, number>>();
  const mcNow = new Map<string, number>();
  for (const r of data as {
    coin_id: string;
    recorded_date: string;
    current_price: number;
    market_cap: number;
  }[]) {
    const m = px.get(r.coin_id) ?? {};
    m[r.recorded_date] = r.current_price;
    px.set(r.coin_id, m);
    if (r.recorded_date === dNow) mcNow.set(r.coin_id, r.market_cap);
  }

  const ret = (coinId: string, day: string): number | null => {
    const m = px.get(coinId);
    if (!m) return null;
    const a = m[dNow];
    const b = m[day];
    if (a == null || b == null || !b) return null;
    return (a / b - 1) * 100;
  };
  const btc7 = ret('bitcoin', d7);
  const btc30 = ret('bitcoin', d30);
  const btc90 = ret('bitcoin', d90);
  const vs = (r: number | null, btc: number | null) => (r != null && btc != null ? r - btc : 0);

  const entries: AltcoinScannerEntry[] = [];
  for (const [coinId, m] of px) {
    if (coinId === 'bitcoin' || m[dNow] == null) continue;
    const r7 = ret(coinId, d7);
    const r30 = ret(coinId, d30);
    const r90 = ret(coinId, d90);
    const md = meta.get(coinId);
    entries.push({
      id: coinId,
      symbol: (md?.symbol ?? coinId).toUpperCase(),
      name: md?.name ?? coinId,
      current_price: m[dNow],
      market_cap: md?.market_cap ?? mcNow.get(coinId) ?? 0,
      return_7d: r7 ?? 0,
      return_30d: r30 ?? 0,
      return_90d: r90 ?? 0,
      vs_btc_7d: vs(r7, btc7),
      vs_btc_30d: vs(r30, btc30),
      vs_btc_90d: vs(r90, btc90),
      image: md?.image,
    });
  }
  entries.sort((a, b) => b.market_cap - a.market_cap);
  return entries.length ? entries.slice(0, 30) : demoAltcoinScanner;
}

/* ── Market Breadth ── (market_breadth: % tokens in uptrend + EMA crossover) */
export async function fetchMarketBreadth(): Promise<MarketBreadthData | null> {
  if (!isSupabaseConfigured()) return null;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('market_breadth')
    .select('signal_date, breadth_pct, trend, prev_trend, crossover, trending_tokens, total_tokens, btc_price')
    .order('signal_date', { ascending: false })
    .limit(30);
  if (error || !data?.length) return null;
  const rows = data as {
    breadth_pct: number; trend: string; prev_trend: string | null; crossover: string | null;
    trending_tokens: number; total_tokens: number; btc_price: number | null;
  }[];
  const latest = rows[0];
  return {
    breadth_pct: Number(latest.breadth_pct),
    trend: latest.trend,
    prev_trend: latest.prev_trend,
    crossover: latest.crossover,
    trending_tokens: latest.trending_tokens,
    total_tokens: latest.total_tokens,
    btc_price: latest.btc_price,
    history: rows.map((r) => Number(r.breadth_pct)).reverse(),
  };
}

/* ── Signal Changes ── (positioning_signals where today's signal != prior) */
export async function fetchSignalChanges(): Promise<SignalChangeItem[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const latest = await supabase
    .from('positioning_signals')
    .select('signal_date')
    .order('signal_date', { ascending: false })
    .limit(1);
  const latestDate = latest.data?.[0]?.signal_date;
  if (!latestDate) return [];
  const { data, error } = await supabase
    .from('positioning_signals')
    .select('asset, signal, prev_signal')
    .eq('signal_date', latestDate);
  if (error || !data?.length) return [];
  const valid: QpsSignal[] = ['bullish', 'neutral', 'bearish'];
  return (data as { asset: string; signal: string; prev_signal: string | null }[])
    .filter((r) => r.prev_signal && r.signal !== r.prev_signal && valid.includes(r.signal as QpsSignal))
    .map((r) => ({ asset: r.asset, signal: r.signal as QpsSignal, prev_signal: r.prev_signal as QpsSignal }));
}

/* ── Stock Risk Levels ── (indicator_snapshots stock_risk_*) */
export async function fetchStockRiskLevels(): Promise<StockRiskItem[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('indicator_snapshots')
    .select('indicator, value, recorded_date')
    .like('indicator', 'stock_risk_%')
    .order('recorded_date', { ascending: false })
    .limit(120);
  if (error || !data?.length) return [];
  const rows = data as { indicator: string; value: number; recorded_date: string }[];
  const latestDate = rows[0].recorded_date;
  return rows
    .filter((r) => r.recorded_date === latestDate)
    .map((r) => ({ symbol: r.indicator.replace('stock_risk_', '').toUpperCase(), risk_value: Number(r.value) }))
    .sort((a, b) => b.risk_value - a.risk_value)
    .slice(0, 12);
}

/* ── Trade Signals ── (trade_signals: Fibonacci-based setups) */
export async function fetchTradeSignals(): Promise<TradeSignalItem[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('trade_signals')
    .select('id, asset, signal_type, status, risk_reward_ratio, timeframe, generated_at')
    .order('generated_at', { ascending: false })
    .limit(6);
  if (error || !data?.length) return [];
  return (data as TradeSignalItem[]).map((r) => ({
    id: r.id, asset: r.asset, signal_type: r.signal_type, status: r.status,
    risk_reward_ratio: r.risk_reward_ratio, timeframe: r.timeframe,
  }));
}

/* ── Rotation Signal ── (rotation_signals + top sectors) */
export async function fetchRotationSignal(): Promise<RotationData | null> {
  if (!isSupabaseConfigured()) return null;
  const supabase = getSupabase();
  const rot = await supabase
    .from('rotation_signals')
    .select('signal_date, rotation_score, regime, narrative, btc_30d_return, spy_30d_return')
    .order('signal_date', { ascending: false })
    .limit(1);
  const r = rot.data?.[0] as {
    signal_date: string; rotation_score: number; regime: string; narrative: string | null;
    btc_30d_return: number | null; spy_30d_return: number | null;
  } | undefined;
  if (rot.error || !r) return null;

  const secRes = await supabase
    .from('sector_performance')
    .select('sector_name, return_30d, signal_date')
    .order('signal_date', { ascending: false })
    .limit(40);
  const secRows = (secRes.data ?? []) as { sector_name: string; return_30d: number; signal_date: string }[];
  const latestSecDate = secRows[0]?.signal_date;
  const sectors = secRows
    .filter((s) => s.signal_date === latestSecDate)
    .sort((a, b) => Number(b.return_30d) - Number(a.return_30d))
    .slice(0, 3)
    .map((s) => ({ name: s.sector_name, return_30d: Number(s.return_30d) }));

  return {
    rotation_score: Number(r.rotation_score),
    regime: r.regime,
    narrative: r.narrative,
    btc_30d_return: r.btc_30d_return,
    spy_30d_return: r.spy_30d_return,
    sectors,
  };
}

/* ── Model Portfolio Update ── (latest rebalance from model_portfolio_trades) */
export async function fetchModelPortfolioUpdate(): Promise<ModelPortfolioUpdate | null> {
  if (!isSupabaseConfigured()) return null;
  const supabase = getSupabase();
  const tr = await supabase
    .from('model_portfolio_trades')
    .select('portfolio_id, trade_date, trigger, from_allocation, to_allocation')
    .order('trade_date', { ascending: false })
    .limit(1);
  const t = tr.data?.[0] as {
    portfolio_id: string; trade_date: string; trigger: string;
    from_allocation: Record<string, number>; to_allocation: Record<string, number>;
  } | undefined;
  if (tr.error || !t) return null;

  const pf = await supabase.from('model_portfolios').select('name').eq('id', t.portfolio_id).maybeSingle();
  const portfolio_name = (pf.data as { name: string } | null)?.name ?? 'Model Portfolio';

  const from = t.from_allocation ?? {};
  const to = t.to_allocation ?? {};
  const assets = Array.from(new Set([...Object.keys(from), ...Object.keys(to)]));
  const changes = assets
    .map((a) => ({ asset: a, from: Number(from[a] ?? 0), to: Number(to[a] ?? 0) }))
    .filter((c) => Math.abs(c.from - c.to) >= 0.05)
    .sort((a, b) => Math.abs(b.to - b.from) - Math.abs(a.to - a.from));

  return { portfolio_name, trigger: t.trigger, trade_date: t.trade_date, changes };
}

/* ── Weekly Update deck ── (market_update_decks latest published) */
export async function fetchWeeklyDeck(): Promise<WeeklyDeck | null> {
  if (!isSupabaseConfigured()) return null;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('market_update_decks')
    .select('week_start, week_end, status, slides, published_at')
    .order('week_start', { ascending: false })
    .limit(1);
  const d = data?.[0] as { week_start: string; week_end: string; status: string; slides: unknown } | undefined;
  if (error || !d) return null;
  let raw = d.slides;
  if (typeof raw === 'string') {
    try { raw = JSON.parse(raw); } catch { raw = []; }
  }
  const arr = Array.isArray(raw) ? raw : [];
  const slides: DeckSlide[] = arr.map((s: Record<string, unknown>, i) => {
    const dataObj = (s.data as Record<string, unknown> | undefined) ?? {};
    return {
      id: String(s.id ?? i),
      type: String(s.type ?? dataObj.type ?? 'slide'),
      title: String(s.title ?? ''),
      payload: (dataObj.payload as Record<string, unknown>) ?? {},
    };
  });
  return {
    week_start: d.week_start,
    week_end: d.week_end,
    slide_count: slides.length,
    status: d.status,
    slides,
  };
}
