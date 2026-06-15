'use client';

import { useState } from 'react';
import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip } from 'recharts';
import { ChevronRight, ChevronLeft, ArrowUp, ArrowDown } from 'lucide-react';
import { Skeleton } from '@/components/ui';
import { useRiskLevels, useIndicatorHistory } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';
import type { RiskBand, RiskLevelItem } from '@/types';

const BANDS: { band: RiskBand; color: string }[] = [
  { band: 'Very Low', color: 'var(--ark-info)' },
  { band: 'Low', color: 'var(--ark-success)' },
  { band: 'Neutral', color: 'var(--ark-warning)' },
  { band: 'Elevated', color: '#F97316' },
  { band: 'High', color: 'var(--ark-error)' },
];
const bandColor = (b: RiskBand) => BANDS.find((x) => x.band === b)?.color ?? 'var(--ark-text-tertiary)';

export function CryptoRiskLevelsDetail({ initialSymbol }: { initialSymbol?: string } = {}) { return <RiskLevelsDetail kind="crypto" initialSymbol={initialSymbol} />; }
export function StockRiskLevelsDetail({ initialSymbol }: { initialSymbol?: string } = {}) { return <RiskLevelsDetail kind="stock" initialSymbol={initialSymbol} />; }

function RiskLevelsDetail({ kind, initialSymbol }: { kind: 'crypto' | 'stock'; initialSymbol?: string }) {
  const { data, isLoading } = useRiskLevels(kind);
  const [sort, setSort] = useState<'band' | 'az'>('band');
  const [period, setPeriod] = useState<7 | 30>(7);
  const [selectedSym, setSelectedSym] = useState<string | null>(initialSymbol ? initialSymbol.toUpperCase() : null);

  const selected = selectedSym ? (data ?? []).find((i) => i.symbol === selectedSym) : undefined;
  if (selectedSym && selected) {
    return <AssetRiskChart kind={kind} item={selected} onBack={() => setSelectedSym(null)} />;
  }

  if (isLoading || !data) {
    return <div className="space-y-3 pb-4">{[0, 1, 2, 3, 4].map((i) => <Skeleton key={i} className="h-14 w-full rounded-xl" />)}</div>;
  }

  const items = data;
  const subtitle = kind === 'crypto' ? `Regression model · ${items.length} assets` : `Trend & momentum · ${items.length} stocks bucketed`;

  return (
    <div className="space-y-4 pb-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <p className="text-sm text-ark-text-secondary">{subtitle}</p>
          <p className="text-[11px] text-ark-text-disabled">Refreshes at 7 AM &amp; 5 PM ET</p>
        </div>
        <div className="flex items-center gap-2">
          <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
            <Toggle active={sort === 'band'} onClick={() => setSort('band')}>By Band</Toggle>
            <Toggle active={sort === 'az'} onClick={() => setSort('az')}>A–Z</Toggle>
          </div>
          <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
            <Toggle active={period === 7} onClick={() => setPeriod(7)}>7D</Toggle>
            <Toggle active={period === 30} onClick={() => setPeriod(30)}>30D</Toggle>
          </div>
        </div>
      </div>

      {sort === 'az' ? (
        <div className="overflow-hidden rounded-2xl border border-ark-divider bg-ark-fill-secondary/20">
          {[...items].sort((a, b) => a.symbol.localeCompare(b.symbol)).map((it, i) => (
            <Row key={it.symbol} it={it} period={period} divider={i > 0} onClick={() => setSelectedSym(it.symbol)} />
          ))}
        </div>
      ) : (
        BANDS.map(({ band, color }) => {
          const group = items.filter((it) => it.band === band);
          if (!group.length) return null;
          return (
            <div key={band}>
              <div className="mb-2 flex items-center gap-2">
                <span className="h-2 w-2 rounded-full" style={{ backgroundColor: color }} />
                <span className="text-sm font-bold" style={{ color }}>{band} Risk</span>
                <span className="rounded-full bg-ark-fill-secondary px-1.5 py-0.5 text-[10px] font-semibold text-ark-text-tertiary">{group.length}</span>
              </div>
              <div className="overflow-hidden rounded-2xl border border-ark-divider bg-ark-fill-secondary/20">
                {group.map((it, i) => <Row key={it.symbol} it={it} period={period} divider={i > 0} onClick={() => setSelectedSym(it.symbol)} />)}
              </div>
            </div>
          );
        })
      )}
    </div>
  );
}

function Toggle({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button onClick={onClick} className={cn('rounded-full px-3 py-1 text-xs font-semibold transition-colors', active ? 'bg-ark-info text-white' : 'text-ark-text-tertiary')}>{children}</button>
  );
}

