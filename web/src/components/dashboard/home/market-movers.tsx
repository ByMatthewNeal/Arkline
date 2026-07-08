'use client';

import { useState } from 'react';
import { ArrowUp, ArrowDown, ArrowDownRight, ArrowUpRight, ArrowRight, Snowflake, Flame, AlertTriangle } from 'lucide-react';
import { Skeleton } from '@/components/ui';
import { useAssetTechnical } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';
import type { AssetTechnicalData } from '@/types';

const ASSETS = ['BTC', 'ETH', 'SOL'];
const ASSET_COLORS: Record<string, string> = { BTC: '#F7931A', ETH: '#627EEA', SOL: '#14F195' };

const RED = 'var(--ark-error)';
const GREEN = 'var(--ark-success)';
const YELLOW = 'var(--ark-warning)';

const money = (v: number) => `$${v.toLocaleString(undefined, { maximumFractionDigits: v < 10 ? 4 : 2 })}`;
const pct = (v: number) => `${v >= 0 ? '+' : ''}${v.toFixed(1)}%`;

export function MarketMovers({ initialSymbol }: { initialSymbol?: string } = {}) {
  const [symbol, setSymbol] = useState(initialSymbol && ASSETS.includes(initialSymbol.toUpperCase()) ? initialSymbol.toUpperCase() : 'BTC');
  const { data, isLoading } = useAssetTechnical(symbol);

  return (
    <div className="space-y-4 pb-2">
      {/* Asset tabs */}
      <div className="flex justify-center">
        <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
          {ASSETS.map((a) => (
            <button key={a} onClick={() => setSymbol(a)} className={cn('rounded-full px-5 py-1.5 text-sm font-semibold transition-colors', symbol === a ? 'bg-ark-info text-white' : 'text-ark-text-tertiary')}>{a}</button>
          ))}
        </div>
      </div>

      {isLoading || !data ? (
        <div className="space-y-4">
          <Skeleton className="h-20 w-full rounded-2xl" />
          <Skeleton className="h-40 w-full rounded-2xl" />
          <Skeleton className="h-40 w-full rounded-2xl" />
        </div>
      ) : (
        <AssetTechnical d={data} />
      )}
    </div>
  );
}

