'use client';

import { Activity, ArrowUpRight, DollarSign, Equal, TrendingDown } from 'lucide-react';
import { GlassCard, Skeleton } from '@/components/ui';
import { useMomentumMap } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';
import type { MomentumQuadrant, PositioningSignal } from '@/types';

const quadrantMeta: Record<
  MomentumQuadrant,
  { title: string; subtitle: string; icon: typeof Activity; accent: string; tint: string; ring: string }
> = {
  momentum: {
    title: 'True momentum',
    subtitle: 'USD and BTC pair both bullish — the wave is real.',
    icon: Activity, accent: 'text-ark-success', tint: 'bg-ark-success/10', ring: 'border-ark-success/25',
  },
  outperforming_btc: {
    title: 'Outperforming BTC',
    subtitle: 'Gaining on Bitcoin while USD lags — early relative strength.',
    icon: ArrowUpRight, accent: 'text-ark-primary', tint: 'bg-ark-primary/10', ring: 'border-ark-primary/25',
  },
  usd_leading: {
    title: 'Leading in USD',
    subtitle: 'Strong in dollar terms, not yet beating Bitcoin.',
    icon: DollarSign, accent: 'text-ark-warning', tint: 'bg-ark-warning/10', ring: 'border-ark-warning/25',
  },
  mixed: {
    title: 'Mixed / neutral',
    subtitle: 'Signals not aligned — wait for confirmation.',
    icon: Equal, accent: 'text-ark-text-tertiary', tint: 'bg-ark-fill-secondary', ring: 'border-ark-divider',
  },
  both_bearish: {
    title: 'Both bearish',
    subtitle: 'Both pairs bearish — no momentum.',
    icon: TrendingDown, accent: 'text-ark-error', tint: 'bg-ark-error/10', ring: 'border-ark-error/25',
  },
};

const signalLabel: Record<PositioningSignal, string> = { bullish: 'Bullish', neutral: 'Neutral', bearish: 'Bearish' };
const signalColor: Record<PositioningSignal, string> = {
  bullish: 'text-ark-success', neutral: 'text-ark-warning', bearish: 'text-ark-error',
};
const signalTint: Record<PositioningSignal, string> = {
  bullish: 'bg-ark-success/12', neutral: 'bg-ark-warning/12', bearish: 'bg-ark-error/12',
};

function SignalPill({ label, signal }: { label: string; signal: PositioningSignal }) {
  return (
    <span className={cn('inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs', signalTint[signal])}>
      <span className={cn('font-medium opacity-70', signalColor[signal])}>{label}</span>
      <span className={cn('font-semibold', signalColor[signal])}>{signalLabel[signal]}</span>
    </span>
  );
}

export function MomentumMap() {
  const { data, isLoading } = useMomentumMap();

  if (isLoading) {
    return (
      <div className="space-y-6">
        <GlassCard><Skeleton className="h-6 w-40" /><Skeleton className="mt-4 h-40 w-full" /></GlassCard>
        <GlassCard><Skeleton className="h-6 w-40" /><Skeleton className="mt-4 h-40 w-full" /></GlassCard>
      </div>
    );
  }

  if (!data || data.groups.length === 0) {
    return (
      <GlassCard className="p-6">
        <p className="text-sm text-ark-text-tertiary">No paired positioning data available yet.</p>
      </GlassCard>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between px-1">
        <p className="text-sm leading-relaxed text-ark-text-tertiary">
          Assets where the USD pair and the BTC pair agree.
        </p>
        {data.as_of && (
          <span className="fig shrink-0 text-xs font-medium text-ark-text-disabled">{data.as_of}</span>
        )}
      </div>

      {data.groups.map(({ quadrant, pairs }) => {
        const meta = quadrantMeta[quadrant];
        const Icon = meta.icon;
        return (
          <GlassCard key={quadrant} className={cn('border p-5', meta.ring)}>
            <div className="mb-4 flex items-start gap-3">
              <div className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-xl', meta.tint)}>
                <Icon className={cn('h-4.5 w-4.5', meta.accent)} />
              </div>
              <div className="flex-1">
                <h3 className="text-sm font-semibold text-ark-text">{meta.title}</h3>
                <p className="text-xs text-ark-text-tertiary">{meta.subtitle}</p>
              </div>
              <span className={cn('fig text-base font-bold', meta.accent)}>{pairs.length}</span>
            </div>

            <div className="divide-y divide-ark-divider/50">
              {pairs.map((pair) => (
                <div key={pair.asset} className="flex items-center gap-3 py-3">
                  <div className="flex flex-1 items-center gap-2">
                    <span className="text-sm font-semibold text-ark-text">{pair.asset}</span>
                    {!pair.is_real_btc_pair && (
                      <span className="rounded-full bg-ark-fill-secondary px-1.5 py-0.5 text-[9px] font-medium uppercase tracking-wide text-ark-text-disabled">
                        synthetic
                      </span>
                    )}
                  </div>
                  <SignalPill label="USD" signal={pair.usd_signal} />
                  <SignalPill label="BTC" signal={pair.btc_signal} />
                </div>
              ))}
            </div>
          </GlassCard>
        );
      })}

      {/* How it works */}
      <GlassCard className="p-6">
        <h3 className="mb-3 text-sm font-semibold text-ark-text">How the Momentum Map Works</h3>
        <ul className="space-y-2.5 text-sm leading-relaxed text-ark-text-tertiary">
          <li className="flex gap-2"><span className="text-ark-primary">•</span>Each asset is read on two pairs — its USD pair (e.g. SOL/USD) and its BTC pair (e.g. SOL/BTC) — each classified bullish, neutral, or bearish.</li>
          <li className="flex gap-2"><span className="text-ark-primary">•</span>True momentum = both pairs bullish. The strongest moves happen when an asset is rising in dollars and gaining on Bitcoin at once.</li>
          <li className="flex gap-2"><span className="text-ark-primary">•</span>Outperforming BTC = the BTC pair is bullish while USD lags. These relative-strength leaders often move first when risk turns back on.</li>
          <li className="flex gap-2"><span className="text-ark-primary">•</span>Synthetic pairs are derived as USD ÷ BTC price; when Bitcoin is falling they can read bullish simply because the asset drops slower. Treat the real Coinbase pairs as the cleaner read.</li>
        </ul>
      </GlassCard>
    </div>
  );
}
