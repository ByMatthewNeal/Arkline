'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAuth } from './use-auth';
import {
  fetchModelPortfolios,
  fetchModelPortfolioNav,
  fetchBenchmarkNav,
  fetchModelPortfolioTrades,
  fetchFollowedModelPortfolio,
  setFollowedModelPortfolio,
} from '@/lib/api/model-portfolios';

export function useModelPortfolios() {
  return useQuery({
    queryKey: ['model-portfolios'],
    queryFn: fetchModelPortfolios,
    staleTime: 3_600_000,
  });
}

export function useModelPortfolioNav(portfolioId: string | undefined, days = 365) {
  return useQuery({
    queryKey: ['model-portfolio-nav', portfolioId, days],
    queryFn: () => fetchModelPortfolioNav(portfolioId!, days),
    enabled: !!portfolioId,
    staleTime: 900_000,
  });
}

export function useBenchmarkNav(days = 365) {
  return useQuery({
    queryKey: ['benchmark-nav', days],
    queryFn: () => fetchBenchmarkNav(days),
    staleTime: 900_000,
  });
}

export function useModelPortfolioTrades(portfolioId: string | undefined) {
  return useQuery({
    queryKey: ['model-portfolio-trades', portfolioId],
    queryFn: () => fetchModelPortfolioTrades(portfolioId!),
    enabled: !!portfolioId,
    staleTime: 900_000,
  });
}

export function useFollowedModelPortfolio() {
  const { profile } = useAuth();
  const profileId = profile?.id;
  return useQuery({
    queryKey: ['followed-model-portfolio', profileId],
    queryFn: () => fetchFollowedModelPortfolio(profileId!),
    enabled: !!profileId,
    staleTime: 300_000,
  });
}

export function useFollowModelPortfolio() {
  const { profile } = useAuth();
  const profileId = profile?.id;
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (strategy: string | null) => setFollowedModelPortfolio(profileId!, strategy),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['followed-model-portfolio', profileId] });
    },
  });
}
