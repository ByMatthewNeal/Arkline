'use client';

import { useState } from 'react';
import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip, ReferenceLine } from 'recharts';
import { Skeleton } from '@/components/ui';
import { useFearGreedDetail } from '@/lib/hooks/use-market';
import type { FearGreedHistoryPoint } from '@/types';

function fgColor(v: number): string {
  if (v < 25) return 'var(--ark-error)';
  if (v < 45) return '#F97316';
  if (v < 56) return 'var(--ark-warning)';
  if (v < 76) return '#65A30D';
  return 'var(--ark-success)';
}
function fgClass(v: number): string {
  if (v < 25) return 'Extreme Fear';
  if (v < 45) return 'Fear';
  if (v < 56) return 'Neutral';
  if (v < 76) return 'Greed';
  return 'Extreme Greed';
}

const LEVELS = [
  { range: '0–24', label: 'Extreme Fear', note: 'Market panic — historically a buying opportunity', color: 'var(--ark-error)' },
  { range: '25–44', label: 'Fear', note: 'Investors are worried — caution dominates', color: '#F97316' },
  { range: '45–55', label: 'Neutral', note: 'No strong bias in either direction', color: 'var(--ark-warning)' },
  { range: '56–75', label: 'Greed', note: 'Optimism rising — markets trending up', color: '#65A30D' },
  { range: '76–100', label: 'Extreme Greed', note: 'Euphoria — historically a time to be cautious', color: 'var(--ark-success)' },
];

// point on a 180° semicircle (cx100 cy100 r80) for value 0-100
function pointAt(v: number) {
  const angle = (Math.PI) * (1 - v / 100); // π (left) → 0 (right)
  return { x: 100 + 80 * Math.cos(angle), y: 100 - 80 * Math.sin(angle) };
}

const money = (v?: number) => v == null ? '—' : `$${Math.round(v).toLocaleString()}`;

