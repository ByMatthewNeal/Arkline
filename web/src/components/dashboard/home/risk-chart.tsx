'use client';

import { Shield, TrendingUp, TrendingDown } from 'lucide-react';
import {
  Area,
  AreaChart,
  ResponsiveContainer,
  XAxis,
  YAxis,
  Tooltip,
  ReferenceArea,
} from 'recharts';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { useRiskHistory } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';

const riskBands = [
  { y1: 0, y2: 0.2, fill: 'var(--ark-success)', label: 'Very Low' },
  { y1: 0.2, y2: 0.4, fill: 'var(--ark-accent-light)', label: 'Low' },
  { y1: 0.4, y2: 0.6, fill: 'var(--ark-warning)', label: 'Neutral' },
  { y1: 0.6, y2: 0.8, fill: '#F97316', label: 'Elevated' },
  { y1: 0.8, y2: 1.0, fill: 'var(--ark-error)', label: 'High' },
];

function getRiskColor(value: number): string {
  if (value < 0.2) return 'var(--ark-success)';
  if (value < 0.4) return 'var(--ark-accent-light)';
  if (value < 0.6) return 'var(--ark-warning)';
  if (value < 0.8) return '#F97316';
  return 'var(--ark-error)';
}

function getRiskLabel(value: number): string {
  if (value < 0.2) return 'Very Low';
  if (value < 0.4) return 'Low';
  if (value < 0.6) return 'Neutral';
  if (value < 0.8) return 'Elevated';
  return 'High';
}

function getRiskVariant(value: number): 'success' | 'info' | 'warning' | 'error' {
  if (value < 0.3) return 'success';
  if (value < 0.5) return 'info';
  if (value < 0.7) return 'warning';
  return 'error';
}

export function RiskChart() {
  const { data, isLoading } = useRiskHistory(365);

  const chartData = (data ?? []).map((p) => ({
    date: p.date,
    risk: p.risk_level,
    price: p.price,
  }));

  const latest = chartData[chartData.length - 1];
  const prev7 = chartData[chartData.length - 8];
  const riskValue = latest?.risk ?? 0;
  const riskColor = getRiskColor(riskValue);
  const weekChange = prev7 ? riskValue - prev7.risk : 0;

  return (
    <GlassCard className="relative overflow-hidden">
      {/* Accent line */}
      <div
        className="pointer-events-none absolute inset-x-0 top-0 h-px"
        style={{
          background: `linear-gradient(to right, transparent, ${riskColor}40, transparent)`,
        }}
      />

      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div
            className="flex h-10 w-10 items-center justify-center rounded-xl"
            style={{ backgroundColor: `${riskColor}15` }}
          >
            <Shield className="h-5 w-5" style={{ color: riskColor }} />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-ark-text">Risk Score</h3>
            <p className="text-[10px] text-ark-text-disabled">Multi-factor model</p>
          </div>
        </div>
        {latest && (
          <div className="flex items-center gap-2.5">
            <Badge variant={getRiskVariant(riskValue)}>{getRiskLabel(riskValue)}</Badge>
            <span
              className="fig font-[family-name:var(--font-urbanist)] text-2xl font-bold"
              style={{ color: riskColor }}
            >
              {(riskValue * 100).toFixed(0)}
            </span>
          </div>
        )}
      </div>

      {/* 7d change indicator */}
      {latest && prev7 && (
        <div className={cn(
          'mb-3 inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-semibold',
          weekChange > 0.02 ? 'bg-ark-error/10 text-ark-error' : weekChange < -0.02 ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-fill-secondary text-ark-text-disabled',
        )}>
          {weekChange > 0.02 ? <TrendingUp className="h-2.5 w-2.5" /> : weekChange < -0.02 ? <TrendingDown className="h-2.5 w-2.5" /> : null}
          {weekChange > 0 ? '+' : ''}{(weekChange * 100).toFixed(1)} pts (7d)
        </div>
      )}

      {isLoading ? (
        <Skeleton className="h-44 w-full" />
      ) : (
        <div className="h-44">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={chartData}>
              {riskBands.map((band) => (
                <ReferenceArea
                  key={band.label}
                  y1={band.y1}
                  y2={band.y2}
                  fill={band.fill}
                  fillOpacity={0.06}
                />
              ))}
              <XAxis
                dataKey="date"
                tick={false}
                axisLine={false}
                tickLine={false}
              />
              <YAxis
                domain={[0, 1]}
                tick={{ fontSize: 10, fill: 'var(--ark-text-tertiary)' }}
                axisLine={false}
                tickLine={false}
                width={28}
                tickFormatter={(v: number) => `${(v * 100).toFixed(0)}`}
              />
              <Tooltip
                contentStyle={{
                  background: 'var(--ark-card)',
                  border: '1px solid var(--ark-divider)',
                  borderRadius: '12px',
                  fontSize: '12px',
                  boxShadow: '0 8px 24px rgba(0,0,0,0.12)',
                }}
                formatter={(v) => [`${((v as number) * 100).toFixed(1)}`, 'Risk']}
                labelFormatter={(l) =>
                  new Date(l).toLocaleDateString('en-US', {
                    month: 'short',
                    day: 'numeric',
                  })
                }
              />
              <defs>
                <linearGradient id="risk-grad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={riskColor} stopOpacity={0.35} />
                  <stop offset="100%" stopColor={riskColor} stopOpacity={0} />
                </linearGradient>
              </defs>
              <Area
                type="monotone"
                dataKey="risk"
                stroke={riskColor}
                strokeWidth={2}
                fill="url(#risk-grad)"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Risk band legend */}
      <div className="mt-3 flex gap-0.5">
        {riskBands.map((band) => (
          <div key={band.label} className="flex-1">
            <div
              className="h-1.5 rounded-full"
              style={{ backgroundColor: band.fill, opacity: riskValue >= band.y1 && riskValue < band.y2 ? 1 : 0.2 }}
            />
            <p className={cn(
              'mt-1 text-center text-[8px]',
              riskValue >= band.y1 && riskValue < band.y2 ? 'font-semibold text-ark-text-secondary' : 'text-ark-text-disabled',
            )}>
              {band.label}
            </p>
          </div>
        ))}
      </div>
    </GlassCard>
  );
}
