'use client';

import { useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

/**
 * Full CoinGecko coin search (beyond the cached top-100) via the `api-proxy`
 * edge function — matches the iOS live search in Top Coins / Add Transaction.
 * Debounced; results carry live USD prices.
 */

export interface CoinSearchResult {
  id: string;
  symbol: string;
  name: string;
  rank: number | null;
  price: number | null;
}

async function searchCoins(query: string): Promise<CoinSearchResult[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = createClient();

  type SearchResponse = { coins?: { id: string; symbol: string; name: string; market_cap_rank?: number | null }[] };
  const { data: searchData, error } = await supabase.functions.invoke('api-proxy', {
    body: { service: 'coingecko', path: '/search', queryItems: { query } },
  });
  if (error) return [];

  const coins = ((searchData as SearchResponse)?.coins ?? [])
    .slice(0, 6)
    .map((c) => ({
      id: c.id,
      symbol: c.symbol,
      name: c.name,
      rank: c.market_cap_rank ?? null,
      price: null as number | null,
    }));
  if (!coins.length) return [];

  // Attach live prices in one batch call.
  type SimplePrice = Record<string, { usd?: number }>;
  const { data: priceData } = await supabase.functions.invoke('api-proxy', {
    body: {
      service: 'coingecko',
      path: '/simple/price',
      queryItems: { ids: coins.map((c) => c.id).join(','), vs_currencies: 'usd' },
    },
  });
  const prices = (priceData as SimplePrice) ?? {};
  return coins.map((c) => ({ ...c, price: prices[c.id]?.usd ?? null }));
}

function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const id = window.setTimeout(() => setDebounced(value), delayMs);
    return () => window.clearTimeout(id);
  }, [value, delayMs]);
  return debounced;
}

export function useCoinSearch(query: string) {
  const debounced = useDebouncedValue(query.trim(), 400);
  return useQuery({
    queryKey: ['coin-search', debounced.toLowerCase()],
    queryFn: () => searchCoins(debounced),
    enabled: debounced.length >= 2,
    staleTime: 300_000,
    refetchInterval: false,
  });
}
