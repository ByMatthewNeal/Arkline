'use client';

import { BarChart3, ArrowUpRight, ArrowDownRight } from 'lucide-react';
import { GlassCard, Skeleton } from '@/components/ui';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';

const coinColors: Record<string, string> = {
  btc: '#F7931A',
  eth: '#627EEA',
  sol: '#9945FF',
};

export function MarketMovers() {
  const { data: assets, isLoading } = useCryptoAssets(1);

  const movers = (assets ?? []).filter((a) =>
    ['bitcoin', 'ethereum', 'solana'].includes(a.id),
  );

  return (
    <GlassCard className="relative overflow-hidden">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary/30 to-transparent" />

      <div className="mb-4 flex items-center gap-2.5">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-primary/10">
          <BarChart3 className="h-5 w-5 text-ark-primary" />
        </div>
        <div>
          <h3 className="text-sm font-semibold text-ark-text">Core Technical Analysis</h3>
          <p className="text-[10px] text-ark-text-disabled">Top assets by market cap</p>
        </div>
      </div>

      {isLoading ? (
        <div className="grid grid-cols-3 gap-3">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-28 w-full rounded-xl" />
          ))}
        </div>
      ) : (
        <div className="grid grid-cols-3 gap-3">
          {movers.map((asset) => {
            const isUp = (asset.price_change_percentage_24h ?? 0) >= 0;
            const accent = coinColors[asset.symbol.toLowerCase()] ?? 'var(--ark-primary)';
            return (
              <div
                key={asset.id}
                className="relative overflow-hidden rounded-xl border border-ark-divider/50 bg-ark-fill-secondary/40 p-4 transition-all hover:border-ark-divider hover:bg-ark-fill-secondary/70"
              >
                {/* Accent glow */}
                <div
                  className="pointer-events-none absolute -top-6 -right-6 h-16 w-16 rounded-full opacity-[0.08] blur-2xl"
                  style={{ background: accent }}
                />
                <div className="flex flex-col items-center gap-2.5">
                  {/* Icon circle */}
                  <div
                    className="flex h-11 w-11 items-center justify-center rounded-full text-sm font-bold text-white"
                    style={{ backgroundColor: accent }}
                  >
                    {asset.symbol.toUpperCase().slice(0, 3)}
                  </div>
                  <span className="text-xs font-semibold text-ark-text">
                    {asset.symbol.toUpperCase()}
                  </span>
                  <span className="fig text-sm font-bold text-ark-text">
                    {formatCurrency(asset.current_price)}
                  </span>
                  <span
                    className={cn(
                      'fig flex items-center gap-0.5 rounded-full px-2 py-0.5 text-[10px] font-semibold',
                      isUp ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-error/10 text-ark-error',
                    )}
                  >
                    {isUp ? <ArrowUpRight className="h-2.5 w-2.5" /> : <ArrowDownRight className="h-2.5 w-2.5" />}
                    {formatPercent(asset.price_change_percentage_24h ?? 0)}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </GlassCard>
  );
}
