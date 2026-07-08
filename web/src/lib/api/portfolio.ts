import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';
import type { Portfolio, PortfolioHolding, PortfolioHistoryPoint } from '@/types';
import type { Transaction } from '@/types/transaction';

function getSupabase() {
  return createClient();
}

export async function fetchPortfolios(userId: string): Promise<Portfolio[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('portfolios')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export async function fetchHoldings(portfolioId: string): Promise<PortfolioHolding[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('holdings')
    .select('*')
    .eq('portfolio_id', portfolioId)
    .order('created_at', { ascending: true });
  if (error) throw error;
  return data ?? [];
}

export async function fetchTransactions(portfolioId: string): Promise<Transaction[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const { data, error } = await supabase
    .from('transactions')
    .select('*')
    .eq('portfolio_id', portfolioId)
    .order('transaction_date', { ascending: false });
  if (error) throw error;
  return data ?? [];
}

export async function fetchPortfolioHistory(
  portfolioId: string,
  days = 30,
): Promise<PortfolioHistoryPoint[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = getSupabase();
  const since = new Date();
  since.setDate(since.getDate() - days);

  const sinceISO = since.toISOString().split('T')[0];
  const { data, error } = await supabase
    .from('portfolio_history')
    .select('recorded_date, total_value')
    .eq('portfolio_id', portfolioId)
    .gte('recorded_date', sinceISO)
    .order('recorded_date', { ascending: true });
  if (error) return [];
  return (data as { recorded_date: string; total_value: number }[]).map((p) => ({
    date: p.recorded_date,
    value: Number(p.total_value),
  }));
}

/* ── Live pricing ─────────────────────────────────────────────────────────
 * Live prices for ALL holdings (crypto beyond the cached top-100, stocks,
 * metals) via the `api-proxy` edge function — mirrors the iOS pricing path
 * (CoinGecko + FMP + Metals API). NOTE: the proxy reads `queryItems`, not
 * `params`, and CoinGecko `/simple/price` requires coin IDS, not symbols.
 */

export interface LivePrice {
  price: number;
  change24h?: number;
}

/** symbol(lowercase) → CoinGecko id, memoized per session to avoid re-searching. */
const cgIdCache = new Map<string, string | null>();

async function invokeProxy<T>(
  body: { service: string; path: string; queryItems?: Record<string, string> },
): Promise<T | null> {
  const supabase = getSupabase();
  const { data, error } = await supabase.functions.invoke('api-proxy', { body });
  if (error) return null;
  return data as T;
}

async function resolveCoinGeckoIds(
  symbols: string[],
  knownIds: Map<string, string>,
): Promise<Map<string, string>> {
  const resolved = new Map<string, string>();
  const unresolved: string[] = [];

  for (const sym of symbols) {
    const known = knownIds.get(sym) ?? cgIdCache.get(sym);
    if (known) resolved.set(sym, known);
    else if (cgIdCache.get(sym) !== null || !cgIdCache.has(sym)) unresolved.push(sym);
  }

  // Fall back to CoinGecko /search for long-tail coins (exact symbol match,
  // best market-cap rank wins). Sequential-ish but only runs for unknowns once.
  await Promise.all(
    unresolved.map(async (sym) => {
      type SearchResult = { coins?: { id: string; symbol: string; market_cap_rank?: number | null }[] };
      const res = await invokeProxy<SearchResult>({
        service: 'coingecko',
        path: '/search',
        queryItems: { query: sym },
      });
      const match = (res?.coins ?? [])
        .filter((c) => c.symbol?.toLowerCase() === sym)
        .sort((a, b) => (a.market_cap_rank ?? 1e9) - (b.market_cap_rank ?? 1e9))[0];
      cgIdCache.set(sym, match?.id ?? null);
      if (match?.id) resolved.set(sym, match.id);
    }),
  );

  return resolved;
}

async function fetchCryptoPrices(
  symbols: string[],
  knownIds: Map<string, string>,
): Promise<Map<string, LivePrice>> {
  const out = new Map<string, LivePrice>();
  if (!symbols.length) return out;

  const idBySymbol = await resolveCoinGeckoIds(symbols, knownIds);
  if (!idBySymbol.size) return out;

  type SimplePrice = Record<string, { usd?: number; usd_24h_change?: number }>;
  const data = await invokeProxy<SimplePrice>({
    service: 'coingecko',
    path: '/simple/price',
    queryItems: {
      ids: [...new Set(idBySymbol.values())].join(','),
      vs_currencies: 'usd',
      include_24hr_change: 'true',
    },
  });
  if (!data) return out;

  for (const [sym, id] of idBySymbol) {
    const p = data[id];
    if (p?.usd != null) out.set(sym, { price: p.usd, change24h: p.usd_24h_change });
  }
  return out;
}

async function fetchStockPrices(symbols: string[]): Promise<Map<string, LivePrice>> {
  const out = new Map<string, LivePrice>();
  // FMP stable tier: one /quote call per symbol (matches iOS FMPService).
  await Promise.all(
    symbols.map(async (sym) => {
      type FMPQuote = { symbol: string; price?: number; changePercentage?: number; changesPercentage?: number };
      const data = await invokeProxy<FMPQuote[]>({
        service: 'fmp',
        path: '/quote',
        queryItems: { symbol: sym.toUpperCase() },
      });
      const q = Array.isArray(data) ? data[0] : undefined;
      if (q?.price != null) {
        out.set(sym, { price: q.price, change24h: q.changePercentage ?? q.changesPercentage });
      }
    }),
  );
  return out;
}

async function fetchMetalPrices(symbols: string[]): Promise<Map<string, LivePrice>> {
  const out = new Map<string, LivePrice>();
  if (!symbols.length) return out;
  // Metals API returns rates per USD → invert for price per unit (matches iOS).
  type MetalsResponse = { rates?: Record<string, number> };
  const data = await invokeProxy<MetalsResponse>({
    service: 'metals',
    path: '/latest',
    queryItems: { base: 'USD', symbols: symbols.map((s) => s.toUpperCase()).join(',') },
  });
  for (const sym of symbols) {
    const rate = data?.rates?.[sym.toUpperCase()];
    if (rate) out.set(sym, { price: 1 / rate });
  }
  return out;
}

/**
 * Fetch live prices for every holding, keyed by lowercase symbol.
 * `knownIds` lets callers pass symbol→CoinGecko-id pairs already known from
 * the cached top-100 list so those never need a /search round-trip.
 */
export async function fetchLivePrices(
  holdings: PortfolioHolding[],
  knownIds: Map<string, string> = new Map(),
): Promise<Map<string, LivePrice>> {
  if (!isSupabaseConfigured() || !holdings.length) return new Map();

  const uniq = (type: string) =>
    [...new Set(holdings.filter((h) => h.asset_type === type).map((h) => h.symbol.toLowerCase()))];

  const [crypto, stocks, metals] = await Promise.all([
    fetchCryptoPrices(uniq('crypto'), knownIds),
    fetchStockPrices(uniq('stock')),
    fetchMetalPrices(uniq('metal')),
  ]);

  return new Map([...crypto, ...stocks, ...metals]);
}

/** Merge live prices into holdings (live > cached top-100 > stored > avg cost). */
export function applyLivePrices(
  holdings: PortfolioHolding[],
  live: Map<string, LivePrice> | undefined,
  cached?: Map<string, LivePrice>,
): PortfolioHolding[] {
  return holdings.map((h) => {
    const sym = h.symbol.toLowerCase();
    const p = live?.get(sym) ?? cached?.get(sym);
    if (!p) return h;
    return {
      ...h,
      current_price: p.price,
      price_change_percentage_24h: p.change24h ?? h.price_change_percentage_24h ?? 0,
    };
  });
}
