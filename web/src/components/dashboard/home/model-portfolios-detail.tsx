'use client';

/**
 * Model Portfolios — full drawer detail (iOS ModelPortfolioDetailView parity):
 * strategy tabs (Core / Edge / Alpha), follow/unfollow persisted to the
 * profile (same column iOS reads), NAV vs. SPY benchmark chart, current
 * allocations, and the rebalance/trade log.
 */

import { useState } from 'react';
import { Area, AreaChart, Line, ResponsiveContainer, Tooltip, XAxis, YAxis, ReferenceLine } from 'recharts';
import { BellRing, Check, ArrowUpRight, ArrowDownRight } from 'lucide-react';
import { Badge, Skeleton, useToast } from '@/components/ui';
import {
  useModelPortfolios,
  useModelPortfolioNav,
  useBenchmarkNav,
  useModelPortfolioTrades,
  useFollowedModelPortfolio,
  useFollowModelPortfolio,
} from '@/lib/hooks/use-model-portfolios';
import type { AllocationDetail } from '@/lib/api/model-portfolios';
import { formatPercent, cn } from '@/lib/utils/format';

const RANGES = ['1M', '3M', '6M', '1Y'] as const;
type Range = (typeof RANGES)[number];
const RANGE_DAYS: Record<Range, number> = { '1M': 30, '3M': 90, '6M': 180, '1Y': 365 };

function allocPct(v: AllocationDetail | number): number {
  return typeof v === 'number' ? v : Number(v.pct ?? 0);
}

