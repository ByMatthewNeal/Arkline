'use client';

import { TrendingUp, TrendingDown, Wallet, Clock, ArrowUpRight, ArrowDownRight, ChevronDown } from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer, YAxis, Tooltip } from 'recharts';
import { GlassCard, Skeleton } from '@/components/ui';
import { formatCurrency, formatPercent, formatTimestamp } from '@/lib/utils/format';
import { useRiskHistory } from '@/lib/hooks/use-market';
import { useState, useEffect } from 'react';

const periods = ['1H', '1D', '1W', '1M', 'YTD', '1Y', 'ALL'] as const;
type Period = (typeof periods)[number];

function sliceByPeriod(data: { date: string; value: number }[], period: Period) {
  if (period === 'ALL') return data;
  if (period === 'YTD') {
    const yearStart = new Date().getFullYear() + '-01-01';
    return data.filter((d) => d.date >= yearStart);
  }
  const days = period === '1H' ? 1 : period === '1D' ? 1 : period === '1W' ? 7 : period === '1M' ? 30 : 365;
  return data.slice(-days);
}

export function PortfolioHero() {
  const { data: riskData, isLoading } = useRiskHistory(90);
  const [period, setPeriod] = useState<Period>('1M');
  const [now, setNow] = useState('');

  useEffect(() => {
    setNow(formatTimestamp());
  }, []);

  const allData = (riskData ?? []).map((p) => ({
    date: p.date,
    value: p.price,
  }));

  const chartData = sliceByPeriod(allData, period);

  const currentValue = allData[allData.length - 1]?.value ?? 0;
  const previousValue = allData[allData.length - 2]?.value ?? currentValue;
  const periodStart = chartData[0]?.value ?? currentValue;
  const periodHigh = chartData.length > 0 ? Math.max(...chartData.map((d) => d.value)) : currentValue;
  const periodLow = chartData.length > 0 ? Math.min(...chartData.map((d) => d.value)) : currentValue;

  const dayChange = currentValue - previousValue;
  const dayChangePct = previousValue ? (dayChange / previousValue) * 100 : 0;
  const periodChange = currentValue - periodStart;
  const periodChangePct = periodStart ? (periodChange / periodStart) * 100 : 0;
  const isUp = dayChange >= 0;
  const isPeriodUp = periodChange >= 0;

  // How far current value sits within the period range (0-100)
  const rangeSpan = periodHigh - periodLow || 1;
  const rangePct = ((currentValue - periodLow) / rangeSpan) * 100;

  // Market hours check (simplified — US Eastern 9:30-4:00 weekdays)
  const isMarketOpen = (() => {
    const d = new Date();
    const utcHour = d.getUTCHours();
    const utcDay = d.getUTCDay();
    const etHour = utcHour - 5;
    return utcDay >= 1 && utcDay <= 5 && etHour >= 9 && etHour < 16;
  })();

  return (
    <GlassCard className="relative overflow-hidden" glow="primary">
      {/* Top accent */}
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary/30 to-transparent" />
      {/* Subtle ambient glow */}
      <div
        className="pointer-events-none absolute -top-20 -right-20 h-40 w-40 rounded-full opacity-[0.04] blur-3xl"
        style={{ background: isPeriodUp ? 'var(--ark-success)' : 'var(--ark-error)' }}
      />

      <div className="flex flex-col gap-6 lg:flex-row lg:gap-10">
        {/* Left: Metrics */}
        <div className="flex-1 space-y-5">
          {/* Header with status */}
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-primary/10">
              <Wallet className="h-5 w-5 text-ark-primary" />
            </div>
            <div className="flex items-center gap-2.5">
              <button className="flex cursor-pointer items-center gap-1 text-sm font-semibold text-ark-text hover:text-ark-primary transition-colors">
                Portfolio
                <ChevronDown className="h-3.5 w-3.5 text-ark-text-tertiary" />
              </button>
              <span className="flex items-center gap-1.5 rounded-full bg-ark-fill-secondary px-2.5 py-0.5">
                <span className={`h-1.5 w-1.5 rounded-full ${isMarketOpen ? 'bg-ark-success animate-status' : 'bg-ark-text-tertiary'}`} />
                <span className="text-[10px] font-medium text-ark-text-tertiary">
                  {isMarketOpen ? 'Market Open' : 'Market Closed'}
                </span>
              </span>
            </div>
          </div>

          {isLoading ? (
            <div className="space-y-3">
              <Skeleton className="h-12 w-64" />
              <Skeleton className="h-5 w-44" />
              <div className="flex gap-6">
                <Skeleton className="h-14 w-32" />
                <Skeleton className="h-14 w-32" />
                <Skeleton className="h-14 w-24" />
              </div>
            </div>
          ) : (
            <>
              {/* Main value */}
              <div>
                <p className="mb-1 text-[10px] font-semibold uppercase tracking-widest text-ark-text-disabled">Funds</p>
                <p className="fig font-[family-name:var(--font-urbanist)] text-4xl font-bold tracking-tight text-ark-text lg:text-5xl">
                  <span className="opacity-40 font-normal">$</span>
                  {currentValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </p>
                <div className="mt-1.5 flex items-center gap-2">
                  <span
                    className={`fig flex items-center gap-1 rounded-full px-2 py-0.5 text-sm font-semibold ${
                      isUp
                        ? 'bg-ark-success/10 text-ark-success'
                        : 'bg-ark-error/10 text-ark-error'
                    }`}
                  >
                    {isUp ? (
                      <ArrowUpRight className="h-3.5 w-3.5" />
                    ) : (
                      <ArrowDownRight className="h-3.5 w-3.5" />
                    )}
                    {formatCurrency(Math.abs(dayChange))} ({formatPercent(dayChangePct)})
                  </span>
                  <span className="text-[10px] text-ark-text-disabled">today</span>
                </div>
              </div>

              {/* Sub metrics */}
              <div className="flex gap-8">
                <div>
                  <p className="text-[10px] font-medium uppercase tracking-wider text-ark-text-disabled">
                    {period} Return
                  </p>
                  <p
                    className={`fig mt-1 text-xl font-bold ${
                      isPeriodUp ? 'text-ark-success' : 'text-ark-error'
                    }`}
                  >
                    {formatPercent(periodChangePct)}
                  </p>
                </div>
                <div className="w-px bg-ark-divider" />
                <div>
                  <p className="text-[10px] font-medium uppercase tracking-wider text-ark-text-disabled">
                    {period} P&L
                  </p>
                  <p
                    className={`fig mt-1 text-xl font-bold ${
                      isPeriodUp ? 'text-ark-success' : 'text-ark-error'
                    }`}
                  >
                    {formatCurrency(periodChange, 'USD', { sign: true })}
                  </p>
                </div>
                <div className="w-px bg-ark-divider" />
                <div>
                  <p className="text-[10px] font-medium uppercase tracking-wider text-ark-text-disabled">
                    Assets
                  </p>
                  <p className="fig mt-1 text-xl font-bold text-ark-text">10</p>
                </div>
              </div>

              {/* Period high/low range */}
              <div className="max-w-xs">
                <div className="flex items-center justify-between text-[10px] text-ark-text-disabled">
                  <span className="fig">{formatCurrency(periodLow)}</span>
                  <span className="font-medium">{period} Range</span>
                  <span className="fig">{formatCurrency(periodHigh)}</span>
                </div>
                <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-ark-fill-secondary">
                  <div
                    className="relative h-full rounded-full bg-gradient-to-r from-ark-error via-ark-warning to-ark-success transition-all duration-500"
                    style={{ width: `${Math.max(4, rangePct)}%` }}
                  >
                    <div className="absolute right-0 top-1/2 h-2.5 w-2.5 -translate-y-1/2 translate-x-1/2 rounded-full border-2 border-ark-card bg-ark-text" />
                  </div>
                </div>
              </div>
            </>
          )}

          {/* Timestamp */}
          {now && (
            <div className="flex items-center gap-1.5 text-[10px] text-ark-text-disabled">
              <Clock className="h-3 w-3" />
              Last updated {now}
            </div>
          )}
        </div>

        {/* Right: Chart */}
        <div className="flex flex-col lg:w-[420px]">
          {/* Period selector */}
          <div className="mb-3 flex items-center justify-end gap-1 rounded-full bg-ark-fill-secondary/60 p-0.5">
            {periods.map((p) => (
              <button
                key={p}
                onClick={() => setPeriod(p)}
                className={`rounded-full px-2.5 py-1 text-[11px] font-semibold transition-all cursor-pointer ${
                  period === p
                    ? 'bg-ark-primary text-white shadow-sm'
                    : 'text-ark-text-tertiary hover:text-ark-text-secondary'
                }`}
              >
                {p}
              </button>
            ))}
          </div>

          <div className="h-40 w-full lg:h-52">
            {isLoading ? (
              <Skeleton className="h-full w-full rounded-xl" />
            ) : (
              chartData.length > 1 && (
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={chartData}>
                    <defs>
                      <linearGradient id="portfolio-grad" x1="0" y1="0" x2="0" y2="1">
                        <stop
                          offset="0%"
                          stopColor={isPeriodUp ? 'var(--ark-success)' : 'var(--ark-error)'}
                          stopOpacity={0.2}
                        />
                        <stop
                          offset="100%"
                          stopColor={isPeriodUp ? 'var(--ark-success)' : 'var(--ark-error)'}
                          stopOpacity={0}
                        />
                      </linearGradient>
                    </defs>
                    <YAxis domain={['dataMin', 'dataMax']} hide />
                    <Tooltip
                      contentStyle={{
                        background: 'var(--ark-card)',
                        border: '1px solid var(--ark-divider)',
                        borderRadius: '12px',
                        fontSize: '12px',
                        boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
                        padding: '8px 12px',
                      }}
                      formatter={(v) => [
                        `$${(v as number).toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
                        '',
                      ]}
                      labelFormatter={(l) =>
                        new Date(l).toLocaleDateString('en-US', {
                          month: 'short',
                          day: 'numeric',
                        })
                      }
                    />
                    <Area
                      type="monotone"
                      dataKey="value"
                      stroke={isPeriodUp ? 'var(--ark-success)' : 'var(--ark-error)'}
                      strokeWidth={2}
                      fill="url(#portfolio-grad)"
                      dot={false}
                      activeDot={{ r: 4, strokeWidth: 2, stroke: 'var(--ark-card)' }}
                    />
                  </AreaChart>
                </ResponsiveContainer>
              )
            )}
          </div>
        </div>
      </div>
    </GlassCard>
  );
}
