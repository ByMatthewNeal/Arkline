'use client';

import { useQuery } from '@tanstack/react-query';
import {
  fetchCryptoAssets,
  fetchGlobalMarketData,
  fetchFearGreedIndex,
  fetchNews,
  fetchEconomicEvents,
  fetchCryptoPositioning,
  fetchMomentumMap,
  fetchTraditionalMarkets,
  fetchMarketSentiment,
  fetchAltcoinScanner,
  fetchMarketBreadth,
  fetchSignalChanges,
  fetchSignalChangeHistory,
  fetchStockRiskLevels,
  fetchTradeSignals,
  fetchRotationSignal,
  fetchModelPortfolioUpdate,
  fetchWeeklyDeck,
  fetchUSFutures,
  fetchPerpPremiumData,
  fetchFedWatchData,
  fetchAssetSnapshots,
} from '@/lib/api/market';
import {
  fetchMacroIndicators,
  fetchRiskHistory,
  fetchMarketBriefing,
  fetchSentimentData,
  fetchRegimeData,
  fetchArkLineScore,
  fetchArkLineScoreHistory,
  fetchSupplyInProfit,
  fetchAssetRiskLevels,
  fetchAssetRiskHistory,
  fetchMacroDashboard,
  fetchAssetTechnical,
  fetchMarketBreadthDetail,
  fetchFearGreedDetail,
  fetchIndicatorHistory,
  fetchRiskLevels,
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

export function useMomentumMap() {
  return useQuery({
    queryKey: ['momentum-map'],
    queryFn: fetchMomentumMap,
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

export function useMarketBreadth() {
  return useQuery({
    queryKey: ['market-breadth'],
    queryFn: fetchMarketBreadth,
    staleTime: 300_000,
  });
}

export function useSignalChanges() {
  return useQuery({
    queryKey: ['signal-changes'],
    queryFn: fetchSignalChanges,
    staleTime: 300_000,
  });
}

export function useSignalChangeHistory() {
  return useQuery({
    queryKey: ['signal-change-history'],
    queryFn: () => fetchSignalChangeHistory(),
    staleTime: 900_000,
  });
}

export function useStockRiskLevels() {
  return useQuery({
    queryKey: ['stock-risk-levels'],
    queryFn: fetchStockRiskLevels,
    staleTime: 300_000,
  });
}

export function useTradeSignals() {
  return useQuery({ queryKey: ['trade-signals'], queryFn: fetchTradeSignals, staleTime: 300_000 });
}

export function useRotationSignal() {
  return useQuery({ queryKey: ['rotation-signal'], queryFn: fetchRotationSignal, staleTime: 300_000 });
}

export function useModelPortfolioUpdate() {
  return useQuery({ queryKey: ['model-portfolio-update'], queryFn: fetchModelPortfolioUpdate, staleTime: 300_000 });
}

export function useWeeklyDeck() {
  return useQuery({ queryKey: ['weekly-deck'], queryFn: fetchWeeklyDeck, staleTime: 300_000 });
}

export function useUSFutures() {
  return useQuery({ queryKey: ['us-futures'], queryFn: fetchUSFutures, staleTime: 120_000 });
}

export function usePerpPremium() {
  return useQuery({ queryKey: ['perp-premium'], queryFn: fetchPerpPremiumData, staleTime: 300_000 });
}

export function useFedWatch() {
  return useQuery({ queryKey: ['fed-watch'], queryFn: fetchFedWatchData, staleTime: 900_000 });
}

export function useArkLineScore() {
  return useQuery({
    queryKey: ['arkline-score'],
    queryFn: fetchArkLineScore,
    staleTime: 60_000,
  });
}

export function useArkLineScoreHistory() {
  return useQuery({
    queryKey: ['arkline-score-history'],
    queryFn: fetchArkLineScoreHistory,
    staleTime: 60_000,
  });
}

export function useMacroDashboard() {
  return useQuery({ queryKey: ['macro-dashboard'], queryFn: fetchMacroDashboard, staleTime: 60_000 });
}

export function useAssetTechnical(symbol: string) {
  return useQuery({ queryKey: ['asset-technical', symbol], queryFn: () => fetchAssetTechnical(symbol), staleTime: 60_000, enabled: !!symbol });
}

export function useMarketBreadthDetail(days = 365) {
  return useQuery({ queryKey: ['market-breadth-detail', days], queryFn: () => fetchMarketBreadthDetail(days), staleTime: 60_000 });
}

export function useFearGreedDetail() {
  return useQuery({ queryKey: ['fear-greed-detail'], queryFn: fetchFearGreedDetail, staleTime: 60_000 });
}

export function useIndicatorHistory(dbKey: string, days: number) {
  return useQuery({ queryKey: ['indicator-history', dbKey, days], queryFn: () => fetchIndicatorHistory(dbKey, days), staleTime: 60_000, enabled: !!dbKey });
}

export function useRiskLevels(kind: 'crypto' | 'stock') {
  return useQuery({ queryKey: ['risk-levels', kind], queryFn: () => fetchRiskLevels(kind), staleTime: 60_000 });
}

export function useAssetSnapshots(coinId: string) {
  return useQuery({ queryKey: ['asset-snapshots', coinId], queryFn: () => fetchAssetSnapshots(coinId), staleTime: 60_000, enabled: !!coinId });
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

export function useAssetRiskHistory(asset: string, days: number) {
  return useQuery({
    queryKey: ['asset-risk-history', asset, days],
    queryFn: () => fetchAssetRiskHistory(asset, days),
    staleTime: 300_000,
  });
}
