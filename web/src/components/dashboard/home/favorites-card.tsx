'use client';

import { useState, useMemo } from 'react';
import { useRouter } from 'next/navigation';
import { Star, Search, X, ArrowUpRight, ArrowDownRight, Plus } from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer } from 'recharts';
import { Skeleton } from '@/components/ui';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import { useWatchlist } from '@/lib/hooks/use-watchlist';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';

export function FavoritesCard() {
  const router = useRouter();
  const { data: assets, isLoading } = useCryptoAssets(1);
  const { coins, has, toggle } = useWatchlist();
  const [search, setSearch] = useState('');

  const all = assets ?? [];
  const favorites = all.filter((a) => has(a.symbol));

  const searchResults = useMemo(() => {
    const t = search.trim().toLowerCase();
    if (!t) return [];
    return all.filter((a) => (a.symbol.toLowerCase().includes(t) || a.name.toLowerCase().includes(t)) && !has(a.symbol)).slice(0, 6);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search, all, coins]);

  return (
    <div className="space-y-4 pb-2">
      {/* Add coins */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ark-text-disabled" />
        <input
          value={search} onChange={(e) => setSearch(e.target.value)}
          placeholder="Add a coin to your watchlist…"
          className="w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 py-2.5 pl-9 pr-3 text-sm text-ark-text outline-none focus:border-ark-info"
        />
        {searchResults.length > 0 && (
          <div className="mt-1 overflow-hidden rounded-xl border border-ark-divider bg-ark-card">
            {searchResults.map((a) => (
              <button key={a.id} onClick={() => { toggle(a.symbol); setSearch(''); }}
                className="flex w-full items-center justify-between px-3 py-2 text-left hover:bg-ark-fill-secondary">
                <span className="flex items-center gap-2 text-sm text-ark-text">
                  {a.image ? <img src={a.image} alt={a.name} className="h-5 w-5 rounded-full" /> : null}
                  <b>{a.symbol.toUpperCase()}</b> <span className="text-ark-text-disabled">{a.name}</span>
                </span>
                <Plus className="h-4 w-4 text-ark-info" />
              </button>
            ))}
          </div>
        )}
      </div>

      {isLoading ? (
        <div className="space-y-2">{[0, 1, 2].map((i) => <Skeleton key={i} className="h-16 w-full rounded-xl" />)}</div>
      ) : favorites.length === 0 ? (
        <div className="flex flex-col items-center py-10 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ark-fill-secondary"><Star className="h-6 w-6 text-ark-text-tertiary" /></div>
          <p className="mt-3 text-sm text-ark-text-secondary">Your watchlist is empty</p>
          <p className="mt-1 text-xs text-ark-text-disabled">Search above, or tap the ⭐ on any coin&apos;s page.</p>
        </div>
      ) : (
        <div className="space-y-2">
          {favorites.map((asset) => {
            const isUp = (asset.price_change_percentage_24h ?? 0) >= 0;
            const sparkData = asset.sparkline_in_7d?.price?.map((v, i) => ({ i, v })) ?? [];
            return (
              <div key={asset.id}
                onClick={() => router.push(`/dashboard/market/${asset.id}`)}
                className="group flex cursor-pointer items-center gap-3 rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-3 transition-colors hover:bg-ark-fill-secondary">
                {asset.image ? <img src={asset.image} alt={asset.name} className="h-9 w-9 rounded-full" /> : (
                  <div className="flex h-9 w-9 items-center justify-center rounded-full bg-ark-primary/15 text-xs font-bold uppercase text-ark-primary">{asset.symbol.slice(0, 2)}</div>
                )}
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-bold text-ark-text">{asset.symbol.toUpperCase()}</p>
                  <p className="truncate text-[11px] text-ark-text-disabled">{asset.name}</p>
                </div>
                <div className="h-8 w-16">
                  {sparkData.length > 1 && (
                    <ResponsiveContainer width="100%" height="100%">
                      <AreaChart data={sparkData}>
                        <Area type="monotone" dataKey="v" stroke={isUp ? 'var(--ark-success)' : 'var(--ark-error)'} strokeWidth={1.5} fill="transparent" dot={false} />
                      </AreaChart>
                    </ResponsiveContainer>
                  )}
                </div>
                <div className="text-right">
                  <p className="fig text-sm font-bold text-ark-text">{formatCurrency(asset.current_price)}</p>
                  <p className={cn('fig flex items-center justify-end gap-0.5 text-[11px] font-semibold', isUp ? 'text-ark-success' : 'text-ark-error')}>
                    {isUp ? <ArrowUpRight className="h-2.5 w-2.5" /> : <ArrowDownRight className="h-2.5 w-2.5" />}{formatPercent(asset.price_change_percentage_24h ?? 0)}
                  </p>
                </div>
                <button onClick={(e) => { e.stopPropagation(); toggle(asset.symbol); }} title="Remove"
                  className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg text-ark-text-tertiary opacity-0 transition-opacity hover:bg-ark-fill-secondary group-hover:opacity-100">
                  <X className="h-3.5 w-3.5" />
                </button>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
