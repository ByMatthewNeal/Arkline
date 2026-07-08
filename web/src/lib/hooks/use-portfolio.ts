'use client';

import { useQuery } from '@tanstack/react-query';
import { useAuth } from './use-auth';
import { useCryptoAssets } from './use-market';
import {
  fetchPortfolios,
  fetchHoldings,
  fetchTransactions,
  fetchPortfolioHistory,
  fetchLivePrices,
  applyLivePrices,
  type LivePrice,
} from '@/lib/api/portfolio';
import type { PortfolioHolding } from '@/types';

export function usePortfolios() {
  const { authUser } = useAuth();
  return useQuery({
    queryKey: ['portfolios', authUser?.id],
    queryFn: () => fetchPortfolios(authUser!.id),
    enabled: !!authUser?.id,
    staleTime: 60_000,
  });
}

export function useHoldings(portfolioId: string | undefined) {
  return useQuery({
    queryKey: ['holdings', portfolioId],
    queryFn: () => fetchHoldings(portfolioId!),
    enabled: !!portfolioId,
    staleTime: 60_000,
  });
}

export function useTransactions(portfolioId: string | undefined) {
  return useQuery({
    queryKey: ['transactions', portfolioId],
    queryFn: () => fetchTransactions(portfolioId!),
    enabled: !!portfolioId,
    staleTime: 60_000,
  });
}

export function usePortfolioHistory(portfolioId: string | undefined, days = 30) {
  return useQuery({
    queryKey: ['portfolio-history', portfolioId, days],
    queryFn: () => fetchPortfolioHistory(portfolioId!, days),
    enabled: !!portfolioId,
    staleTime: 300_000,
  });
}

/**
 * Live prices for a set of holdings (crypto beyond top-100, stocks, metals),
 * refreshed every 60 s to match the iOS portfolio-price timer.
 * Top-100 CoinGecko ids from the cached asset list are passed through so
 * common coins never need a /search round-trip.
 */
export function useLivePrices(holdings: PortfolioHolding[] | undefined) {
  const { data: assets } = useCryptoAssets(1);
  const symbolKey = [...new Set((holdings ?? []).map((h) => `${h.asset_type}:${h.symbol.toLowerCase()}`))]
    .sort()
    .join(',');

  return useQuery({
    queryKey: ['live-prices', symbolKey],
    queryFn: () => {
      const knownIds = new Map<string, string>();
      for (const a of assets ?? []) knownIds.set(a.symbol.toLowerCase(), a.id);
      return fetchLivePrices(holdings!, knownIds);
    },
    enabled: !!holdings && holdings.length > 0,
    staleTime: 60_000,
    refetchInterval: 60_000,
  });
}

/**
 * Holdings with prices merged in: live (60 s) > cached top-100 > stored value.
 * Cached top-100 renders instantly while the live fetch is in flight.
 */
export function usePricedHoldings(portfolioId: string | undefined) {
  const holdingsQuery = useHoldings(portfolioId);
  const { data: assets } = useCryptoAssets(1);
  const liveQuery = useLivePrices(holdingsQuery.data);

  const cached = new Map<string, LivePrice>();
  for (const a of assets ?? []) {
    cached.set(a.symbol.toLowerCase(), {
      price: a.current_price,
      change24h: a.price_change_percentage_24h ?? 0,
    });
  }

  return {
    ...holdingsQuery,
    data: holdingsQuery.data ? applyLivePrices(holdingsQuery.data, liveQuery.data, cached) : holdingsQuery.data,
    livePricesUpdatedAt: liveQuery.dataUpdatedAt,
  };
}
