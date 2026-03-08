'use client';

import { Star, ArrowUpRight, ArrowDownRight } from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer } from 'recharts';
import { GlassCard, Skeleton } from '@/components/ui';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import { useAuth } from '@/lib/hooks/use-auth';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';

export function FavoritesCard() {
  const { profile } = useAuth();
  const { data: assets, isLoading } = useCryptoAssets(1);

  const riskCoins = profile?.risk_coins ?? ['bitcoin', 'ethereum'];
  const favorites = (assets ?? []).filter((a) =>
    riskCoins.some((rc) => rc.toLowerCase() === a.id.toLowerCase()),
  );

  return (
    <GlassCard className="relative overflow-hidden">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-warning/30 to-transparent" />

      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-warning/10">
            <Star className="h-5 w-5 text-ark-warning" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-ark-text">Watchlist</h3>
            <p className="text-[10px] text-ark-text-disabled">{favorites.length} assets tracked</p>
          </div>
        </div>
      </div>

      {isLoading ? (
        <div className="space-y-3">
          {[0, 1].map((i) => (
            <Skeleton key={i} className="h-16 w-full" />
          ))}
        </div>
      ) : favorites.length === 0 ? (
        <div className="flex flex-col items-center py-6 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ark-fill-secondary">
            <Star className="h-6 w-6 text-ark-text-tertiary" />
          </div>
          <p className="mt-3 text-sm text-ark-text-tertiary">No favorites set</p>
          <p className="mt-1 text-xs text-ark-text-disabled">Add coins from the Market page</p>
        </div>
      ) : (
        <div className="space-y-2.5">
          {favorites.map((asset) => {
            const sparkData =
              asset.sparkline_in_7d?.price?.map((v, i) => ({ i, v })) ?? [];
            const isUp = (asset.price_change_percentage_24h ?? 0) >= 0;
            return (
              <div
                key={asset.id}
                className="rounded-xl border border-ark-divider/50 bg-ark-fill-secondary/40 px-3.5 py-3 transition-all hover:border-ark-divider hover:bg-ark-fill-secondary/70"
              >
                <div className="flex items-center gap-3">
                  {asset.image ? (
                    <img
                      src={asset.image}
                      alt={asset.name}
                      className="h-9 w-9 rounded-full"
                    />
                  ) : (
                    <div className="flex h-9 w-9 items-center justify-center rounded-full bg-ark-primary/15 text-xs font-bold text-ark-primary uppercase">
                      {asset.symbol.slice(0, 2)}
                    </div>
                  )}
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between">
                      <p className="text-sm font-semibold text-ark-text">{asset.symbol.toUpperCase()}</p>
                      <p className="fig text-sm font-bold text-ark-text">
                        {formatCurrency(asset.current_price)}
                      </p>
                    </div>
                    <div className="flex items-center justify-between">
                      <p className="text-[10px] text-ark-text-disabled truncate">{asset.name}</p>
                      <span
                        className={cn(
                          'fig flex items-center gap-0.5 text-[10px] font-semibold',
                          isUp ? 'text-ark-success' : 'text-ark-error',
                        )}
                      >
                        {isUp ? <ArrowUpRight className="h-2.5 w-2.5" /> : <ArrowDownRight className="h-2.5 w-2.5" />}
                        {formatPercent(asset.price_change_percentage_24h ?? 0)}
                      </span>
                    </div>
                  </div>
                </div>
                {/* Inline sparkline */}
                <div className="mt-2 h-8">
                  {sparkData.length > 1 && (
                    <ResponsiveContainer width="100%" height="100%">
                      <AreaChart data={sparkData}>
                        <defs>
                          <linearGradient id={`fav-${asset.id}`} x1="0" y1="0" x2="0" y2="1">
                            <stop
                              offset="0%"
                              stopColor={isUp ? 'var(--ark-success)' : 'var(--ark-error)'}
                              stopOpacity={0.15}
                            />
                            <stop
                              offset="100%"
                              stopColor={isUp ? 'var(--ark-success)' : 'var(--ark-error)'}
                              stopOpacity={0}
                            />
                          </linearGradient>
                        </defs>
                        <Area
                          type="monotone"
                          dataKey="v"
                          stroke={isUp ? 'var(--ark-success)' : 'var(--ark-error)'}
                          strokeWidth={1.5}
                          fill={`url(#fav-${asset.id})`}
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
      )}
    </GlassCard>
  );
}