function Row({ it, period, divider, onClick }: { it: RiskLevelItem; period: 7 | 30; divider: boolean; onClick: () => void }) {
  const color = bandColor(it.band);
  const change = period === 7 ? it.change7d : it.change30d;
  const flat = Math.abs(change) < 0.005;
  return (
    <button onClick={onClick} className={cn('flex w-full items-center gap-3 p-3 text-left transition-colors hover:bg-ark-fill-secondary/40', divider && 'border-t border-ark-divider')}>
      <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-ark-fill-secondary text-[10px] font-bold text-ark-text-secondary">{it.symbol.slice(0, 4)}</span>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-bold text-ark-text">{it.symbol}</p>
        <p className="truncate text-[11px] text-ark-text-disabled">{it.name}</p>
      </div>
      <div className="text-right">
        <p className="fig text-base font-bold" style={{ color }}>{it.value.toFixed(3)}</p>
        {flat ? (
          <p className="text-[11px] text-ark-text-disabled">—</p>
        ) : (
          <p className={cn('fig flex items-center justify-end gap-0.5 text-[11px] font-semibold', change > 0 ? 'text-ark-error' : 'text-ark-success')}>
            {change > 0 ? <ArrowUp className="h-2.5 w-2.5" /> : <ArrowDown className="h-2.5 w-2.5" />}
            {change > 0 ? '+' : ''}{change.toFixed(3)}
          </p>
        )}
      </div>
      <ChevronRight className="h-4 w-4 shrink-0 text-ark-text-disabled" />
    </button>
  );
}

/* ── Per-asset risk history chart ── */
const PERIODS = [{ label: '7D', days: 7 }, { label: '30D', days: 30 }, { label: '90D', days: 90 }, { label: '1Y', days: 365 }, { label: 'ALL', days: 3650 }];

function AssetRiskChart({ kind, item, onBack }: { kind: 'crypto' | 'stock'; item: RiskLevelItem; onBack: () => void }) {
  const [days, setDays] = useState(90);
  const dbKey = `${kind === 'stock' ? 'stock' : 'crypto'}_risk_${item.symbol.toLowerCase()}`;
  const { data, isLoading } = useIndicatorHistory(dbKey, days);
  const series = data ?? [];
  const current = series.length ? series[series.length - 1].value : item.value;
  const color = bandColor(item.band);
  const fmtDay = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

  return (
    <div className="space-y-5 pb-2">
      <button onClick={onBack} className="inline-flex items-center gap-1 text-sm font-semibold text-ark-info">
        <ChevronLeft className="h-4 w-4" /> All assets
      </button>

      <div className="flex items-center gap-3">
        <span className="flex h-11 w-11 items-center justify-center rounded-full bg-ark-fill-secondary text-xs font-bold text-ark-text-secondary">{item.symbol.slice(0, 4)}</span>
        <div className="flex-1">
          <p className="text-lg font-bold text-ark-text">{item.symbol}</p>
          <p className="text-xs text-ark-text-disabled">{item.name}</p>
        </div>
        <div className="text-right">
          <p className="fig text-2xl font-bold" style={{ color }}>{current.toFixed(3)}</p>
          <span className="rounded-full px-2 py-0.5 text-[10px] font-semibold" style={{ backgroundColor: `${color}1F`, color }}>{item.band} Risk</span>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-3"><p className="text-[10px] uppercase tracking-wider text-ark-text-disabled">7d Avg</p><p className="fig mt-0.5 text-sm font-bold text-ark-text">{item.sevenDayAvg.toFixed(3)}</p></div>
        <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-3"><p className="text-[10px] uppercase tracking-wider text-ark-text-disabled">Days at level</p><p className="fig mt-0.5 text-sm font-bold text-ark-text">{item.daysAtLevel}</p></div>
      </div>

      <div className="flex justify-center">
        <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
          {PERIODS.map((p) => <Toggle key={p.label} active={days === p.days} onClick={() => setDays(p.days)}>{p.label}</Toggle>)}
        </div>
      </div>

      {isLoading ? (
        <Skeleton className="h-56 w-full" />
      ) : series.length > 1 ? (
        <div className="h-56 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={series} margin={{ top: 8, right: 8, bottom: 0, left: 0 }}>
              <defs>
                <linearGradient id="rl-chart" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={color} stopOpacity={0.22} />
                  <stop offset="100%" stopColor={color} stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="date" tickLine={false} axisLine={false} ticks={series.length ? [series[0].date, series[series.length - 1].date] : []} tickFormatter={fmtDay} tick={{ fontSize: 10, fill: 'var(--ark-text-disabled)' }} interval="preserveStartEnd" />
              <YAxis domain={[0, 1]} hide />
              <Tooltip contentStyle={{ background: 'var(--ark-card)', border: '1px solid var(--ark-divider)', borderRadius: 8, fontSize: 12 }} labelFormatter={(l) => fmtDay(String(l))} formatter={(v) => [Number(v).toFixed(3), 'Risk']} />
              <Area type="monotone" dataKey="value" stroke={color} strokeWidth={2.5} fill="url(#rl-chart)" dot={false} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      ) : (
        <p className="py-8 text-center text-sm text-ark-text-tertiary">No risk history for this period.</p>
      )}

      <p className="text-[13px] leading-relaxed text-ark-text-secondary">
        Risk is {item.symbol}&apos;s position within its long-term {kind === 'stock' ? 'trend & momentum model' : 'logarithmic regression channel'} — 0.0 is deeply undervalued (accumulation), 1.0 is historically overextended (distribution).
      </p>
    </div>
  );
}
