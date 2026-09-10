'use client';

import { Skeleton } from '@/components/ui';
import { cn, formatPercent } from '@/lib/utils/format';
import { useUSFutures, usePerpPremium, useFedWatch } from '@/lib/hooks/use-market';

/** Structured "about this data" footer: labeled rows scan faster than prose. */
function Info({ title, items }: { title: string; items: { label: string; text: string }[] }) {
  return (
    <div className="rounded-xl bg-ark-fill-secondary/40 p-3.5">
      <h4 className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">{title}</h4>
      <div className="mt-2 space-y-2">
        {items.map((item) => (
          <div key={item.label} className="flex gap-3">
            <span className="w-20 shrink-0 pt-px text-[10px] font-semibold uppercase tracking-wide text-ark-text-tertiary">{item.label}</span>
            <p className="text-xs leading-relaxed text-ark-text-secondary">{item.text}</p>
          </div>
        ))}
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

  // Session (ET) + overall bias
  const parts = new Intl.DateTimeFormat('en-US', { timeZone: 'America/New_York', weekday: 'short', hour: '2-digit', minute: '2-digit', hour12: false }).formatToParts(new Date());
  const wd = parts.find((p) => p.type === 'weekday')?.value ?? '';
  const t = Number(parts.find((p) => p.type === 'hour')?.value ?? 0) * 60 + Number(parts.find((p) => p.type === 'minute')?.value ?? 0);
  const session = (wd === 'Sat' || wd === 'Sun') ? 'Weekend'
    : t >= 240 && t < 570 ? 'Pre-Market'
    : t >= 570 && t < 960 ? 'Regular Session'
    : t >= 960 && t < 1200 ? 'After Hours'
    : 'Overnight';
  const up = futures.filter((f) => f.change_percent >= 0).length;
  const down = futures.length - up;
  const bias = up > down ? 'Bullish' : down > up ? 'Bearish' : 'Mixed';
  const biasColor = bias === 'Bullish' ? 'var(--ark-success)' : bias === 'Bearish' ? 'var(--ark-error)' : 'var(--ark-warning)';
  const sessionWord = session === 'Regular Session' ? 'Session' : session === 'Weekend' ? "Friday's close" : session.toLowerCase();

  return (
    <div className="space-y-5 pb-4">
      {/* Session-aware bias banner + per-index breadth strip */}
      <div className="rounded-2xl p-4 text-center" style={{ backgroundColor: `${biasColor}14` }}>
        <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">{session}</p>
        <p className="mt-1 font-[family-name:var(--font-urbanist)] text-2xl font-bold" style={{ color: biasColor }}>{bias}</p>
        <p className="mt-1 text-xs text-ark-text-secondary">{up} of {futures.length} index futures higher this {sessionWord}</p>
        <div className="mx-auto mt-3 flex max-w-xs gap-1">
          {futures.map((f) => (
            <div key={f.symbol} className="flex-1">
              <div className={cn('h-1.5 rounded-full', f.change_percent >= 0 ? 'bg-ark-success' : 'bg-ark-error')} />
              <p className="mt-1 text-[9px] font-semibold uppercase text-ark-text-tertiary">{f.symbol}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Index cards — side by side so the row doesn't stretch across dead space */}
      <div className="grid gap-2 sm:grid-cols-3">
        {futures.map((f) => {
          const bullish = f.change_percent >= 0;
          // Centered strength bar, full scale at ±1.5% (a big overnight move).
          const fill = Math.min(Math.abs(f.change_percent) / 1.5, 1) * 50;
          return (
            <div key={f.symbol} className={cn(
              'rounded-xl border p-4 text-center',
              bullish ? 'border-ark-success/20 bg-ark-success/[0.03]' : 'border-ark-error/20 bg-ark-error/[0.03]',
            )}>
              <p className="text-sm font-semibold text-ark-text">{f.name}</p>
              <p className="text-[10px] uppercase tracking-wider text-ark-text-disabled">{f.symbol} futures</p>
              <p className="fig mt-2 font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">
                {f.price.toLocaleString(undefined, { maximumFractionDigits: 0 })}
              </p>
              <p className={cn('fig mt-0.5 text-xs font-semibold', bullish ? 'text-ark-success' : 'text-ark-error')}>
                {f.change >= 0 ? '+' : ''}{f.change.toLocaleString(undefined, { maximumFractionDigits: 0 })} ({formatPercent(f.change_percent)})
              </p>
              <div className="relative mx-auto mt-3 h-1.5 w-full rounded-full bg-ark-fill-secondary">
                <div className="absolute left-1/2 top-0 h-full w-px bg-ark-divider" />
                <div
                  className={cn('absolute top-0 h-full rounded-full', bullish ? 'bg-ark-success' : 'bg-ark-error')}
                  style={bullish ? { left: '50%', width: `${fill}%` } : { right: '50%', width: `${fill}%` }}
                />
              </div>
              <p className={cn('mt-2 inline-block rounded-full px-2 py-0.5 text-[10px] font-bold', bullish ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-error/10 text-ark-error')}>
                {bullish ? 'Bullish' : 'Bearish'}
              </p>
            </div>
          );
        })}
      </div>
      <Info title="About this data" items={[
        { label: 'What', text: 'Front-month index futures: S&P 500 (ES), Dow (YM), Nasdaq (NQ).' },
        { label: 'Timing', text: 'Outside market hours this is overnight sentiment. On weekends, it shows Friday’s session.' },
        { label: 'Why it matters', text: 'Equity futures often lead crypto risk appetite at the open.' },
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
      <Info title="About this data" items={[
        { label: 'What', text: 'Funding rates keep perpetual futures tethered to spot price.' },
        { label: 'Reading it', text: 'Positive → longs pay shorts (leverage skewed bullish). Negative → shorts pay longs (skewed bearish).' },
        { label: 'Why it matters', text: 'Extreme funding often precedes mean-reversion squeezes.' },
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
      <Info title="About this data" items={[
        { label: 'What', text: 'Estimated probabilities for upcoming FOMC rate decisions.' },
        { label: 'Source', text: 'Derived from the current fed funds rate and the meeting calendar.' },
        { label: 'Why it matters', text: 'Cut expectations are broadly risk-on for crypto; hold-higher or hikes are a headwind.' },
      ]} />
    </div>
  );
}
