export interface MacroIndicator {
  name: string;
  value: number;
  change: number;
  change_percentage: number;
  sparkline: number[];
  z_score?: number;
  regime?: string;
}

export type MacroIndicatorType = 'vix' | 'dxy' | 'm2' | 'wti';

/* ── Macro Dashboard (regime + 4 key indicators) ── */
export interface MacroDashIndicator {
  key: 'vix' | 'dxy' | 'netLiquidity' | 'cbLiquidity';
  label: string;
  value: number;
  formattedValue: string;
  changePct?: number;
  signal: 'bullish' | 'bearish' | 'neutral' | 'expanding' | 'contracting';
  signalLabel: string;
}

export interface MacroDashboardData {
  regimeLabel: string;
  regimeDescription: string;
  regimeBullish: boolean;
  asOf: string;
  indicators: MacroDashIndicator[];
  insight: string;
}

/* ── Per-asset Core Technical detail ── */
export interface TechnicalTimeframeTrend {
  timeframe: string;          // 1D / 1W / 1M
  label: string;              // Strong Down, Up, etc.
  direction: 'up' | 'down' | 'flat';
  strength: number;           // 0-3 bars
}
export interface AssetTechnicalData {
  symbol: string;             // BTC / ETH / SOL
  name: string;               // Bitcoin
  price: number;
  changePct24h: number;
  insight: string;
  trendScore: number;         // 0-100
  trendLabel: string;         // Strong Down
  valuationScore: number;     // 0-100
  valuationLabel: string;     // Oversold
  shortTerm: { label: string; direction: 'up' | 'down' | 'flat' };
  longTerm: { label: string; direction: 'up' | 'down' | 'flat' };
  rsi: number;
  rsiLabel: string;
  rsiNote: string;
  timeframes: TechnicalTimeframeTrend[];
  bmsb: {
    status: string;           // Below Support / Above Support
    above: boolean;
    sma20w: number;
    ema21w: number;
    sma20wPct: number;
    ema21wPct: number;
  };
  keyLevels: { label: string; value: number; above: boolean }[];   // 21/50/200 MA
  deathCross: boolean;
  goldenCross: boolean;
}

/* ── Market Breadth detail (history + signals) ── */
export interface MarketBreadthPoint {
  date: string;
  breadth: number;
  ema12: number;
  ema21: number;
  btc: number;
  crossover?: string | null;
}
export interface MarketBreadthDetailData {
  breadthPct: number;
  trend: string;
  ema12: number;
  ema21: number;
  trendingTokens: number;
  totalTokens: number;
  btcPrice: number;
  asOf: string;
  recentSignals: { type: 'bullish' | 'bearish'; date: string }[];
  history: MarketBreadthPoint[];
}

/* ── Fear & Greed detail ── */
export interface FearGreedDetailData {
  value: number;
  classification: string;
  yesterday?: number;
  lastWeek?: number;
  lastMonth?: number;
  history: { date: string; value: number }[];
}

export interface VIXData {
  date: string;
  value: number;
}

export interface DXYData {
  date: string;
  value: number;
}

export interface GlobalLiquidityData {
  date: string;
  total_m2: number;
  us_m2?: number;
}

export interface RiskHistoryPoint {
  date: string;
  risk_level: number;
  price: number;
  fair_value: number;
  deviation: number;
}

export type RiskFactorType =
  | 'Log Regression'
  | 'RSI'
  | 'SMA Position'
  | 'Bull Market Bands'
  | 'Funding Rate'
  | 'Fear & Greed'
  | 'Macro Risk';

export interface RiskFactor {
  type: RiskFactorType;
  raw_value?: number;
  normalized_value?: number;
  weight: number;
}

export interface MacroZScoreData {
  indicator: MacroIndicatorType;
  current_value: number;
  z_score: number;
  mean: number;
  std_dev: number;
  is_extreme: boolean;
  direction: 'above' | 'below';
}

/* ── ArkLine Score ── */

export type ArkLineScoreLevel = 'Low Risk' | 'Moderate' | 'Elevated' | 'High Risk';

export interface ArkLineScoreComponent {
  name: string;
  value: number;       // 0-100
  weight: number;      // percentage weight
  icon: string;        // lucide icon name
  signal?: string;     // directional label, e.g. "Bullish", "Extremely Bearish"
}

export interface ArkLineScoreData {
  score: number;       // 0-100
  level: ArkLineScoreLevel;
  tier: string;        // directional label from DB, e.g. "Bearish"
  recommendation: string; // description text
  btcPrice?: number;
  sp500Price?: number;
  nasdaqPrice?: number;
  components: ArkLineScoreComponent[];
}

export interface ArkLineScoreHistoryPoint {
  date: string;        // YYYY-MM-DD
  score: number;
  tier: string;
  btcPrice?: number;
  sp500Price?: number;
  nasdaqPrice?: number;
}

/* ── BTC Supply in Profit ── */

export type SupplyInProfitStatus = 'Buy Zone' | 'Normal' | 'Elevated' | 'Overheated';

export interface SupplyInProfitData {
  percentage: number;
  status: SupplyInProfitStatus;
  date: string;
  history: { date: string; value: number }[];
}

/* ── Asset Risk Level (detailed) ── */

export type AssetRiskCategory = 'Low' | 'Moderate' | 'Elevated' | 'Critical';

export interface AssetRiskLevelData {
  symbol: string;
  name: string;
  risk_value: number;           // 0.000 - 1.000
  level: AssetRiskCategory;
  days_at_level: number;
  seven_day_avg: number;
  factors: RiskFactor[];
}
