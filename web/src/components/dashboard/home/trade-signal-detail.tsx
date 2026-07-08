'use client';

/**
 * Trade Signals — rich drawer detail (iOS SignalDetailView parity):
 * signal list → per-signal deep dive with status banner, live P&L,
 * trade-structure ladder, market context, rationale, and an embedded
 * leverage calculator.
 */

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ChevronLeft, ChevronRight, Calculator, TrendingUp, TrendingDown } from 'lucide-react';
import { Badge, Skeleton } from '@/components/ui';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import {
  fetchTradeSignalsFull,
  isLong,
  SIGNAL_TYPE_LABEL,
  SIGNAL_STATUS_META,
  type TradeSignal,
} from '@/lib/api/signals';
import { Markdown } from '@/components/dashboard/shared/markdown';
import { formatCurrency, formatPercent, formatRelativeTime, cn } from '@/lib/utils/format';

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

export function TradeSignalsDetail() {
  const { data, isLoading } = useTradeSignalsFull();
  const [selected, setSelected] = useState<TradeSignal | null>(null);

  if (isLoading) return <Skeleton className="h-64 w-full" />;
  const signals = data ?? [];

  if (selected) {
    // Keep the selected signal fresh across the 15 s poll.
    const fresh = signals.find((s) => s.id === selected.id) ?? selected;
    return <SignalDeepDive signal={fresh} onBack={() => setSelected(null)} />;
  }

  if (!signals.length) {
    return <p className="py-8 text-center text-sm text-ark-text-tertiary">No recent signals.</p>;
  }

  return (
    <div className="space-y-2 pb-4">
      {signals.map((s) => {
        const long = isLong(s.signal_type);
        const status = SIGNAL_STATUS_META[s.status] ?? SIGNAL_STATUS_META.active;
        return (
          <button
            key={s.id}
            onClick={() => setSelected(s)}
            className="flex w-full items-center gap-3 rounded-xl border border-ark-divider p-3 text-left transition-colors hover:bg-ark-fill-secondary/40"
          >
            <div className={cn('flex h-8 w-8 shrink-0 items-center justify-center rounded-lg', long ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-error/10 text-ark-error')}>
              {long ? <TrendingUp className="h-4 w-4" /> : <TrendingDown className="h-4 w-4" />}
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-semibold text-ark-text">
                {s.asset.toUpperCase()} <span className={cn('font-medium', long ? 'text-ark-success' : 'text-ark-error')}>{SIGNAL_TYPE_LABEL[s.signal_type]}</span>
              </p>
              <p className="fig text-[11px] text-ark-text-tertiary">
                {s.timeframe ? `${s.timeframe.toUpperCase()} · ` : ''}R:R {s.risk_reward_ratio?.toFixed(1) ?? '—'} · {formatRelativeTime(s.generated_at)}
              </p>
            </div>
            <Badge variant={status.tone}>{status.label}</Badge>
            <ChevronRight className="h-4 w-4 shrink-0 text-ark-text-tertiary" />
          </button>
        );
      })}
    </div>
  );
}
