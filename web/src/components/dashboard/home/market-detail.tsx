'use client';

import { Area, AreaChart, ResponsiveContainer, YAxis, Tooltip } from 'recharts';
import { ArrowRight } from 'lucide-react';
import { Badge, Skeleton } from '@/components/ui';
import { cn, signalChangeHint } from '@/lib/utils/format';
import { useMarketBreadth, useSignalChanges, useStockRiskLevels } from '@/lib/hooks/use-market';

const SIG: Record<string, string> = {
  bullish: 'var(--ark-success)', neutral: 'var(--ark-warning)', bearish: 'var(--ark-error)',
};
const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);

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

// ── Market Breadth ──────────────────────────────────────────────────────────
export function MarketBreadthDetail() {
  const { data, isLoading } = useMarketBreadth();
  if (isLoading) return <Skeleton className="h-64 w-full" />;
  if (!data) return <p className="py-8 text-center text-sm text-ark-text-tertiary">No data available.</p>;

  const color = data.breadth_pct >= 70 ? 'var(--ark-success)' : data.breadth_pct >= 40 ? 'var(--ark-warning)' : 'var(--ark-error)';
  const chart = data.history.map((v, i) => ({ i, v }));

  return (
    <div className="space-y-6 pb-4">
      <div className="flex flex-col items-center gap-2 pt-2">
        <span className="font-[family-name:var(--font-urbanist)] text-5xl font-bold" style={{ color }}>{data.breadth_pct.toFixed(1)}%</span>
        <Badge variant={data.trend === 'bullish' ? 'success' : data.trend === 'bearish' ? 'error' : 'warning'}>{cap(data.trend)}</Badge>
      </div>

      {chart.length > 1 && (
        <div className="h-44 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={chart} margin={{ top: 8, right: 8, bottom: 0, left: 8 }}>
              <defs>
                <linearGradient id="mb-detail" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={color} stopOpacity={0.25} />
                  <stop offset="100%" stopColor={color} stopOpacity={0} />
                </linearGradient>
              </defs>
              <YAxis domain={[0, 100]} hide />
              <Tooltip contentStyle={{ background: 'var(--ark-card)', border: '1px solid var(--ark-divider)', borderRadius: 8, fontSize: 12 }} labelFormatter={() => ''} formatter={(v) => [`${Number(v).toFixed(1)}%`, 'Breadth']} />
              <Area type="monotone" dataKey="v" stroke={color} strokeWidth={2} fill="url(#mb-detail)" dot={false} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}

      <div className="grid grid-cols-3 gap-3">
        <Stat label="Trending" value={`${data.trending_tokens}/${data.total_tokens}`} />
        <Stat label="Trend" value={cap(data.trend)} />
        <Stat label="Crossover" value={data.crossover ? cap(data.crossover) : '—'} />
      </div>

      <Info title="What is Market Breadth?" lines={[
        'Market breadth measures the percentage of tokens currently in an uptrend (price above their 7-day moving average).',
        'High values (70–100%) indicate broad market strength; low values (0–30%) suggest most tokens are trending down.',
      ]} />
      <Info title="EMA Trend Analysis" lines={[
        '• EMA 12 > EMA 21 (bullish): breadth improving — more tokens entering uptrends.',
        '• EMA 12 < EMA 21 (bearish): breadth declining — tokens losing momentum.',
        '• Crossovers mark potential turning points; divergence vs. BTC price can signal a narrowing or broadening rally.',
      ]} />
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-3 text-center">
      <p className="text-[10px] uppercase tracking-wider text-ark-text-disabled">{label}</p>
      <p className="fig mt-0.5 text-sm font-bold text-ark-text">{value}</p>
    </div>
  );
}

// ── Signal Changes ──────────────────────────────────────────────────────────
export function SignalChangesDetail() {
  const { data, isLoading } = useSignalChanges();
  if (isLoading) return <Skeleton className="h-64 w-full" />;
  const changes = data ?? [];

  const dir = (from: string, to: string) => {
    const order = ['bearish', 'neutral', 'bullish'];
    const d = order.indexOf(to) - order.indexOf(from);
    return d > 0 ? 'var(--ark-success)' : d < 0 ? 'var(--ark-error)' : 'var(--ark-warning)';
  };

  return (
    <div className="space-y-4 pb-4">
      <p className="text-sm text-ark-text-secondary">{changes.length === 0 ? 'No positioning signal changes today.' : `${changes.length} asset${changes.length === 1 ? '' : 's'} changed positioning today.`}</p>
      <div className="space-y-2">
        {changes.map((c) => (
          <div key={c.asset} className="rounded-xl border p-3" style={{ borderColor: `${dir(c.prev_signal, c.signal)}4D` }}>
            <div className="flex items-center gap-3">
              <span className="w-16 text-sm font-semibold text-ark-text">{c.asset}</span>
              <span className="rounded px-2 py-0.5 text-[10px] font-bold text-white" style={{ backgroundColor: SIG[c.prev_signal] }}>{cap(c.prev_signal)}</span>
              <ArrowRight className="h-3.5 w-3.5 text-ark-text-tertiary" />
              <span className="rounded px-2 py-0.5 text-[10px] font-bold text-white" style={{ backgroundColor: SIG[c.signal] }}>{cap(c.signal)}</span>
            </div>
            <p className="mt-1.5 text-xs leading-relaxed text-ark-text-secondary">{signalChangeHint(c.prev_signal, c.signal)}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Stock Risk Levels ───────────────────────────────────────────────────────
const BANDS = [
  { label: 'Low (0.0–0.3)', color: 'var(--ark-success)' },
  { label: 'Moderate (0.3–0.5)', color: 'var(--ark-warning)' },
  { label: 'Elevated (0.5–0.7)', color: '#F97316' },
  { label: 'High (0.7–1.0)', color: 'var(--ark-error)' },
];
function riskColor(v: number) { return v < 0.3 ? 'var(--ark-success)' : v < 0.5 ? 'var(--ark-warning)' : v < 0.7 ? '#F97316' : 'var(--ark-error)'; }

export function StockRiskDetail() {
  const { data, isLoading } = useStockRiskLevels();
  if (isLoading) return <Skeleton className="h-64 w-full" />;
  const stocks = data ?? [];

  return (
    <div className="space-y-5 pb-4">
      <div className="flex flex-wrap gap-x-4 gap-y-1.5">
        {BANDS.map((b) => (
          <div key={b.label} className="flex items-center gap-1.5">
            <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: b.color }} />
            <span className="text-[11px] text-ark-text-secondary">{b.label}</span>
          </div>
        ))}
      </div>
      <div className="space-y-2.5">
        {stocks.map((s) => (
          <div key={s.symbol} className="flex items-center gap-3">
            <span className="w-14 text-xs font-semibold text-ark-text">{s.symbol}</span>
            <div className="h-2 flex-1 overflow-hidden rounded-full bg-ark-fill-secondary">
              <div className="h-full rounded-full" style={{ width: `${s.risk_value * 100}%`, backgroundColor: riskColor(s.risk_value) }} />
            </div>
            <span className="fig w-10 text-right text-xs font-semibold text-ark-text">{s.risk_value.toFixed(2)}</span>
          </div>
        ))}
      </div>
      <Info title="Regression Risk" lines={['Risk is derived from each stock’s position within its long-term logarithmic regression channel (0 = deeply undervalued, 1 = historically overextended).']} />
    </div>
  );
}
