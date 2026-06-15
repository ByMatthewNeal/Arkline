'use client';

import { useState } from 'react';
import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip } from 'recharts';
import { TrendingUp, TrendingDown, Minus } from 'lucide-react';
import { Skeleton } from '@/components/ui';
import { useIndicatorHistory } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';

interface LevelRow { range: string; description: string; color: string }
interface InfoSection { title: string; content: string }

interface MacroDetailConfig {
  dbKey: string;       // indicator_snapshots key (vix/dxy/global_m2/net_liquidity)
  title: string;
  format: (v: number) => string;
  level: (v: number, changePct: number) => { label: string; color: string };
  levels?: LevelRow[];
  info: InfoSection[];
}

const C = {
  success: 'var(--ark-success)',
  warning: 'var(--ark-warning)',
  error: 'var(--ark-error)',
  primary: 'var(--ark-primary)',
  violet: 'var(--ark-violet)',
};

const PERIODS = [{ label: '1M', days: 30 }, { label: '3M', days: 90 }, { label: '6M', days: 180 }, { label: '1Y', days: 365 }];

function MacroDetail({ config }: { config: MacroDetailConfig }) {
  const [days, setDays] = useState(30);
  const { data: history, isLoading } = useIndicatorHistory(config.dbKey, days);

  if (isLoading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-20 w-full" />
        <Skeleton className="h-48 w-full" />
        <Skeleton className="h-32 w-full" />
      </div>
    );
  }
  const series = history ?? [];
  if (!series.length) return <p className="py-8 text-center text-sm text-ark-text-tertiary">No data available.</p>;

  const value = series[series.length - 1].value;
  const first = series[0].value;
  const changePct = first !== 0 ? ((value - first) / first) * 100 : 0;
  const lvl = config.level(value, changePct);
  const TrendIcon = lvl.label === 'Bullish' ? TrendingUp : lvl.label === 'Bearish' ? TrendingDown : Minus;
  const fmtDay = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  const periodLabel = PERIODS.find((p) => p.days === days)?.label ?? '';

  return (
    <div className="space-y-6 pb-4">
      {/* Hero value + signal */}
      <div className="flex flex-col items-center gap-3 pt-2">
        <span className="font-[family-name:var(--font-urbanist)] text-5xl font-bold text-ark-text">{config.format(value)}</span>
        <span className="inline-flex items-center gap-1.5 rounded-xl px-3 py-1.5 text-sm font-semibold" style={{ color: lvl.color, backgroundColor: `${lvl.color}26` }}>
          <TrendIcon className="h-4 w-4" />
          {lvl.label}
          <span className="ml-1 opacity-70">{changePct >= 0 ? '+' : ''}{changePct.toFixed(2)}% · {periodLabel}</span>
        </span>
      </div>

      {/* Period toggle */}
      <div className="flex justify-center">
        <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
          {PERIODS.map((p) => (
            <button key={p.label} onClick={() => setDays(p.days)} className={cn('rounded-full px-4 py-1 text-xs font-semibold transition-colors', days === p.days ? 'bg-ark-info text-white' : 'text-ark-text-tertiary')}>{p.label}</button>
          ))}
        </div>
      </div>

      {/* Chart */}
      {series.length > 1 && (
        <div className="h-52 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={series} margin={{ top: 8, right: 8, bottom: 0, left: 8 }}>
              <defs>
                <linearGradient id={`md-${config.dbKey}`} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={lvl.color} stopOpacity={0.25} />
                  <stop offset="100%" stopColor={lvl.color} stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="date" tickLine={false} axisLine={false} ticks={series.length ? [series[0].date, series[series.length - 1].date] : []} tickFormatter={fmtDay} tick={{ fontSize: 10, fill: 'var(--ark-text-disabled)' }} interval="preserveStartEnd" />
              <YAxis domain={['dataMin', 'dataMax']} hide />
              <Tooltip
                contentStyle={{ background: 'var(--ark-card)', border: '1px solid var(--ark-divider)', borderRadius: 8, fontSize: 12 }}
                labelFormatter={(l) => fmtDay(String(l))}
                formatter={(v) => [config.format(Number(v)), config.title]}
              />
              <Area type="monotone" dataKey="value" stroke={lvl.color} strokeWidth={2} fill={`url(#md-${config.dbKey})`} dot={false} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Level interpretation */}
      {config.levels && (
        <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/30 p-4">
          <h4 className="mb-3 text-sm font-semibold text-ark-text">Level Interpretation</h4>
          <div className="space-y-2.5">
            {config.levels.map((l) => (
              <div key={l.range} className="flex items-center gap-3">
                <span className="h-2.5 w-2.5 shrink-0 rounded-full" style={{ backgroundColor: l.color }} />
                <span className="w-20 shrink-0 text-xs font-semibold text-ark-text">{l.range}</span>
                <span className="text-xs text-ark-text-secondary">{l.description}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Educational sections */}
      {config.info.map((s) => (
        <div key={s.title}>
          <h4 className="mb-1.5 text-sm font-semibold text-ark-text">{s.title}</h4>
          <div className="space-y-1 text-[13px] leading-relaxed text-ark-text-secondary">
            {s.content.trim().split('\n').map((line, i) => <p key={i}>{line}</p>)}
          </div>
        </div>
      ))}
    </div>
  );
}

const vixLevel = (v: number) => v < 20 ? { label: 'Bullish', color: C.success } : v < 25 ? { label: 'Neutral', color: C.warning } : { label: 'Bearish', color: C.error };
const dxyLevel = (v: number) => v < 100 ? { label: 'Bullish', color: C.success } : v < 105 ? { label: 'Neutral', color: C.warning } : { label: 'Bearish', color: C.error };
const liquidityLevel = (_v: number, chg: number) => chg >= 0 ? { label: 'Bullish', color: C.success } : chg > -1 ? { label: 'Neutral', color: C.warning } : { label: 'Bearish', color: C.error };

export function VixDetail() {
  return <MacroDetail config={{
    dbKey: 'vix', title: 'VIX', format: (v) => v.toFixed(2), level: vixLevel,
    levels: [
      { range: 'Below 15', description: 'Low volatility — complacency', color: C.success },
      { range: '15–20', description: 'Normal market conditions', color: C.primary },
      { range: '20–25', description: 'Elevated uncertainty', color: C.warning },
      { range: '25–30', description: 'High fear — market stress', color: C.error },
      { range: 'Above 30', description: 'Extreme fear — potential panic', color: C.violet },
    ],
    info: [
      { title: 'What is VIX?', content: 'The CBOE Volatility Index (VIX) measures the market’s expectation of 30-day volatility implied by S&P 500 index options. Often called the "fear gauge," it reflects investor sentiment and uncertainty.' },
      { title: 'Impact on Crypto', content: '• High VIX (>25): risk-off — investors flee to safety, often selling crypto.\n• Low VIX (<18): risk-on — investors seek higher returns in assets like crypto.\n• VIX spikes often coincide with Bitcoin drawdowns as correlations rise during stress.' },
      { title: 'Historical Context', content: '• Average VIX: ~19–20\n• COVID crash (Mar 2020): VIX hit 82.69\n• 2008 Financial Crisis: VIX peaked at 89.53\n• Calm markets: VIX can stay below 15 for long stretches' },
    ],
  }} />;
}

export function DxyDetail() {
  return <MacroDetail config={{
    dbKey: 'dxy', title: 'DXY', format: (v) => v.toFixed(2), level: dxyLevel,
    levels: [
      { range: 'Below 90', description: 'Weak dollar — risk-on', color: C.success },
      { range: '90–100', description: 'Normal range', color: C.primary },
      { range: '100–105', description: 'Strong dollar', color: C.warning },
      { range: 'Above 105', description: 'Very strong — risk-off', color: C.error },
    ],
    info: [
      { title: 'What is DXY?', content: 'The US Dollar Index (DXY) measures the value of the US dollar against a basket of foreign currencies: Euro (57.6%), Yen (13.6%), Pound (11.9%), Canadian Dollar (9.1%), Krona (4.2%), and Swiss Franc (3.6%).' },
      { title: 'Impact on Crypto', content: '• Rising DXY: bearish for crypto — a stronger dollar reduces appetite for risk assets.\n• Falling DXY: bullish for crypto — dollar weakness drives investors to alternatives.\n• BTC and DXY typically show inverse correlation in macro-driven markets.' },
      { title: 'Historical Context', content: '• 2022 peak: DXY reached ~114, highest in 20 years\n• Pre-COVID: typically 95–100\n• 2008 low: around 71\n• Fed policy significantly impacts DXY' },
    ],
  }} />;
}

export function M2Detail() {
  return <MacroDetail config={{
    dbKey: 'global_m2', title: 'CB Liquidity', format: (v) => `$${(v / 1e12).toFixed(2)}T`, level: liquidityLevel,
    info: [
      { title: 'What is Global M2 / CB Liquidity?', content: 'Global M2 represents the total money supply across major economies — cash, deposits, and easily convertible near-money. It’s a key gauge of global liquidity and central-bank monetary conditions.' },
      { title: 'Impact on Crypto', content: '• Expanding liquidity: more money in the system, historically supportive of risk assets including Bitcoin (often with a 2–3 month lag).\n• Contracting liquidity: tightening conditions, a headwind for crypto.' },
    ],
  }} />;
}

export function NetLiquidityDetail() {
  return <MacroDetail config={{
    dbKey: 'net_liquidity', title: 'US Net Liquidity', format: (v) => `$${(v / 1e12).toFixed(2)}T`, level: liquidityLevel,
    info: [
      { title: 'What is US Net Liquidity?', content: 'US Net Liquidity tracks the Federal Reserve’s balance sheet minus money locked in the Treasury General Account (TGA) and reverse repos (RRP). It measures how much cash is actually circulating in financial markets.' },
      { title: 'Impact on Crypto', content: '• Rising Net Liquidity: more cash available for risk assets — historically the #1 short-term driver of crypto prices.\n• Falling Net Liquidity: liquidity drains (TGA rebuilds, QT, RRP inflows) tend to pressure crypto and equities.' },
      { title: 'What moves it', content: '• Fed balance sheet (QE adds, QT removes liquidity)\n• Treasury General Account (debt issuance drains, spending adds)\n• Reverse repo facility (inflows drain, outflows add)' },
    ],
  }} />;
}
