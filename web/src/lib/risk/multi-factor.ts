/**
 * BTC Multi-Factor Risk model — a 1:1 port of the iOS RiskCalculation
 * service (`RiskFactorNormalizer` + `RiskFactorWeights` + weight
 * renormalization). Keep formulas in lockstep with
 * ArkLine/Data/Services/RiskCalculation/RiskFactorData.swift.
 */

export interface FactorResult {
  key: string;
  name: string;
  weight: number;        // renormalized weight (0-1)
  value: number | null;  // normalized risk 0-1, null = unavailable
  raw: string;           // raw-value sub-label, e.g. "57.8" / "Below 200 SMA"
}

export interface MultiFactorResult {
  composite: number;           // 0-1
  factors: FactorResult[];
  availableCount: number;
  totalCount: number;
}

export const DEFAULT_WEIGHTS = {
  logRegression: 0.33,
  rsi: 0.11,
  smaPosition: 0.11,
  bullMarketBands: 0.10,
  fundingRate: 0.10,
  fearGreed: 0.10,
  macroRisk: 0.08,
  oilRisk: 0.07,
} as const;

/* ── Normalizers (formulas copied from iOS) ── */

/** RSI 30 → 0.0, RSI 70 → 1.0 (linear, clamped). */
export function normalizeRSI(rsi: number): number {
  return clamp((rsi - 30) / 40);
}

/** Price vs 200-day SMA: stepped gradient (far above 0.2 … far below 0.8). */
export function normalizeSMAPosition(price: number, sma200: number): number {
  if (sma200 <= 0) return 0.5;
  const pct = (price - sma200) / sma200;
  if (pct > 0.20) return 0.2;
  if (pct > 0.10) return 0.3;
  if (pct > 0) return 0.4;
  if (pct > -0.10) return 0.6;
  if (pct > -0.20) return 0.7;
  return 0.8;
}

/** Funding [-0.001, +0.001] → [0, 1]; positive funding = leveraged longs = risk. */
export function normalizeFundingRate(rate: number): number {
  return clamp((rate + 0.001) / 0.002);
}

/** F&G 0-100 → 0-1 directly (greed = risk). */
export function normalizeFearGreed(fg: number): number {
  return clamp(fg / 100);
}

/** VIX: moderate inverse — VIX 10 ≈ 0.7 (complacency), VIX 40 ≈ 0.3 (fear = opportunity). */
export function normalizeVIX(vix: number): number {
  const normalized = (40 - vix) / 30;
  return clamp(0.3 + normalized * 0.4);
}

/** DXY 90 → 0.0, 110 → 1.0 (strong dollar = crypto headwind). */
export function normalizeDXY(dxy: number): number {
  return clamp((dxy - 90) / 20);
}

/** Macro = average of available VIX/DXY normalizations. */
export function normalizeMacroRisk(vix: number | null, dxy: number | null): number | null {
  const v = vix != null ? normalizeVIX(vix) : null;
  const d = dxy != null ? normalizeDXY(dxy) : null;
  if (v != null && d != null) return (v + d) / 2;
  return v ?? d;
}

/** WTI stepped: <$60 → 0.15 … >$100 → 0.90 (inflation pressure). */
export function normalizeOilRisk(oil: number): number {
  if (oil < 60) return 0.15;
  if (oil < 70) return 0.25;
  if (oil < 80) return 0.40;
  if (oil < 90) return 0.55;
  if (oil < 100) return 0.75;
  return 0.90;
}

/** Bull Market Support Bands (20W SMA + 21W EMA) position with gradient. */
export function normalizeBullMarketBands(price: number, sma20w: number, ema21w: number): number {
  const upper = Math.max(sma20w, ema21w);
  const lower = Math.min(sma20w, ema21w);
  const avg = (sma20w + ema21w) / 2;
  const pct = avg > 0 ? (price - avg) / avg : 0;

  if (price > upper) {
    if (pct > 0.20) return 0.1;
    if (pct > 0.10) return 0.2;
    return 0.3;
  }
  if (price >= lower) return 0.5;
  if (pct < -0.20) return 0.9;
  if (pct < -0.10) return 0.8;
  return 0.7;
}

/* ── Composite (weighted avg, unavailable weights redistributed) ── */

export function computeComposite(
  factors: Omit<FactorResult, 'weight'>[] & { length: number },
  weights: number[],
): MultiFactorResult {
  const availableWeight = factors.reduce((s, f, i) => s + (f.value != null ? weights[i] : 0), 0);
  const scale = availableWeight > 0 ? 1 / availableWeight : 0;

  const withWeights: FactorResult[] = factors.map((f, i) => ({
    ...f,
    weight: f.value != null ? weights[i] * scale : weights[i],
  }));

  const composite = withWeights.reduce(
    (s, f) => s + (f.value != null ? f.value * f.weight : 0),
    0,
  );

  return {
    composite: clamp(composite),
    factors: withWeights,
    availableCount: factors.filter((f) => f.value != null).length,
    totalCount: factors.length,
  };
}

/* ── Risk bands (iOS Risk Level Guide, copy matched) ── */

export interface RiskBandInfo {
  label: string;
  range: string;
  color: string;
  description: string;
}

export const RISK_BANDS: RiskBandInfo[] = [
  { label: 'Very Low Risk', range: '0.00 – 0.20', color: 'var(--ark-info)', description: 'Deep value range, historically excellent accumulation zone' },
  { label: 'Low Risk', range: '0.20 – 0.40', color: 'var(--ark-success)', description: 'Still favorable accumulation, historically suited for long-term holders' },
  { label: 'Neutral', range: '0.40 – 0.55', color: 'var(--ark-warning)', description: 'Mid-cycle territory, neither strong buy nor sell' },
  { label: 'Elevated Risk', range: '0.55 – 0.70', color: '#F97316', description: 'Late-cycle behavior, higher probability of corrections' },
  { label: 'High Risk', range: '0.70 – 0.90', color: 'var(--ark-error)', description: 'Historically blow-off-top region, major cycle tops occur here' },
  { label: 'Extreme Risk', range: '0.90 – 1.00', color: '#991B1B', description: 'Historically where macro tops happen, smart-money distribution' },
];

export function riskBandFor(value: number): RiskBandInfo {
  if (value < 0.20) return RISK_BANDS[0];
  if (value < 0.40) return RISK_BANDS[1];
  if (value < 0.55) return RISK_BANDS[2];
  if (value < 0.70) return RISK_BANDS[3];
  if (value < 0.90) return RISK_BANDS[4];
  return RISK_BANDS[5];
}

function clamp(v: number): number {
  return Math.max(0, Math.min(1, v));
}
