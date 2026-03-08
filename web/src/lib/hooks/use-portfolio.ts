'use client';

import { useQuery } from '@tanstack/react-query';
import { useAuth } from './use-auth';
import {
  fetchPortfolios,
  fetchHoldings,
  fetchTransactions,
  fetchPortfolioHistory,
} from '@/lib/api/portfolio';

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
