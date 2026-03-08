'use client';

import { PieChart } from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip, ReferenceArea } from 'recharts';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { useSupplyInProfit } from '@/lib/hooks/use-market';
import type { SupplyInProfitStatus } from '@/types';

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

  const percentage = data?.percentage ?? 0;
  const status = data?.status ?? 'Normal';
  const history = data?.history ?? [];
  const date = data?.date ?? '';
  const color = statusColor(status);

  const chartData = history.map((h) => ({ date: h.date, value: h.value }));

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
          <div className="mb-3">
            <span className="font-[family-name:var(--font-urbanist)] text-3xl font-bold text-ark-text" style={{ color }}>
              {percentage.toFixed(2)}%
            </span>
            {date && (
              <p className="mt-0.5 text-[10px] text-ark-text-disabled">
                As of {new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
              </p>
            )}
          </div>

          <div className="h-36">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData}>
                {/* Zone backgrounds */}
                <ReferenceArea y1={0} y2={50} fill="var(--ark-success)" fillOpacity={0.04} />
                <ReferenceArea y1={50} y2={85} fill="var(--ark-info)" fillOpacity={0.04} />
                <ReferenceArea y1={85} y2={97} fill="var(--ark-warning)" fillOpacity={0.04} />
                <ReferenceArea y1={97} y2={100} fill="var(--ark-error)" fillOpacity={0.04} />
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
                  dot={false}
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </>
      )}
    </GlassCard>
  );
}
