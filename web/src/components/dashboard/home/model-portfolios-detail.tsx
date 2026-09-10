'use client';

/**
 * Model Portfolios — full drawer detail (iOS ModelPortfolioDetailView parity):
 * strategy tabs (crypto Core/Edge, curated Equity, systematic Metals — the
 * retired Alpha book is filtered out server-side), follow/unfollow persisted to
 * the profile (same column iOS reads), NAV vs. SPY benchmark chart, a
 * metals-aware positioning strip, current allocations, and a history section
 * that toggles between the derived Position timeline and the raw rebalance log.
 */

import { useMemo, useState } from 'react';
import { Area, AreaChart, Line, ResponsiveContainer, Tooltip, XAxis, YAxis, ReferenceLine } from 'recharts';
import { BellRing, Check, ArrowUpRight, ArrowDownRight, Circle, CheckCircle2, ChevronDown } from 'lucide-react';
import { Badge, Skeleton, useToast } from '@/components/ui';
import {
  useModelPortfolios,
  useModelPortfolioNav,
  useBenchmarkNav,
  useModelPortfolioTrades,
  useFollowedModelPortfolio,
  useFollowModelPortfolio,
} from '@/lib/hooks/use-model-portfolios';
import { allocPct, buildPositionHistory, type AllocationDetail } from '@/lib/api/model-portfolios';
import { formatPercent, cn } from '@/lib/utils/format';

const RANGES = ['1M', '3M', '6M', '1Y', 'ALL'] as const;
type Range = (typeof RANGES)[number];
const RANGE_DAYS: Record<Range, number> = { '1M': 30, '3M': 90, '6M': 180, '1Y': 365, 'ALL': 100000 };

/** Tab label: "Arkline Equity Core" → "Equity Core" (iOS picker names). */
const tabLabel = (name: string) => name.replace(/^Arkline\s+/i, '');

/** Friendly names for the metals book's synthetic tickers. */
const ASSET_LABEL: Record<string, string> = { GOLD: 'Gold', CASH: 'Cash' };
const assetLabel = (a: string) => ASSET_LABEL[a] ?? a;

/** Gold valuation-zone → friendly label + tone. Mirrors iOS zoneLabel/zoneColor. */
const ZONE_MAP: Record<string, { label: string; cls: string }> = {
  deepValue: { label: 'Deep Value', cls: 'text-emerald-500' },
  value: { label: 'Accumulate', cls: 'text-lime-500' },
  fair: { label: 'Fair', cls: 'text-amber-500' },
  elevated: { label: 'Elevated', cls: 'text-orange-500' },
  overextended: { label: 'Stretched', cls: 'text-red-500' },
};
function zoneTone(zone: string | null | undefined): { label: string; cls: string } | null {
  if (!zone) return null;
  return ZONE_MAP[zone] ?? { label: zone, cls: 'text-ark-text-secondary' };
}

function fmtDate(iso: string, withYear = true) {
  return new Date(iso + 'T00:00:00').toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    ...(withYear ? { year: 'numeric' } : {}),
  });
}

