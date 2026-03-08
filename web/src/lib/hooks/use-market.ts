'use client';

import { useQuery } from '@tanstack/react-query';
import {
  fetchCryptoAssets,
  fetchGlobalMarketData,
  fetchFearGreedIndex,
  fetchNews,
  fetchEconomicEvents,
  fetchCryptoPositioning,
  fetchTraditionalMarkets,
  fetchMarketSentiment,
  fetchAltcoinScanner,
} from '@/lib/api/market';
import {
  fetchMacroIndicators,
  fetchRiskHistory,
  fetchMarketBriefing,
  fetchSentimentData,
  fetchRegimeData,
  fetchArkLineScore,
  fetchSupplyInProfit,
  fetchAssetRiskLevels,
} from '@/lib/api/macro';

export function useCryptoAssets(page = 1) {
  return useQuery({
    queryKey: ['crypto-assets', page],
    queryFn: () => fetchCryptoAssets(page),
    staleTime: 60_000,
    refetchInterval: 60_000,
  });
}

export function useGlobalMarketData() {
  return useQuery({
    queryKey: ['global-market'],
    queryFn: fetchGlobalMarketData,
    staleTime: 60_000,
  });
}

export function useFearGreedIndex() {
  return useQuery({
    queryKey: ['fear-greed'],
    queryFn: fetchFearGreedIndex,
    staleTime: 300_000,
  });
}

export function useMacroIndicators() {
  return useQuery({
    queryKey: ['macro-indicators'],
    queryFn: fetchMacroIndicators,
    staleTime: 300_000,
  });
}

export function useRiskHistory(days = 365) {
  return useQuery({
    queryKey: ['risk-history', days],
    queryFn: () => fetchRiskHistory(days),
    staleTime: 300_000,
  });
}

export function useMarketBriefing() {
  return useQuery({
    queryKey: ['market-briefing'],
    queryFn: fetchMarketBriefing,
    staleTime: 900_000,
  });
}

export function useSentimentData() {
  return useQuery({
    queryKey: ['sentiment'],
    queryFn: fetchSentimentData,
    staleTime: 300_000,
  });
}

export function useRegimeData() {
  return useQuery({
    queryKey: ['regime'],
    queryFn: fetchRegimeData,
    staleTime: 300_000,
  });
}

export function useNews(limit = 20) {
  return useQuery({
    queryKey: ['news', limit],
    queryFn: () => fetchNews(limit),
    staleTime: 900_000,
  });
}

export function useEconomicEvents() {
  return useQuery({
    queryKey: ['economic-events'],
    queryFn: fetchEconomicEvents,
    staleTime: 900_000,
  });
}

export function useCryptoPositioning() {
  return useQuery({
    queryKey: ['crypto-positioning'],
    queryFn: fetchCryptoPositioning,
    staleTime: 300_000,
  });
}

export function useTraditionalMarkets() {
  return useQuery({
    queryKey: ['traditional-markets'],
    queryFn: fetchTraditionalMarkets,
    staleTime: 60_000,
  });
}

export function useMarketSentiment() {
  return useQuery({
    queryKey: ['market-sentiment'],
    queryFn: fetchMarketSentiment,
    staleTime: 300_000,
  });
}

export function useAltcoinScanner() {
  return useQuery({
    queryKey: ['altcoin-scanner'],
    queryFn: fetchAltcoinScanner,
    staleTime: 300_000,
  });
}

export function useArkLineScore() {
  return useQuery({
    queryKey: ['arkline-score'],
    queryFn: fetchArkLineScore,
    staleTime: 60_000,
  });
}

export function useSupplyInProfit() {
  return useQuery({
    queryKey: ['supply-in-profit'],
    queryFn: fetchSupplyInProfit,
    staleTime: 300_000,
  });
}

export function useAssetRiskLevels() {
  return useQuery({
    queryKey: ['asset-risk-levels'],
    queryFn: fetchAssetRiskLevels,
    staleTime: 60_000,
  });
}
