'use client';

import { BarChart3, ArrowUpRight, ArrowDownRight } from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer } from 'recharts';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { useTraditionalMarkets } from '@/lib/hooks/use-market';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';
import type { TrendSignal } from '@/types';

const trendVariant: Record<TrendSignal, 'success' | 'default' | 'error'> = {
  Bullish: 'success',
  Neutral: 'default',
  Bearish: 'error',
};

export function TraditionalMarkets() {
  const { data, isLoading } = useTraditionalMarkets();
  const assets = data ?? [];

  if (isLoading) {
    return (
      <GlassCard>
        <Skeleton className="h-6 w-40" />
        <Skeleton className="mt-4 h-32 w-full" />
      </GlassCard>
    );
  }

  return (
    <GlassCard className="relative overflow-hidden p-6">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary/20 to-transparent" />

      <div className="mb-5 flex items-center gap-3">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-primary/10">
          <BarChart3 className="h-5 w-5 text-ark-primary" />
        </div>
        <div>
          <h3 className="text-base font-semibold text-ark-text">Traditional Markets</h3>
          <p className="text-xs text-ark-text-disabled">Equities & precious metals</p>
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        {assets.map((asset) => {
          const isUp = asset.price_change_percentage_24h >= 0;
          const sparkData = asset.sparkline.map((v, i) => ({ i, v }));
          return (
            <div
              key={asset.id}
              className="flex items-center gap-4 rounded-xl border border-ark-divider bg-ark-surface px-5 py-4 transition-colors hover:border-ark-text-disabled/30"
            >
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className="text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary">
                    {asset.symbol}
                  </span>
                  <Badge variant={trendVariant[asset.trend_signal]}>
                    {asset.trend_signal}
                  </Badge>
                </div>
                <p className="fig mt-1.5 text-2xl font-bold text-ark-text">
                  <span className="currency-sign">$</span>
                  {asset.current_price.toLocaleString('en-US', {
                    minimumFractionDigits: asset.current_price < 100 ? 2 : 0,
                    maximumFractionDigits: asset.current_price < 100 ? 2 : 0,
                  })}
                </p>
                <div className={cn(
                  'fig mt-1 flex items-center gap-0.5 text-sm font-medium',
                  isUp ? 'text-ark-success' : 'text-ark-error',
                )}>
                  {isUp ? <ArrowUpRight className="h-3.5 w-3.5" /> : <ArrowDownRight className="h-3.5 w-3.5" />}
                  {formatPercent(asset.price_change_percentage_24h)}
                </div>
              </div>
              <div className="h-14 w-28">
                {sparkData.length > 1 && (
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={sparkData}>
                      <Area
                        type="monotone"
                        dataKey="v"
                        stroke={isUp ? 'var(--ark-success)' : 'var(--ark-error)'}
                        strokeWidth={1.5}
                        fill="transparent"
                        dot={false}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </GlassCard>
  );
}
