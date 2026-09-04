'use client';

import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip } from 'recharts';
import { Eye, EyeOff } from 'lucide-react';
import { DetailDrawer, Skeleton } from '@/components/ui';
import { CoinIcon } from '@/components/dashboard/shared/coin-icon';
import { fetchHoldingHistory } from '@/lib/api/portfolio';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';
import type { PortfolioHolding } from '@/types';

// Same global privacy flag as the home hero, so hiding your balance anywhere
// hides it here too (and lets you screenshot an asset without exposing size).
const HIDE_BALANCE_KEY = 'arkline-hide-balance';

const PERIODS = ['1D', '1W', '1M', 'YTD', '1Y', 'ALL'] as const;
type Period = (typeof PERIODS)[number];

/** Calendar days for a range; YTD is computed from Jan 1. */
function daysForPeriod(period: Period): number {
  switch (period) {
    case '1D': return 1;
    case '1W': return 7;
    case '1M': return 30;
    case 'YTD': {
      const now = new Date();
      const start = new Date(now.getFullYear(), 0, 1);
      return Math.max(1, Math.round((now.getTime() - start.getTime()) / 86_400_000));
    }
    case '1Y': return 365;
    case 'ALL': return 100_000;
  }
}

const fmtDay = (d: string) =>
  new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

interface Props {
  holding: PortfolioHolding | null;
  knownIds?: Map<string, string>;
  onClose: () => void;
}

