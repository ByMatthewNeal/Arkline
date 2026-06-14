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
  TraditionalMarketAsset,
  TrendSignal,
  MarketSentimentData,
  AltcoinScannerEntry,
  PositioningSignal,
  RegimeQuadrant,
  AssetPositioning,
  MacroInput,
  MacroInputSignal,
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
  const { data, error } = await supabase
    .from('economic_events')
    .select('id, title, country, currency, event_date, event_time, impact, forecast, previous, actual')
    .gte('event_date', todayISO)
    .order('event_date', { ascending: true })
    .limit(12);
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
    };
  });
}

export async function fetchFedWatchData(): Promise<FedWatchData[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('market_data_cache')
    .select('data')
    .eq('key', 'fed_watch')
    .single();
  if (error || !data) return [];
  return data.data as FedWatchData[];
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
