'use client';

import {
  Target, TrendingUp, TrendingDown, Minus, AlertTriangle, ChevronRight,
  Globe, DollarSign, BarChart3, Droplet, Diamond,
} from 'lucide-react';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { useCryptoPositioning } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';
import type { PositioningSignal, MacroInputSignal } from '@/types';

const signalConfig: Record<PositioningSignal, { label: string; color: string; badgeVariant: 'success' | 'default' | 'error' | 'info'; icon: typeof TrendingUp }> = {
  bullish: { label: 'Bullish', color: 'text-ark-success', badgeVariant: 'success', icon: TrendingUp },
  neutral: { label: 'DCA', color: 'text-ark-primary', badgeVariant: 'info', icon: Minus },
  bearish: { label: 'Bearish', color: 'text-ark-error', badgeVariant: 'error', icon: TrendingDown },
};

const inputSignalVariant: Record<MacroInputSignal, 'success' | 'default' | 'error'> = {
  Bullish: 'success',
  Neutral: 'default',
  Bearish: 'error',
};

const iconMap: Record<string, typeof Globe> = {
  globe: Globe,
  'trending-up': TrendingUp,
  'dollar-sign': DollarSign,
  'bar-chart-3': BarChart3,
  droplet: Droplet,
  diamond: Diamond,
};

const allocationSteps = [
  { pct: 0, label: 'Sidelines', color: 'bg-ark-text-disabled/40' },
  { pct: 25, label: 'Small / DCA', color: 'bg-ark-success' },
  { pct: 50, label: 'Half', color: 'bg-ark-warning' },
  { pct: 100, label: 'Full', color: 'bg-ark-primary' },
];

