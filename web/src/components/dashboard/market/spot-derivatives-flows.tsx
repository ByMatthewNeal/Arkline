'use client';

import { Area, AreaChart, Line, LineChart, CartesianGrid, XAxis, YAxis, ResponsiveContainer, ReferenceLine } from 'recharts';
import { Skeleton } from '@/components/ui';
import { useSpotDerivativesFlows } from '@/lib/hooks/use-market';
import type { SpotDerivativesFlows } from '@/types';

function fmtSignedM(v: number | null): string {
  if (v == null) return '—';
  const sign = v > 0 ? '+' : v < 0 ? '-' : '';
  const a = Math.abs(v);
  return a >= 1000 ? `${sign}$${(a / 1000).toFixed(1)}B` : `${sign}$${a.toFixed(0)}M`;
}
function fmtSignedPct(v: number | null): string {
  if (v == null) return '—';
  return `${v > 0 ? '+' : ''}${v.toFixed(1)}%`;
}
function fmtK(v: number): string {
  return v >= 1000 ? `$${(v / 1000).toFixed(1)}k` : `$${v.toFixed(0)}`;
}

function regimeClasses(regime: string | null): string {
  switch (regime) {
    case 'Spot-led bid':
    case 'Broad risk-on':
      return 'text-emerald-500 bg-emerald-500/14';
    case 'Leverage-driven':
      return 'text-amber-500 bg-amber-500/14';
    case 'Deleveraging':
      return 'text-red-500 bg-red-500/14';
    default:
      return 'text-ark-accent bg-ark-accent/14';
  }
}

function toSeries(days: number[], values: number[]) {
  return values.map((v, i) => ({ t: days[i] * 1000, v }));
}

