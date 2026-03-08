'use client';

import { Shield } from 'lucide-react';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { useArkLineScore } from '@/lib/hooks/use-market';
import type { ArkLineScoreLevel } from '@/types';

function scoreColor(score: number): string {
  if (score < 30) return 'var(--ark-success)';
  if (score < 50) return 'var(--ark-warning)';
  if (score < 70) return '#F97316';
  return 'var(--ark-error)';
}

function levelVariant(level: ArkLineScoreLevel): 'success' | 'warning' | 'error' | 'default' {
  switch (level) {
    case 'Low Risk': return 'success';
    case 'Moderate': return 'warning';
    case 'Elevated': return 'error';
    case 'High Risk': return 'error';
  }
}

export function ArkLineScore() {
  const { data, isLoading } = useArkLineScore();

  const score = data?.score ?? 0;
  const level = data?.level ?? 'Moderate';
  const components = data?.components ?? [];
  const color = scoreColor(score);

  // SVG gauge params
  const radius = 70;
  const cx = 80;
  const cy = 80;
  const circumference = Math.PI * radius; // half-circle
  const dashOffset = circumference - (score / 100) * circumference;

  return (
    <GlassCard className="relative overflow-hidden">
      <div
        className="pointer-events-none absolute inset-x-0 top-0 h-px"
        style={{ background: `linear-gradient(to right, transparent, ${color}40, transparent)` }}
      />

      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-primary/10">
            <Shield className="h-5 w-5 text-ark-primary" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-ark-text">ArkLine Score</h3>
            <p className="text-[10px] text-ark-text-disabled">Composite risk index</p>
          </div>
        </div>
        <Badge variant={levelVariant(level)}>{level}</Badge>
      </div>

      {isLoading ? (
        <div className="flex flex-col items-center gap-4">
          <Skeleton className="h-40 w-40 rounded-full" />
          <Skeleton className="h-32 w-full" />
        </div>
      ) : (
        <>
          {/* Circular gauge */}
          <div className="flex justify-center">
            <div className="relative">
              <svg viewBox="0 0 160 100" className="w-48">
                <defs>
                  <linearGradient id="score-grad" x1="0" y1="0" x2="1" y2="0">
                    <stop offset="0%" stopColor="var(--ark-success)" />
                    <stop offset="40%" stopColor="var(--ark-warning)" />
                    <stop offset="70%" stopColor="#F97316" />
                    <stop offset="100%" stopColor="var(--ark-error)" />
                  </linearGradient>
                </defs>
                {/* Background arc */}
                <path
                  d={`M ${cx - radius} ${cy} A ${radius} ${radius} 0 0 1 ${cx + radius} ${cy}`}
                  fill="none"
                  stroke="var(--ark-divider)"
                  strokeWidth="10"
                  strokeLinecap="round"
                />
                {/* Score arc */}
                <path
                  d={`M ${cx - radius} ${cy} A ${radius} ${radius} 0 0 1 ${cx + radius} ${cy}`}
                  fill="none"
                  stroke="url(#score-grad)"
                  strokeWidth="10"
                  strokeLinecap="round"
                  strokeDasharray={circumference}
                  strokeDashoffset={dashOffset}
                  className="transition-all duration-700"
                />
                {/* Labels */}
                <text x={cx - radius - 2} y={cy + 14} textAnchor="start" className="fill-ark-text-disabled text-[9px]">0</text>
                <text x={cx + radius + 2} y={cy + 14} textAnchor="end" className="fill-ark-text-disabled text-[9px]">100</text>
              </svg>
              {/* Center score */}
              <div className="absolute inset-0 flex flex-col items-center justify-end pb-1">
                <span
                  className="font-[family-name:var(--font-urbanist)] text-4xl font-bold leading-none"
                  style={{ color }}
                >
                  {score}
                </span>
                <span className="text-[10px] text-ark-text-disabled">/100</span>
              </div>
            </div>
          </div>

          {/* Component breakdown */}
          <div className="mt-4 space-y-2">
            {components.map((c) => (
              <div key={c.name} className="flex items-center gap-2.5">
                <span className="w-24 truncate text-[11px] text-ark-text-secondary">{c.name}</span>
                <span className="fig w-8 text-right text-[10px] text-ark-text-disabled">{c.weight}%</span>
                <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-ark-fill-secondary">
                  <div
                    className="h-full rounded-full transition-all duration-500"
                    style={{
                      width: `${c.value}%`,
                      backgroundColor: scoreColor(c.value),
                    }}
                  />
                </div>
                <span className="fig w-8 text-right text-xs font-semibold text-ark-text">{c.value}</span>
              </div>
            ))}
          </div>
        </>
      )}
    </GlassCard>
  );
}
