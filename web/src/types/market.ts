export interface CryptoAsset {
  id: string;
  symbol: string;
  name: string;
  current_price: number;
  price_change_24h: number;
  price_change_percentage_24h: number;
  image?: string;
  market_cap?: number;
  market_cap_rank?: number;
  total_volume?: number;
  high_24h?: number;
  low_24h?: number;
  circulating_supply?: number;
  total_supply?: number;
  max_supply?: number;
  ath?: number;
  ath_change_percentage?: number;
  sparkline_in_7d?: { price?: number[] };
  last_updated?: string;
}

export interface StockAsset {
  id: string;
  symbol: string;
  name: string;
  current_price: number;
  price_change_24h: number;
  price_change_percentage_24h: number;
  icon_url?: string;
  open?: number;
  high?: number;
  low?: number;
  previous_close?: number;
  volume?: number;
  market_cap?: number;
  pe_ratio?: number;
}

export interface MetalAsset {
  id: string;
  symbol: string;
  name: string;
  current_price: number;
  price_change_24h: number;
  price_change_percentage_24h: number;
  unit: string;
  currency: string;
}

export interface FearGreedIndex {
  value: number;
  value_classification: string;
  timestamp: string;
}

export interface GlobalMarketData {
  total_market_cap: number;
  total_volume: number;
  btc_dominance: number;
  eth_dominance: number;
  market_cap_change_percentage_24h: number;
}

export interface NewsItem {
  id: string;
  title: string;
  description?: string;
  url: string;
  source: string;
  image_url?: string;
  published_at: string;
  categories?: string[];
}

export interface EconomicEvent {
  id: string;
  title: string;
  date: string;
  time?: string;
  impact: 'low' | 'medium' | 'high';
  country: string;
  actual?: string;
  forecast?: string;
  previous?: string;
}

export interface FedWatchData {
  meeting_date: string;
  cut_probability: number;
  hold_probability: number;
  hike_probability: number;
}

export type AssetCategory = 'crypto' | 'stock' | 'metal' | 'real_estate';

/* ── Crypto Positioning ── */

export type PositioningSignal = 'bullish' | 'neutral' | 'bearish';
export type RegimeQuadrant = 'risk-on-disinflation' | 'risk-on-inflation' | 'risk-off-inflation' | 'risk-off-disinflation';

export interface AssetPositioning {
  symbol: string;
  name: string;
  signal: PositioningSignal;
  regime_fit: number; // 0-1
  target_allocation: number; // 0, 25, 50, 100
  is_dca_opportunity: boolean;
  risk_level?: number; // 0-1
  interpretation: string;
}

export type MacroInputSignal = 'Bullish' | 'Neutral' | 'Bearish';

export interface MacroInput {
  id: string;
  name: string;
  value: number;
  formatted_value: string;
  signal: MacroInputSignal;
  icon: string; // lucide icon name
}

export interface CryptoPositioningData {
  regime: RegimeQuadrant;
  regime_label: string;
  regime_description: string;
  growth_score: number; // 0-100
  inflation_score: number; // 0-100
  signal_counts: { bullish: number; neutral: number; bearish: number };
  extreme_move: boolean;
  extreme_asset?: string;
  macro_inputs: MacroInput[];
  assets: AssetPositioning[];
}

/* ── Traditional Markets ── */

export type TrendSignal = 'Bullish' | 'Neutral' | 'Bearish';

export interface TraditionalMarketAsset {
  id: string;
  symbol: string;
  name: string;
  current_price: number;
  price_change_24h: number;
  price_change_percentage_24h: number;
  trend_signal: TrendSignal;
  sparkline: number[];
}

/* ── Market Sentiment ── */

export type SentimentRegimeType = 'Panic' | 'FOMO' | 'Apathy' | 'Complacency';

export interface SentimentRegimePoint {
  date: string;
  emotion_score: number; // 0-100 (Fear → Greed)
  engagement_score: number; // 0-100 (Low → High vol)
  regime: SentimentRegimeType;
}

export interface AssetRiskLevel {
  symbol: string;
  name: string;
  risk_level: number; // 0-1
  risk_category: string;
  days_at_level: number;
}

export interface FundingRateData {
  rate: number; // raw rate e.g. -0.0023
  sentiment: string;
  annualized_rate: number;
  exchange: string;
}

export interface RetailSentimentData {
  coinbase_rank: number | null; // null = >200
  coinbase_rank_change: number;
  btc_search_index: number; // 0-100
  btc_search_change: number;
}

export interface MarketSentimentData {
  risk_score: number; // 0-100
  fear_greed: number;
  fear_greed_label: string;
  season: 'bitcoin' | 'altcoin';
  season_index: number; // 0-100 (>75 = altcoin season)
  btc_dominance: number;
  btc_dominance_change: number;
  total_market_cap: number;
  market_cap_change: number;
  market_cap_sparkline: number[];
  sentiment_regime: SentimentRegimeType;
  sentiment_regime_description: string;
  emotion_score: number; // 0-100
  engagement_score: number; // 0-100
  regime_trajectory: SentimentRegimePoint[];
  asset_risk_levels: AssetRiskLevel[];
  funding_rate: FundingRateData;
  retail_sentiment: RetailSentimentData;
}

/* ── Altcoin Scanner ── */

export type ScannerPeriod = '7d' | '30d' | '90d';

export interface AltcoinScannerEntry {
  id: string;
  symbol: string;
  name: string;
  current_price: number;
  market_cap: number;
  return_7d: number;
  return_30d: number;
  return_90d: number;
  vs_btc_7d: number;
  vs_btc_30d: number;
  vs_btc_90d: number;
  image?: string;
}