export function FearGreedGauge() {
  const { data, isLoading } = useFearGreedDetail();
  const [active, setActive] = useState<FearGreedHistoryPoint | null>(null);
  if (isLoading || !data) return <Skeleton className="h-72 w-full rounded-2xl" />;

  const { value } = data;
  const color = fgColor(value);
  const marker = pointAt(value);
  const cmp = (label: string, v?: number) => (
    <div className="flex-1 text-center">
      <p className="fig text-lg font-bold text-ark-text">{v == null ? '—' : v}</p>
      <p className="text-[11px] text-ark-text-disabled">{label}</p>
    </div>
  );

  return (
    <div className="space-y-5 pb-2">
      {/* Gauge card */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-5">
        <div className="flex justify-center">
          <svg viewBox="0 0 200 120" className="w-60">
            <defs>
              <linearGradient id="fg-arc" x1="0" y1="0" x2="1" y2="0">
                <stop offset="0%" stopColor="var(--ark-error)" />
                <stop offset="35%" stopColor="#F97316" />
                <stop offset="50%" stopColor="var(--ark-warning)" />
                <stop offset="70%" stopColor="#65A30D" />
                <stop offset="100%" stopColor="var(--ark-success)" />
              </linearGradient>
            </defs>
            <path d="M 20 100 A 80 80 0 0 1 180 100" fill="none" stroke="url(#fg-arc)" strokeWidth="12" strokeLinecap="round" />
            <circle cx={marker.x} cy={marker.y} r="7" fill="var(--ark-card)" stroke={color} strokeWidth="3" />
          </svg>
        </div>
        <div className="-mt-4 text-center">
          <p className="font-[family-name:var(--font-urbanist)] text-5xl font-bold text-ark-text">{value}</p>
          <p className="text-xs text-ark-text-disabled">/ 100</p>
          <p className="mt-1 text-lg font-bold" style={{ color }}>{data.classification || fgClass(value)}</p>
        </div>
        <div className="mt-4 flex border-t border-ark-divider pt-3">
          {cmp('Yesterday', data.yesterday)}
          <div className="w-px bg-ark-divider" />
          {cmp('Last Week', data.lastWeek)}
          <div className="w-px bg-ark-divider" />
          {cmp('Last Month', data.lastMonth)}
        </div>
      </div>

      {/* History */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <div className="flex items-center justify-between">
          <p className="text-[11px] font-bold uppercase tracking-wider text-ark-text-disabled">History (90 Days)</p>
          {active && <button onClick={() => setActive(null)} className="text-xs font-semibold text-ark-info">Reset</button>}
        </div>

        {data.history.length > 1 ? (
          <>
            {active ? (
              <div className="mt-2">
                <p className="text-xs text-ark-text-tertiary">{new Date(active.date + 'T00:00:00').toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })}</p>
                <div className="mt-0.5 flex items-center gap-2">
                  <span className="fig text-2xl font-bold" style={{ color: fgColor(active.value) }}>{active.value}</span>
                  <span className="rounded px-2 py-0.5 text-[10px] font-semibold" style={{ backgroundColor: `${fgColor(active.value)}1F`, color: fgColor(active.value) }}>{active.classification || fgClass(active.value)}</span>
                </div>
                <div className="mt-1 flex flex-wrap gap-x-4 gap-y-0.5 text-[11px] text-ark-text-disabled">
                  <span>BTC <span className="fig font-semibold text-ark-text-secondary">{money(active.btcPrice)}</span></span>
                  <span>S&amp;P <span className="fig font-semibold text-ark-text-secondary">{money(active.sp500Price)}</span></span>
                  <span>NDX <span className="fig font-semibold text-ark-text-secondary">{money(active.nasdaqPrice)}</span></span>
                </div>
              </div>
            ) : (
              <p className="mt-1 text-xs text-ark-text-disabled">Touch the chart to view historical values</p>
            )}

            <div className="mt-3 h-40 w-full">
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart
                  data={data.history}
                  margin={{ top: 6, right: 6, bottom: 0, left: 6 }}
                  onMouseMove={(s) => {
                    const st = s as { activeLabel?: string; activeTooltipIndex?: number };
                    let pt: FearGreedHistoryPoint | undefined;
                    if (st.activeLabel != null) pt = data.history.find((h) => h.date === st.activeLabel);
                    if (!pt && st.activeTooltipIndex != null && st.activeTooltipIndex >= 0) pt = data.history[st.activeTooltipIndex];
                    if (pt) setActive(pt);
                  }}
                  onMouseLeave={() => setActive(null)}
                >
                  <defs>
                    <linearGradient id="fg-hist" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor={color} stopOpacity={0.3} />
                      <stop offset="100%" stopColor={color} stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <XAxis dataKey="date" hide />
                  <YAxis domain={[0, 100]} hide />
                  <Tooltip cursor={{ stroke: 'var(--ark-text-tertiary)', strokeDasharray: '3 3' }} content={() => null} />
                  {active && <ReferenceLine x={active.date} stroke={color} strokeWidth={1} />}
                  <Area type="monotone" dataKey="value" stroke={color} strokeWidth={2} fill="url(#fg-hist)" activeDot={{ r: 4, fill: color }} dot={false} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </>
        ) : (
          <p className="py-10 text-center text-sm text-ark-text-disabled">Not enough history data</p>
        )}
      </div>

      {/* Level guide */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <p className="mb-3 text-[11px] font-bold uppercase tracking-wider text-ark-text-disabled">Level Guide</p>
        <div className="space-y-3">
          {LEVELS.map((l) => (
            <div key={l.range} className="flex items-start gap-2.5">
              <span className="mt-1 h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: l.color }} />
              <div>
                <p className="text-sm font-semibold text-ark-text">
                  <span className="fig">{l.range}</span> <span style={{ color: l.color }}>{l.label}</span>
                </p>
                <p className="text-[12px] text-ark-text-tertiary">{l.note}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