export function ModelPortfoliosDetail() {
  const { data: portfolios, isLoading } = useModelPortfolios();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [range, setRange] = useState<Range>('3M');
  const [scrubIdx, setScrubIdx] = useState<number | null>(null);
  const [historyTab, setHistoryTab] = useState<'positions' | 'rebalances'>('positions');
  const [expandedTrade, setExpandedTrade] = useState<string | null>(null);
  const toast = useToast();

  const active = portfolios?.find((p) => p.id === selectedId) ?? portfolios?.[0];
  const { data: nav } = useModelPortfolioNav(active?.id);
  const { data: benchmark } = useBenchmarkNav();
  const { data: trades } = useModelPortfolioTrades(active?.id);
  const { data: followed } = useFollowedModelPortfolio();
  const follow = useFollowModelPortfolio();

  // Derived position timeline (entered/exited/P&L per name) from trades + NAV.
  const positions = useMemo(
    () => buildPositionHistory(trades ?? [], nav ?? []),
    [trades, nav],
  );

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
  // Open-position P&L per ticker (iOS shows +3.3% next to each holding).
  const openPnl = new Map(positions.filter((p) => p.exitedDate == null && p.pnlPct != null).map((p) => [p.ticker, p.pnlPct as number]));
  const allocations = latest
    ? Object.entries(latest.allocations ?? {})
        .map(([asset, v]) => {
          const detail = v && typeof v === 'object' ? (v as AllocationDetail) : null;
          const pct = allocPct(v);
          return {
            asset,
            pct,
            entry: detail?.entry_price && detail.entry_price > 0 ? detail.entry_price : null,
            value: detail?.value && detail.value > 0 ? detail.value : (latest.nav * pct) / 100,
            pnl: openPnl.get(asset) ?? null,
          };
        })
        .filter((a) => a.pct > 0.01)
        .sort((a, b) => b.pct - a.pct)
    : [];

  // ── Metals-aware positioning strip ────────────────────────────────────────
  const isMetals = active.asset_class === 'metal';
  const sig = latest?.signal_context ?? null;
  const zone = zoneTone(sig?.zone);
  const goldRaw = latest?.allocations?.GOLD;
  const goldDetail: AllocationDetail | null =
    goldRaw && typeof goldRaw === 'object' ? goldRaw : null;
  const goldCostBasis =
    goldDetail?.entry_price && goldDetail.entry_price > 0 ? goldDetail.entry_price : null;
  const goldSpot =
    goldDetail?.value && goldDetail?.qty && goldDetail.qty > 0
      ? goldDetail.value / goldDetail.qty
      : null;

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
              'flex shrink-0 items-center gap-1 rounded-full px-3 py-1.5 text-xs font-semibold transition-colors',
              p.id === active.id ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text',
            )}
          >
            {tabLabel(p.name)}
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

      {/* NAV headline + since-returns (iOS strategy header) */}
      {(() => {
        const series = nav ?? [];
        const last = series[series.length - 1];
        if (!last) return null;
        const inception = active.starting_nav > 0 ? ((last.nav - active.starting_nav) / active.starting_nav) * 100 : null;
        const janISO = `${new Date(last.nav_date + 'T00:00:00').getFullYear()}-01-01`;
        const janPoint = series.find((p) => p.nav_date >= janISO);
        const ytd = janPoint ? ((last.nav - janPoint.nav) / janPoint.nav) * 100 : null;
        const firstYear = series[0] ? new Date(series[0].nav_date + 'T00:00:00').getFullYear() : null;
        return (
          <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4 text-center">
            <p className="fig font-[family-name:var(--font-urbanist)] text-3xl font-bold text-ark-text">
              ${last.nav.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
            </p>
            <p className="mt-0.5 text-[11px] text-ark-text-tertiary">as of {fmtDate(last.nav_date)}</p>
            <div className="mt-2.5 flex items-center justify-center gap-8">
              {inception != null && firstYear != null && (
                <div>
                  <p className="text-[10px] text-ark-text-tertiary">Since Jan {firstYear}</p>
                  <p className={cn('fig text-sm font-bold', inception >= 0 ? 'text-ark-success' : 'text-ark-error')}>{formatPercent(inception)}</p>
                </div>
              )}
              {ytd != null && (
                <div>
                  <p className="text-[10px] text-ark-text-tertiary">Since Jan {new Date(last.nav_date + 'T00:00:00').getFullYear()}</p>
                  <p className={cn('fig text-sm font-bold', ytd >= 0 ? 'text-ark-success' : 'text-ark-error')}>{formatPercent(ytd)}</p>
                </div>
              )}
            </div>
          </div>
        );
      })()}

      {/* Hypothetical-model disclaimer (iOS parity, prominent) */}
      <div className="rounded-2xl border border-ark-warning/30 bg-ark-warning/5 p-3.5">
        <p className="text-xs font-bold text-ark-text">ⓘ Hypothetical model portfolio, not investment advice</p>
        <p className="mt-1 text-[11px] leading-relaxed text-ark-text-secondary">
          AI-generated systematic strategy for educational and informational purposes only. Performance shown is simulated, not actual — history before launch is backtested. Past performance does not guarantee future results. Always do your own research and consult a licensed financial advisor before making investment decisions.
        </p>
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

      {/* Metals positioning strip — gold valuation zone, target weight, RSI */}
      {isMetals && (zone || sig?.target_gold != null || sig?.rsi != null) && (
        <div className="rounded-2xl border border-amber-500/25 bg-amber-500/5 p-3">
          <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-amber-600 dark:text-amber-400">
            How the book is positioned
          </p>
          <div className="grid grid-cols-3 gap-2">
            <div>
              <p className="text-[10px] uppercase tracking-wide text-ark-text-tertiary">Gold zone</p>
              <p className={cn('mt-0.5 text-sm font-semibold capitalize', zone?.cls ?? 'text-ark-text-secondary')}>
                {zone?.label ?? '—'}
              </p>
            </div>
            <div>
              <p className="text-[10px] uppercase tracking-wide text-ark-text-tertiary">Target gold</p>
              <p className="fig mt-0.5 text-sm font-semibold text-ark-text">
                {sig?.target_gold != null ? `${Math.round(sig.target_gold * (sig.target_gold <= 1 ? 100 : 1))}%` : '—'}
              </p>
            </div>
            <div>
              <p className="text-[10px] uppercase tracking-wide text-ark-text-tertiary">Gold RSI</p>
              <p className="fig mt-0.5 text-sm font-semibold text-ark-text">
                {sig?.rsi != null ? sig.rsi.toFixed(0) : '—'}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Strategy Signals (iOS parity): the inputs driving the book right now */}
      {!isMetals && latest && (latest.macro_regime || latest.btc_risk_category || latest.btc_signal) && (
        <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
          <p className="mb-2.5 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Strategy Signals</p>
          <div className="grid grid-cols-2 gap-3">
            {latest.macro_regime && (
              <div>
                <p className="text-[10px] uppercase tracking-wide text-ark-text-tertiary">Macro Regime</p>
                <p className={cn('mt-0.5 text-sm font-bold', latest.macro_regime.toLowerCase().includes('risk-on') ? 'text-ark-success' : latest.macro_regime.toLowerCase().includes('risk-off') ? 'text-ark-error' : 'text-ark-text')}>{latest.macro_regime}</p>
              </div>
            )}
            {latest.btc_risk_category && (
              <div>
                <p className="text-[10px] uppercase tracking-wide text-ark-text-tertiary">BTC Risk</p>
                <p className="mt-0.5 text-sm font-bold capitalize text-ark-text">{latest.btc_risk_category}</p>
              </div>
            )}
          </div>
          {latest.btc_signal && (() => {
            const s = latest.btc_signal.toLowerCase();
            const bull = s.includes('bull');
            const bear = s.includes('bear');
            const c = bull ? 'var(--ark-success)' : bear ? 'var(--ark-error)' : 'var(--ark-warning)';
            const fill = bull ? 78 : bear ? 22 : 50;
            return (
              <div className="mt-3">
                <div className="flex items-center justify-between">
                  <p className="text-[10px] uppercase tracking-wide text-ark-text-tertiary">BTC Trend</p>
                  <p className="text-xs font-bold capitalize" style={{ color: c }}>{latest.btc_signal.replace(/_/g, ' ')}</p>
                </div>
                <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-ark-fill-secondary">
                  <div className="h-full rounded-full transition-all duration-500" style={{ width: `${fill}%`, backgroundColor: c }} />
                </div>
                <p className="mt-1 text-[10px]" style={{ color: c }}>
                  {bull ? 'Bullish, crypto deployment active' : bear ? 'Bearish, defensive positioning' : 'Neutral, holding current allocation'}
                </p>
              </div>
            );
          })()}
        </div>
      )}

      {/* Current allocations */}
      {allocations.length > 0 && (
        <div>
          <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Current allocation</p>
          <div className="space-y-1.5">
            {allocations.map((a) => (
              <div key={a.asset} className="rounded-xl bg-ark-fill-secondary/30 px-3 py-2">
                <div className="flex items-center gap-3">
                  <span className="w-14 shrink-0 text-sm font-semibold text-ark-text">{assetLabel(a.asset)}</span>
                  <div className="h-2 flex-1 overflow-hidden rounded-full bg-ark-fill-secondary">
                    <div className="h-full rounded-full bg-ark-primary/70" style={{ width: `${Math.min(100, a.pct)}%` }} />
                  </div>
                  <span className="fig w-12 shrink-0 text-right text-xs font-semibold text-ark-text">{a.pct.toFixed(1)}%</span>
                </div>
                {/* Entry / P&L / value — iOS Current Allocation detail */}
                <div className="mt-1 flex items-center gap-3 pl-[68px] text-[10px] text-ark-text-tertiary">
                  {a.entry != null && <span>Entry <span className="fig font-semibold text-ark-text-secondary">${a.entry.toLocaleString('en-US', { maximumFractionDigits: 2 })}</span></span>}
                  {a.pnl != null && <span className={cn('fig font-semibold', a.pnl >= 0 ? 'text-ark-success' : 'text-ark-error')}>{a.pnl >= 0 ? '+' : ''}{a.pnl.toFixed(1)}%</span>}
                  <span className="fig ml-auto font-semibold text-ark-text-secondary">${a.value.toLocaleString('en-US', { maximumFractionDigits: 0 })}</span>
                </div>
              </div>
            ))}
          </div>
          {isMetals && goldCostBasis && (
            <p className="mt-2 text-[11px] text-ark-text-tertiary">
              Blended gold cost basis{' '}
              <span className="fig font-semibold text-ark-text-secondary">
                ${goldCostBasis.toLocaleString('en-US', { maximumFractionDigits: 0 })}/oz
              </span>
              {goldSpot != null && (
                <>
                  {' · spot '}
                  <span className="fig font-semibold text-ark-text-secondary">
                    ${goldSpot.toLocaleString('en-US', { maximumFractionDigits: 0 })}
                  </span>
                </>
              )}
            </p>
          )}
        </div>
      )}

      {/* History — Position timeline (default) or the raw rebalance log */}
      {((trades ?? []).length > 0 || positions.length > 0) && (
        <div>
          <div className="mb-2 flex items-center justify-between">
            <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">History</p>
            <div className="flex gap-1 rounded-full bg-ark-fill-secondary/60 p-0.5">
              {(['positions', 'rebalances'] as const).map((tab) => (
                <button
                  key={tab}
                  onClick={() => setHistoryTab(tab)}
                  className={cn(
                    'rounded-full px-2.5 py-0.5 text-[10px] font-semibold capitalize transition-colors',
                    historyTab === tab ? 'bg-ark-primary text-white' : 'text-ark-text-tertiary hover:text-ark-text',
                  )}
                >
                  {tab === 'positions' ? 'Positions' : 'Rebalances'}
                </button>
              ))}
            </div>
          </div>

          {/* Position timeline */}
          {historyTab === 'positions' && (
            positions.length > 0 ? (
              <div className="space-y-1.5">
                {positions.map((p) => {
                  const open = p.exitedDate == null;
                  const pnl = p.pnlPct;
                  return (
                    <div
                      key={`${p.ticker}-${p.enteredDate}-${p.exitedDate ?? 'open'}`}
                      className="flex items-center gap-3 rounded-xl border border-ark-divider/70 px-3 py-2.5"
                    >
                      {open ? (
                        <Circle className="h-4 w-4 shrink-0 text-ark-success" />
                      ) : (
                        <CheckCircle2 className="h-4 w-4 shrink-0 text-ark-text-tertiary" />
                      )}
                      <div className="min-w-0 flex-1">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-semibold text-ark-text">{assetLabel(p.ticker)}</span>
                          <Badge variant={open ? 'success' : 'default'}>{open ? 'Open' : 'Closed'}</Badge>
                        </div>
                        <p className="mt-0.5 truncate text-[11px] text-ark-text-tertiary">
                          {fmtDate(p.enteredDate)}
                          {p.exitedDate ? ` → ${fmtDate(p.exitedDate)}` : ' → now'}
                          {p.exitRationale ? ` · ${p.exitRationale}` : ''}
                        </p>
                      </div>
                      {pnl != null && (
                        <span className={cn('fig shrink-0 text-sm font-semibold', pnl >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                          {pnl >= 0 ? '+' : ''}{pnl.toFixed(1)}%
                        </span>
                      )}
                    </div>
                  );
                })}
              </div>
            ) : (
              <p className="py-4 text-center text-xs text-ark-text-tertiary">No positions yet.</p>
            )
          )}

          {/* Raw rebalance log */}
          {historyTab === 'rebalances' && (
          <div className="space-y-2">
            {(trades ?? []).slice(0, 20).map((t) => {
              const changes = Object.keys({ ...t.from_allocation, ...t.to_allocation })
                .map((asset) => ({
                  asset,
                  from: Number(t.from_allocation?.[asset] ?? 0),
                  to: Number(t.to_allocation?.[asset] ?? 0),
                }))
                .filter((c) => Math.abs(c.to - c.from) > 0.05)
                .sort((a, b) => Math.abs(b.to - b.from) - Math.abs(a.to - a.from));
              const headlines = t.market_context?.headlines ?? [];
              const isExpanded = expandedTrade === t.id;
              const allocChips = Object.entries(t.to_allocation ?? {})
                .map(([asset, pct]) => ({ asset, pct: Number(pct) }))
                .filter((c) => c.pct > 0.5)
                .sort((a, b) => b.pct - a.pct);
              return (
                <div key={t.id} className="rounded-xl border border-ark-divider p-3">
                  <button
                    onClick={() => setExpandedTrade(isExpanded ? null : t.id)}
                    className="flex w-full items-center justify-between gap-2 text-left"
                  >
                    <p className="text-xs font-semibold text-ark-text">
                      {new Date(t.trade_date + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                    </p>
                    <span className="flex items-center gap-2">
                      <Badge variant={changes.length > 0 ? 'info' : 'default'}>{changes.length > 0 ? t.trigger : 'No changes'}</Badge>
                      <ChevronDown className={cn('h-3.5 w-3.5 text-ark-text-tertiary transition-transform', isExpanded && 'rotate-180')} />
                    </span>
                  </button>

                  {/* Day's allocation snapshot (iOS Trade Log chips) */}
                  {allocChips.length > 0 && (
                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {allocChips.map((c) => (
                        <span key={c.asset} className="fig rounded-full bg-ark-fill-secondary px-2 py-0.5 text-[10px] font-semibold text-ark-text-secondary">
                          {assetLabel(c.asset)}: {c.pct.toFixed(0)}%
                        </span>
                      ))}
                    </div>
                  )}

                  {changes.length > 0 && (
                    <div className="mt-2 space-y-1">
                      {changes.slice(0, 6).map((c) => {
                        const up = c.to >= c.from;
                        return (
                          <div key={c.asset} className="flex items-center gap-2 text-xs">
                            <span className="w-14 font-medium text-ark-text">{assetLabel(c.asset)}</span>
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

                  {/* What was moving markets that day (iOS expanded log) */}
                  {isExpanded && headlines.length > 0 && (
                    <div className="mt-2.5 border-t border-ark-divider/60 pt-2">
                      <p className="mb-1 text-[9px] font-bold uppercase tracking-wider text-ark-text-tertiary">Headlines</p>
                      <ul className="space-y-1">
                        {headlines.slice(0, 5).map((h, i) => (
                          <li key={i} className="text-[11px] leading-relaxed text-ark-text-secondary">· {h}</li>
                        ))}
                      </ul>
                    </div>
                  )}
                  {isExpanded && headlines.length === 0 && (
                    <p className="mt-2 text-[10px] text-ark-text-disabled">No market context recorded for this day.</p>
                  )}
                </div>
              );
            })}
          </div>
          )}
        </div>
      )}

      <p className="text-[10px] leading-relaxed text-ark-text-disabled">
        Model portfolios are simulated strategies for educational purposes only and do not constitute financial advice.
        Past performance does not guarantee future results.
      </p>
    </div>
  );
}
