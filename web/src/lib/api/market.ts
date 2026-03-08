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
  MarketSentimentData,
  AltcoinScannerEntry,
} from '@/types';

function getSupabase() {
  return createClient();
}

async function proxyFetch<T>(service: string, path: string, params?: Record<string, string>): Promise<T> {
  const { data, error } = await getSupabase().functions.invoke('api-proxy', {
    body: { service, path, params },
  });
  if (error) throw error;
  return data as T;
}

export async function fetchCryptoAssets(page = 1, perPage = 50): Promise<CryptoAsset[]> {
  if (!isSupabaseConfigured()) return demoCryptoAssets.slice(0, perPage);
  return proxyFetch('coingecko', '/coins/markets', {
    vs_currency: 'usd',
    order: 'market_cap_desc',
    per_page: String(perPage),
    page: String(page),
    sparkline: 'true',
    price_change_percentage: '24h',
  });
}

export async function fetchGlobalMarketData(): Promise<GlobalMarketData> {
  if (!isSupabaseConfigured()) return demoGlobalMarket;
  const data = await proxyFetch<{ data: Record<string, unknown> }>('coingecko', '/global');
  const d = data.data;
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
  const data = await proxyFetch<{ data: Array<{ value: string; value_classification: string; timestamp: string }> }>(
    'coingecko',
    '/fear-greed-index',
  );
  const item = data?.data?.[0];
  return {
    value: Number(item?.value ?? 50),
    value_classification: item?.value_classification ?? 'Neutral',
    timestamp: item?.timestamp ?? new Date().toISOString(),
  };
}

export async function fetchNews(limit = 20): Promise<NewsItem[]> {
  if (!isSupabaseConfigured()) return demoNews.slice(0, limit);
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('marketDataCache')
    .select('data')
    .eq('key', 'news_feed')
    .single();
  if (error || !data) return [];
  return (data.data as NewsItem[]).slice(0, limit);
}

export async function fetchEconomicEvents(): Promise<EconomicEvent[]> {
  if (!isSupabaseConfigured()) return demoEvents;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('marketDataCache')
    .select('data')
    .eq('key', 'economic_events')
    .single();
  if (error || !data) return [];
  return data.data as EconomicEvent[];
}

export async function fetchFedWatchData(): Promise<FedWatchData[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('marketDataCache')
    .select('data')
    .eq('key', 'fed_watch')
    .single();
  if (error || !data) return [];
  return data.data as FedWatchData[];
}

export async function fetchCryptoPositioning(): Promise<CryptoPositioningData> {
  if (!isSupabaseConfigured()) return demoCryptoPositioning;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('marketDataCache')
    .select('data')
    .eq('key', 'crypto_positioning')
    .single();
  if (error || !data) return demoCryptoPositioning;
  return data.data as CryptoPositioningData;
}

export async function fetchTraditionalMarkets(): Promise<TraditionalMarketAsset[]> {
  if (!isSupabaseConfigured()) return demoTraditionalMarkets;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('marketDataCache')
    .select('data')
    .eq('key', 'traditional_markets')
    .single();
  if (error || !data) return demoTraditionalMarkets;
  return data.data as TraditionalMarketAsset[];
}

export async function fetchMarketSentiment(): Promise<MarketSentimentData> {
  if (!isSupabaseConfigured()) return demoSentiment;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('marketDataCache')
    .select('data')
    .eq('key', 'market_sentiment')
    .single();
  if (error || !data) return demoSentiment;
  return data.data as MarketSentimentData;
}

export async function fetchAltcoinScanner(): Promise<AltcoinScannerEntry[]> {
  if (!isSupabaseConfigured()) return demoAltcoinScanner;
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('marketDataCache')
    .select('data')
    .eq('key', 'altcoin_scanner')
    .single();
  if (error || !data) return demoAltcoinScanner;
  return data.data as AltcoinScannerEntry[];
}
