'use client';

import { Area, AreaChart, ResponsiveContainer, YAxis, Tooltip } from 'recharts';
import { Skeleton } from '@/components/ui';
import { useFearGreedDetail } from '@/lib/hooks/use-market';

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

export function FearGreedGauge() {
  const { data, isLoading } = useFearGreedDetail();
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
        <p className="text-[11px] font-bold uppercase tracking-wider text-ark-text-disabled">History (90 Days)</p>
        {data.history.length > 1 ? (
          <div className="mt-3 h-40 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={data.history} margin={{ top: 6, right: 6, bottom: 0, left: 6 }}>
                <defs>
                  <linearGradient id="fg-hist" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor={color} stopOpacity={0.3} />
                    <stop offset="100%" stopColor={color} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <YAxis domain={[0, 100]} hide />
                <Tooltip
                  contentStyle={{ background: 'var(--ark-card)', border: '1px solid var(--ark-divider)', borderRadius: 8, fontSize: 11 }}
                  labelFormatter={(l) => new Date(String(l) + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                  formatter={(v) => [`${v}`, 'Index']}
                />
                <Area type="monotone" dataKey="value" stroke={color} strokeWidth={2} fill="url(#fg-hist)" dot={false} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
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
