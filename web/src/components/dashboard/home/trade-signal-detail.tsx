'use client';

/**
 * Trade Signals — rich drawer detail (iOS SignalDetailView parity):
 * signal list → per-signal deep dive with status banner, live P&L,
 * trade-structure ladder, market context, rationale, and an embedded
 * leverage calculator.
 */

import { useMemo, useState, useSyncExternalStore } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ChevronLeft, Calculator, TrendingUp, TrendingDown } from 'lucide-react';
import { AreaChart, Area, ReferenceLine, ResponsiveContainer, YAxis } from 'recharts';
import { Badge, Skeleton } from '@/components/ui';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import {
  fetchTradeSignalsFull,
  fetchSignalHistory,
  isLong,
  SIGNAL_TYPE_LABEL,
  SIGNAL_STATUS_META,
  type TradeSignal,
} from '@/lib/api/signals';
import { computeSummary, byDirection, byAsset, dailyBuckets, notableTrades } from '@/lib/signals/performance';
import { Markdown } from '@/components/dashboard/shared/markdown';
import { CoinIcon } from '@/components/dashboard/shared/coin-icon';
import { formatCurrency, formatPercent, formatRelativeTime, localDateISO, cn } from '@/lib/utils/format';

function useTradeSignalsFull() {
  return useQuery({
    queryKey: ['trade-signals-full'],
    queryFn: () => fetchTradeSignalsFull(),
    staleTime: 60_000,
    // iOS polls the live signal view every 15 s.
    refetchInterval: 15_000,
  });
}

/* ── Leverage calculator (iOS LeverageCalculatorView parity) ── */
function LeverageCalculator({ signal }: { signal: TradeSignal }) {
  const [margin, setMargin] = useState(100);
  const [leverage, setLeverage] = useState(5);
  const long = isLong(signal.signal_type);
  const entry = signal.entry_price_mid;

  const position = margin * leverage;
  const qty = entry ? position / entry : 0;
  // Approximate isolated-margin liquidation (excl. fees/funding).
  const liq = long ? entry * (1 - 1 / leverage) : entry * (1 + 1 / leverage);
  const pnlAt = (price: number | null) =>
    price == null ? null : (long ? price - entry : entry - price) * qty;
  const stopLoss = pnlAt(signal.stop_loss);
  const t1 = pnlAt(signal.target_1);
  const t2 = pnlAt(signal.target_2);

  return (
    <div className="rounded-xl border border-ark-divider p-3.5">
      <div className="flex items-center gap-2">
        <Calculator className="h-4 w-4 text-ark-primary" />
        <p className="text-sm font-semibold text-ark-text">Leverage calculator</p>
      </div>
      <div className="mt-3 grid grid-cols-2 gap-3">
        <label className="block">
          <span className="text-[11px] font-medium text-ark-text-secondary">Margin ($)</span>
          <input
            type="number" min={1} value={margin || ''}
            onChange={(e) => setMargin(Number(e.target.value))}
            className="fig mt-1 h-9 w-full rounded-lg border border-ark-divider bg-ark-fill-secondary px-2.5 text-sm text-ark-text outline-none focus:border-ark-primary"
          />
        </label>
        <label className="block">
          <span className="fig text-[11px] font-medium text-ark-text-secondary">Leverage · {leverage}x</span>
          <input
            type="range" min={1} max={125} value={leverage}
            onChange={(e) => setLeverage(Number(e.target.value))}
            className="mt-3 w-full accent-[var(--ark-primary)]"
          />
        </label>
      </div>
      <div className="mt-3 grid grid-cols-2 gap-2 text-xs sm:grid-cols-4">
        {[
          { label: 'Position', value: formatCurrency(position), color: 'text-ark-text' },
          { label: 'Est. liq. price', value: formatCurrency(liq), color: 'text-ark-warning' },
          { label: 'Loss at stop', value: stopLoss != null ? formatCurrency(stopLoss) : '—', color: 'text-ark-error' },
          { label: 'Gain at T1', value: t1 != null ? formatCurrency(t1) : '—', color: 'text-ark-success' },
        ].map((c) => (
          <div key={c.label} className="rounded-lg bg-ark-fill-secondary/40 px-2.5 py-2">
            <p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">{c.label}</p>
            <p className={cn('fig mt-0.5 font-semibold', c.color)}>{c.value}</p>
          </div>
        ))}
      </div>
      {t2 != null && (
        <p className="fig mt-2 text-[11px] text-ark-text-tertiary">Gain at T2: <span className="font-semibold text-ark-success">{formatCurrency(t2)}</span></p>
      )}
      <p className="mt-2 text-[10px] leading-relaxed text-ark-text-disabled">
        Liquidation estimate assumes isolated margin and excludes fees and funding. Not financial advice — size responsibly.
      </p>
    </div>
  );
}

