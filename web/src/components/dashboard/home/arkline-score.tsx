'use client';

import { useState } from 'react';
import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip, ReferenceLine } from 'recharts';
import { ArrowDown, ArrowDownRight, ArrowUpRight, ArrowUp, ArrowRight, BarChart3, Smile, Globe } from 'lucide-react';
import { Skeleton } from '@/components/ui';
import { useArkLineScore, useArkLineScoreHistory } from '@/lib/hooks/use-market';
import type { ArkLineScoreComponent, ArkLineScoreHistoryPoint } from '@/types';

/* ── Fear/Greed band color for the score & scale ── */
function bandColor(v: number): string {
  if (v < 20) return '#2563EB';                 // Extreme Fear — deep blue
  if (v < 40) return 'var(--ark-info)';         // Fear — light blue
  if (v < 60) return 'var(--ark-text-tertiary)';// Neutral — gray
  if (v < 80) return 'var(--ark-warning)';      // Greed — orange
  return 'var(--ark-error)';                     // Extreme Greed — red
}

/* ── Component coloring is signal-driven (matches iOS) ── */
function signalColor(signal?: string): string {
  const s = (signal ?? '').toLowerCase();
  if (s.includes('bull')) return 'var(--ark-warning)';
  if (s.includes('bear')) return 'var(--ark-info)';
  return 'var(--ark-text-tertiary)';
}
function SignalArrow({ signal, className, color }: { signal?: string; className?: string; color?: string }) {
  const s = (signal ?? '').toLowerCase();
  const style = color ? { color } : undefined;
  if (s.includes('extremely bear')) return <ArrowDown className={className} style={style} />;
  if (s.includes('bear')) return <ArrowDownRight className={className} style={style} />;
  if (s.includes('extremely bull')) return <ArrowUp className={className} style={style} />;
  if (s.includes('bull')) return <ArrowUpRight className={className} style={style} />;
  return <ArrowRight className={className} style={style} />;
}

/* ── Component → category grouping (matches iOS Component Breakdown) ── */
const CATEGORIES: { title: string; icon: typeof BarChart3; members: string[] }[] = [
  { title: 'Market Structure', icon: BarChart3, members: ['BTC Cycle Risk', 'Funding Rates', 'Capital Flow'] },
  { title: 'Sentiment', icon: Smile, members: ['Fear & Greed', 'App Store FOMO', 'Altcoin Season'] },
  { title: 'Macro', icon: Globe, members: ['VIX (Volatility)', 'DXY (Dollar)', 'US Net Liquidity', 'WTI Crude Oil'] },
];

const money = (v?: number) => v == null ? '—' : `$${Math.round(v).toLocaleString()}`;