export function HoldingDetailDrawer({ holding, knownIds, onClose }: Props) {
  const [period, setPeriod] = useState<Period>('1M');
  // Seed from the shared privacy flag once; toggling persists back to it.
  const [hidden, setHidden] = useState<boolean>(() => {
    if (typeof window === 'undefined') return false;
    try { return localStorage.getItem(HIDE_BALANCE_KEY) === '1'; } catch { return false; }
  });

  const toggleHidden = () =>
    setHidden((v) => {
      try { localStorage.setItem(HIDE_BALANCE_KEY, v ? '0' : '1'); } catch { /* ignore */ }
      return !v;
    });

  // History for the selected range, cached per holding+period.
  const { data: series = [], isLoading: loading } = useQuery({
    queryKey: ['holding-history', holding?.id, period],
    queryFn: () => fetchHoldingHistory(holding!, daysForPeriod(period), knownIds ?? new Map()),
    enabled: !!holding,
    staleTime: 60_000,
  });

  const value = holding ? (holding.current_price ?? 0) * holding.quantity : 0;
  const cost = holding ? (holding.average_buy_price ?? 0) * holding.quantity : 0;
  const pnl = value - cost;
  const returnPct = cost > 0 ? (pnl / cost) * 100 : 0;
  const up = pnl >= 0;
  const change24h = holding?.price_change_percentage_24h ?? 0;

  // % change across the selected range (first vs last point).
  const rangePct = useMemo(() => {
    if (series.length < 2) return null;
    const first = series[0].value;
    const last = series[series.length - 1].value;
    if (!(first > 0)) return null;
    return ((last - first) / first) * 100;
  }, [series]);
  const rangeUp = (rangePct ?? 0) >= 0;
  const curveColor = rangeUp ? 'var(--ark-success)' : 'var(--ark-error)';

  // Blur (not char-mask) matches the home hero's privacy style.
  const blur = hidden ? 'blur-md select-none' : '';

  return (
    <DetailDrawer open={!!holding} onClose={onClose} title={holding ? holding.symbol.toUpperCase() : ''}>
      {holding && (
        <div className="space-y-5">
          {/* Header */}
          <div className="flex items-center gap-3">
            <CoinIcon symbol={holding.symbol} size="lg" className="h-11 w-11" />
            <div className="min-w-0 flex-1">
              <p className="truncate text-lg font-bold text-ark-text">{holding.name}</p>
              <p className="text-xs text-ark-text-tertiary">{holding.symbol.toUpperCase()}</p>
            </div>
            <button
              onClick={toggleHidden}
              title={hidden ? 'Show values' : 'Hide values'}
              className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border border-ark-divider text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary hover:text-ark-text"
            >
              {hidden ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
            </button>
          </div>

          {/* Value + stats */}
          <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-5">
            <p className="text-[11px] uppercase tracking-wider text-ark-text-tertiary">Current Value</p>
            <p className={cn('fig mt-1 text-3xl font-bold text-ark-text', blur)}>{formatCurrency(value)}</p>

            <div className="mt-4 grid grid-cols-3 gap-3">
              <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-3">
                <p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">Quantity</p>
                <p className={cn('fig mt-0.5 text-sm font-bold text-ark-text', blur)}>{holding.quantity}</p>
              </div>
              <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-3">
                <p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">Avg Price</p>
                <p className="fig mt-0.5 text-sm font-bold text-ark-text">{formatCurrency(holding.average_buy_price ?? 0)}</p>
              </div>
              <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-3">
                <p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">Current Price</p>
                <p className="fig mt-0.5 text-sm font-bold text-ark-text">{formatCurrency(holding.current_price ?? 0)}</p>
              </div>
            </div>

            <div className="mt-4 flex items-center justify-between border-t border-ark-divider pt-4">
              <div>
                <p className="text-[11px] uppercase tracking-wider text-ark-text-tertiary">Profit / Loss</p>
                <p className={cn('fig mt-0.5 text-lg font-bold', up ? 'text-ark-success' : 'text-ark-error', blur)}>
                  {formatCurrency(pnl)}
                </p>
              </div>
              <div className="text-right">
                <p className="text-[11px] uppercase tracking-wider text-ark-text-tertiary">Return</p>
                <p className={cn('fig mt-0.5 text-lg font-bold', up ? 'text-ark-success' : 'text-ark-error')}>
                  {formatPercent(returnPct)}
                </p>
              </div>
            </div>

            <div className="mt-3 flex items-center justify-between border-t border-ark-divider pt-3">
              <span className="text-xs text-ark-text-secondary">24h Change</span>
              <span className={cn('fig text-sm font-semibold', change24h >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                {formatPercent(change24h)}
              </span>
            </div>
          </div>

          {/* Performance */}
          <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
            <div className="mb-3 flex items-center justify-between">
              <h3 className="text-sm font-semibold text-ark-text">Performance</h3>
              {rangePct != null && (
                <span className={cn('fig text-sm font-bold', rangeUp ? 'text-ark-success' : 'text-ark-error')}>
                  {formatPercent(rangePct)} <span className="font-medium text-ark-text-tertiary">{period}</span>
                </span>
              )}
            </div>

            <div className="mb-3 flex justify-center">
              <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
                {PERIODS.map((p) => (
                  <button
                    key={p}
                    onClick={() => setPeriod(p)}
                    className={cn(
                      'rounded-full px-3 py-1 text-xs font-semibold transition-colors',
                      period === p ? 'bg-ark-info text-white' : 'text-ark-text-tertiary hover:text-ark-text',
                    )}
                  >
                    {p}
                  </button>
                ))}
              </div>
            </div>

            {loading ? (
              <Skeleton className="h-56 w-full rounded-xl" />
            ) : series.length > 1 ? (
              <div className="h-56 w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={series} margin={{ top: 8, right: 8, bottom: 0, left: 8 }}>
                    <defs>
                      <linearGradient id="holding-curve" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor={curveColor} stopOpacity={0.22} />
                        <stop offset="100%" stopColor={curveColor} stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <XAxis
                      dataKey="date"
                      tickLine={false}
                      axisLine={false}
                      ticks={series.length ? [series[0].date, series[series.length - 1].date] : []}
                      tickFormatter={fmtDay}
                      tick={{ fontSize: 10, fill: 'var(--ark-text-disabled)' }}
                      interval="preserveStartEnd"
                    />
                    <YAxis domain={['dataMin', 'dataMax']} hide />
                    <Tooltip
                      contentStyle={{ background: 'var(--ark-card)', border: '1px solid var(--ark-divider)', borderRadius: 8, fontSize: 12 }}
                      labelFormatter={(l) => fmtDay(String(l))}
                      formatter={(v) => [formatCurrency(Number(v)), 'Price']}
                    />
                    <Area type="monotone" dataKey="value" stroke={curveColor} strokeWidth={2} fill="url(#holding-curve)" dot={false} />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            ) : (
              <p className="py-10 text-center text-sm text-ark-text-tertiary">No price history available.</p>
            )}
          </div>
        </div>
      )}
    </DetailDrawer>
  );
}
