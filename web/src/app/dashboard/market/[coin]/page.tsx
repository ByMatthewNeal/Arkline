'use client';

import { useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip } from 'recharts';
import { ArrowLeft, Star } from 'lucide-react';
import { Skeleton } from '@/components/ui';
import { useCryptoAssets, useAssetSnapshots, useRiskLevels } from '@/lib/hooks/use-market';
import { useWatchlist } from '@/lib/hooks/use-watchlist';
import { AssetLogo } from '@/components/dashboard/home/risk-levels-detail';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';

const PERIODS = [{ label: '7D', days: 7 }, { label: '30D', days: 30 }, { label: '90D', days: 90 }, { label: '1Y', days: 365 }, { label: 'ALL', days: 100000 }];

function compact(v: number): string {
  if (!Number.isFinite(v)) return '—';
  if (Math.abs(v) >= 1e12) return `$${(v / 1e12).toFixed(2)}T`;
  if (Math.abs(v) >= 1e9) return `$${(v / 1e9).toFixed(2)}B`;
  if (Math.abs(v) >= 1e6) return `$${(v / 1e6).toFixed(2)}M`;
  return `$${v.toLocaleString()}`;
}
const num = (v: number) => Number.isFinite(v) ? v.toLocaleString(undefined, { maximumFractionDigits: 0 }) : '—';

