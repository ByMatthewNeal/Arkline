'use client';

import { useQuery } from '@tanstack/react-query';
import { CheckCircle2, XCircle, RefreshCw } from 'lucide-react';
import { GlassCard, Skeleton } from '@/components/ui';
import { fetchHealth } from '@/lib/api/admin';
import { cn } from '@/lib/utils/format';

export default function AdminHealthPage() {
  const { data, isLoading, isError, refetch, isFetching, dataUpdatedAt } = useQuery({
    queryKey: ['admin-health'],
    queryFn: fetchHealth,
    staleTime: 120_000,
    refetchInterval: 300_000,
  });

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          {data && (
            <span className={cn('rounded-full px-2.5 py-1 text-[11px] font-bold', data.healthy ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-error/10 text-ark-error')}>
              {data.healthy ? 'All systems healthy' : `${data.checks.filter((c) => !c.ok).length} failing`}
            </span>
          )}
          {dataUpdatedAt > 0 && (
            <span className="text-[11px] text-ark-text-tertiary">checked {new Date(dataUpdatedAt).toLocaleTimeString()}</span>
          )}
        </div>
        <button onClick={() => refetch()} disabled={isFetching}
          className="flex items-center gap-1.5 rounded-lg bg-ark-fill-secondary px-3 py-1.5 text-xs font-semibold text-ark-text-secondary transition-colors hover:text-ark-text disabled:opacity-50">
          <RefreshCw className={cn('h-3.5 w-3.5', isFetching && 'animate-spin')} /> Run checks
        </button>
      </div>

      {isLoading ? (
        <div className="space-y-2">{[0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-14 w-full rounded-2xl" />)}</div>
      ) : isError ? (
        <p className="py-10 text-center text-sm text-ark-error">Could not run the health check — the function may need the CORS redeploy.</p>
      ) : (
        <div className="space-y-2">
          {(data?.checks ?? []).map((c) => (
            <GlassCard key={c.name} className={cn(!c.ok && 'border border-ark-error/30')}>
              <div className="flex items-center gap-3">
                {c.ok
                  ? <CheckCircle2 className="h-5 w-5 shrink-0 text-ark-success" />
                  : <XCircle className="h-5 w-5 shrink-0 text-ark-error" />}
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold text-ark-text">{c.name}</p>
                  <p className={cn('text-[12px]', c.ok ? 'text-ark-text-tertiary' : 'text-ark-error')}>{c.detail}</p>
                </div>
              </div>
            </GlassCard>
          ))}
        </div>
      )}

      <p className="text-[10px] leading-relaxed text-ark-text-disabled">
        Same checks the hourly cron runs (CoinGecko, Claude, FMP, crypto cache, briefing, signal pipeline, curated news). A failing check also pushes you an alert once per day.
      </p>
    </div>
  );
}