export function ModelPortfoliosDetail() {
  const { data: portfolios, isLoading } = useModelPortfolios();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [range, setRange] = useState<Range>('3M');
  const [scrubIdx, setScrubIdx] = useState<number | null>(null);
  const toast = useToast();

  const active = portfolios?.find((p) => p.id === selectedId) ?? portfolios?.[0];
  const { data: nav } = useModelPortfolioNav(active?.id);
  const { data: benchmark } = useBenchmarkNav();
  const { data: trades } = useModelPortfolioTrades(active?.id);
  const { data: followed } = useFollowedModelPortfolio();
  const follow = useFollowModelPortfolio();

  if (isLoading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-10 w-full" />
        <Skeleton className="h-48 w-full" />
        <Skeleton className="h-32 w-full" />
      </div>
    );
  }
  if (!portfolios?.length || !active) {
    return <p className="py-8 text-center text-sm text-ark-text-tertiary">No model portfolios available.</p>;
  }

  const isFollowed = followed === active.strategy;

  // Normalize both series to % return over the selected window.
  const days = RANGE_DAYS[range];
  const navWindow = (nav ?? []).slice(-days);
  const benchByDate = new Map((benchmark ?? []).map((b) => [b.nav_date, b.nav]));
  const navStart = navWindow[0]?.nav || 1;
  const benchStart = navWindow
    .map((p) => benchByDate.get(p.nav_date))
    .find((b): b is number => b != null) ?? null;
  const chart = navWindow.map((p) => {
    const b = benchByDate.get(p.nav_date);
    return {
      date: p.nav_date,
      strategy: ((p.nav - navStart) / navStart) * 100,
      spy: b != null && benchStart ? ((b - benchStart) / benchStart) * 100 : null,
    };
  });

  const latest = navWindow[navWindow.length - 1];
  const totalReturn = latest ? ((latest.nav - navStart) / navStart) * 100 : 0;

  // Scrubbing the chart drives the header return line.
  const scrubbed = scrubIdx != null ? chart[scrubIdx] ?? null : null;
  const headerReturn = scrubbed ? scrubbed.strategy : totalReturn;
  const headerCaption = scrubbed
    ? new Date(scrubbed.date + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
    : range;
  const allocations = latest
    ? Object.entries(latest.allocations ?? {})
        .map(([asset, v]) => ({ asset, pct: allocPct(v) }))
        .filter((a) => a.pct > 0.01)
        .sort((a, b) => b.pct - a.pct)
    : [];

  const toggleFollow = () => {
    const next = isFollowed ? null : active.strategy;
    follow.mutate(next, {
      onSuccess: () =>
        toast.success(next ? `Following ${active.name} — rebalances will appear in your feed` : `Unfollowed ${active.name}`),
      onError: () => toast.error('Could not update. Please try again.'),
    });
  };

  return (
    <div className="space-y-5 pb-4">
      {/* Strategy tabs */}
      <div className="flex gap-1 overflow-x-auto rounded-full bg-ark-fill-secondary/60 p-1">
        {portfolios.map((p) => (
          <button
            key={p.id}
            onClick={() => setSelectedId(p.id)}
            className={cn(
              'flex shrink-0 items-center gap-1 rounded-full px-3 py-1.5 text-xs font-semibold capitalize transition-colors',
              p.id === active.id ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text',
            )}
          >
            {p.strategy}
            {followed === p.strategy && <Check className="h-3 w-3" />}
          </button>
        ))}
      </div>

      {/* Header: name + follow */}
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-lg font-semibold text-ark-text">{active.name}</p>
          {active.description && <p className="mt-0.5 text-xs text-ark-text-tertiary">{active.description}</p>}
          {latest && (
            <div className="mt-1.5 flex items-center gap-2">
              <span className={cn('fig text-sm font-bold', headerReturn >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                {formatPercent(headerReturn)} <span className="font-normal text-ark-text-tertiary">({headerCaption})</span>
                {scrubbed?.spy != null && (
                  <span className="fig ml-2 font-semibold text-ark-text-tertiary">SPY {formatPercent(scrubbed.spy)}</span>
                )}
              </span>
              {latest.macro_regime && <Badge variant="default">{latest.macro_regime}</Badge>}
              {latest.btc_signal && (
                <Badge variant={latest.btc_signal.includes('bull') ? 'success' : latest.btc_signal.includes('bear') ? 'error' : 'default'}>
                  BTC {latest.btc_signal}
                </Badge>
              )}
            </div>
          )}
        </div>
        <button
          onClick={toggleFollow}
          disabled={follow.isPending}
          className={cn(
            'flex shrink-0 items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors disabled:opacity-50',
            isFollowed
              ? 'bg-ark-primary/10 text-ark-primary hover:bg-ark-primary/20'
              : 'bg-ark-primary text-white hover:bg-ark-accent-dark',
          )}
        >
          {isFollowed ? <Check className="h-3.5 w-3.5" /> : <BellRing className="h-3.5 w-3.5" />}
          {isFollowed ? 'Following' : 'Follow'}
        </button>
      </div>

      {/* NAV vs SPY */}
      <div>
        <div className="mb-2 flex items-center justify-between">
          <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Performance vs. S&P 500</p>
          <div className="flex gap-1 rounded-full bg-ark-fill-secondary/60 p-0.5">
            {RANGES.map((r) => (
              <button
                key={r}
                onClick={() => setRange(r)}
                className={cn(
                  'rounded-full px-2 py-0.5 text-[10px] font-semibold transition-colors',
                  range === r ? 'bg-ark-primary text-white' : 'text-ark-text-tertiary hover:text-ark-text',
                )}
              >
                {r}
              </button>
            ))}
          </div>
        </div>
        {chart.length > 1 ? (
          <>
            <div className="h-52 w-full cursor-crosshair">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart
                  data={chart}
                  margin={{ top: 4, right: 10, bottom: 0, left: 4 }}
                  onMouseMove={(state) => {
                    const idx = (state as { activeTooltipIndex?: number | null })?.activeTooltipIndex;
                    setScrubIdx(typeof idx === 'number' ? idx : null);
                  }}
                  onMouseLeave={() => setScrubIdx(null)}
                >
                  <defs>
                    <linearGradient id="mpFill" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor="var(--ark-primary)" stopOpacity={0.12} />
                      <stop offset="70%" stopColor="var(--ark-primary)" stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="date" hide />
                  <YAxis hide domain={['auto', 'auto']} />
                  {/* Zero line — everything is % return from the window start. */}
                  <ReferenceLine y={0} stroke="var(--ark-text-disabled)" strokeDasharray="2 4" strokeOpacity={0.5} />
                  <Tooltip
                    cursor={{ stroke: 'var(--ark-text-tertiary)', strokeDasharray: '3 3', strokeOpacity: 0.5 }}
                    content={() => null}
                  />
                  <Area
                    type="monotone" dataKey="strategy"
                    stroke="var(--ark-primary)" strokeWidth={2} fill="url(#mpFill)"
                    activeDot={{ r: 4, fill: 'var(--ark-primary)', stroke: 'var(--ark-card)', strokeWidth: 2 }}
                  />
                  <Line type="monotone" dataKey="spy" stroke="var(--ark-text-tertiary)" strokeWidth={1.5} strokeDasharray="4 3" dot={false} activeDot={false} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
            <div className="mt-1 flex justify-between px-1 text-[9px] font-medium uppercase tracking-wide text-ark-text-disabled">
              <span>{chart[0] ? new Date(chart[0].date + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : ''}</span>
              <span className="text-ark-text-tertiary">— {active.strategy} &nbsp;·&nbsp; ┄ SPY</span>
              <span>{chart[chart.length - 1] ? new Date(chart[chart.length - 1].date + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' }) : ''}</span>
            </div>
          </>
        ) : (
          <p className="py-6 text-center text-sm text-ark-text-tertiary">No NAV history yet.</p>
        )}
      </div>

      {/* Current allocations */}
      {allocations.length > 0 && (
        <div>
          <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Current allocation</p>
          <div className="space-y-1.5">
            {allocations.map((a) => (
              <div key={a.asset} className="flex items-center gap-3">
                <span className="w-14 shrink-0 text-sm font-semibold text-ark-text">{a.asset}</span>
                <div className="h-2 flex-1 overflow-hidden rounded-full bg-ark-fill-secondary">
                  <div className="h-full rounded-full bg-ark-primary/70" style={{ width: `${Math.min(100, a.pct)}%` }} />
                </div>
                <span className="fig w-12 shrink-0 text-right text-xs font-medium text-ark-text-secondary">{a.pct.toFixed(1)}%</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Trade log */}
      {(trades ?? []).length > 0 && (
        <div>
          <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Rebalance history</p>
          <div className="space-y-2">
            {(trades ?? []).map((t) => {
              const changes = Object.keys({ ...t.from_allocation, ...t.to_allocation })
                .map((asset) => ({
                  asset,
                  from: Number(t.from_allocation?.[asset] ?? 0),
                  to: Number(t.to_allocation?.[asset] ?? 0),
                }))
                .filter((c) => Math.abs(c.to - c.from) > 0.05)
                .sort((a, b) => Math.abs(b.to - b.from) - Math.abs(a.to - a.from));
              return (
                <div key={t.id} className="rounded-xl border border-ark-divider p-3">
                  <div className="flex items-center justify-between">
                    <p className="text-xs font-semibold text-ark-text">
                      {new Date(t.trade_date + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                    </p>
                    <Badge variant="default">{t.trigger}</Badge>
                  </div>
                  {changes.length > 0 && (
                    <div className="mt-2 space-y-1">
                      {changes.slice(0, 6).map((c) => {
                        const up = c.to >= c.from;
                        return (
                          <div key={c.asset} className="flex items-center gap-2 text-xs">
                            <span className="w-14 font-medium text-ark-text">{c.asset}</span>
                            <span className="fig text-ark-text-disabled">{c.from.toFixed(1)}%</span>
                            {up ? <ArrowUpRight className="h-3 w-3 text-ark-success" /> : <ArrowDownRight className="h-3 w-3 text-ark-error" />}
                            <span className="fig font-semibold text-ark-text">{c.to.toFixed(1)}%</span>
                            <span className={cn('fig ml-auto font-medium', up ? 'text-ark-success' : 'text-ark-error')}>
                              {up ? '+' : ''}{(c.to - c.from).toFixed(1)}%
                            </span>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}

      <p className="text-[10px] leading-relaxed text-ark-text-disabled">
        Model portfolios are simulated strategies for educational purposes only and do not constitute financial advice.
        Past performance does not guarantee future results.
      </p>
    </div>
  );
}