export default function AssetDetailPage() {
  const params = useParams();
  const router = useRouter();
  const coin = String(params.coin);

  const { data: assets, isLoading: assetsLoading } = useCryptoAssets(1);
  const { data: snaps, isLoading: snapsLoading } = useAssetSnapshots(coin);
  const { data: risk } = useRiskLevels('crypto');
  const { has, toggle } = useWatchlist();

  const asset = (assets ?? []).find((a) => a.id === coin);
  const latest = snaps && snaps.length ? snaps[snaps.length - 1] : undefined;
  const riskItem = asset ? (risk ?? []).find((r) => r.symbol.toLowerCase() === asset.symbol.toLowerCase()) : undefined;

  const [days, setDays] = useState(90);
  const favSymbol = asset?.symbol ?? coin;
  const fav = has(favSymbol);
  const toggleFav = () => toggle(favSymbol);

  if (assetsLoading || snapsLoading) {
    return <div className="space-y-4"><Skeleton className="h-24 w-full rounded-2xl" /><Skeleton className="h-72 w-full rounded-2xl" /><Skeleton className="h-40 w-full rounded-2xl" /></div>;
  }

  const price = asset?.current_price ?? latest?.price ?? 0;
  const change = asset?.price_change_percentage_24h ?? latest?.price_change_pct_24h ?? 0;
  const up = change >= 0;
  const symbol = asset?.symbol.toUpperCase() ?? coin.toUpperCase();
  const name = asset?.name ?? coin;

  const history = (snaps ?? []).slice(-days).map((s) => ({ date: s.date, value: s.price }));
  const curveColor = up ? 'var(--ark-success)' : 'var(--ark-error)';
  const fmtDay = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

  const stat = (label: string, value: string, sub?: string, color?: string) => (
    <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-3">
      <p className="text-[10px] uppercase tracking-wider text-ark-text-disabled">{label}</p>
      <p className="fig mt-0.5 text-sm font-bold" style={{ color: color ?? 'var(--ark-text)' }}>{value}</p>
      {sub && <p className="fig text-[10px] text-ark-text-disabled">{sub}</p>}
    </div>
  );

  return (
    <div className="space-y-5">
      <button onClick={() => router.back()} className="inline-flex items-center gap-1 text-sm font-semibold text-ark-info">
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      {/* Header */}
      <div className="flex items-center gap-4 rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-5">
        {asset ? <AssetLogo symbol={asset.symbol} kind="crypto" size={48} /> : <div className="h-12 w-12 rounded-full bg-ark-fill-secondary" />}
        <div className="flex-1">
          <div className="flex items-center gap-2">
            <h1 className="text-2xl font-bold text-ark-text">{name}</h1>
            <span className="rounded-md bg-ark-fill-secondary px-1.5 py-0.5 text-[11px] font-semibold text-ark-text-tertiary">{symbol}</span>
            {latest?.market_cap_rank ? <span className="text-[11px] text-ark-text-disabled">#{latest.market_cap_rank}</span> : null}
          </div>
          <div className="mt-1 flex items-baseline gap-2">
            <span className="fig text-2xl font-bold text-ark-text">{formatCurrency(price)}</span>
            <span className={cn('fig text-sm font-semibold', up ? 'text-ark-success' : 'text-ark-error')}>{formatPercent(change)} 24h</span>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {riskItem && (
            <span className="rounded-full px-2.5 py-1 text-[11px] font-bold"
              style={{ backgroundColor: 'var(--ark-fill-secondary)', color: 'var(--ark-text-secondary)' }}>
              Risk <span className="fig">{riskItem.value.toFixed(2)}</span> · {riskItem.band}
            </span>
          )}
          <button onClick={toggleFav} title={fav ? 'Remove from watchlist' : 'Add to watchlist'}
            className={cn('flex h-9 w-9 items-center justify-center rounded-lg border transition-colors', fav ? 'border-ark-warning bg-ark-warning/10 text-ark-warning' : 'border-ark-divider text-ark-text-tertiary hover:bg-ark-fill-secondary')}>
            <Star className={cn('h-4 w-4', fav && 'fill-current')} />
          </button>
        </div>
      </div>

      {/* Chart */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <div className="mb-2 flex justify-center">
          <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
            {PERIODS.map((p) => (
              <button key={p.label} onClick={() => setDays(p.days)} className={cn('rounded-full px-3 py-1 text-xs font-semibold transition-colors', days === p.days ? 'bg-ark-info text-white' : 'text-ark-text-tertiary')}>{p.label}</button>
            ))}
          </div>
        </div>
        {history.length > 1 ? (
          <div className="h-72 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={history} margin={{ top: 8, right: 8, bottom: 0, left: 8 }}>
                <defs>
                  <linearGradient id="asset-curve" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor={curveColor} stopOpacity={0.22} />
                    <stop offset="100%" stopColor={curveColor} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="date" tickLine={false} axisLine={false}
                  ticks={history.length ? [history[0].date, history[history.length - 1].date] : []}
                  tickFormatter={fmtDay} tick={{ fontSize: 10, fill: 'var(--ark-text-disabled)' }} interval="preserveStartEnd" />
                <YAxis domain={['dataMin', 'dataMax']} hide />
                <Tooltip contentStyle={{ background: 'var(--ark-card)', border: '1px solid var(--ark-divider)', borderRadius: 8, fontSize: 12 }}
                  labelFormatter={(l) => fmtDay(String(l))} formatter={(v) => [formatCurrency(Number(v)), 'Price']} />
                <Area type="monotone" dataKey="value" stroke={curveColor} strokeWidth={2} fill="url(#asset-curve)" dot={false} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        ) : (
          <p className="py-10 text-center text-sm text-ark-text-tertiary">No price history available.</p>
        )}
      </div>

      {/* Stats */}
      {latest && (
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {stat('Market Cap', compact(latest.market_cap))}
          {stat('24h Volume', compact(latest.total_volume))}
          {stat('24h High', formatCurrency(latest.high_24h))}
          {stat('24h Low', formatCurrency(latest.low_24h))}
          {stat('All-Time High', formatCurrency(latest.ath), `${formatPercent(latest.ath_change_percentage)} from ATH`, 'var(--ark-text)')}
          {stat('All-Time Low', formatCurrency(latest.atl))}
          {stat('Circulating Supply', `${num(latest.circulating_supply)} ${symbol}`)}
          {stat('Max Supply', latest.max_supply ? `${num(latest.max_supply)} ${symbol}` : '∞')}
        </div>
      )}
    </div>
  );
}
