'use client';

/**
 * "Updated Xm ago" + manual refresh — the desktop equivalent of iOS's
 * pull-to-refresh and StaleDataBanner. Shows the age of the freshest data
 * in the query cache and lets the user force-refetch everything.
 */

import { useSyncExternalStore } from 'react';
import { RefreshCw } from 'lucide-react';
import { useQueryClient, useIsFetching } from '@tanstack/react-query';
import { cn } from '@/lib/utils/format';

/**
 * Current time, quantized to the tick interval so the snapshot is stable
 * between ticks (render-pure). Re-renders subscribers every `intervalMs`.
 */
function useNowTick(intervalMs: number): number {
  return useSyncExternalStore(
    (onChange) => {
      const id = window.setInterval(onChange, intervalMs);
      return () => window.clearInterval(id);
    },
    () => Math.floor(Date.now() / intervalMs) * intervalMs,
    () => 0,
  );
}

function ageLabel(ms: number): string {
  const min = Math.floor(ms / 60_000);
  if (min < 1) return 'Updated just now';
  if (min === 1) return 'Updated 1m ago';
  if (min < 60) return `Updated ${min}m ago`;
  const h = Math.floor(min / 60);
  return `Updated ${h}h ago`;
}

export function RefreshStatus() {
  const queryClient = useQueryClient();
  const fetching = useIsFetching();
  const now = useNowTick(30_000);

  const newest = queryClient
    .getQueryCache()
    .getAll()
    .reduce((max, q) => Math.max(max, q.state.dataUpdatedAt ?? 0), 0);

  const label = newest ? ageLabel(now - newest) : '';
  const isStale = newest > 0 && now - newest > 10 * 60_000;

  return (
    <button
      onClick={() => queryClient.invalidateQueries()}
      title="Refresh all data"
      className={cn(
        'flex items-center gap-1.5 rounded-lg px-2.5 py-1.5 text-xs font-medium transition-colors hover:bg-ark-fill-secondary',
        isStale ? 'text-ark-warning' : 'text-ark-text-tertiary hover:text-ark-text',
      )}
    >
      <RefreshCw className={cn('h-3.5 w-3.5', fetching > 0 && 'animate-spin')} />
      <span suppressHydrationWarning className="fig hidden sm:inline">
        {fetching > 0 ? 'Refreshing…' : label}
      </span>
    </button>
  );
}
