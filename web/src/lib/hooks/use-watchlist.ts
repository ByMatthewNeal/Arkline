'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAuth } from './use-auth';
import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

// Watchlist is stored on profiles.risk_coins as an array of UPPERCASE symbols (e.g. ["BTC","ETH"]).
async function fetchWatchlist(userId: string): Promise<string[]> {
  if (!isSupabaseConfigured()) return [];
  const { data } = await createClient().from('profiles').select('risk_coins').eq('id', userId).single();
  return ((data?.risk_coins as string[] | null) ?? []).map((s) => s.toUpperCase());
}

export function useWatchlist() {
  const { authUser } = useAuth();
  const qc = useQueryClient();
  const uid = authUser?.id;
  const key = ['watchlist', uid];

  const q = useQuery({ queryKey: key, queryFn: () => fetchWatchlist(uid!), enabled: !!uid, staleTime: 60_000 });
  const coins = q.data ?? [];
  const has = (symbol: string) => coins.some((c) => c.toLowerCase() === symbol.toLowerCase());

  const toggle = useMutation({
    mutationFn: async (symbol: string) => {
      if (!uid) return coins;
      const map = new Map(coins.map((c) => [c.toLowerCase(), c]));
      const k = symbol.toLowerCase();
      if (map.has(k)) map.delete(k); else map.set(k, symbol.toUpperCase());
      const next = [...map.values()];
      const { error } = await createClient().from('profiles').update({ risk_coins: next }).eq('id', uid);
      if (error) throw error;
      return next;
    },
    onMutate: async (symbol: string) => {
      await qc.cancelQueries({ queryKey: key });
      const prev = qc.getQueryData<string[]>(key) ?? [];
      const map = new Map(prev.map((c) => [c.toLowerCase(), c]));
      const k = symbol.toLowerCase();
      if (map.has(k)) map.delete(k); else map.set(k, symbol.toUpperCase());
      qc.setQueryData(key, [...map.values()]);
      return { prev };
    },
    onError: (_e, _v, ctx) => { if (ctx?.prev) qc.setQueryData(key, ctx.prev); },
    onSettled: () => qc.invalidateQueries({ queryKey: key }),
  });

  return { coins, has, toggle: (symbol: string) => toggle.mutate(symbol), isLoading: q.isLoading };
}

/* ── Off-list watchlist assets ──
 * The cached market list only covers the top coins, so watchlist symbols
 * outside it (ONDO, RENDER, …) would silently vanish from the Favorites view.
 * Resolve each missing symbol → CoinGecko id via /search, then batch-fetch
 * market data so they render like any other row. */
export interface WatchlistExtra {
  id: string;
  symbol: string;
  name: string;
  image?: string;
  current_price: number;
  price_change_percentage_24h: number | null;
  sparkline_in_7d?: { price?: number[] };
}

async function fetchAssetsBySymbols(symbols: string[]): Promise<WatchlistExtra[]> {
  if (!symbols.length || !isSupabaseConfigured()) return [];
  const supabase = createClient();
  type SearchResponse = { coins?: { id: string; symbol: string; market_cap_rank?: number | null }[] };

  const ids: string[] = [];
  for (const sym of symbols) {
    const { data } = await supabase.functions.invoke('api-proxy', {
      body: { service: 'coingecko', path: '/search', queryItems: { query: sym } },
    });
    const match = (((data as SearchResponse)?.coins) ?? [])
      .filter((c) => c.symbol.toLowerCase() === sym.toLowerCase())
      .sort((a, b) => (a.market_cap_rank ?? 1e9) - (b.market_cap_rank ?? 1e9))[0];
    if (match) ids.push(match.id);
  }
  if (!ids.length) return [];

  const { data: mkts, error } = await supabase.functions.invoke('api-proxy', {
    body: {
      service: 'coingecko',
      path: '/coins/markets',
      queryItems: { vs_currency: 'usd', ids: ids.join(','), sparkline: 'true' },
    },
  });
  if (error || !Array.isArray(mkts)) return [];
  return mkts as WatchlistExtra[];
}

/** Market rows for watchlist symbols missing from the cached top list. */
export function useWatchlistExtras(missingSymbols: string[]) {
  const sorted = [...missingSymbols].map((s) => s.toUpperCase()).sort();
  return useQuery({
    queryKey: ['watchlist-extras', sorted.join(',')],
    queryFn: () => fetchAssetsBySymbols(sorted),
    enabled: sorted.length > 0,
    staleTime: 300_000,
  });
}
