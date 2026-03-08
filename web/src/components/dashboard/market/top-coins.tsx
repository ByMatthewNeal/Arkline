'use client';

import { useState } from 'react';
import { Coins, Search, ArrowUpRight, ArrowDownRight, ChevronDown, ChevronUp } from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer } from 'recharts';
import { GlassCard, Skeleton } from '@/components/ui';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';

const INITIAL_SHOW = 10;

export function TopCoins() {
  const { data: assets, isLoading } = useCryptoAssets(1);
  const [search, setSearch] = useState('');
  const [expanded, setExpanded] = useState(false);

  const allCoins = assets ?? [];
  const filtered = allCoins.filter(
    (a) =>
      a.name.toLowerCase().includes(search.toLowerCase()) ||
      a.symbol.toLowerCase().includes(search.toLowerCase()),
  );
  const visible = expanded ? filtered : filtered.slice(0, INITIAL_SHOW);
  const hasMore = filtered.length > INITIAL_SHOW;

  if (isLoading) {
    return (
      <GlassCard>
        <Skeleton className="h-6 w-40" />
        <Skeleton className="mt-4 h-64 w-full" />
      </GlassCard>
    );
  }

  return (
    <GlassCard className="relative overflow-hidden p-0">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-[#F7931A]/20 to-transparent" />

      <div className="flex items-center justify-between gap-3 px-6 pt-6 pb-4">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-[#F7931A]/10">
            <Coins className="h-5 w-5 text-[#F7931A]" />
          </div>
          <div>
            <h3 className="text-base font-semibold text-ark-text">Top Coins</h3>
            <p className="text-xs text-ark-text-disabled">By market capitalization</p>
          </div>
        </div>

        {/* Search */}
        <div className="relative max-w-[200px]">
          <Search className="absolute left-3 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-ark-text-tertiary" />
          <input
            type="text"
            placeholder="Search..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="h-9 w-full rounded-lg border border-ark-divider bg-ark-fill-secondary pl-8 pr-3 text-xs text-ark-text placeholder:text-ark-text-disabled outline-none focus:border-ark-primary focus:ring-1 focus:ring-ark-primary/20 transition-all"
          />
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-y border-ark-divider bg-ark-fill-secondary/50">
              <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary w-10">
                #
              </th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary">
                Asset
              </th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary">
                Price
              </th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary">
                24h
              </th>
              <th className="hidden px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary sm:table-cell">
                Mkt Cap
              </th>
              <th className="hidden px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary lg:table-cell">
                Volume
              </th>
              <th className="hidden px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary md:table-cell">
                7d
              </th>
            </tr>
          </thead>
          <tbody>
            {visible.map((asset, idx) => {
              const isUp = (asset.price_change_percentage_24h ?? 0) >= 0;
              const sparkData = asset.sparkline_in_7d?.price?.map((v, i) => ({ i, v })) ?? [];
              return (
                <tr
                  key={asset.id}
                  className={cn(
                    'border-b border-ark-divider/30 transition-colors hover:bg-ark-fill-secondary/50',
                    idx % 2 === 1 && 'bg-ark-fill-secondary/20',
                  )}
                >
                  <td className="px-6 py-3 text-sm text-ark-text-disabled">
                    {asset.market_cap_rank}
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      {asset.image ? (
                        <img src={asset.image} alt={asset.name} className="h-7 w-7 rounded-full" />
                      ) : (
                        <div className="flex h-7 w-7 items-center justify-center rounded-full bg-ark-fill-secondary text-[10px] font-bold uppercase text-ark-text-tertiary">
                          {asset.symbol.slice(0, 2)}
                        </div>
                      )}
                      <div>
                        <span className="text-sm font-semibold text-ark-text">
                          {asset.symbol.toUpperCase()}
                        </span>
                        <span className="ml-2 hidden text-xs text-ark-text-disabled sm:inline">
                          {asset.name}
                        </span>
                      </div>
                    </div>
                  </td>
                  <td className="fig px-4 py-3 text-right text-sm font-semibold text-ark-text">
                    {formatCurrency(asset.current_price)}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <span className={cn(
                      'fig inline-flex items-center gap-0.5 text-sm font-semibold',
                      isUp ? 'text-ark-success' : 'text-ark-error',
                    )}>
                      {isUp ? <ArrowUpRight className="h-3.5 w-3.5" /> : <ArrowDownRight className="h-3.5 w-3.5" />}
                      {formatPercent(asset.price_change_percentage_24h ?? 0)}
                    </span>
                  </td>
                  <td className="fig hidden px-4 py-3 text-right text-sm text-ark-text-secondary sm:table-cell">
                    {asset.market_cap ? formatCurrency(asset.market_cap, 'USD', { compact: true }) : '-'}
                  </td>
                  <td className="fig hidden px-4 py-3 text-right text-sm text-ark-text-secondary lg:table-cell">
                    {asset.total_volume ? formatCurrency(asset.total_volume, 'USD', { compact: true }) : '-'}
                  </td>
                  <td className="hidden px-4 py-3 md:table-cell">
                    <div className="ml-auto h-8 w-20">
                      {sparkData.length > 1 && (
                        <ResponsiveContainer width="100%" height="100%">
                          <AreaChart data={sparkData}>
                            <Area
                              type="monotone"
                              dataKey="v"
                              stroke={isUp ? 'var(--ark-success)' : 'var(--ark-error)'}
                              strokeWidth={1}
                              fill="transparent"
                              dot={false}
                            />
                          </AreaChart>
                        </ResponsiveContainer>
                      )}
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {hasMore && !search && (
        <button
          onClick={() => setExpanded(!expanded)}
          className="flex w-full items-center justify-center gap-1.5 border-t border-ark-divider py-3.5 text-sm font-medium text-ark-text-tertiary transition-colors hover:text-ark-text-secondary hover:bg-ark-fill-secondary/30 cursor-pointer"
        >
          {expanded ? (
            <>
              Show Less <ChevronUp className="h-3.5 w-3.5" />
            </>
          ) : (
            <>
              Show All {filtered.length} Coins <ChevronDown className="h-3.5 w-3.5" />
            </>
          )}
        </button>
      )}
    </GlassCard>
  );
}