function AssetTechnical({ d }: { d: AssetTechnicalData }) {
  const up24 = d.changePct24h >= 0;
  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center gap-3 rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <div className="flex h-11 w-11 items-center justify-center rounded-full text-sm font-bold text-white" style={{ backgroundColor: ASSET_COLORS[d.symbol] ?? 'var(--ark-info)' }}>{d.symbol}</div>
        <div className="flex-1">
          <p className="text-lg font-bold text-ark-text">{d.name}</p>
          <p className="fig text-sm text-ark-text-secondary">{money(d.price)}</p>
        </div>
        <div className="text-right">
          <p className={cn('fig text-sm font-bold', up24 ? 'text-ark-success' : 'text-ark-error')}>{pct(d.changePct24h)}</p>
          <p className="text-[11px] text-ark-text-disabled">24h</p>
        </div>
      </div>

      {/* Investment insight */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <h4 className="text-sm font-bold text-ark-text">Investment Insight</h4>
        <p className="mt-1.5 text-[13px] leading-relaxed text-ark-text-secondary">{d.insight}</p>
      </div>

      {/* Trend & Valuation gauges */}
      <div className="grid grid-cols-2 gap-3">
        <GaugeCard title="Trend" value={d.trendScore} label={d.trendLabel} color={d.trendScore < 40 ? RED : d.trendScore > 60 ? GREEN : YELLOW} />
        <GaugeCard title="Valuation" value={d.valuationScore} label={d.valuationLabel} color={d.valuationScore > 55 ? GREEN : d.valuationScore < 45 ? RED : YELLOW} />
      </div>

      {/* Market outlook */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <h4 className="mb-3 text-sm font-bold text-ark-text">Market Outlook</h4>
        <div className="flex">
          <OutlookCol title="Short Term" label={d.shortTerm.label} direction={d.shortTerm.direction} />
          <div className="w-px bg-ark-divider" />
          <OutlookCol title="Long Term" label={d.longTerm.label} direction={d.longTerm.direction} />
        </div>
      </div>

      {/* RSI */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <div className="flex items-center justify-between">
          <h4 className="text-sm font-bold text-ark-text">RSI (14)</h4>
          <span className="rounded-full bg-ark-success/10 px-2.5 py-0.5 text-[11px] font-semibold text-ark-success">{d.rsiLabel}</span>
        </div>
        <p className="mt-2 text-center"><span className="fig text-4xl font-bold text-ark-success">{d.rsi.toFixed(1)}</span><span className="text-sm text-ark-text-disabled"> / 100</span></p>
        <div className="relative mt-2">
          <div className="flex h-2.5 overflow-hidden rounded-full">
            <div className="w-[30%]" style={{ background: 'linear-gradient(90deg, #166534, #3F6212)' }} />
            <div className="w-[40%]" style={{ background: 'linear-gradient(90deg, #3F6212, #7C5210)' }} />
            <div className="w-[30%]" style={{ background: 'linear-gradient(90deg, #7C5210, #991B1B)' }} />
          </div>
          <div className="absolute top-1/2 h-4 w-4 -translate-x-1/2 -translate-y-1/2 rounded-full border-2 border-ark-card bg-white shadow" style={{ left: `${Math.min(98, Math.max(2, d.rsi))}%` }} />
        </div>
        <div className="mt-1 flex justify-between text-[11px] text-ark-text-disabled"><span>30</span><span>70</span></div>
        <p className="mt-1.5 text-[12px] font-medium text-ark-success">{d.rsiNote}</p>
      </div>

      {/* Trend overview */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <h4 className="mb-3 text-sm font-bold text-ark-text">Trend Overview</h4>
        <div className="grid grid-cols-3 gap-3">
          {d.timeframes.map((tf) => {
            const down = tf.direction === 'down';
            const c = down ? RED : tf.direction === 'up' ? GREEN : YELLOW;
            return (
              <div key={tf.timeframe} className="rounded-xl border border-ark-divider bg-ark-card/40 p-3 text-center">
                <p className="text-[11px] text-ark-text-disabled">{tf.timeframe}</p>
                <div className="my-2 flex justify-center">
                  <div className="flex h-9 w-9 items-center justify-center rounded-full" style={{ backgroundColor: `${c}1F` }}>
                    {down ? <ArrowDown className="h-4 w-4" style={{ color: c }} /> : tf.direction === 'up' ? <ArrowUp className="h-4 w-4" style={{ color: c }} /> : <ArrowRight className="h-4 w-4" style={{ color: c }} />}
                  </div>
                </div>
                <p className="text-[12px] font-bold" style={{ color: c }}>{tf.label}</p>
                <div className="mt-1.5 flex justify-center gap-0.5">
                  {[0, 1, 2].map((i) => <span key={i} className="h-2 w-1 rounded-sm" style={{ backgroundColor: i < tf.strength ? c : 'var(--ark-fill-secondary)' }} />)}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Bull market bands */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <div className="flex items-center justify-between">
          <h4 className="text-sm font-bold text-ark-text">Bull Market Bands</h4>
          <span className={cn('flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11px] font-semibold', d.bmsb.above ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-error/10 text-ark-error')}>{d.bmsb.status}</span>
        </div>
        <div className="mt-3 grid grid-cols-2 gap-3">
          <BandCol label="20W SMA" value={d.bmsb.sma20w} pctv={d.bmsb.sma20wPct} />
          <BandCol label="21W EMA" value={d.bmsb.ema21w} pctv={d.bmsb.ema21wPct} />
        </div>
        <p className={cn('mt-3 text-[12px] font-medium', d.bmsb.above ? 'text-ark-success' : 'text-ark-error')}>{d.bmsb.above ? 'Bull market support holding' : 'Bull market support lost'}</p>
      </div>

      {/* Key levels */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <div className="flex items-center justify-between">
          <h4 className="text-sm font-bold text-ark-text">Key Levels</h4>
          <span className={cn('rounded-full px-2.5 py-0.5 text-[11px] font-semibold', d.keyLevels.every((k) => k.above) ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-error/10 text-ark-error')}>{d.keyLevels.every((k) => k.above) ? 'Bullish' : d.keyLevels.some((k) => k.above) ? 'Mixed' : 'Bearish'}</span>
        </div>
        <div className="mt-3 grid grid-cols-3 gap-3">
          {d.keyLevels.map((k) => {
            const c = k.above ? GREEN : RED;
            return (
              <div key={k.label} className="text-center">
                <div className="mx-auto flex h-9 w-9 items-center justify-center rounded-full" style={{ backgroundColor: `${c}1F` }}>
                  {k.above ? <ArrowUp className="h-4 w-4" style={{ color: c }} /> : <ArrowDown className="h-4 w-4" style={{ color: c }} />}
                </div>
                <p className="mt-1 text-[11px] text-ark-text-disabled">{k.label}</p>
                <p className="fig text-[11px] font-semibold text-ark-text-secondary">{money(k.value)}</p>
              </div>
            );
          })}
        </div>
        {d.deathCross && (
          <p className="mt-3 flex items-center gap-1.5 text-[12px] font-semibold text-ark-error"><AlertTriangle className="h-3.5 w-3.5" /> Death Cross</p>
        )}
        {d.goldenCross && !d.deathCross && (
          <p className="mt-3 flex items-center gap-1.5 text-[12px] font-semibold text-ark-success"><Flame className="h-3.5 w-3.5" /> Golden Cross</p>
        )}
      </div>
    </div>
  );
}

function GaugeCard({ title, value, label, color }: { title: string; value: number; label: string; color: string }) {
  const R = 34, C = 2 * Math.PI * R, off = C * (1 - value / 100);
  return (
    <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
      <div className="relative mx-auto h-24 w-24">
        <svg viewBox="0 0 80 80" className="h-full w-full -rotate-90">
          <circle cx="40" cy="40" r={R} fill="none" stroke="var(--ark-fill-secondary)" strokeWidth="7" />
          <circle cx="40" cy="40" r={R} fill="none" stroke={color} strokeWidth="7" strokeLinecap="round" strokeDasharray={C} strokeDashoffset={off} />
        </svg>
        <div className="absolute inset-0 flex items-center justify-center">
          <span className="fig text-2xl font-bold" style={{ color }}>{value}</span>
        </div>
      </div>
      <p className="mt-1 text-center text-[11px] uppercase tracking-wider text-ark-text-tertiary">{title}</p>
      <p className="text-center text-[13px] font-bold" style={{ color }}>{label}</p>
    </div>
  );
}

function OutlookCol({ title, label, direction }: { title: string; label: string; direction: 'up' | 'down' | 'flat' }) {
  const veryBear = label.toLowerCase().includes('very');
  const c = direction === 'down' ? RED : direction === 'up' ? GREEN : YELLOW;
  return (
    <div className="flex-1 text-center">
      <div className="mx-auto flex h-11 w-11 items-center justify-center rounded-full" style={{ backgroundColor: `${c}1F` }}>
        {veryBear ? <Snowflake className="h-5 w-5" style={{ color: c }} /> : direction === 'down' ? <ArrowDownRight className="h-5 w-5" style={{ color: c }} /> : direction === 'up' ? <ArrowUpRight className="h-5 w-5" style={{ color: c }} /> : <ArrowRight className="h-5 w-5" style={{ color: c }} />}
      </div>
      <p className="mt-1.5 text-[11px] text-ark-text-disabled">{title}</p>
      <p className="text-[13px] font-bold" style={{ color: c }}>{label}</p>
    </div>
  );
}

function BandCol({ label, value, pctv }: { label: string; value: number; pctv: number }) {
  const c = pctv >= 0 ? GREEN : RED;
  return (
    <div className="text-center">
      <div className="mx-auto flex h-9 w-9 items-center justify-center rounded-full" style={{ backgroundColor: `${c}1F` }}>
        {pctv >= 0 ? <ArrowUp className="h-4 w-4" style={{ color: c }} /> : <ArrowDown className="h-4 w-4" style={{ color: c }} />}
      </div>
      <p className="mt-1 text-[11px] text-ark-text-disabled">{label}</p>
      <p className="fig text-sm font-semibold text-ark-text">{money(value)}</p>
      <p className="fig text-[11px] font-semibold" style={{ color: c }}>{pct(pctv)}</p>
    </div>
  );
}
