'use client';

/**
 * Trade Signals — rich drawer detail (iOS SignalDetailView parity):
 * signal list → per-signal deep dive with status banner, live P&L,
 * trade-structure ladder, market context, rationale, and an embedded
 * leverage calculator.
 */

import { useMemo, useState, useSyncExternalStore } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { ChevronLeft, ChevronDown, Calculator, TrendingUp, TrendingDown, Pencil, Wrench, Clock3 } from 'lucide-react';
import { AreaChart, Area, ReferenceLine, ResponsiveContainer, YAxis } from 'recharts';
import { Badge, Skeleton, useToast } from '@/components/ui';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import { useAuth } from '@/lib/hooks/use-auth';
import {
  fetchTradeSignalsFull,
  fetchSignalHistory,
  resolveSignal,
  isLong,
  SIGNAL_TYPE_LABEL,
  SIGNAL_STATUS_META,
  type TradeSignal,
  type SignalOutcome,
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

/* ── Small shared bits ── */

function PresetChip({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={cn('fig rounded-lg px-2.5 py-1 text-[11px] font-semibold transition-colors',
        active ? 'bg-ark-primary text-white' : 'bg-ark-fill-secondary text-ark-text-tertiary hover:text-ark-text')}
    >
      {label}
    </button>
  );
}

function Collapsible({ icon, title, badge, children, defaultOpen = false }: {
  icon: React.ReactNode; title: string; badge?: React.ReactNode; children: React.ReactNode; defaultOpen?: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <div className="rounded-xl border border-ark-divider">
      <button onClick={() => setOpen((v) => !v)} className="flex w-full items-center gap-2 p-3.5 text-left">
        {icon}
        <p className="text-sm font-semibold text-ark-text">{title}</p>
        {badge}
        <ChevronDown className={cn('ml-auto h-4 w-4 text-ark-text-tertiary transition-transform', open && 'rotate-180')} />
      </button>
      {open && <div className="px-3.5 pb-3.5">{children}</div>}
    </div>
  );
}

/* ── Trade structure chart (iOS TradeStructureView parity) ── */
function StructLine({ price, top, color, label, dashed, rLabel }: {
  price: number; top: number; color: string; label: string; dashed?: boolean; rLabel?: string | null;
}) {
  return (
    <>
      <div className="absolute left-0 right-16 border-t" style={{ top: `${top}%`, borderColor: color, borderTopStyle: dashed ? 'dashed' : 'solid' }} />
      <span className="absolute rounded px-1 py-px text-[8px] font-bold text-white" style={{ top: `calc(${top}% - 14px)`, left: 4, backgroundColor: color }}>{label}</span>
      <span className="fig absolute right-0 -translate-y-1/2 text-[10px] font-semibold" style={{ top: `${top}%`, color }}>{formatCurrency(price)}</span>
      {rLabel && (
        <span className="fig absolute right-16 -translate-y-1/2 pr-1 text-[8px] font-bold text-ark-text-tertiary" style={{ top: `${top}%` }}>{rLabel}</span>
      )}
    </>
  );
}

function TradeStructureChart({ signal, entryOverride }: { signal: TradeSignal; entryOverride?: number | null }) {
  const long = isLong(signal.signal_type);
  const entry = entryOverride ?? signal.entry_price_mid;
  const prices = [signal.target_2, signal.target_1, signal.entry_zone_low, signal.entry_zone_high, signal.stop_loss, entry]
    .filter((p): p is number => p != null);
  if (prices.length < 3) return null;
  const min = Math.min(...prices);
  const max = Math.max(...prices);
  const pad = (max - min) * 0.12 || 1;
  const y = (p: number) => ((max + pad - p) / (max - min + 2 * pad)) * 100; // % from top

  const risk = Math.abs(entry - signal.stop_loss);
  const rFor = (p: number) => (risk > 0 && Math.abs(p - entry) / risk > 0.01 ? `${(Math.abs(p - entry) / risk).toFixed(1)}R` : null);

  const t1 = signal.target_1;
  return (
    <div>
      <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Trade structure</p>
      <div className="relative h-44 overflow-hidden rounded-xl bg-ark-fill-secondary/30">
        {/* Shaded profit / risk zones relative to entry */}
        {t1 != null && (
          <div className="absolute left-0 right-16 bg-ark-success/10" style={{
            top: `${Math.min(y(t1), y(entry))}%`,
            height: `${Math.abs(y(t1) - y(entry))}%`,
          }} />
        )}
        <div className="absolute left-0 right-16 bg-ark-error/10" style={{
          top: `${Math.min(y(signal.stop_loss), y(entry))}%`,
          height: `${Math.abs(y(signal.stop_loss) - y(entry))}%`,
        }} />
        {signal.target_2 != null && <StructLine price={signal.target_2} top={y(signal.target_2)} color="var(--ark-success)" label="T2" dashed rLabel={rFor(signal.target_2)} />}
        {signal.target_1 != null && <StructLine price={signal.target_1} top={y(signal.target_1)} color="var(--ark-success)" label="T1" rLabel={rFor(signal.target_1)} />}
        <StructLine price={entry} top={y(entry)} color="var(--ark-info)" label="ENTRY" dashed />
        <StructLine price={signal.stop_loss} top={y(signal.stop_loss)} color="var(--ark-error)" label="STOP" rLabel={rFor(signal.stop_loss)} />
      </div>
      {!long && <p className="mt-1 text-[9px] text-ark-text-disabled">Short setup — profit zone sits below entry.</p>}
    </div>
  );
}

/* ── Signal parameters (iOS SignalParametersView parity) ── */
function ParamRow({ label, children, pct }: { label: string; children: React.ReactNode; pct?: number | null }) {
  return (
    <div className="flex items-center justify-between py-1.5">
      <span className="text-xs text-ark-text-tertiary">{label}</span>
      <span className="fig text-sm font-semibold text-ark-text">
        {children}
        {pct != null && (
          <span className={cn('fig ml-2 text-[11px] font-semibold', pct >= 0 ? 'text-ark-success' : 'text-ark-error')}>
            {formatPercent(pct)}
          </span>
        )}
      </span>
    </div>
  );
}

function SignalParameters({ signal, price, entryOverride }: { signal: TradeSignal; price: number | null; entryOverride?: number | null }) {
  const entry = entryOverride ?? signal.entry_price_mid;
  const vsEntry = (p: number | null) => (p == null || !entry ? null : ((p - entry) / entry) * 100);
  // "Consider profit" band: 30–75% of the way from entry to T1 (works for both directions).
  const cpLow = signal.target_1 != null ? entry + (signal.target_1 - entry) * 0.30 : null;
  const cpHigh = signal.target_1 != null ? entry + (signal.target_1 - entry) * 0.75 : null;

  return (
    <div className="rounded-xl border border-ark-divider p-3.5">
      <p className="text-sm font-semibold text-ark-text">Signal parameters</p>
      <p className="mt-0.5 text-[10px] text-ark-text-disabled">Pattern detected — not financial advice</p>
      <div className="mt-2 divide-y divide-ark-divider/60">
        {price != null && <ParamRow label="Current price" pct={vsEntry(price)}>{formatCurrency(price)}</ParamRow>}
        <ParamRow label="Entry zone">{formatCurrency(signal.entry_zone_low)} – {formatCurrency(signal.entry_zone_high)}</ParamRow>
        {cpLow != null && cpHigh != null && (
          <ParamRow label="Consider profit" pct={null}>
            {formatCurrency(cpLow)} – {formatCurrency(cpHigh)}
            <span className="ml-2 text-[10px] font-semibold text-ark-warning">30–75%</span>
          </ParamRow>
        )}
        {signal.target_1 != null && <ParamRow label="Target 1" pct={vsEntry(signal.target_1)}>{formatCurrency(signal.target_1)}</ParamRow>}
        {signal.target_2 != null && <ParamRow label="Target 2" pct={vsEntry(signal.target_2)}>{formatCurrency(signal.target_2)}</ParamRow>}
        <ParamRow label="Stop loss" pct={vsEntry(signal.stop_loss)}>{formatCurrency(signal.stop_loss)}</ParamRow>
        <ParamRow label="Risk / Reward">{signal.risk_reward_ratio != null ? `${signal.risk_reward_ratio.toFixed(1)}x` : '—'}</ParamRow>
      </div>
    </div>
  );
}

/* ── Your Setup — full calculator (iOS parity) ── */

const LEV_PRESETS = [1, 5, 10, 25, 50, 75, 100, 125];
const WALLET_PRESETS = [1000, 5000, 10000, 25000];
const RISK_PRESETS = [1, 2, 5, 7, 10, 15];
const MARGIN_PRESETS = [100, 250, 500, 1000];
const TOLERANCE = {
  Conservative: { maxLoss: 0.15, blurb: 'Protects capital first' },
  Moderate: { maxLoss: 0.35, blurb: 'Balanced risk and reward' },
  Aggressive: { maxLoss: 0.60, blurb: 'Maximum upside, maximum drawdown' },
} as const;
type Tolerance = keyof typeof TOLERANCE;

function YourSetup({ signal, entryOverride }: { signal: TradeSignal; entryOverride?: number | null }) {
  const long = isLong(signal.signal_type);
  const entry = entryOverride ?? signal.entry_price_mid;

  const [leverage, setLeverage] = useState(1);
  const [wallet, setWallet] = useState(0);
  const [riskPct, setRiskPct] = useState<number>(signal.suggested_risk_pct ?? 1);
  const [manualMargin, setManualMargin] = useState(0);
  const [tolerance, setTolerance] = useState<Tolerance>('Moderate');
  const [mode, setMode] = useState<'Isolated' | 'Cross'>('Isolated');

  const stopDist = entry ? Math.abs(entry - signal.stop_loss) / entry : 0;
  // Margin-loss at stop = leverage × stop distance.
  const lossAtStopPct = leverage * stopDist * 100;
  // Cap: keep the liquidation price safely beyond the stop (~30% buffer).
  const levCap = stopDist > 0 ? Math.max(1, Math.floor(0.7 / stopDist)) : 125;

  // Auto margin from wallet + risk-per-trade; manual entry overrides.
  const autoMargin = wallet > 0 && stopDist > 0 && leverage > 0
    ? (wallet * (riskPct / 100)) / (leverage * stopDist)
    : 0;
  const margin = manualMargin > 0 ? manualMargin : autoMargin;

  const position = margin * leverage;
  const qty = entry ? position / entry : 0;
  const liq = leverage > 1 ? (long ? entry * (1 - 1 / leverage) : entry * (1 + 1 / leverage)) : null;
  const pnlAt = (price: number | null) => (price == null ? null : (long ? price - entry : entry - price) * qty);
  const stopLoss = pnlAt(signal.stop_loss);
  const t1 = pnlAt(signal.target_1);
  const t2 = pnlAt(signal.target_2);

  return (
    <Collapsible
      icon={<Calculator className="h-4 w-4 text-ark-primary" />}
      title="Your setup"
      defaultOpen
      badge={<span className="fig rounded-full bg-ark-info/10 px-2 py-0.5 text-[10px] font-bold text-ark-info">cap {levCap}x</span>}
    >
      {/* Leverage */}
      <div className="flex items-center justify-between">
        <span className="text-[11px] font-medium text-ark-text-secondary">Leverage</span>
        <span className="fig text-sm font-bold text-ark-primary">{leverage}x</span>
      </div>
      <input
        type="range" min={1} max={125} value={leverage}
        onChange={(e) => setLeverage(Number(e.target.value))}
        className="mt-1 w-full accent-[var(--ark-primary)]"
      />
      <div className="mt-1.5 flex flex-wrap gap-1.5">
        {LEV_PRESETS.map((l) => <PresetChip key={l} label={`${l}x`} active={leverage === l} onClick={() => setLeverage(l)} />)}
      </div>
      {leverage === 1 ? (
        <p className="mt-2 rounded-lg bg-ark-success/5 px-2.5 py-1.5 text-[11px] text-ark-success">✓ Spot trade — no leverage risk</p>
      ) : leverage > levCap ? (
        <p className="mt-2 rounded-lg bg-ark-error/5 px-2.5 py-1.5 text-[11px] text-ark-error">
          Above the {levCap}x cap for this signal — liquidation would sit inside the stop.
        </p>
      ) : null}

      {/* Wallet size */}
      <div className="mt-3">
        <span className="text-[11px] font-medium text-ark-text-secondary">Wallet size</span>
        <div className="mt-1 flex items-center gap-1.5">
          <input
            type="number" min={0} value={wallet || ''}
            onChange={(e) => setWallet(Number(e.target.value))}
            placeholder="$ 0"
            className="fig h-8 w-24 rounded-lg border border-ark-divider bg-ark-fill-secondary px-2 text-xs text-ark-text outline-none focus:border-ark-primary"
          />
          {WALLET_PRESETS.map((w) => <PresetChip key={w} label={`$${w >= 1000 ? `${w / 1000}K` : w}`} active={wallet === w} onClick={() => setWallet(w)} />)}
        </div>
      </div>

      {/* Risk per trade */}
      <div className="mt-3">
        <span className="text-[11px] font-medium text-ark-text-secondary">Risk per trade</span>
        <div className="mt-1 flex flex-wrap gap-1.5">
          {RISK_PRESETS.map((r) => <PresetChip key={r} label={`${r}%`} active={riskPct === r} onClick={() => setRiskPct(r)} />)}
          {signal.suggested_risk_pct != null && (
            <PresetChip label={`1R (${signal.suggested_risk_pct}%)`} active={riskPct === signal.suggested_risk_pct} onClick={() => setRiskPct(signal.suggested_risk_pct!)} />
          )}
        </div>
        <p className="mt-1 text-[10px] text-ark-text-disabled">Enter wallet size to auto-calculate margin</p>
      </div>

      {/* Margin */}
      <div className="mt-3">
        <span className="text-[11px] font-medium text-ark-text-secondary">
          Margin {autoMargin > 0 && manualMargin === 0 ? <span className="fig text-ark-info">(auto: {formatCurrency(autoMargin)})</span> : '(manual)'}
        </span>
        <div className="mt-1 flex items-center gap-1.5">
          <input
            type="number" min={0} value={manualMargin || ''}
            onChange={(e) => setManualMargin(Number(e.target.value))}
            placeholder={autoMargin > 0 ? autoMargin.toFixed(0) : '$ 0'}
            className="fig h-8 w-24 rounded-lg border border-ark-divider bg-ark-fill-secondary px-2 text-xs text-ark-text outline-none focus:border-ark-primary"
          />
          {MARGIN_PRESETS.map((m) => <PresetChip key={m} label={`$${m}`} active={manualMargin === m} onClick={() => setManualMargin(m)} />)}
        </div>
      </div>

      {/* Risk tolerance */}
      <div className="mt-3">
        <div className="flex items-center justify-between">
          <span className="text-[11px] font-medium text-ark-text-secondary">Risk tolerance</span>
          <span className="fig text-[10px] font-semibold text-ark-warning">Max loss per trade: ~{Math.round(TOLERANCE[tolerance].maxLoss * 100)}%</span>
        </div>
        <div className="mt-1 flex gap-1.5">
          {(Object.keys(TOLERANCE) as Tolerance[]).map((t) => (
            <button
              key={t}
              onClick={() => { setTolerance(t); setLeverage(Math.max(1, Math.min(125, Math.floor(TOLERANCE[t].maxLoss / Math.max(stopDist, 0.0001))))); }}
              className={cn('flex-1 rounded-lg px-2 py-1.5 text-[11px] font-semibold transition-colors',
                tolerance === t
                  ? t === 'Conservative' ? 'bg-ark-success/15 text-ark-success' : t === 'Moderate' ? 'bg-ark-warning/20 text-ark-warning' : 'bg-ark-error/15 text-ark-error'
                  : 'bg-ark-fill-secondary text-ark-text-tertiary hover:text-ark-text')}
            >
              {t}
            </button>
          ))}
        </div>
        <p className="mt-1 text-[10px] text-ark-text-disabled">{TOLERANCE[tolerance].blurb}</p>
      </div>

      {/* Mode */}
      <div className="mt-3 flex rounded-lg bg-ark-fill-secondary p-0.5">
        {(['Isolated', 'Cross'] as const).map((m) => (
          <button key={m} onClick={() => setMode(m)}
            className={cn('flex-1 rounded-md px-2 py-1 text-[11px] font-semibold transition-colors',
              mode === m ? 'bg-ark-card text-ark-text shadow-sm' : 'text-ark-text-tertiary')}>
            {m}
          </button>
        ))}
      </div>
      {mode === 'Cross' && <p className="mt-1 text-[10px] text-ark-warning">Cross margin risks your whole wallet balance — liquidation estimates below assume isolated.</p>}

      {/* Outputs */}
      <div className="mt-3 grid grid-cols-2 gap-2 text-xs sm:grid-cols-4">
        {[
          { label: 'Position', value: position > 0 ? formatCurrency(position) : '—', color: 'text-ark-text' },
          { label: 'Est. liq. price', value: liq != null ? formatCurrency(liq) : 'None (1x)', color: 'text-ark-warning' },
          { label: 'Loss at stop', value: stopLoss != null && position > 0 ? `${formatCurrency(stopLoss)} · ${lossAtStopPct.toFixed(0)}%` : '—', color: 'text-ark-error' },
          { label: 'Gain at T1', value: t1 != null && position > 0 ? formatCurrency(t1) : '—', color: 'text-ark-success' },
        ].map((c) => (
          <div key={c.label} className="rounded-lg bg-ark-fill-secondary/40 px-2.5 py-2">
            <p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">{c.label}</p>
            <p className={cn('fig mt-0.5 font-semibold', c.color)}>{c.value}</p>
          </div>
        ))}
      </div>
      {t2 != null && position > 0 && (
        <p className="fig mt-2 text-[11px] text-ark-text-tertiary">Gain at T2: <span className="font-semibold text-ark-success">{formatCurrency(t2)}</span></p>
      )}
      <p className="mt-2 text-[10px] leading-relaxed text-ark-text-disabled">
        Liquidation estimate assumes isolated margin and excludes fees and funding. Not financial advice — size responsibly.
      </p>
    </Collapsible>
  );
}

/* ── Adjust My Entry (iOS parity) ── */
function AdjustMyEntry({ signal, value, onChange }: { signal: TradeSignal; value: number | null; onChange: (v: number | null) => void }) {
  return (
    <Collapsible icon={<Pencil className="h-4 w-4 text-ark-primary" />} title="Adjust my entry"
      badge={value != null ? <span className="fig rounded-full bg-ark-primary/10 px-2 py-0.5 text-[10px] font-bold text-ark-primary">{formatCurrency(value)}</span> : undefined}>
      <p className="text-[11px] leading-relaxed text-ark-text-secondary">
        Got filled at a different price? Enter your actual entry — the structure, parameters, and calculator update to your fill.
      </p>
      <div className="mt-2 flex items-center gap-2">
        <input
          type="number" step="any" value={value ?? ''}
          onChange={(e) => onChange(e.target.value === '' ? null : Number(e.target.value))}
          placeholder={signal.entry_price_mid ? String(signal.entry_price_mid) : 'Your entry price'}
          className="fig h-9 w-40 rounded-lg border border-ark-divider bg-ark-fill-secondary px-2.5 text-sm text-ark-text outline-none focus:border-ark-primary"
        />
        {value != null && (
          <button onClick={() => onChange(null)} className="text-[11px] font-medium text-ark-text-tertiary hover:text-ark-text">Reset to signal entry</button>
        )}
      </div>
    </Collapsible>
  );
}

/* ── Timeline (iOS parity) ── */
function SignalTimeline({ signal }: { signal: TradeSignal }) {
  const now = useNowHourly();
  const fmt = (iso: string) => new Date(iso).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' });
  const isOpen = signal.status === 'active' || signal.status === 'triggered';
  const events: { label: string; when: string; done: boolean }[] = [
    { label: 'Signal generated', when: fmt(signal.generated_at), done: true },
  ];
  if (signal.triggered_at) events.push({ label: 'Price entered zone', when: fmt(signal.triggered_at), done: true });
  if (signal.t1_hit_at) events.push({ label: 'Target 1 hit', when: fmt(signal.t1_hit_at), done: true });
  if (signal.closed_at) {
    events.push({ label: signal.outcome === 'win' ? 'Closed — target hit' : signal.outcome === 'loss' ? 'Closed — stopped out' : 'Closed', when: fmt(signal.closed_at), done: true });
  } else if (isOpen && signal.expires_at) {
    const hrs = Math.max(0, Math.round((new Date(signal.expires_at).getTime() - now) / 3_600_000));
    events.push({ label: `Expires in ${hrs}h`, when: fmt(signal.expires_at), done: false });
  }
  return (
    <div className="rounded-xl border border-ark-divider p-3.5">
      <div className="flex items-center gap-2">
        <Clock3 className="h-4 w-4 text-ark-primary" />
        <p className="text-sm font-semibold text-ark-text">Timeline</p>
      </div>
      <div className="mt-3 space-y-0">
        {events.map((e, i) => (
          <div key={e.label} className="relative flex gap-3 pb-4 last:pb-0">
            {i < events.length - 1 && <span className="absolute left-[5px] top-3 h-full w-px bg-ark-divider" />}
            <span className={cn('relative mt-1 h-[11px] w-[11px] shrink-0 rounded-full', e.done ? 'bg-ark-primary' : 'border-2 border-ark-divider bg-transparent')} />
            <div>
              <p className={cn('text-xs font-semibold', e.done ? 'text-ark-text' : 'text-ark-text-tertiary')}>{e.label}</p>
              <p className="fig text-[10px] text-ark-text-disabled">{e.when}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ── Manual Resolution (admin only — RLS is_admin() enforces server-side) ── */
function ManualResolution({ signal, price }: { signal: TradeSignal; price: number | null }) {
  const toast = useToast();
  const qc = useQueryClient();
  const long = isLong(signal.signal_type);
  const entry = signal.entry_price_mid;
  const pctAt = (p: number | null) => (p == null || !entry ? null : (long ? (p - entry) / entry : (entry - p) / entry) * 100);

  const resolve = useMutation({
    mutationFn: (v: { status: TradeSignal['status']; outcome: SignalOutcome | null; outcome_pct: number | null }) =>
      resolveSignal(signal.id, v),
    onSuccess: () => {
      toast.success('Signal resolved');
      qc.invalidateQueries({ queryKey: ['trade-signals-full'] });
      qc.invalidateQueries({ queryKey: ['signal-history'] });
      qc.invalidateQueries({ queryKey: ['trade-signals'] });
    },
    onError: () => toast.error('Could not resolve signal.'),
  });

  const actions: { label: string; cls: string; v: Parameters<typeof resolve.mutate>[0] }[] = [
    { label: 'Mark T1 hit (win)', cls: 'bg-ark-success/10 text-ark-success hover:bg-ark-success/20', v: { status: 'target_hit', outcome: 'win', outcome_pct: pctAt(signal.target_1) } },
    { label: 'Mark stopped (loss)', cls: 'bg-ark-error/10 text-ark-error hover:bg-ark-error/20', v: { status: 'invalidated', outcome: 'loss', outcome_pct: pctAt(signal.stop_loss) } },
    { label: 'Close at market (partial)', cls: 'bg-ark-warning/10 text-ark-warning hover:bg-ark-warning/20', v: { status: 'invalidated', outcome: 'partial', outcome_pct: pctAt(price) } },
    { label: 'Expire', cls: 'bg-ark-fill-secondary text-ark-text-secondary hover:bg-ark-fill-secondary/70', v: { status: 'expired', outcome: 'partial', outcome_pct: pctAt(price) } },
  ];

  return (
    <Collapsible
      icon={<Wrench className="h-4 w-4 text-ark-warning" />}
      title="Manual resolution"
      badge={<span className="rounded-full bg-ark-warning/15 px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider text-ark-warning">Admin</span>}
    >
      <p className="text-[11px] leading-relaxed text-ark-text-secondary">
        Override the automated resolver. Outcome % is computed from the signal&apos;s levels{price != null ? ' (market closes use the live price)' : ''}.
      </p>
      <div className="mt-2 grid grid-cols-2 gap-1.5">
        {actions.map((a) => (
          <button
            key={a.label}
            disabled={resolve.isPending}
            onClick={() => resolve.mutate(a.v)}
            className={cn('rounded-lg px-2.5 py-2 text-[11px] font-semibold transition-colors disabled:opacity-50', a.cls)}
          >
            {a.label}
          </button>
        ))}
      </div>
    </Collapsible>
  );
}

function SignalDeepDive({ signal, onBack }: { signal: TradeSignal; onBack: () => void }) {
  const { data: assets } = useCryptoAssets(1);
  const { profile } = useAuth();
  const isAdmin = profile?.role === 'admin';
  const [adjEntry, setAdjEntry] = useState<number | null>(null);
  const long = isLong(signal.signal_type);
  const status = SIGNAL_STATUS_META[signal.status] ?? SIGNAL_STATUS_META.active;
  const entry = adjEntry ?? signal.entry_price_mid;

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

      {/* Trade structure — visual ladder (iOS parity) */}
      <TradeStructureChart signal={signal} entryOverride={adjEntry} />
      {signal.invalidation_note && (
        <p className="text-[11px] leading-relaxed text-ark-text-tertiary">{signal.invalidation_note}</p>
      )}

      {/* Signal parameters */}
      <SignalParameters signal={signal} price={price} entryOverride={adjEntry} />

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

      <AdjustMyEntry signal={signal} value={adjEntry} onChange={setAdjEntry} />

      <YourSetup signal={signal} entryOverride={adjEntry} />

      {isAdmin && <ManualResolution signal={signal} price={price} />}

      <SignalTimeline signal={signal} />

      <p className="text-center text-[10px] leading-relaxed text-ark-text-disabled">
        Prices are delayed and may lag the live market by a few minutes — they are not real-time. Set your own take-profit and stop-loss orders on your exchange at your discretion. Arkline signals are informational only, not financial advice. Always do your own research.
      </p>
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
