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
}

export interface ArkLineScoreData {
  score: number;       // 0-100
  level: ArkLineScoreLevel;
  components: ArkLineScoreComponent[];
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