export function CryptoPositioning() {
  const { data, isLoading } = useCryptoPositioning();

  if (isLoading) {
    return (
      <div className="space-y-6">
        <GlassCard><Skeleton className="h-6 w-40" /><Skeleton className="mt-4 h-40 w-full" /></GlassCard>
        <GlassCard><Skeleton className="h-6 w-40" /><Skeleton className="mt-4 h-64 w-full" /></GlassCard>
      </div>
    );
  }

  if (!data) return null;

  return (
    <div className="space-y-6">
      {/* ── Macro Regime ── */}
      <GlassCard className="relative overflow-hidden p-6">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary/20 to-transparent" />

        <div className="mb-5 flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-primary/10">
            <Target className="h-5 w-5 text-ark-primary" />
          </div>
          <div>
            <h3 className="text-base font-semibold text-ark-text">Crypto Positioning</h3>
            <p className="text-xs text-ark-text-disabled">Multi-factor signal analysis</p>
          </div>
        </div>

        {/* Regime card */}
        <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-5">
          <p className="text-xs font-medium uppercase tracking-wider text-ark-text-tertiary">
            Current Macro Regime
          </p>
          <h4 className={cn(
            'mt-1.5 text-xl font-bold',
            data.regime.includes('risk-on') ? 'text-ark-success' : 'text-ark-warning',
          )}>
            {data.regime_label}
          </h4>
          <p className="mt-2 text-sm leading-relaxed text-ark-text-tertiary">
            {data.regime_description}
          </p>

          {/* Growth / Inflation bars */}
          <div className="mt-4 grid grid-cols-2 gap-4">
            <div>
              <div className="flex items-center justify-between text-xs">
                <span className="font-medium text-ark-success">Growth</span>
                <span className="fig font-semibold text-ark-text">{data.growth_score}</span>
              </div>
              <div className="mt-1.5 h-2.5 overflow-hidden rounded-full bg-ark-fill-secondary">
                <div
                  className="h-full rounded-full bg-ark-success transition-all"
                  style={{ width: `${data.growth_score}%` }}
                />
              </div>
            </div>
            <div>
              <div className="flex items-center justify-between text-xs">
                <span className="font-medium text-ark-warning">Inflation</span>
                <span className="fig font-semibold text-ark-text">{data.inflation_score}</span>
              </div>
              <div className="mt-1.5 h-2.5 overflow-hidden rounded-full bg-ark-fill-secondary">
                <div
                  className="h-full rounded-full bg-ark-warning transition-all"
                  style={{ width: `${data.inflation_score}%` }}
                />
              </div>
            </div>
          </div>
        </div>
      </GlassCard>

      {/* ── Macro Inputs ── */}
      <GlassCard className="p-6">
        <h3 className="mb-4 text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary">
          Macro Inputs
        </h3>
        <div className="space-y-2">
          {data.macro_inputs.map((input) => {
            const Icon = iconMap[input.icon] ?? Globe;
            return (
              <div
                key={input.id}
                className="flex items-center gap-4 rounded-xl border border-ark-divider bg-ark-fill-secondary/30 px-4 py-3.5 transition-colors hover:border-ark-text-disabled/30"
              >
                <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-primary/8">
                  <Icon className="h-5 w-5 text-ark-primary" />
                </div>
                <div className="flex-1">
                  <p className="text-sm font-semibold text-ark-text">{input.name}</p>
                  <p className="fig text-xs text-ark-text-tertiary">{input.formatted_value}</p>
                </div>
                <Badge variant={inputSignalVariant[input.signal]}>
                  {input.signal}
                </Badge>
                <ChevronRight className="h-4 w-4 text-ark-text-disabled" />
              </div>
            );
          })}
        </div>
      </GlassCard>

      {/* ── Asset Positioning ── */}
      <GlassCard className="p-6">
        <p className="mb-1 text-sm leading-relaxed text-ark-text-tertiary">
          Each asset is scored on its technical trend, risk level, and macro regime fit.
        </p>

        {/* Table header */}
        <div className="mt-4 mb-2 flex items-center px-1 text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary">
          <span className="flex-1">Asset</span>
          <span className="w-20 text-center">Signal</span>
          <span className="w-16 text-right">Allocation</span>
        </div>

        {/* Asset list */}
        <div className="divide-y divide-ark-divider/50">
          {data.assets.map((asset) => {
            const config = signalConfig[asset.signal];
            return (
              <div key={asset.symbol} className="py-4 px-1">
                <div className="flex items-center">
                  <div className="flex flex-1 items-center gap-3">
                    <div className="flex h-9 w-9 items-center justify-center rounded-full bg-ark-fill-secondary text-[11px] font-bold uppercase text-ark-text-tertiary">
                      {asset.symbol.slice(0, 2)}
                    </div>
                    <div>
                      <p className="text-sm font-semibold text-ark-text">{asset.name}</p>
                      <p className="text-xs text-ark-text-disabled">{asset.symbol}</p>
                    </div>
                  </div>
                  <div className="w-20 text-center">
                    <Badge variant={config.badgeVariant}>
                      {asset.is_dca_opportunity ? 'DCA' : config.label}
                    </Badge>
                  </div>
                  <div className="w-16 text-right">
                    <span className={cn(
                      'fig text-lg font-bold',
                      asset.target_allocation > 0 ? 'text-ark-success' : 'text-ark-text-disabled',
                    )}>
                      {asset.target_allocation}%
                    </span>
                  </div>
                </div>
                <p className="mt-1.5 pl-12 text-xs leading-relaxed text-ark-text-tertiary">
                  {asset.interpretation}
                </p>
              </div>
            );
          })}
        </div>

        {/* Allocation scale */}
        <div className="mt-5 border-t border-ark-divider pt-4">
          <div className="flex">
            {allocationSteps.map((step, i) => (
              <div key={step.pct} className={cn('flex-1', i > 0 && 'ml-0.5')}>
                <div className={cn('h-2 rounded-full', step.color)} />
                <div className="mt-1.5 text-center">
                  <p className="fig text-[10px] font-semibold text-ark-text-secondary">{step.pct}%</p>
                  <p className="text-[10px] text-ark-text-disabled">{step.label}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </GlassCard>
    </div>
  );
}
