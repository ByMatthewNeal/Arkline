import { localDateISO } from '@/lib/utils/format';
import type { TradeSignal } from '@/lib/api/signals';

/**
 * Signal performance analytics — pure functions over closed signals,
 * mirroring the iOS Trade Signals → Performance tab math.
 * "Return" figures are spot (1x) per-signal moves (outcome_pct).
 */

export interface PerformanceSummary {
  total: number;
  wins: number;
  partials: number;
  losses: number;
  winRate: number;            // wins / total, 0-100
  avgWin: number;             // avg outcome_pct of wins
  avgLoss: number;            // avg outcome_pct of losses (negative)
  profitFactor: number;       // gross gains / gross losses
  streak: number;             // current run: +N consecutive wins, -N consecutive losses
  avgDurationHours: number | null;
  compoundedReturn: number;   // % compounded following every signal at equal size
  cumulativeCurve: { date: string; value: number }[]; // compounded equity curve, oldest→newest
}

export function computeSummary(signals: TradeSignal[]): PerformanceSummary {
  const closed = signals.filter((s) => s.outcome != null);
  const wins = closed.filter((s) => s.outcome === 'win');
  const partials = closed.filter((s) => s.outcome === 'partial');
  const losses = closed.filter((s) => s.outcome === 'loss');

  const pct = (s: TradeSignal) => s.outcome_pct ?? 0;
  const avg = (arr: TradeSignal[]) => (arr.length ? arr.reduce((a, s) => a + pct(s), 0) / arr.length : 0);

  const gains = closed.filter((s) => pct(s) > 0).reduce((a, s) => a + pct(s), 0);
  const lossSum = Math.abs(closed.filter((s) => pct(s) < 0).reduce((a, s) => a + pct(s), 0));

  // Current streak — walk newest→oldest while the win/loss sign holds.
  let streak = 0;
  for (const s of closed) {
    const won = s.outcome === 'win';
    if (streak === 0) streak = won ? 1 : -1;
    else if (won && streak > 0) streak++;
    else if (!won && streak < 0) streak--;
    else break;
  }

  const durations = closed.map((s) => s.duration_hours).filter((d): d is number => d != null);

  // Compounded equity curve, oldest → newest.
  const chrono = [...closed].reverse();
  let equity = 1;
  const cumulativeCurve = chrono.map((s) => {
    equity *= 1 + pct(s) / 100;
    return { date: s.closed_at ?? s.generated_at, value: (equity - 1) * 100 };
  });

  return {
    total: closed.length,
    wins: wins.length,
    partials: partials.length,
    losses: losses.length,
    winRate: closed.length ? (wins.length / closed.length) * 100 : 0,
    avgWin: avg(wins),
    avgLoss: avg(losses),
    profitFactor: lossSum > 0 ? gains / lossSum : gains > 0 ? Infinity : 0,
    streak,
    avgDurationHours: durations.length ? durations.reduce((a, b) => a + b, 0) / durations.length : null,
    compoundedReturn: (equity - 1) * 100,
    cumulativeCurve,
  };
}

export interface DirectionStats {
  trades: number;
  winRate: number;
  avgPnl: number;
}

export function byDirection(signals: TradeSignal[], isLongFn: (t: TradeSignal['signal_type']) => boolean): { long: DirectionStats; short: DirectionStats } {
  const stat = (arr: TradeSignal[]): DirectionStats => ({
    trades: arr.length,
    winRate: arr.length ? (arr.filter((s) => s.outcome === 'win').length / arr.length) * 100 : 0,
    avgPnl: arr.length ? arr.reduce((a, s) => a + (s.outcome_pct ?? 0), 0) / arr.length : 0,
  });
  const closed = signals.filter((s) => s.outcome != null);
  return {
    long: stat(closed.filter((s) => isLongFn(s.signal_type))),
    short: stat(closed.filter((s) => !isLongFn(s.signal_type))),
  };
}

export interface AssetStats {
  asset: string;
  trades: number;
  winRate: number;
  avgPnl: number;
}

export function byAsset(signals: TradeSignal[], top = 6): AssetStats[] {
  const closed = signals.filter((s) => s.outcome != null);
  const groups = new Map<string, TradeSignal[]>();
  for (const s of closed) {
    const key = s.asset.toUpperCase();
    const arr = groups.get(key);
    if (arr) arr.push(s);
    else groups.set(key, [s]);
  }
  return Array.from(groups.entries())
    .map(([asset, arr]) => ({
      asset,
      trades: arr.length,
      winRate: (arr.filter((s) => s.outcome === 'win').length / arr.length) * 100,
      avgPnl: arr.reduce((a, s) => a + (s.outcome_pct ?? 0), 0) / arr.length,
    }))
    .sort((a, b) => b.trades - a.trades)
    .slice(0, top);
}

export interface DayBucket {
  date: string;        // local YYYY-MM-DD
  avgPnl: number;
  trades: number;
}

/** Daily average P&L per trade — feeds the calendar heat view. */
export function dailyBuckets(signals: TradeSignal[]): Map<string, DayBucket> {
  const closed = signals.filter((s) => s.outcome != null && s.closed_at);
  const map = new Map<string, { sum: number; n: number }>();
  for (const s of closed) {
    const day = localDateISO(new Date(s.closed_at!));
    const cur = map.get(day) ?? { sum: 0, n: 0 };
    cur.sum += s.outcome_pct ?? 0;
    cur.n += 1;
    map.set(day, cur);
  }
  const out = new Map<string, DayBucket>();
  for (const [date, { sum, n }] of map) out.set(date, { date, avgPnl: sum / n, trades: n });
  return out;
}

export interface NotableTrades {
  best: TradeSignal | null;
  worst: TradeSignal | null;
}

export function notableTrades(signals: TradeSignal[]): NotableTrades {
  const closed = signals.filter((s) => s.outcome != null && s.outcome_pct != null);
  if (!closed.length) return { best: null, worst: null };
  const sorted = [...closed].sort((a, b) => (b.outcome_pct ?? 0) - (a.outcome_pct ?? 0));
  return { best: sorted[0], worst: sorted[sorted.length - 1] };
}