function MiniChart({ data, color, baseline }: { data: { t: number; v: number }[]; color: string; baseline: boolean }) {
  return (
    <ResponsiveContainer width="100%" height={140}>
      <LineChart data={data} margin={{ top: 6, right: 6, bottom: 0, left: 0 }}>
        <CartesianGrid vertical={false} stroke="var(--ark-divider, #e5e7eb)" strokeOpacity={0.3} />
        {baseline && <ReferenceLine y={0} stroke="var(--ark-text-tertiary, #9ca3af)" strokeDasharray="3 3" strokeOpacity={0.5} />}
        <XAxis
          dataKey="t" type="number" domain={['dataMin', 'dataMax']} scale="time"
          tickFormatter={(t) => new Date(t).toLocaleDateString(undefined, { month: 'short' })}
          tick={{ fontSize: 10, fill: 'var(--ark-text-tertiary, #9ca3af)' }} minTickGap={40} axisLine={false} tickLine={false}
        />
        <YAxis
          orientation="right" width={44}
          tick={{ fontSize: 10, fill: 'var(--ark-text-tertiary, #9ca3af)' }} axisLine={false} tickLine={false}
        />
        <Line type="monotone" dataKey="v" stroke={color} strokeWidth={1.8} dot={false} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export function SpotDerivativesFlowsDetail() {
  const { data, isLoading } = useSpotDerivativesFlows();
  if (isLoading) return <Skeleton className="h-72 w-full" />;
  if (!data) return <p className="py-8 text-center text-sm text-ark-text-tertiary">Flow data unavailable right now.</p>;

  const cvd = toSeries(data.days, data.spot_cvd);
  const oi = toSeries(data.days, data.oi_usd);
  const fund = toSeries(data.days, data.funding_pct);

  return (
    <div className="space-y-4">
      <div className={`rounded-2xl p-3 ${regimeClasses(data.regime)}`}>
        <div className="flex items-center justify-between">
          <span className="text-sm font-bold">{data.regime ?? 'Mixed'}</span>
          <span className="fig text-xs text-ark-text-secondary">BTC {fmtK(data.current_price)}</span>
        </div>
        {data.regime_note && <p className="mt-1 text-[13px] leading-relaxed text-ark-text-secondary">{data.regime_note}</p>}
      </div>

      <ChartCard title="Spot CVD" subtitle="Cumulative spot buying minus selling across Binance, Coinbase and Kraken"
        value={fmtSignedM(data.spot_cvd[data.spot_cvd.length - 1] ?? null)} color="#34b36b">
        <MiniChart data={cvd} color="#34b36b" baseline={false} />
      </ChartCard>

      <ChartCard title="Open Interest" subtitle="Total perp positions open, in USD"
        value={`$${(data.oi_usd[data.oi_usd.length - 1] ?? 0).toFixed(2)}B`} color="#668cf2">
        <MiniChart data={oi} color="#668cf2" baseline={false} />
      </ChartCard>

      <ChartCard title="Funding Rate" subtitle="Positive means longs pay shorts (crowded long)"
        value={data.funding_now != null ? `${data.funding_now.toFixed(3)}%` : '—'} color="#f2a033">
        <MiniChart data={fund} color="#f2a033" baseline />
      </ChartCard>

      <div className="rounded-2xl border border-ark-divider bg-ark-card p-3">
        <h4 className="mb-1.5 text-sm font-semibold text-ark-text">How to Read This</h4>
        <div className="space-y-1 text-[13px] leading-relaxed text-ark-text-secondary">
          <p>Spot CVD rising means buyers are lifting the offer on real spot exchanges. That is organic demand, not leverage.</p>
          <p>Open interest is the size of leveraged positioning. Price rising on rising OI with flat spot is leverage led and tends to be more fragile.</p>
          <p>Funding is what longs and shorts pay each other. Persistently high positive funding means the long side is crowded.</p>
          <p>The best setups usually have spot leading. Guides, not guarantees. Source: Coinalyze.</p>
        </div>
      </div>
    </div>
  );
}

function ChartCard({ title, subtitle, value, color, children }: { title: string; subtitle: string; value: string; color: string; children: React.ReactNode }) {
  return (
    <div className="rounded-2xl border border-ark-divider bg-ark-card p-3">
      <div className="flex items-baseline justify-between">
        <span className="text-sm font-semibold text-ark-text">{title}</span>
        <span className="fig text-sm font-bold" style={{ color }}>{value}</span>
      </div>
      <p className="mb-1 text-[11px] text-ark-text-tertiary">{subtitle}</p>
      {children}
    </div>
  );
}

export function SpotDerivativesFlowsTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useSpotDerivativesFlows();
  if (isLoading) return <Skeleton className="h-full w-full" />;
  if (!data) return null;
  const cvd = toSeries(data.days, data.spot_cvd);
  return (
    <button onClick={onOpen} className="flex h-full w-full flex-col overflow-hidden rounded-2xl border border-ark-divider bg-ark-card p-3 text-left">
      <div className="flex items-center justify-between">
        <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Spot vs Derivatives</span>
        {data.regime && <span className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${regimeClasses(data.regime)}`}>{data.regime}</span>}
      </div>
      <div className="mt-2 flex-1">
        <ResponsiveContainer width="100%" height={110}>
          <AreaChart data={cvd} margin={{ top: 4, right: 0, bottom: 0, left: 0 }}>
            <defs>
              <linearGradient id="cvdFill" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#34b36b" stopOpacity={0.35} />
                <stop offset="100%" stopColor="#34b36b" stopOpacity={0} />
              </linearGradient>
            </defs>
            <Area type="monotone" dataKey="v" stroke="#34b36b" strokeWidth={1.6} fill="url(#cvdFill)" />
          </AreaChart>
        </ResponsiveContainer>
      </div>
      <div className="mt-2 flex items-center justify-between text-[11px] text-ark-text-secondary">
        <span>Spot 7d <span className="fig font-semibold text-ark-text">{fmtSignedM(data.cvd_7d)}</span></span>
        <span>OI 7d <span className="fig font-semibold text-ark-text">{fmtSignedPct(data.oi_7d_pct)}</span></span>
      </div>
    </button>
  );
}