export function ArkLineScore() {
  const { data, isLoading } = useArkLineScore();
  const { data: history } = useArkLineScoreHistory();
  const [active, setActive] = useState<ArkLineScoreHistoryPoint | null>(null);

  if (isLoading || !data) {
    return (
      <div className="flex flex-col items-center gap-5 pb-4">
        <Skeleton className="h-48 w-48 rounded-full" />
        <Skeleton className="h-10 w-full rounded-xl" />
        <Skeleton className="h-48 w-full rounded-2xl" />
      </div>
    );
  }

  const { score, tier, recommendation, components } = data;
  const color = bandColor(score);

  // Full-circle gauge
  const R = 84, C = 2 * Math.PI * R;
  const offset = C * (1 - score / 100);

  const hist = history ?? [];
  const labelFmt = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  const fullFmt = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' });

  const compByName = (n: string): ArkLineScoreComponent | undefined => components.find((c) => c.name === n);
  const ungrouped = components.filter((c) => !CATEGORIES.some((cat) => cat.members.includes(c.name)));

  return (
    <div className="space-y-7 pb-2">
      {/* ── Circular gauge ── */}
      <div className="flex flex-col items-center">
        <div className="relative h-48 w-48">
          <svg viewBox="0 0 200 200" className="h-full w-full -rotate-90">
            <circle cx="100" cy="100" r={R} fill="none" stroke="var(--ark-fill-secondary)" strokeWidth="14" />
            <circle
              cx="100" cy="100" r={R} fill="none" stroke={color} strokeWidth="14" strokeLinecap="round"
              strokeDasharray={C} strokeDashoffset={offset} className="transition-all duration-700"
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="font-[family-name:var(--font-urbanist)] text-6xl font-bold leading-none text-ark-text">{score}</span>
            <span className="mt-1 text-xs text-ark-text-disabled">/ 100</span>
          </div>
        </div>

        {/* Tier badge */}
        <div className="mt-3 flex items-center gap-1.5 rounded-full px-3.5 py-1.5" style={{ backgroundColor: `${color}1F` }}>
          <SignalArrow signal={tier} className="h-3.5 w-3.5" color={color} />
          <span className="text-sm font-bold" style={{ color }}>{tier}</span>
        </div>

        {recommendation && (
          <p className="mt-3 max-w-sm text-center text-sm leading-relaxed text-ark-text-secondary">{recommendation}</p>
        )}
      </div>

      {/* ── Fear/Greed scale ── */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <div className="relative">
          <div className="flex gap-1">
            {['#2563EB', 'var(--ark-info)', 'var(--ark-text-tertiary)', 'var(--ark-warning)', 'var(--ark-error)'].map((c, i) => (
              <div key={i} className="h-2.5 flex-1 rounded-full" style={{ backgroundColor: c }} />
            ))}
          </div>
          {/* Marker */}
          <div
            className="absolute top-1/2 h-4 w-4 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-ark-card bg-white shadow"
            style={{ left: `${Math.min(98, Math.max(2, score))}%` }}
          />
        </div>
        <div className="mt-2 flex justify-between text-[10px] text-ark-text-disabled">
          <span>0</span><span>Fear</span><span>Neutral</span><span>Greed</span><span>100</span>
        </div>
      </div>

      {/* ── Score History ── */}
      {hist.length > 1 && (
        <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-bold uppercase tracking-wider text-ark-text-disabled">Score History</span>
            {active && (
              <button onClick={() => setActive(null)} className="text-xs font-semibold text-ark-info">Reset</button>
            )}
          </div>

          {active ? (
            <div className="mt-2">
              <p className="text-xs text-ark-text-tertiary">{fullFmt(active.date)}</p>
              <div className="mt-0.5 flex items-center gap-2">
                <span className="fig text-2xl font-bold text-ark-text">{active.score}</span>
                <span className="rounded px-2 py-0.5 text-[10px] font-semibold" style={{ backgroundColor: `${bandColor(active.score)}1F`, color: bandColor(active.score) }}>{active.tier}</span>
              </div>
              <div className="mt-1 flex flex-wrap gap-x-4 gap-y-0.5 text-[11px] text-ark-text-disabled">
                <span>BTC <span className="fig font-semibold text-ark-text-secondary">{money(active.btcPrice)}</span></span>
                <span>S&amp;P <span className="fig font-semibold text-ark-text-secondary">{money(active.sp500Price)}</span></span>
                <span>NDX <span className="fig font-semibold text-ark-text-secondary">{money(active.nasdaqPrice)}</span></span>
              </div>
            </div>
          ) : (
            <p className="mt-1 text-xs text-ark-text-disabled">Touch the chart to view historical scores</p>
          )}

          <div className="mt-3 h-44 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart
                data={hist}
                margin={{ top: 6, right: 4, bottom: 0, left: 4 }}
                onMouseMove={(s) => {
                  const st = s as { activeLabel?: string; activeTooltipIndex?: number; activePayload?: { payload?: ArkLineScoreHistoryPoint }[] };
                  let pt = st.activePayload?.[0]?.payload;
                  if (!pt && st.activeLabel != null) pt = hist.find((h) => h.date === st.activeLabel);
                  if (!pt && st.activeTooltipIndex != null && st.activeTooltipIndex >= 0) pt = hist[st.activeTooltipIndex];
                  if (pt) setActive(pt);
                }}
                onMouseLeave={() => setActive(null)}
              >
                <defs>
                  <linearGradient id="ark-score-hist" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--ark-info)" stopOpacity={0.3} />
                    <stop offset="100%" stopColor="var(--ark-info)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis
                  dataKey="date" tickLine={false} axisLine={false}
                  ticks={hist.length ? [hist[0].date, hist[hist.length - 1].date] : []}
                  tickFormatter={labelFmt}
                  tick={{ fontSize: 10, fill: 'var(--ark-text-disabled)' }}
                  interval="preserveStartEnd"
                />
                <YAxis domain={['dataMin - 5', 'dataMax + 5']} hide />
                <Tooltip cursor={{ stroke: 'var(--ark-text-tertiary)', strokeDasharray: '3 3' }} content={() => null} />
                {active && <ReferenceLine x={active.date} stroke="var(--ark-info)" strokeWidth={1} />}
                <Area type="monotone" dataKey="score" stroke="var(--ark-info)" strokeWidth={2} fill="url(#ark-score-hist)" activeDot={{ r: 4, fill: 'var(--ark-info)' }} dot={false} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* ── Component Breakdown ── */}
      <div className="space-y-5">
        <h3 className="text-base font-bold text-ark-text">Component Breakdown</h3>
        {CATEGORIES.map((cat) => {
          const rows = cat.members.map(compByName).filter(Boolean) as ArkLineScoreComponent[];
          if (!rows.length) return null;
          const Icon = cat.icon;
          return (
            <div key={cat.title}>
              <div className="mb-2 flex items-center gap-1.5">
                <Icon className="h-3.5 w-3.5 text-ark-text-tertiary" />
                <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">{cat.title}</span>
              </div>
              <div className="space-y-2">{rows.map((c) => <ComponentRow key={c.name} c={c} />)}</div>
            </div>
          );
        })}
        {ungrouped.length > 0 && (
          <div className="space-y-2">{ungrouped.map((c) => <ComponentRow key={c.name} c={c} />)}</div>
        )}
      </div>

      {/* ── How It Works ── */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <h4 className="text-sm font-bold text-ark-text">How It Works</h4>
        <p className="mt-1.5 text-[13px] leading-relaxed text-ark-text-secondary">
          The ArkLine Score is a proprietary composite indicator combining market signals across sentiment, macro
          conditions, and market structure. Each component is normalized to 0–100 and weighted by its predictive
          relevance. Missing data points redistribute weight to available indicators. Lower scores reflect fear and
          potential opportunity; higher scores reflect greed and elevated risk.
        </p>
      </div>
    </div>
  );
}

function ComponentRow({ c }: { c: ArkLineScoreComponent }) {
  const color = signalColor(c.signal);
  return (
    <div className="flex items-center gap-3 rounded-xl border border-ark-divider bg-ark-card/40 p-3">
      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full" style={{ backgroundColor: `${color}1F` }}>
        <SignalArrow signal={c.signal} className="h-4 w-4" color={color} />
      </div>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold text-ark-text">{c.name}</p>
        <p className="text-[11px] text-ark-text-disabled">{c.weight}% weight</p>
      </div>
      <div className="h-1.5 w-24 shrink-0 overflow-hidden rounded-full bg-ark-fill-secondary">
        <div className="h-full rounded-full" style={{ width: `${c.value}%`, backgroundColor: color }} />
      </div>
      <span className="fig w-7 shrink-0 text-right text-base font-bold" style={{ color }}>{c.value}</span>
    </div>
  );
}
