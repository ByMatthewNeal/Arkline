'use client';

import { Gauge, TrendingUp, TrendingDown, Minus } from 'lucide-react';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { useFearGreedIndex } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';

function getVariant(value: number): 'error' | 'warning' | 'default' | 'success' {
  if (value <= 25) return 'error';
  if (value <= 45) return 'warning';
  if (value <= 55) return 'default';
  return 'success';
}

function getGaugeColor(value: number): string {
  if (value <= 25) return 'var(--ark-error)';
  if (value <= 45) return 'var(--ark-warning)';
  if (value <= 55) return 'var(--ark-text-tertiary)';
  return 'var(--ark-success)';
}

export function FearGreedGauge() {
  const { data, isLoading } = useFearGreedIndex();

  const value = data?.value ?? 50;
  const label = data?.value_classification ?? 'Neutral';
  const rotation = (value / 100) * 180 - 90;
  const color = getGaugeColor(value);

  // Simulate yesterday's value for comparison (in real app, fetch historical)
  const prevValue = Math.max(0, Math.min(100, value + (value > 50 ? -3 : 4)));
  const change = value - prevValue;

  return (
    <GlassCard className="relative flex flex-col overflow-hidden">
      {/* Subtle glow at top */}
      <div
        className="pointer-events-none absolute inset-x-0 top-0 h-px"
        style={{
          background: `linear-gradient(to right, transparent, ${color}40, transparent)`,
        }}
      />

      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-warning/10">
            <Gauge className="h-5 w-5 text-ark-warning" />
          </div>
          <h3 className="text-sm font-semibold text-ark-text">Fear & Greed</h3>
        </div>
        <Badge variant={getVariant(value)}>{label}</Badge>
      </div>

      {isLoading ? (
        <div className="flex flex-1 items-center justify-center">
          <Skeleton className="h-32 w-48" />
        </div>
      ) : (
        <div className="flex flex-1 flex-col items-center justify-center">
          {/* Semi-circle gauge */}
          <svg viewBox="0 0 200 120" className="w-52">
            {/* Background arc */}
            <path
              d="M 20 100 A 80 80 0 0 1 180 100"
              fill="none"
              stroke="var(--ark-divider)"
              strokeWidth="12"
              strokeLinecap="round"
            />
            {/* Extreme Fear */}
            <path
              d="M 20 100 A 80 80 0 0 1 52 40"
              fill="none"
              stroke="var(--ark-error)"
              strokeWidth="12"
              strokeLinecap="round"
              opacity="0.75"
            />
            {/* Fear */}
            <path
              d="M 52 40 A 80 80 0 0 1 85 22"
              fill="none"
              stroke="var(--ark-warning)"
              strokeWidth="12"
              strokeLinecap="round"
              opacity="0.75"
            />
            {/* Neutral */}
            <path
              d="M 85 22 A 80 80 0 0 1 115 22"
              fill="none"
              stroke="var(--ark-text-tertiary)"
              strokeWidth="12"
              strokeLinecap="round"
              opacity="0.35"
            />
            {/* Greed */}
            <path
              d="M 115 22 A 80 80 0 0 1 148 40"
              fill="none"
              stroke="var(--ark-success)"
              strokeWidth="12"
              strokeLinecap="round"
              opacity="0.75"
            />
            {/* Extreme Greed */}
            <path
              d="M 148 40 A 80 80 0 0 1 180 100"
              fill="none"
              stroke="var(--ark-success-muted)"
              strokeWidth="12"
              strokeLinecap="round"
              opacity="0.75"
            />
            {/* Needle */}
            <line
              x1="100"
              y1="100"
              x2="100"
              y2="35"
              stroke="var(--ark-text-primary)"
              strokeWidth="2.5"
              strokeLinecap="round"
              transform={`rotate(${rotation}, 100, 100)`}
              className="transition-transform duration-700"
            />
            {/* Center dot */}
            <circle cx="100" cy="100" r="6" fill="var(--ark-text-primary)" />
            <circle cx="100" cy="100" r="3" fill="var(--ark-card)" />
            {/* Scale labels */}
            <text x="20" y="116" textAnchor="start" className="fill-ark-text-disabled text-[9px]">0</text>
            <text x="100" y="14" textAnchor="middle" className="fill-ark-text-disabled text-[9px]">50</text>
            <text x="180" y="116" textAnchor="end" className="fill-ark-text-disabled text-[9px]">100</text>
          </svg>

          {/* Value + change */}
          <div className="mt-2 flex flex-col items-center">
            <div className="flex items-baseline gap-1.5">
              <span
                className="font-[family-name:var(--font-urbanist)] text-4xl font-bold"
                style={{ color }}
              >
                {value}
              </span>
              <span className="text-sm text-ark-text-disabled">/ 100</span>
            </div>
            <div className={cn(
              'mt-1.5 flex items-center gap-1 rounded-full px-2 py-0.5 text-[10px] font-semibold',
              change > 0 ? 'bg-ark-success/10 text-ark-success' : change < 0 ? 'bg-ark-error/10 text-ark-error' : 'bg-ark-fill-secondary text-ark-text-disabled',
            )}>
              {change > 0 ? <TrendingUp className="h-2.5 w-2.5" /> : change < 0 ? <TrendingDown className="h-2.5 w-2.5" /> : <Minus className="h-2.5 w-2.5" />}
              {change > 0 ? '+' : ''}{change} vs yesterday
            </div>
          </div>

          {/* Scale bar */}
          <div className="mt-4 flex w-full items-center justify-between px-1 text-[9px] text-ark-text-disabled">
            <span>Extreme Fear</span>
            <span>Neutral</span>
            <span>Extreme Greed</span>
          </div>
        </div>
      )}
    </GlassCard>
  );
}
