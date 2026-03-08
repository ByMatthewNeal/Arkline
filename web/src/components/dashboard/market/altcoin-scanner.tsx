'use client';

import { useState, useMemo } from 'react';
import { Scan, ArrowUpDown, ArrowUpRight, ArrowDownRight } from 'lucide-react';
import { GlassCard, Skeleton } from '@/components/ui';
import { useAltcoinScanner } from '@/lib/hooks/use-market';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';
import type { ScannerPeriod, AltcoinScannerEntry } from '@/types';

const periods: { key: ScannerPeriod; label: string }[] = [
  { key: '7d', label: '7D' },
  { key: '30d', label: '30D' },
  { key: '90d', label: '90D' },
];

type SortKey = 'return' | 'vs_btc' | 'market_cap';

function getReturn(entry: AltcoinScannerEntry, period: ScannerPeriod): number {
  return period === '7d' ? entry.return_7d : period === '30d' ? entry.return_30d : entry.return_90d;
}

function getVsBtc(entry: AltcoinScannerEntry, period: ScannerPeriod): number {
  return period === '7d' ? entry.vs_btc_7d : period === '30d' ? entry.vs_btc_30d : entry.vs_btc_90d;
}

export function AltcoinScanner() {
  const { data, isLoading } = useAltcoinScanner();
  const [period, setPeriod] = useState<ScannerPeriod>('30d');
  const [sortBy, setSortBy] = useState<SortKey>('return');
  const [sortAsc, setSortAsc] = useState(false);
  const entries = data ?? [];

  const sorted = useMemo(() => {
    const copy = [...entries];
    copy.sort((a, b) => {
      let va: number, vb: number;
      switch (sortBy) {
        case 'return':
          va = getReturn(a, period);
          vb = getReturn(b, period);
          break;
        case 'vs_btc':
          va = getVsBtc(a, period);
          vb = getVsBtc(b, period);
          break;
        case 'market_cap':
          va = a.market_cap;
          vb = b.market_cap;
          break;
        default:
          va = 0; vb = 0;
      }
      return sortAsc ? va - vb : vb - va;
    });
    return copy;
  }, [entries, period, sortBy, sortAsc]);

  function toggleSort(key: SortKey) {
    if (sortBy === key) {
      setSortAsc(!sortAsc);
    } else {
      setSortBy(key);
      setSortAsc(false);
    }
  }

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
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-success/20 to-transparent" />

      <div className="flex items-center justify-between px-6 pt-6 pb-4">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-success/10">
            <Scan className="h-5 w-5 text-ark-success" />
          </div>
          <div>
            <h3 className="text-base font-semibold text-ark-text">Altcoin Scanner</h3>
            <p className="text-xs text-ark-text-disabled">{sorted.length} assets tracked</p>
          </div>
        </div>

        {/* Period selector */}
        <div className="flex rounded-lg bg-ark-fill-secondary p-0.5">
          {periods.map((p) => (
            <button
              key={p.key}
              onClick={() => setPeriod(p.key)}
              className={cn(
                'rounded-md px-4 py-1.5 text-xs font-semibold transition-all cursor-pointer',
                period === p.key
                  ? 'bg-ark-card text-ark-text shadow-sm'
                  : 'text-ark-text-tertiary hover:text-ark-text-secondary',
              )}
            >
              {p.label}
            </button>
          ))}
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-y border-ark-divider bg-ark-fill-secondary/50">
              <th className="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary">
                Asset
              </th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary">
                Price
              </th>
              <th className="hidden px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary sm:table-cell">
                Mkt Cap
              </th>
              <th
                className="cursor-pointer px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary transition-colors hover:text-ark-text-secondary"
                onClick={() => toggleSort('return')}
              >
                <span className="inline-flex items-center gap-1">
                  Return
                  <ArrowUpDown className={cn('h-3 w-3', sortBy === 'return' && 'text-ark-primary')} />
                </span>
              </th>
              <th
                className="cursor-pointer px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-ark-text-tertiary transition-colors hover:text-ark-text-secondary"
                onClick={() => toggleSort('vs_btc')}
              >
                <span className="inline-flex items-center gap-1">
                  vs BTC
                  <ArrowUpDown className={cn('h-3 w-3', sortBy === 'vs_btc' && 'text-ark-primary')} />
                </span>
              </th>
            </tr>
          </thead>
          <tbody>
            {sorted.map((entry, idx) => {
              const ret = getReturn(entry, period);
              const vsBtc = getVsBtc(entry, period);
              const isRetUp = ret >= 0;
              const isVsUp = vsBtc >= 0;
              return (
                <tr
                  key={entry.id}
                  className={cn(
                    'border-b border-ark-divider/30 transition-colors hover:bg-ark-fill-secondary/50',
                    idx % 2 === 1 && 'bg-ark-fill-secondary/20',
                  )}
                >
                  <td className="px-6 py-3">
                    <div className="flex items-center gap-3">
                      <div className="flex h-7 w-7 items-center justify-center rounded-full bg-ark-fill-secondary text-[10px] font-bold uppercase text-ark-text-tertiary">
                        {entry.symbol.slice(0, 2)}
                      </div>
                      <div>
                        <span className="text-sm font-semibold text-ark-text">
                          {entry.symbol}
                        </span>
                        <span className="ml-2 hidden text-xs text-ark-text-disabled sm:inline">
                          {entry.name}
                        </span>
                      </div>
                    </div>
                  </td>
                  <td className="fig px-4 py-3 text-right text-sm font-semibold text-ark-text">
                    {formatCurrency(entry.current_price)}
                  </td>
                  <td className="fig hidden px-4 py-3 text-right text-sm text-ark-text-secondary sm:table-cell">
                    {formatCurrency(entry.market_cap, 'USD', { compact: true })}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <span className={cn(
                      'fig inline-flex items-center gap-0.5 text-sm font-semibold',
                      isRetUp ? 'text-ark-success' : 'text-ark-error',
                    )}>
                      {isRetUp ? <ArrowUpRight className="h-3.5 w-3.5" /> : <ArrowDownRight className="h-3.5 w-3.5" />}
                      {formatPercent(ret)}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-right">
                    <span className={cn(
                      'fig text-sm font-medium',
                      isVsUp ? 'text-ark-success' : 'text-ark-error',
                    )}>
                      {formatPercent(vsBtc)}
                    </span>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </GlassCard>
  );
}
