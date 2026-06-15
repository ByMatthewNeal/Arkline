'use client';

import { useState } from 'react';
import { Area, AreaChart, ResponsiveContainer, YAxis, Tooltip } from 'recharts';
import { Skeleton } from '@/components/ui';
import { useAssetRiskHistory } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';

const ASSETS = [
  { symbol: 'BTC', name: 'Bitcoin' },
  { symbol: 'ETH', name: 'Ethereum' },
  { symbol: 'SOL', name: 'Solana' },
];

const PERIODS: { label: string; days: number }[] = [
  { label: '7D', days: 7 },
  { label: '30D', days: 30 },
  { label: '90D', days: 90 },
  { label: '1Y', days: 365 },
  { label: 'ALL', days: 3650 },
];

function riskColor(v: number): string {
  if (v < 0.3) return 'var(--ark-success)';
  if (v < 0.5) return 'var(--ark-warning)';
  if (v < 0.7) return '#F97316';
  return 'var(--ark-error)';
}
function riskLabel(v: number): string {
  if (v < 0.3) return 'Low';
  if (v < 0.5) return 'Moderate';
  if (v < 0.7) return 'Elevated';
  return 'Critical';
}

export function CryptoRiskDetail() {
  const [asset, setAsset] = useState('BTC');
  const [days, setDays] = useState(90);
  const { data, isLoading } = useAssetRiskHistory(asset, days);

  const points = data ?? [];
  const current = points.length ? points[points.length - 1].risk_level : 0;
  const color = riskColor(current);
  const chart = points.map((p, i) => ({ i, v: p.risk_level, date: p.date }));

  return (
    <div className="space-y-5 pb-4">
      {/* Asset tabs */}
      <div className="flex gap-1">
        {ASSETS.map((a) => (
          <button
            key={a.symbol}
            onClick={() => setAsset(a.symbol)}
            className={cn(
              'cursor-pointer rounded-lg px-3 py-1.5 text-xs font-semibold transition-all',
              asset === a.symbol ? 'bg-ark-primary/10 text-ark-primary' : 'text-ark-text-tertiary hover:bg-ark-fill-secondary',
            )}
          >
            {a.symbol}
          </button>
        ))}
      </div>

      {/* Current value */}
      {isLoading ? (
        <Skeleton className="h-16 w-32" />
      ) : (
        <div className="flex items-baseline gap-3">
          <span className="font-[family-name:var(--font-urbanist)] text-4xl font-bold" style={{ color }}>{current.toFixed(3)}</span>
          <span className="rounded-full px-2.5 py-1 text-xs font-semibold" style={{ color, backgroundColor: `${color}1A` }}>{riskLabel(current)}</span>
          <span className="text-[11px] text-ark-text-disabled">0–1 scale</span>
        </div>
      )}

      {/* Period selector */}
      <div className="flex gap-1 rounded-full bg-ark-fill-secondary/60 p-1">
        {PERIODS.map((p) => (
          <button
            key={p.label}
            onClick={() => setDays(p.days)}
            className={cn(
              'flex-1 rounded-full px-2 py-1 text-[11px] font-semibold transition-colors',
              days === p.days ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text',
            )}
          >
            {p.label}
          </button>
        ))}
      </div>

      {/* Chart */}
      {isLoading ? (
        <Skeleton className="h-56 w-full" />
      ) : chart.length > 1 ? (
        <div className="h-56 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={chart} margin={{ top: 8, right: 8, bottom: 0, left: 0 }}>
              <defs>
                <linearGradient id="crd" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={color} stopOpacity={0.22} />
                  <stop offset="100%" stopColor={color} stopOpacity={0} />
                </linearGradient>
              </defs>
              <YAxis domain={[0, 1]} hide />
              <Tooltip
                contentStyle={{ background: 'var(--ark-card)', border: '1px solid var(--ark-divider)', borderRadius: 8, fontSize: 12 }}
                labelFormatter={() => ''}
                formatter={(v) => [Number(v).toFixed(3), 'Risk']}
              />
              <Area type="monotone" dataKey="v" stroke={color} strokeWidth={2.5} fill="url(#crd)" isAnimationActive={false} dot={false} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      ) : (
        <p className="py-8 text-center text-sm text-ark-text-tertiary">No risk history for this period.</p>
      )}

      <p className="text-[13px] leading-relaxed text-ark-text-secondary">
        Risk is each asset’s position within its long-term logarithmic regression channel — 0.0 is deeply undervalued (accumulation), 1.0 is historically overextended (distribution).
      </p>
    </div>
  );
}
