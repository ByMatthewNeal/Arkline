'use client';

import { Area, AreaChart, ResponsiveContainer, YAxis, ReferenceLine } from 'recharts';
import { Skeleton } from '@/components/ui';
import { useSupportResistanceLevels } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';
import type { SupportResistanceAsset, SRLevel } from '@/types';

function fmtPrice(v: number): string {
  if (Math.abs(v) >= 1000) return `$${Math.round(v).toLocaleString()}`;
  if (Math.abs(v) >= 100) return `$${v.toFixed(2)}`;
  return `$${v.toFixed(2)}`;
}

function strengthColor(s: SRLevel['strength']): string {
  return s === 'strong' ? 'var(--ark-text)' : s === 'moderate' ? 'var(--ark-text-secondary)' : 'var(--ark-text-tertiary)';
}

function LevelRow({ lvl, current }: { lvl: SRLevel; current: number }) {
  const isSupport = lvl.kind === 'support';
  const pct = current > 0 ? ((lvl.price - current) / current) * 100 : 0;
  const color = isSupport ? 'var(--ark-success)' : 'var(--ark-error)';
  return (
    <div className="flex items-center gap-3 py-2">
      <span className="h-2 w-2 shrink-0 rounded-full" style={{ backgroundColor: color }} />
      <span className="fig text-sm font-semibold text-ark-text">{fmtPrice(lvl.price)}</span>
      <span className="fig text-xs text-ark-text-secondary">{pct >= 0 ? '+' : ''}{pct.toFixed(1)}%</span>
      <span className="ml-auto rounded-full px-2 py-0.5 text-[10px] font-semibold capitalize"
        style={{ color: strengthColor(lvl.strength), backgroundColor: 'var(--ark-fill-secondary)' }}>
        {lvl.strength}
      </span>
    </div>
  );
}

function AssetCard({ a }: { a: SupportResistanceAsset }) {
  const current = a.current_price;
  const nearestRes = a.resistances[0];
  const nearestSup = a.supports[0];

  // Zoom the y-axis to the recent price slice + the nearest drawn levels so the
  // reference lines have room to separate (same idea as the iOS card).
  const closes = a.series.map((p) => p.close);
  const candidates = [...closes];
  if (nearestRes) candidates.push(nearestRes.price);
  if (nearestSup) candidates.push(nearestSup.price);
  candidates.push(current);
  const lo = Math.min(...candidates);
  const hi = Math.max(...candidates);
  const pad = Math.max((hi - lo) * 0.06, hi * 0.004);

  return (
    <div className="rounded-2xl border border-ark-divider bg-ark-card p-4">
      <div className="mb-2">
        <h4 className="text-base font-semibold text-ark-text">{a.name}</h4>
        <p className="text-[11px] text-ark-text-tertiary">{a.asset} · where price has reacted before</p>
      </div>

      <div className="h-40 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={a.series} margin={{ top: 6, right: 8, bottom: 0, left: 0 }}>
            <defs>
              <linearGradient id={`sr-${a.asset}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="var(--ark-info)" stopOpacity={0.25} />
                <stop offset="100%" stopColor="var(--ark-info)" stopOpacity={0} />
              </linearGradient>
            </defs>
            <YAxis
              domain={[lo - pad, hi + pad]}
              orientation="right"
              width={56}
              tick={{ fontSize: 10, fill: 'var(--ark-text-tertiary)' }}
              tickFormatter={(v: number) => (v >= 1000 ? `$${Math.round(v / 1000)}k` : `$${Math.round(v)}`)}
            />
            <Area type="monotone" dataKey="close" stroke="var(--ark-info)" strokeWidth={1.5} fill={`url(#sr-${a.asset})`} isAnimationActive={false} />
            {nearestRes && <ReferenceLine y={nearestRes.price} stroke="var(--ark-error)" strokeDasharray="4 3" strokeOpacity={0.6} />}
            {nearestSup && <ReferenceLine y={nearestSup.price} stroke="var(--ark-success)" strokeDasharray="4 3" strokeOpacity={0.6} />}
            <ReferenceLine y={current} stroke="var(--ark-text-tertiary)" strokeOpacity={0.5}
              label={{ value: `Now · ${fmtPrice(current)}`, position: 'insideLeft', fontSize: 10, fill: 'var(--ark-text-secondary)' }} />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {a.resistances.length > 0 && (
        <>
          <p className="mt-3 mb-0.5 text-[10px] font-bold uppercase tracking-wider text-ark-error">Resistance</p>
          {a.resistances.map((l, i) => <LevelRow key={`r${i}`} lvl={l} current={current} />)}
        </>
      )}
      {a.supports.length > 0 && (
        <>
          <p className="mt-2 mb-0.5 text-[10px] font-bold uppercase tracking-wider text-ark-success">Support</p>
          {a.supports.map((l, i) => <LevelRow key={`s${i}`} lvl={l} current={current} />)}
        </>
      )}

      <p className={cn('mt-3 text-[10px] leading-relaxed text-ark-text-tertiary')}>
        Algorithmic levels from price history and volume. Guides, not guarantees, the market doesn&apos;t owe them respect.
      </p>
    </div>
  );
}

export function SupportResistanceDetail() {
  const { data, isLoading } = useSupportResistanceLevels();

  if (isLoading) return <Skeleton className="h-64 w-full" />;
  const assets = data ?? [];
  if (assets.length === 0) {
    return <p className="py-8 text-center text-sm text-ark-text-tertiary">Levels unavailable right now.</p>;
  }

  return (
    <div className="space-y-4 pb-4">
      {assets.map((a) => <AssetCard key={a.asset} a={a} />)}
    </div>
  );
}
