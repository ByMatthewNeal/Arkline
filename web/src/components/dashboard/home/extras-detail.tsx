'use client';

import { Skeleton } from '@/components/ui';
import { cn, formatPercent } from '@/lib/utils/format';
import { useUSFutures, usePerpPremium, useFedWatch } from '@/lib/hooks/use-market';

function Info({ title, lines }: { title: string; lines: string[] }) {
  return (
    <div>
      <h4 className="mb-1.5 text-sm font-semibold text-ark-text">{title}</h4>
      <div className="space-y-1 text-[13px] leading-relaxed text-ark-text-secondary">
        {lines.map((l, i) => <p key={i}>{l}</p>)}
      </div>
    </div>
  );
}

const empty = <p className="py-8 text-center text-sm text-ark-text-tertiary">Awaiting data — the market-extras job will populate this shortly.</p>;

// ── US Futures ──────────────────────────────────────────────────────────────
export function USFuturesDetail() {
  const { data, isLoading } = useUSFutures();
  if (isLoading) return <Skeleton className="h-64 w-full" />;
  const futures = data ?? [];
  if (!futures.length) return empty;

  return (
    <div className="space-y-5 pb-4">
      <div className="space-y-2">
        {futures.map((f) => (
          <div key={f.symbol} className="flex items-center justify-between rounded-xl border border-ark-divider p-3.5">
            <div>
              <p className="text-sm font-semibold text-ark-text">{f.name}</p>
              <p className="text-[11px] text-ark-text-disabled">{f.symbol} futures</p>
            </div>
            <div className="text-right">
              <p className="fig text-lg font-bold text-ark-text">{f.price.toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
              <p className={cn('fig text-xs font-semibold', f.change_percent >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                {f.change >= 0 ? '+' : ''}{f.change.toLocaleString(undefined, { maximumFractionDigits: 0 })} ({formatPercent(f.change_percent)})
              </p>
            </div>
          </div>
        ))}
      </div>
      <Info title="US Index Futures" lines={[
        'Front-month futures for the S&P 500 (ES), Dow (YM), and Nasdaq (NQ). Outside cash-market hours these reflect overnight sentiment; on weekends they show the last Friday session move.',
        'Equity futures often lead crypto risk appetite at the open.',
      ]} />
    </div>
  );
}

// ── Perp Premium ────────────────────────────────────────────────────────────
export function PerpPremiumDetail() {
  const { data, isLoading } = usePerpPremium();
  if (isLoading) return <Skeleton className="h-64 w-full" />;
  const perps = data ?? [];
  if (!perps.length) return empty;

  return (
    <div className="space-y-5 pb-4">
      <div className="space-y-2">
        {perps.map((p) => {
          const bullish = p.funding_rate >= 0;
          return (
            <div key={p.symbol} className="rounded-xl border border-ark-divider p-3.5">
              <div className="flex items-center justify-between">
                <span className="text-sm font-semibold text-ark-text">{p.symbol}</span>
                <span className={cn('text-sm font-bold', bullish ? 'text-ark-success' : 'text-ark-error')}>{(p.funding_rate * 100).toFixed(4)}%</span>
              </div>
              <div className="mt-1 flex items-center justify-between text-[11px] text-ark-text-disabled">
                <span>{bullish ? 'Longs pay shorts (bullish bias)' : 'Shorts pay longs (bearish bias)'}</span>
                <span className="fig">{p.annualized_rate >= 0 ? '+' : ''}{p.annualized_rate.toFixed(1)}% APR</span>
              </div>
            </div>
          );
        })}
      </div>
      <Info title="What is Perp Premium?" lines={[
        'Perpetual futures use a funding rate to keep their price tethered to spot. Positive funding means longs pay shorts (leverage skewed bullish); negative means shorts pay longs (skewed bearish).',
        'Extreme funding often precedes mean-reversion squeezes.',
      ]} />
    </div>
  );
}

// ── Fed Watch ───────────────────────────────────────────────────────────────
export function FedWatchDetail() {
  const { data, isLoading } = useFedWatch();
  if (isLoading) return <Skeleton className="h-64 w-full" />;
  const meetings = data ?? [];
  if (!meetings.length) return empty;
  const fmt = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });

  return (
    <div className="space-y-5 pb-4">
      <div className="space-y-3">
        {meetings.map((m) => (
          <div key={m.meeting_date} className="rounded-xl border border-ark-divider p-3.5">
            <div className="flex items-center justify-between">
              <span className="text-sm font-semibold text-ark-text">{fmt(m.meeting_date)}</span>
            </div>
            <div className="mt-2 flex h-2 overflow-hidden rounded-full bg-ark-fill-secondary">
              <div className="h-full bg-ark-success" style={{ width: `${m.cut_probability}%` }} />
              <div className="h-full bg-ark-text-tertiary" style={{ width: `${m.hold_probability}%` }} />
              <div className="h-full bg-ark-error" style={{ width: `${m.hike_probability}%` }} />
            </div>
            <div className="mt-1.5 flex justify-between text-[11px]">
              <span className="text-ark-success">Cut {m.cut_probability}%</span>
              <span className="text-ark-text-tertiary">Hold {m.hold_probability}%</span>
              <span className="text-ark-error">Hike {m.hike_probability}%</span>
            </div>
          </div>
        ))}
      </div>
      <Info title="CME FedWatch" lines={[
        'Estimated probabilities for upcoming FOMC rate decisions, derived from the current fed funds rate and the meeting calendar.',
        'Rate-cut expectations are broadly risk-on for crypto; hike or hold-higher expectations are a headwind.',
      ]} />
    </div>
  );
}
