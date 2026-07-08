'use client';

import { useState } from 'react';
import { Calendar, ChevronDown } from 'lucide-react';
import { Skeleton } from '@/components/ui';
import { useEconomicEvents } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';
import type { EconomicEvent } from '@/types';

const impactStyles: Record<string, { dot: string; label: string }> = {
  high: { dot: 'bg-ark-error', label: 'text-ark-error' },
  medium: { dot: 'bg-ark-warning', label: 'text-ark-warning' },
  low: { dot: 'bg-ark-text-disabled', label: 'text-ark-text-tertiary' },
};

function cleanAnalysis(md: string): string {
  return md.replace(/\*\*(.*?)\*\*/g, '$1').replace(/`/g, '').trim();
}

function EventRow({ e }: { e: EconomicEvent }) {
  const [open, setOpen] = useState(false);
  const imp = impactStyles[e.impact] ?? impactStyles.low;
  const released = e.actual != null && e.actual !== '';
  const beat = e.beat_miss?.toLowerCase();
  const beatColor = beat === 'beat' ? 'text-ark-success' : beat === 'miss' ? 'text-ark-error' : 'text-ark-text-tertiary';

  return (
    <div className="rounded-xl border border-ark-divider">
      <button onClick={() => setOpen((v) => !v)} className="flex w-full items-center gap-3 p-3 text-left">
        <span className={cn('h-2 w-2 shrink-0 rounded-full', imp.dot)} />
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-medium text-ark-text">{e.title}</p>
          <p className="text-[11px] text-ark-text-disabled">
            {e.country}{e.time ? ` · ${e.time}` : ''}{released && beat ? <span className={cn('ml-1 font-semibold capitalize', beatColor)}>· {beat}</span> : ''}
          </p>
        </div>
        <ChevronDown className={cn('h-4 w-4 shrink-0 text-ark-text-tertiary transition-transform', open && 'rotate-180')} />
      </button>

      {open && (
        <div className="border-t border-ark-divider p-3">
          <div className="grid grid-cols-3 gap-2 text-center">
            {[['Previous', e.previous], ['Forecast', e.forecast], ['Actual', e.actual]].map(([label, val]) => (
              <div key={label} className="rounded-lg bg-ark-fill-secondary/40 py-2">
                <p className="text-[9px] uppercase tracking-wider text-ark-text-tertiary">{label}</p>
                <p className={cn('fig mt-0.5 text-sm font-bold', label === 'Actual' ? beatColor : 'text-ark-text')}>{val ?? '—'}</p>
              </div>
            ))}
          </div>
          {e.analysis ? (
            <div className="mt-3">
              <p className="mb-1 text-[10px] font-bold uppercase tracking-wider text-ark-primary">Why it matters</p>
              <div className="space-y-1.5 text-[13px] leading-relaxed text-ark-text-secondary">
                {cleanAnalysis(e.analysis).split('\n').filter(Boolean).map((l, i) => <p key={i}>{l}</p>)}
              </div>
            </div>
          ) : (
            <p className="mt-3 text-xs text-ark-text-disabled">Analysis available after the release.</p>
          )}
        </div>
      )}
    </div>
  );
}

export function EventsCard() {
  const { data: events, isLoading } = useEconomicEvents();
  if (isLoading) return <div className="space-y-3">{[0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-14 w-full rounded-xl" />)}</div>;

  const list = events ?? [];
  if (!list.length) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-center">
        <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ark-fill-secondary"><Calendar className="h-6 w-6 text-ark-text-tertiary" /></div>
        <p className="mt-3 text-sm text-ark-text-tertiary">No economic events.</p>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <p className="text-[11px] text-ark-text-disabled">Tap an event for the data, forecast vs. actual, and why it matters.</p>
      {list.map((e) => <EventRow key={e.id} e={e} />)}
    </div>
  );
}
