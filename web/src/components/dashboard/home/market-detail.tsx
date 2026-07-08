'use client';

import { useState } from 'react';
import { Area, AreaChart, ComposedChart, Line, CartesianGrid, XAxis, ResponsiveContainer, YAxis, Tooltip, ReferenceDot } from 'recharts';
import { ArrowRight } from 'lucide-react';
import { Badge, Skeleton } from '@/components/ui';
import { cn, signalChangeHint } from '@/lib/utils/format';
import { useSignalChanges, useStockRiskLevels, useMarketBreadthDetail } from '@/lib/hooks/use-market';

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
const BREADTH_PERIODS = [{ label: '1M', days: 30 }, { label: '3M', days: 90 }, { label: '6M', days: 180 }, { label: '1Y', days: 365 }];

export function MarketBreadthDetail() {
  const [days, setDays] = useState(90);
  const { data, isLoading } = useMarketBreadthDetail(days);
  if (isLoading) return <Skeleton className="h-72 w-full" />;
  if (!data) return <p className="py-8 text-center text-sm text-ark-text-tertiary">No data available.</p>;

  const bullish = data.trend === 'bullish';
  const trendColor = bullish ? 'var(--ark-success)' : 'var(--ark-error)';
  const breadthColor = data.breadthPct >= 60 ? 'var(--ark-success)' : data.breadthPct >= 40 ? 'var(--ark-warning)' : 'var(--ark-error)';
  const breadthLabel = data.breadthPct >= 60 ? 'Strong' : data.breadthPct >= 40 ? 'Moderate' : 'Weak';

  const fmtDay = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  const btcVals = data.history.map((h) => h.btc);
  const btcMin = Math.min(...btcVals), btcMax = Math.max(...btcVals);
  const signals = data.history.filter((h) => h.crossover === 'bullish_crossover' || h.crossover === 'bearish_crossover');
  const firstDate = data.history[0]?.date, lastDate = data.history[data.history.length - 1]?.date;

  return (
    <div className="space-y-5 pb-2">
      {/* Current trend card */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <div className="flex items-start justify-between">
          <div>
            <p className="text-[11px] uppercase tracking-wider text-ark-text-tertiary">Current Trend</p>
            <p className="font-[family-name:var(--font-urbanist)] text-2xl font-bold" style={{ color: trendColor }}>{cap(data.trend)}</p>
          </div>
          <p className="text-right text-xs font-semibold" style={{ color: trendColor }}>
            EMA 12 ({data.ema12.toFixed(1)}%)<br />
            <span className="text-ark-text-tertiary">{data.ema12 >= data.ema21 ? '>' : '<'}</span> EMA 21 ({data.ema21.toFixed(1)}%)
          </p>
        </div>
        <div className="mt-3 h-2 w-full overflow-hidden rounded-full bg-ark-fill-secondary">
          <div className="h-full rounded-full" style={{ width: `${data.breadthPct}%`, backgroundColor: trendColor }} />
        </div>
        <div className="mt-1 flex justify-between text-[11px] text-ark-text-disabled">
          <span>{data.breadthPct.toFixed(1)}% of tokens in uptrend</span>
          <span className="fig font-semibold text-ark-text">{data.trendingTokens} / {data.totalTokens}</span>
        </div>
        <div className="mt-3 grid grid-cols-3 gap-3 border-t border-ark-divider pt-3">
          <div><p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">Breadth</p><p className="fig text-base font-bold" style={{ color: breadthColor }}>{data.breadthPct.toFixed(1)}%</p><p className="text-[10px] text-ark-text-disabled">{breadthLabel}</p></div>
          <div><p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">Trending</p><p className="fig text-base font-bold text-ark-text">{data.trendingTokens}</p><p className="text-[10px] text-ark-text-disabled">of {data.totalTokens}</p></div>
          <div><p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">BTC</p><p className="fig text-base font-bold text-ark-text">${data.btcPrice.toLocaleString()}</p><p className="text-[10px] text-ark-text-disabled">{fmtDay(data.asOf)}</p></div>
        </div>
      </div>

      {/* Recent signals */}
      {data.recentSignals.length > 0 && (
        <div>
          <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Recent Signals</p>
          <div className="flex gap-2 overflow-x-auto pb-1">
            {data.recentSignals.map((s, i) => (
              <span key={i} className={cn('flex shrink-0 items-center gap-1 rounded-full px-2.5 py-1 text-[11px] font-semibold', s.type === 'bullish' ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-error/10 text-ark-error')}>
                {s.type === 'bullish' ? '▲' : '▼'} {s.type} ({fmtDay(s.date)})
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Multi-line chart */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-3">
        <div className="mb-2 flex justify-center">
          <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
            {BREADTH_PERIODS.map((p) => (
              <button key={p.label} onClick={() => setDays(p.days)} className={cn('rounded-full px-3 py-1 text-xs font-semibold transition-colors', days === p.days ? 'bg-ark-info text-white' : 'text-ark-text-tertiary')}>{p.label}</button>
            ))}
          </div>
        </div>
        <div className="h-56 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <ComposedChart data={data.history} margin={{ top: 8, right: 8, bottom: 0, left: 0 }}>
              <CartesianGrid stroke="var(--ark-divider)" strokeDasharray="3 3" vertical={false} opacity={0.4} />
              <XAxis dataKey="date" tickLine={false} axisLine={false} ticks={firstDate && lastDate ? [firstDate, lastDate] : []} tickFormatter={fmtDay} tick={{ fontSize: 10, fill: 'var(--ark-text-disabled)' }} interval="preserveStartEnd" />
              <YAxis yAxisId="b" domain={[0, 100]} hide />
              <YAxis yAxisId="btc" orientation="right" domain={[btcMin, btcMax]} hide />
              <Tooltip
                contentStyle={{ background: 'var(--ark-card)', border: '1px solid var(--ark-divider)', borderRadius: 8, fontSize: 11 }}
                labelFormatter={(l) => fmtDay(String(l))}
                formatter={(v, name) => name === 'btc' ? [`$${Number(v).toLocaleString()}`, 'BTC'] : [`${Number(v).toFixed(1)}%`, name === 'breadth' ? 'Breadth' : name === 'ema12' ? 'EMA 12' : 'EMA 21']}
              />
              <Line yAxisId="b" type="monotone" dataKey="breadth" stroke="var(--ark-text-tertiary)" strokeWidth={1} dot={false} opacity={0.5} />
              <Line yAxisId="b" type="monotone" dataKey="ema12" stroke="var(--ark-success)" strokeWidth={2} dot={false} />
              <Line yAxisId="b" type="monotone" dataKey="ema21" stroke="#15803D" strokeWidth={1.5} dot={false} />
              <Line yAxisId="btc" type="monotone" dataKey="btc" stroke="#F59E0B" strokeWidth={1.5} dot={false} />
              {signals.map((s, i) => {
                const bull = s.crossover === 'bullish_crossover';
                const col = bull ? 'var(--ark-success)' : 'var(--ark-error)';
                return (
                  <ReferenceDot key={i} yAxisId="b" x={s.date} y={s.ema12} r={0} shape={(props: { cx?: number; cy?: number }) => {
                    const { cx = 0, cy = 0 } = props;
                    // up triangle for bullish, down triangle for bearish
                    const pts = bull ? `${cx},${cy - 6} ${cx - 5},${cy + 4} ${cx + 5},${cy + 4}` : `${cx},${cy + 6} ${cx - 5},${cy - 4} ${cx + 5},${cy - 4}`;
                    return <polygon points={pts} fill={col} stroke="var(--ark-card)" strokeWidth={1} />;
                  }} />
                );
              })}
            </ComposedChart>
          </ResponsiveContainer>
        </div>
        <div className="mt-2 flex flex-wrap justify-center gap-x-4 gap-y-1 text-[10px] text-ark-text-tertiary">
          <span className="flex items-center gap-1"><span className="h-0.5 w-3 rounded bg-ark-text-tertiary" /> Breadth</span>
          <span className="flex items-center gap-1"><span className="h-0.5 w-3 rounded bg-ark-success" /> EMA 12</span>
          <span className="flex items-center gap-1"><span className="h-0.5 w-3 rounded" style={{ background: '#15803D' }} /> EMA 21</span>
          <span className="flex items-center gap-1"><span className="h-0.5 w-3 rounded" style={{ background: '#F59E0B' }} /> BTC</span>
        </div>
      </div>

      <Info title="How Market Breadth Works" lines={[
        'Market Breadth measures the percentage of tokens in an uptrend (price above their 7-day moving average).',
        'Green EMAs = bullish trend (breadth improving). Red EMAs = bearish trend (breadth declining).',
        'EMA 12 crossing above EMA 21 marks a bullish signal; crossing below marks a bearish signal. Divergence vs. BTC can flag a narrowing or broadening rally.',
      ]} />
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-3 text-center">
      <p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">{label}</p>
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
