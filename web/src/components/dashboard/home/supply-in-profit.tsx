'use client';

import { useState } from 'react';
import { PieChart } from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip, ReferenceArea, ReferenceLine } from 'recharts';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { useSupplyInProfit } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';
import type { SupplyInProfitStatus } from '@/types';

const RANGES = ['1M', '3M', '6M', '1Y'] as const;
type Range = (typeof RANGES)[number];
const RANGE_DAYS: Record<Range, number> = { '1M': 30, '3M': 90, '6M': 180, '1Y': 365 };

function statusVariant(status: SupplyInProfitStatus): 'success' | 'info' | 'warning' | 'error' {
  switch (status) {
    case 'Buy Zone': return 'success';
    case 'Normal': return 'info';
    case 'Elevated': return 'warning';
    case 'Overheated': return 'error';
  }
}

function statusColor(status: SupplyInProfitStatus): string {
  switch (status) {
    case 'Buy Zone': return 'var(--ark-success)';
    case 'Normal': return 'var(--ark-info)';
    case 'Elevated': return 'var(--ark-warning)';
    case 'Overheated': return 'var(--ark-error)';
  }
}

export function SupplyInProfit() {
  const { data, isLoading } = useSupplyInProfit();
  const [range, setRange] = useState<Range>('3M');

  const percentage = data?.percentage ?? 0;
  const status = data?.status ?? 'Normal';
  const history = data?.history ?? [];
  const date = data?.date ?? '';
  const color = statusColor(status);

  // History is daily — slice the selected window off the end. A point is a
  // BUY SIGNAL when the metric crosses down into the Buy Zone (<50%).
  const windowed = history.slice(-RANGE_DAYS[range]);
  const chartData = windowed.map((h, i) => ({
    date: h.date,
    value: h.value,
    buySignal: h.value < 50 && (i === 0 ? false : windowed[i - 1].value >= 50),
  }));
  const edgeDate = (d: string | undefined) =>
    d ? new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : '';

  // Buy-zone visits in this window, plus the most recent one EVER (so the
  // answer to "has this ever signaled buy?" doesn't depend on the window).
  const windowSignals = chartData.filter((p) => p.buySignal);
  const lastEver = [...history].reverse().find((h, i, arr) => h.value < 50 && (arr[i + 1]?.value ?? 100) >= 50);

  return (
    <GlassCard className="relative overflow-hidden">
      <div
        className="pointer-events-none absolute inset-x-0 top-0 h-px"
        style={{ background: `linear-gradient(to right, transparent, ${color}40, transparent)` }}
      />

      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-info/10">
            <PieChart className="h-5 w-5 text-ark-info" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-ark-text">BTC Supply in Profit</h3>
            <p className="text-[10px] text-ark-text-disabled">On-chain metric</p>
          </div>
        </div>
        <Badge variant={statusVariant(status)}>{status}</Badge>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          <Skeleton className="h-10 w-32" />
          <Skeleton className="h-36 w-full" />
        </div>
      ) : (
        <>
          <div className="mb-3 flex items-end justify-between">
            <div>
              <span className="font-[family-name:var(--font-urbanist)] text-3xl font-bold text-ark-text" style={{ color }}>
                {percentage.toFixed(2)}%
              </span>
              {date && (
                <p className="mt-0.5 text-[10px] text-ark-text-disabled">
                  As of {new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                </p>
              )}
            </div>
            {/* Time-range selector (same grammar as the portfolio hero) */}
            <div className="flex gap-1 rounded-full bg-ark-fill-secondary/60 p-1">
              {RANGES.map((r) => (
                <button
                  key={r}
                  onClick={() => setRange(r)}
                  className={cn(
                    'rounded-full px-2.5 py-1 text-[10px] font-semibold transition-colors',
                    range === r ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text',
                  )}
                >
                  {r}
                </button>
              ))}
            </div>
          </div>

          <div className="h-36">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData}>
                {/* Zone backgrounds — same thresholds as the status bands (50/75/90) */}
                <ReferenceArea y1={0} y2={50} fill="var(--ark-success)" fillOpacity={0.06} />
                <ReferenceArea y1={50} y2={75} fill="var(--ark-info)" fillOpacity={0.04} />
                <ReferenceArea y1={75} y2={90} fill="var(--ark-warning)" fillOpacity={0.04} />
                <ReferenceArea y1={90} y2={100} fill="var(--ark-error)" fillOpacity={0.04} />
                <ReferenceLine y={50} stroke="var(--ark-success)" strokeDasharray="4 4" strokeOpacity={0.5} />
                <XAxis dataKey="date" tick={false} axisLine={false} tickLine={false} />
                <YAxis
                  domain={[40, 100]}
                  tick={{ fontSize: 10, fill: 'var(--ark-text-tertiary)' }}
                  axisLine={false}
                  tickLine={false}
                  width={30}
                  tickFormatter={(v: number) => `${v}%`}
                />
                <Tooltip
                  contentStyle={{
                    background: 'var(--ark-card)',
                    border: '1px solid var(--ark-divider)',
                    borderRadius: '12px',
                    fontSize: '12px',
                    boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
                  }}
                  formatter={(v) => [`${(v as number).toFixed(2)}%`, 'Supply in Profit']}
                  labelFormatter={(l) =>
                    new Date(l).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
                  }
                />
                <defs>
                  <linearGradient id="sip-grad" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor={color} stopOpacity={0.25} />
                    <stop offset="100%" stopColor={color} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <Area
                  type="monotone"
                  dataKey="value"
                  stroke={color}
                  strokeWidth={2}
                  fill="url(#sip-grad)"
                  isAnimationActive={false}
                  // Green marker on the day the metric crossed into the Buy Zone
                  dot={(props: { cx?: number; cy?: number; payload?: { buySignal?: boolean }; index?: number }) =>
                    props.payload?.buySignal && props.cx != null && props.cy != null ? (
                      <circle key={`buy-${props.index}`} cx={props.cx} cy={props.cy} r={4.5} fill="var(--ark-success)" stroke="var(--ark-card)" strokeWidth={2} />
                    ) : <g key={`nd-${props.index}`} />
                  }
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
          <div className="mt-1 flex justify-between px-8 text-[9px] font-medium uppercase tracking-wide text-ark-text-disabled">
            <span>{edgeDate(chartData[0]?.date)}</span>
            <span>{edgeDate(chartData[chartData.length - 1]?.date)}</span>
          </div>

          {/* Buy-zone signals: when the metric dipped under 50% (accumulation zone) */}
          <div className="mt-3 rounded-xl border border-ark-success/20 bg-ark-success/5 px-3.5 py-2.5">
            <div className="flex items-center gap-1.5">
              <span className="h-2 w-2 rounded-full bg-ark-success" />
              <p className="text-[11px] font-semibold text-ark-success">Buy-zone signals</p>
            </div>
            {status === 'Buy Zone' ? (
              <p className="mt-1 text-[12px] leading-relaxed text-ark-text-secondary">
                <b className="text-ark-success">In the buy zone now</b> — supply in profit is under 50%, historically an accumulation area.
              </p>
            ) : windowSignals.length > 0 ? (
              <p className="mt-1 text-[12px] leading-relaxed text-ark-text-secondary">
                Entered the buy zone {windowSignals.length === 1 ? 'once' : `${windowSignals.length} times`} in this window:{' '}
                <span className="fig font-semibold text-ark-text">{windowSignals.map((s) => edgeDate(s.date)).join(', ')}</span>
              </p>
            ) : lastEver ? (
              <p className="mt-1 text-[12px] leading-relaxed text-ark-text-secondary">
                None in this window — last buy-zone entry was{' '}
                <span className="fig font-semibold text-ark-text">{new Date(lastEver.date + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</span>. Try a longer range to see it.
              </p>
            ) : (
              <p className="mt-1 text-[12px] leading-relaxed text-ark-text-secondary">
                No buy-zone entries in the recorded history — supply in profit has stayed above 50%.
              </p>
            )}
          </div>
        </>
      )}
    </GlassCard>
  );
}
