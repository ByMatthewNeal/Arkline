'use client';

import { useState } from 'react';
import { Shield, ArrowUp, ArrowDown, Minus } from 'lucide-react';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { useAssetRiskLevels } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';
import type { AssetRiskCategory, RiskFactorType } from '@/types';

function categoryVariant(level: AssetRiskCategory): 'success' | 'warning' | 'error' | 'default' {
  switch (level) {
    case 'Low': return 'success';
    case 'Moderate': return 'warning';
    case 'Elevated': return 'error';
    case 'Critical': return 'error';
  }
}

function riskColor(value: number): string {
  if (value < 0.3) return 'var(--ark-success)';
  if (value < 0.5) return 'var(--ark-warning)';
  if (value < 0.7) return '#F97316';
  return 'var(--ark-error)';
}

const factorLabels: Record<RiskFactorType, string> = {
  'Log Regression': 'Log Regression',
  'RSI': 'RSI',
  'SMA Position': 'SMA Position',
  'Bull Market Bands': 'Bull Mkt Bands',
  'Funding Rate': 'Funding Rate',
  'Fear & Greed': 'Fear & Greed',
  'Macro Risk': 'Macro Risk',
};

export function AssetRiskLevel() {
  const { data: assets, isLoading } = useAssetRiskLevels();
  const [activeIndex, setActiveIndex] = useState(0);

  const tabs = assets ?? [];
  const active = tabs[activeIndex];

  const riskVal = active?.risk_value ?? 0;
  const color = riskColor(riskVal);
  const delta = active ? riskVal - active.seven_day_avg : 0;

  // Mini circular gauge
  const gaugeRadius = 28;
  const gaugeCirc = 2 * Math.PI * gaugeRadius;
  const gaugeDash = gaugeCirc * (1 - riskVal);

  return (
    <GlassCard className="relative overflow-hidden">
      <div
        className="pointer-events-none absolute inset-x-0 top-0 h-px"
        style={{ background: `linear-gradient(to right, transparent, ${color}40, transparent)` }}
      />

      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div
            className="flex h-10 w-10 items-center justify-center rounded-xl"
            style={{ backgroundColor: `${color}15` }}
          >
            <Shield className="h-5 w-5" style={{ color }} />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-ark-text">Asset Risk Level</h3>
            <p className="text-[10px] text-ark-text-disabled">ITC-style 0-1 scale</p>
          </div>
        </div>
        {active && <Badge variant={categoryVariant(active.level)}>{active.level}</Badge>}
      </div>

      {/* Tab selector */}
      <div className="mb-4 flex gap-1">
        {tabs.map((t, i) => (
          <button
            key={t.symbol}
            onClick={() => setActiveIndex(i)}
            className={cn(
              'cursor-pointer rounded-lg px-3 py-1.5 text-xs font-semibold transition-all',
              i === activeIndex
                ? 'bg-ark-primary/10 text-ark-primary'
                : 'text-ark-text-tertiary hover:text-ark-text-secondary hover:bg-ark-fill-secondary',
            )}
          >
            {t.symbol}
          </button>
        ))}
      </div>

      {isLoading || !active ? (
        <div className="space-y-3">
          <Skeleton className="h-16 w-full" />
          <Skeleton className="h-48 w-full" />
        </div>
      ) : (
        <>
          {/* Risk value + mini gauge */}
          <div className="mb-4 flex items-center gap-5">
            <div className="relative flex h-[72px] w-[72px] items-center justify-center">
              <svg viewBox="0 0 64 64" className="h-full w-full -rotate-90">
                <circle cx="32" cy="32" r={gaugeRadius} fill="none" stroke="var(--ark-divider)" strokeWidth="5" />
                <circle
                  cx="32" cy="32" r={gaugeRadius} fill="none"
                  stroke={color} strokeWidth="5"
                  strokeLinecap="round"
                  strokeDasharray={gaugeCirc}
                  strokeDashoffset={gaugeDash}
                  className="transition-all duration-700"
                />
              </svg>
              <span
                className="absolute font-[family-name:var(--font-urbanist)] text-lg font-bold"
                style={{ color }}
              >
                {riskVal.toFixed(2)}
              </span>
            </div>
            <div className="flex-1 space-y-1.5">
              <p className="text-xs text-ark-text-disabled">
                {active.days_at_level} days at {active.level}
              </p>
              <div className="flex items-center gap-2">
                <span className="text-[10px] text-ark-text-disabled">7d avg</span>
                <span className="fig text-sm font-semibold text-ark-text">{active.seven_day_avg.toFixed(3)}</span>
                <span
                  className={cn(
                    'fig flex items-center gap-0.5 text-[10px] font-semibold',
                    delta > 0.01 ? 'text-ark-error' : delta < -0.01 ? 'text-ark-success' : 'text-ark-text-disabled',
                  )}
                >
                  {delta > 0.01 ? <ArrowUp className="h-2.5 w-2.5" /> : delta < -0.01 ? <ArrowDown className="h-2.5 w-2.5" /> : <Minus className="h-2.5 w-2.5" />}
                  {delta > 0 ? '+' : ''}{delta.toFixed(3)}
                </span>
              </div>
            </div>
          </div>

          {/* Factor breakdown */}
          <div className="space-y-2">
            {active.factors.map((f) => {
              const val = f.normalized_value ?? 0;
              return (
                <div key={f.type} className="flex items-center gap-2.5">
                  <span className="w-24 truncate text-[11px] text-ark-text-secondary">
                    {factorLabels[f.type] ?? f.type}
                  </span>
                  <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-ark-fill-secondary">
                    <div
                      className="h-full rounded-full transition-all duration-500"
                      style={{ width: `${val * 100}%`, backgroundColor: riskColor(val) }}
                    />
                  </div>
                  <span className="fig w-10 text-right text-xs font-semibold text-ark-text">
                    {val.toFixed(2)}
                  </span>
                </div>
              );
            })}
          </div>
        </>
      )}
    </GlassCard>
  );
}