/* ── Price ladder ── */
function StructureRow({ label, price, entry, tone }: { label: string; price: number | null; entry: number; tone: string }) {
  if (price == null) return null;
  const pct = entry ? ((price - entry) / entry) * 100 : 0;
  return (
    <div className="flex items-center justify-between rounded-lg bg-ark-fill-secondary/40 px-3 py-2">
      <span className="text-xs font-medium" style={{ color: tone }}>{label}</span>
      <div className="text-right">
        <span className="fig text-sm font-semibold text-ark-text">{formatCurrency(price)}</span>
        <span className="fig ml-2 text-[11px] text-ark-text-tertiary">{formatPercent(pct)}</span>
      </div>
    </div>
  );
}

function SignalDeepDive({ signal, onBack }: { signal: TradeSignal; onBack: () => void }) {
  const { data: assets } = useCryptoAssets(1);
  const long = isLong(signal.signal_type);
  const status = SIGNAL_STATUS_META[signal.status] ?? SIGNAL_STATUS_META.active;
  const entry = signal.entry_price_mid;

  const live = assets?.find((a) => a.symbol.toLowerCase() === signal.asset.toLowerCase());
  const price = live?.current_price ?? null;
  const isOpen = signal.status === 'active' || signal.status === 'triggered';
  const pnlPct =
    price != null && entry ? (long ? (price - entry) / entry : (entry - price) / entry) * 100 : null;
  const riskPerUnit = Math.abs(entry - signal.stop_loss) || 1;
  const rMultiple = price != null ? ((long ? price - entry : entry - price) / riskPerUnit) : null;

  const context: { label: string; value: string }[] = [];
  if (signal.btc_risk_score != null) context.push({ label: 'BTC Risk', value: signal.btc_risk_score.toFixed(2) });
  if (signal.fear_greed_index != null) context.push({ label: 'Fear & Greed', value: String(signal.fear_greed_index) });
  if (signal.macro_regime) context.push({ label: 'Regime', value: signal.macro_regime });
  if (signal.arkline_score != null) context.push({ label: 'ArkLine Score', value: String(signal.arkline_score) });
  if (signal.composite_score != null) context.push({ label: 'Composite', value: String(signal.composite_score) });

  return (
    <div className="space-y-4 pb-4">
      <button onClick={onBack} className="flex items-center gap-1 text-xs font-medium text-ark-primary hover:text-ark-accent-light">
        <ChevronLeft className="h-3.5 w-3.5" /> All signals
      </button>

      {/* Header + status banner */}
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <CoinIcon symbol={signal.asset} size="md" />
            <p className="text-lg font-bold text-ark-text">{signal.asset.toUpperCase()}</p>
            <span className={cn('flex items-center gap-1 text-sm font-semibold', long ? 'text-ark-success' : 'text-ark-error')}>
              {long ? <TrendingUp className="h-4 w-4" /> : <TrendingDown className="h-4 w-4" />}
              {SIGNAL_TYPE_LABEL[signal.signal_type]}
            </span>
          </div>
          <p className="mt-0.5 text-[11px] text-ark-text-tertiary">
            {signal.timeframe ? `${signal.timeframe.toUpperCase()} · ` : ''}{formatRelativeTime(signal.generated_at)}
            {signal.risk_reward_ratio ? <span className="fig"> · R:R {signal.risk_reward_ratio.toFixed(1)}</span> : null}
          </p>
        </div>
        <Badge variant={status.tone}>{status.label}</Badge>
      </div>

      {/* Live P&L (open) or outcome (closed) */}
      {isOpen && price != null ? (
        <div className={cn(
          'rounded-xl border px-3.5 py-3',
          (pnlPct ?? 0) >= 0 ? 'border-ark-success/30 bg-ark-success/5' : 'border-ark-error/30 bg-ark-error/5',
        )}>
          <div className="flex items-center justify-between">
            <div>
              <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Live P&L from entry</p>
              <p className={cn('fig text-xl font-bold', (pnlPct ?? 0) >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                {pnlPct != null ? formatPercent(pnlPct) : '—'}
                {rMultiple != null && <span className="ml-2 text-sm font-semibold text-ark-text-secondary">{rMultiple.toFixed(2)}R</span>}
              </p>
            </div>
            <div className="text-right">
              <p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">Current price</p>
              <p className="fig text-sm font-semibold text-ark-text">{formatCurrency(price)}</p>
            </div>
          </div>
        </div>
      ) : signal.outcome_pct != null ? (
        <div className={cn(
          'rounded-xl border px-3.5 py-3',
          signal.outcome_pct >= 0 ? 'border-ark-success/30 bg-ark-success/5' : 'border-ark-error/30 bg-ark-error/5',
        )}>
          <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Outcome</p>
          <p className={cn('fig text-xl font-bold', signal.outcome_pct >= 0 ? 'text-ark-success' : 'text-ark-error')}>
            {formatPercent(signal.outcome_pct)}
          </p>
        </div>
      ) : null}

      {/* Trade structure */}
      <div>
        <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Trade structure</p>
        <div className="space-y-1.5">
          <StructureRow label="Target 2" price={signal.target_2} entry={entry} tone="var(--ark-success)" />
          <StructureRow label="Target 1" price={signal.target_1} entry={entry} tone="var(--ark-success)" />
          <div className="flex items-center justify-between rounded-lg border border-ark-primary/40 bg-ark-primary/5 px-3 py-2">
            <span className="text-xs font-semibold text-ark-primary">Entry zone</span>
            <span className="fig text-sm font-semibold text-ark-text">
              {formatCurrency(signal.entry_zone_low)} – {formatCurrency(signal.entry_zone_high)}
            </span>
          </div>
          <StructureRow label="Stop loss" price={signal.stop_loss} entry={entry} tone="var(--ark-error)" />
        </div>
        {signal.invalidation_note && (
          <p className="mt-2 text-[11px] leading-relaxed text-ark-text-tertiary">{signal.invalidation_note}</p>
        )}
      </div>

      {/* Market context */}
      {context.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {context.map((c) => (
            <span key={c.label} className="rounded-full bg-ark-fill-secondary px-2.5 py-1 text-[10px] font-medium text-ark-text-secondary">
              {c.label}: <span className="fig font-semibold text-ark-text">{c.value}</span>
            </span>
          ))}
        </div>
      )}

      {/* Rationale */}
      {(signal.short_rationale || signal.briefing_text) && (
        <div>
          <p className="mb-1 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Analysis</p>
          <Markdown content={signal.briefing_text || signal.short_rationale || ''} />
        </div>
      )}

      <LeverageCalculator signal={signal} />
    </div>
  );
}

/* ── Rich signal card (iOS SignalCardView parity — Active + History lists) ── */

function outcomeR(s: TradeSignal): number | null {
  if (s.outcome_pct == null || !s.entry_price_mid || !s.stop_loss) return null;
  const stopDistPct = (Math.abs(s.entry_price_mid - s.stop_loss) / s.entry_price_mid) * 100;
  return stopDistPct > 0 ? s.outcome_pct / stopDistPct : null;
}

const OUTCOME_META: Record<string, { label: string; cls: string; edge: string }> = {
  win: { label: 'Target Hit', cls: 'bg-ark-success/10 text-ark-success', edge: 'border-ark-success/30' },
  partial: { label: 'Partial', cls: 'bg-ark-warning/10 text-ark-warning', edge: 'border-ark-warning/30' },
  loss: { label: 'Stopped Out', cls: 'bg-ark-error/10 text-ark-error', edge: 'border-ark-error/30' },
};

function SignalCard({ s, onOpen }: { s: TradeSignal; onOpen: () => void }) {
  const long = isLong(s.signal_type);
  const status = SIGNAL_STATUS_META[s.status] ?? SIGNAL_STATUS_META.active;
  const closed = s.outcome != null;
  const om = closed ? OUTCOME_META[s.outcome!] : null;
  const r = outcomeR(s);
  const rationale = s.short_rationale || '';

  return (
    <button
      onClick={onOpen}
      className={cn(
        'w-full rounded-xl border p-3.5 text-left transition-colors hover:bg-ark-fill-secondary/40',
        om?.edge ?? 'border-ark-divider',
      )}
    >
      {/* Header row */}
      <div className="flex items-center gap-2">
        <span className={cn('h-8 w-0.5 shrink-0 rounded-full', long ? 'bg-ark-success' : 'bg-ark-error')} />
        <CoinIcon symbol={s.asset} size="md" />
        <span className="text-sm font-bold text-ark-text">{s.asset.toUpperCase()}</span>
        <span className={cn(
          'rounded-full px-2 py-0.5 text-[10px] font-bold',
          long ? 'bg-ark-success/15 text-ark-success' : 'bg-ark-error/15 text-ark-error',
        )}>
          {SIGNAL_TYPE_LABEL[s.signal_type]}
        </span>
        {s.timeframe && <span className="rounded-full bg-ark-fill-secondary px-1.5 py-0.5 text-[9px] font-semibold uppercase text-ark-text-tertiary">{s.timeframe}</span>}
        {s.risk_reward_ratio != null && <span className="fig rounded-full bg-ark-info/10 px-1.5 py-0.5 text-[9px] font-bold text-ark-info">{s.risk_reward_ratio.toFixed(1)}x</span>}
        <span className="ml-auto shrink-0 text-[10px] text-ark-text-disabled">{formatRelativeTime(s.closed_at ?? s.generated_at)}</span>
      </div>

      {/* Entry zone */}
      <div className="mt-2.5 flex items-baseline justify-between">
        <span className="text-[11px] text-ark-text-tertiary">Entry</span>
        <span className="fig text-sm font-semibold text-ark-text">
          {formatCurrency(s.entry_zone_low)} – {formatCurrency(s.entry_zone_high)}
        </span>
      </div>

      {/* Rationale preview */}
      {rationale && (
        <p className="mt-2 rounded-lg bg-ark-fill-secondary/40 px-2.5 py-2 text-[11px] leading-relaxed text-ark-text-secondary line-clamp-2">
          {rationale}
        </p>
      )}

      {/* T1 / T2 / Stop */}
      <div className="mt-2.5 flex items-center gap-4">
        {s.target_1 != null && (
          <span className="text-[11px]"><span className="text-ark-text-tertiary">T1 </span><span className="fig font-semibold text-ark-success">{formatCurrency(s.target_1)}</span></span>
        )}
        {s.target_2 != null && (
          <span className="text-[11px]"><span className="text-ark-text-tertiary">T2 </span><span className="fig font-semibold text-ark-success">{formatCurrency(s.target_2)}</span></span>
        )}
        <span className="text-[11px]"><span className="text-ark-text-tertiary">Stop </span><span className="fig font-semibold text-ark-error">{formatCurrency(s.stop_loss)}</span></span>
      </div>

      {/* Footer: outcome chips (closed) or status (open) */}
      <div className="mt-2.5 flex items-center gap-1.5">
        {closed ? (
          <>
            {s.outcome_pct != null && (
              <span className={cn('fig rounded-md px-1.5 py-0.5 text-[10px] font-bold', s.outcome_pct >= 0 ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-error/10 text-ark-error')}>
                {formatPercent(s.outcome_pct)}
              </span>
            )}
            {r != null && (
              <span className={cn('fig rounded-md px-1.5 py-0.5 text-[10px] font-bold', r >= 0 ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-error/10 text-ark-error')}>
                {r >= 0 ? '+' : ''}{r.toFixed(1)}R
              </span>
            )}
            {s.duration_hours != null && (
              <span className="fig rounded-md bg-ark-fill-secondary px-1.5 py-0.5 text-[10px] font-semibold text-ark-text-tertiary">{s.duration_hours}h</span>
            )}
            {om && <span className={cn('ml-auto rounded-md px-2 py-0.5 text-[10px] font-bold', om.cls)}>{om.label}</span>}
          </>
        ) : (
          <>
            {s.ema_trend_aligned && <span className="rounded-md bg-ark-info/10 px-1.5 py-0.5 text-[10px] font-semibold text-ark-info">EMA Aligned</span>}
            {s.counter_trend && <span className="rounded-md bg-ark-warning/10 px-1.5 py-0.5 text-[10px] font-semibold text-ark-warning">Counter-trend</span>}
            <span className="ml-auto"><Badge variant={status.tone}>{s.status === 'triggered' ? 'Watching T1' : status.label}</Badge></span>
          </>
        )}
      </div>
    </button>
  );
}

/* ── History tab ── */

const RANGES = [
  { label: '7D', days: 7 },
  { label: '30D', days: 30 },
  { label: '90D', days: 90 },
  { label: 'All', days: undefined },
] as const;

function useSignalHistory(days?: number) {
  return useQuery({
    queryKey: ['signal-history', days ?? 'all'],
    queryFn: () => fetchSignalHistory(days),
    staleTime: 300_000,
  });
}

function RangePills({ value, onChange }: { value: number | undefined; onChange: (d: number | undefined) => void }) {
  return (
    <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
      {RANGES.map((r) => (
        <button
          key={r.label}
          onClick={() => onChange(r.days)}
          className={cn('rounded-full px-3 py-1 text-[11px] font-semibold transition-colors',
            value === r.days ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text')}
        >
          {r.label}
        </button>
      ))}
    </div>
  );
}

/** Hour-quantized "now" via external store — keeps render pure (react-compiler). */
function useNowHourly(): number {
  return useSyncExternalStore(
    (onChange) => {
      const id = window.setInterval(onChange, 3_600_000);
      return () => window.clearInterval(id);
    },
    () => Math.floor(Date.now() / 3_600_000) * 3_600_000,
    () => 0,
  );
}

function DailyCalendar({ signals }: { signals: TradeSignal[] }) {
  const buckets = useMemo(() => dailyBuckets(signals), [signals]);
  const now = useNowHourly();
  // Last 28 days grid, oldest first.
  const days = useMemo(() => {
    const out: { iso: string; dayNum: number }[] = [];
    for (let i = 27; i >= 0; i--) {
      const d = new Date(now - i * 86_400_000);
      out.push({ iso: localDateISO(d), dayNum: d.getDate() });
    }
    return out;
  }, [now]);

  return (
    <div>
      <p className="mb-1 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Daily P&L calendar</p>
      <p className="mb-2 text-[10px] text-ark-text-disabled">Average P&L per trade each day — last 4 weeks</p>
      <div className="grid grid-cols-7 gap-1.5">
        {days.map((d) => {
          const b = buckets.get(d.iso);
          return (
            <div
              key={d.iso}
              title={b ? `${d.iso}: ${formatPercent(b.avgPnl)} avg · ${b.trades} trade${b.trades === 1 ? '' : 's'}` : d.iso}
              className={cn(
                'flex h-11 flex-col items-center justify-center rounded-lg text-center',
                b ? (b.avgPnl >= 0 ? 'bg-ark-success/15' : 'bg-ark-error/15') : 'bg-ark-fill-secondary/40',
              )}
            >
              <span className="fig text-[9px] text-ark-text-disabled">{d.dayNum}</span>
              {b && (
                <span className={cn('fig text-[10px] font-bold', b.avgPnl >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                  {b.avgPnl >= 0 ? '+' : ''}{b.avgPnl.toFixed(1)}
                </span>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function HistoryTab({ onSelect }: { onSelect: (s: TradeSignal) => void }) {
  const [days, setDays] = useState<number | undefined>(30);
  const [asset, setAsset] = useState<string>('All');
  const { data, isLoading } = useSignalHistory(days);

  const signals = useMemo(() => data ?? [], [data]);
  const assets = useMemo(
    () => ['All', ...Array.from(new Set(signals.map((s) => s.asset.toUpperCase()))).sort()],
    [signals],
  );
  const filtered = asset === 'All' ? signals : signals.filter((s) => s.asset.toUpperCase() === asset);
  const summary = useMemo(() => computeSummary(filtered), [filtered]);

  if (isLoading) return <Skeleton className="h-64 w-full" />;

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <RangePills value={days} onChange={setDays} />
        <p className="fig text-[11px] text-ark-text-tertiary">{filtered.length} closed</p>
      </div>

      {/* Summary strip */}
      {filtered.length > 0 && (
        <div className="flex items-center justify-between rounded-xl border border-ark-divider px-3.5 py-3">
          <div>
            <p className={cn('fig text-lg font-bold', summary.compoundedReturn >= 0 ? 'text-ark-success' : 'text-ark-error')}>
              {formatPercent(summary.compoundedReturn)}
            </p>
            <p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">cumulative</p>
          </div>
          <div className="text-right">
            <p className="fig text-sm font-semibold text-ark-text">{summary.total} trades</p>
            <p className="fig text-[11px] font-semibold text-ark-success">{summary.winRate.toFixed(0)}% win rate</p>
          </div>
        </div>
      )}

      {/* Asset filter */}
      {assets.length > 2 && (
        <div className="flex gap-1.5 overflow-x-auto pb-1">
          {assets.map((a) => (
            <button
              key={a}
              onClick={() => setAsset(a)}
              className={cn('shrink-0 rounded-full px-2.5 py-1 text-[10px] font-bold transition-colors',
                asset === a ? 'bg-ark-info text-white' : 'bg-ark-fill-secondary text-ark-text-tertiary hover:text-ark-text')}
            >
              {a}
            </button>
          ))}
        </div>
      )}

      {filtered.length === 0 ? (
        <p className="py-8 text-center text-sm text-ark-text-tertiary">No closed signals in this window.</p>
      ) : (
        <>
          <div className="space-y-2">
            {filtered.slice(0, 25).map((s) => <SignalCard key={s.id} s={s} onOpen={() => onSelect(s)} />)}
          </div>
          <DailyCalendar signals={filtered} />
        </>
      )}
    </div>
  );
}

/* ── Performance tab ── */

function StatCell({ label, value, tone }: { label: string; value: string; tone?: string }) {
  return (
    <div className="rounded-lg bg-ark-fill-secondary/40 px-2.5 py-2 text-center">
      <p className={cn('fig text-sm font-bold', tone ?? 'text-ark-text')}>{value}</p>
      <p className="mt-0.5 text-[9px] uppercase tracking-wider text-ark-text-tertiary">{label}</p>
    </div>
  );
}

function PerformanceTab({ onSelect }: { onSelect: (s: TradeSignal) => void }) {
  const [days, setDays] = useState<number | undefined>(undefined);
  const { data, isLoading } = useSignalHistory(days);

  const signals = useMemo(() => data ?? [], [data]);
  const summary = useMemo(() => computeSummary(signals), [signals]);
  const dir = useMemo(() => byDirection(signals, isLong), [signals]);
  const assets = useMemo(() => byAsset(signals), [signals]);
  const notable = useMemo(() => notableTrades(signals), [signals]);

  if (isLoading) return <Skeleton className="h-64 w-full" />;
  if (!signals.length) return <p className="py-8 text-center text-sm text-ark-text-tertiary">No closed signals yet.</p>;

  const curve = summary.cumulativeCurve;

  return (
    <div className="space-y-4">
      <RangePills value={days} onChange={setDays} />

      {/* Signal ROI */}
      <div className="rounded-xl border border-ark-divider p-3.5">
        <div className="flex items-center justify-between">
          <p className="text-sm font-semibold text-ark-text">Signal ROI</p>
          <p className="fig text-[11px] text-ark-text-tertiary">{summary.total} signals</p>
        </div>
        <p className={cn('fig mt-1 text-2xl font-bold', summary.compoundedReturn >= 0 ? 'text-ark-success' : 'text-ark-error')}>
          {formatPercent(summary.compoundedReturn)}
          <span className="ml-2 text-xs font-medium text-ark-text-tertiary">compounded return</span>
        </p>
        {/* Cumulative P&L curve */}
        {curve.length > 1 && (
          <div className="mt-3 h-28">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={curve} margin={{ top: 2, right: 0, bottom: 0, left: 0 }}>
                <defs>
                  <linearGradient id="sigPnl" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--ark-success)" stopOpacity={0.25} />
                    <stop offset="100%" stopColor="var(--ark-success)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <YAxis hide domain={['auto', 'auto']} />
                <ReferenceLine y={0} stroke="var(--ark-divider)" strokeDasharray="4 4" />
                <Area type="monotone" dataKey="value" stroke="var(--ark-success)" strokeWidth={1.5} fill="url(#sigPnl)" isAnimationActive={false} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}
        <p className="mt-2 text-[10px] leading-relaxed text-ark-text-disabled">
          Spot (1x) compounded return following every signal at equal size. Leverage amplifies both gains and losses. Not financial advice — always do your own research.
        </p>
      </div>

      {/* Win/loss stat grid */}
      <div className="grid grid-cols-3 gap-2">
        <StatCell label="Wins" value={String(summary.wins)} tone="text-ark-success" />
        <StatCell label="Partial" value={String(summary.partials)} tone="text-ark-warning" />
        <StatCell label="Losses" value={String(summary.losses)} tone="text-ark-error" />
        <StatCell label="Avg win" value={formatPercent(summary.avgWin)} tone="text-ark-success" />
        <StatCell label="Avg loss" value={formatPercent(summary.avgLoss)} tone="text-ark-error" />
        <StatCell label="Streak" value={`${summary.streak > 0 ? '+' : ''}${summary.streak}`} tone={summary.streak >= 0 ? 'text-ark-success' : 'text-ark-error'} />
        <StatCell label="Win rate" value={`${summary.winRate.toFixed(0)}%`} />
        <StatCell label="Profit factor" value={Number.isFinite(summary.profitFactor) ? `${summary.profitFactor.toFixed(1)}x` : '∞'} />
        <StatCell label="Avg duration" value={summary.avgDurationHours != null ? `${Math.round(summary.avgDurationHours)}h` : '—'} />
      </div>

      {/* By direction */}
      <div className="rounded-xl border border-ark-divider p-3.5">
        <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">By direction</p>
        <div className="grid grid-cols-2 gap-3">
          {([['Long', dir.long, 'text-ark-success'], ['Short', dir.short, 'text-ark-error']] as const).map(([label, d, tone]) => (
            <div key={label} className="text-center">
              <p className={cn('text-xs font-bold', tone)}>{label}</p>
              <p className="fig mt-1 text-lg font-bold text-ark-text">{d.trades}<span className="ml-1 text-[10px] font-medium text-ark-text-tertiary">trades</span></p>
              <p className="fig text-[11px] text-ark-text-secondary">
                <span className="font-semibold text-ark-success">{d.winRate.toFixed(0)}%</span> win ·{' '}
                <span className={cn('font-semibold', d.avgPnl >= 0 ? 'text-ark-success' : 'text-ark-error')}>{formatPercent(d.avgPnl)}</span> avg
              </p>
            </div>
          ))}
        </div>
      </div>

      {/* By asset */}
      {assets.length > 0 && (
        <div className="rounded-xl border border-ark-divider p-3.5">
          <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">By asset</p>
          <div className="space-y-2">
            {assets.map((a) => (
              <div key={a.asset} className="flex items-center gap-2.5">
                <CoinIcon symbol={a.asset} size="sm" />
                <span className="w-10 text-xs font-bold text-ark-text">{a.asset}</span>
                <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-ark-error/30">
                  <div className="h-full rounded-full bg-ark-success" style={{ width: `${a.winRate}%` }} />
                </div>
                <span className="fig w-9 text-right text-[11px] text-ark-text-secondary">{a.winRate.toFixed(0)}%</span>
                <span className={cn('fig w-12 text-right text-[11px] font-semibold', a.avgPnl >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                  {formatPercent(a.avgPnl)}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Notable trades */}
      {(notable.best || notable.worst) && (
        <div className="rounded-xl border border-ark-divider p-3.5">
          <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Notable trades</p>
          <div className="space-y-1.5">
            {([['Best', notable.best], ['Worst', notable.worst]] as const).map(([label, s]) => s && (
              <button key={label} onClick={() => onSelect(s)} className="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left transition-colors hover:bg-ark-fill-secondary/40">
                <span className="w-10 text-[10px] font-semibold uppercase text-ark-text-tertiary">{label}</span>
                <CoinIcon symbol={s.asset} size="sm" />
                <span className="text-xs font-bold text-ark-text">{s.asset.toUpperCase()}</span>
                <span className={cn('rounded-full px-1.5 py-0.5 text-[9px] font-bold', isLong(s.signal_type) ? 'bg-ark-success/15 text-ark-success' : 'bg-ark-error/15 text-ark-error')}>
                  {SIGNAL_TYPE_LABEL[s.signal_type]}
                </span>
                <span className="text-[10px] text-ark-text-disabled">{s.closed_at ? formatRelativeTime(s.closed_at) : ''}</span>
                <span className={cn('fig ml-auto text-sm font-bold', (s.outcome_pct ?? 0) >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                  {formatPercent(s.outcome_pct ?? 0)}
                </span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

/* ── Root: Active / History / Performance tabs ── */

const TABS = ['Active', 'History', 'Performance'] as const;
type Tab = (typeof TABS)[number];

export function TradeSignalsDetail() {
  const { data, isLoading } = useTradeSignalsFull();
  const [tab, setTab] = useState<Tab>('Active');
  const [selected, setSelected] = useState<TradeSignal | null>(null);

  const signals = data ?? [];

  if (selected) {
    // Keep the selected signal fresh across the 15 s poll.
    const fresh = signals.find((s) => s.id === selected.id) ?? selected;
    return <SignalDeepDive signal={fresh} onBack={() => setSelected(null)} />;
  }

  const open = signals.filter((s) => s.status === 'active' || s.status === 'triggered');
  const recentClosed = signals.filter((s) => s.outcome != null);

  return (
    <div className="space-y-4 pb-4">
      {/* Tabs */}
      <div className="flex rounded-xl bg-ark-fill-secondary/60 p-1">
        {TABS.map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={cn('flex-1 rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors',
              tab === t ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text')}
          >
            {t}
          </button>
        ))}
      </div>

      {tab === 'Active' && (
        isLoading ? <Skeleton className="h-64 w-full" /> : (
          <div className="space-y-2">
            {open.length === 0 ? (
              <>
                <p className="py-4 text-center text-sm text-ark-text-tertiary">No active signals right now.</p>
                {recentClosed.length > 0 && (
                  <>
                    <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Recently closed</p>
                    {recentClosed.slice(0, 5).map((s) => <SignalCard key={s.id} s={s} onOpen={() => setSelected(s)} />)}
                  </>
                )}
              </>
            ) : (
              open.map((s) => <SignalCard key={s.id} s={s} onOpen={() => setSelected(s)} />)
            )}
            <p className="pt-2 text-center text-[10px] leading-relaxed text-ark-text-disabled">
              Prices are delayed and may lag the live market by a few minutes. Set your own take-profit and stop-loss orders on your exchange. Trade signals are educational tools, not financial advice.
            </p>
          </div>
        )
      )}

      {tab === 'History' && <HistoryTab onSelect={setSelected} />}
      {tab === 'Performance' && <PerformanceTab onSelect={setSelected} />}
    </div>
  );
}
