'use client';

import { useState } from 'react';
import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip } from 'recharts';
import { ChevronRight, ChevronLeft, ArrowUp, ArrowDown, HelpCircle } from 'lucide-react';
import { Skeleton } from '@/components/ui';
import { useRiskLevels, useIndicatorHistory, useBtcMultiFactor } from '@/lib/hooks/use-market';
import { RISK_BANDS, riskBandFor } from '@/lib/risk/multi-factor';
import { cn } from '@/lib/utils/format';
import type { RiskBand, RiskLevelItem } from '@/types';

const BANDS: { band: RiskBand; color: string }[] = [
  { band: 'Very Low', color: 'var(--ark-info)' },
  { band: 'Low', color: 'var(--ark-success)' },
  { band: 'Neutral', color: 'var(--ark-warning)' },
  { band: 'Elevated', color: '#F97316' },
  { band: 'High', color: 'var(--ark-error)' },
];
const bandColor = (b: RiskBand) => BANDS.find((x) => x.band === b)?.color ?? 'var(--ark-text-tertiary)';

// ticker → company domain for stock logos (Clearbit); crypto uses the icon CDN
const STOCK_DOMAIN: Record<string, string> = {
  aapl: 'apple.com', amd: 'amd.com', amzn: 'amazon.com', asml: 'asml.com', asts: 'ast-science.com',
  axti: 'axt.com', bitf: 'bitfarms.com', bmnr: 'bitminetech.io', cifr: 'ciphermining.com', coin: 'coinbase.com',
  dgxx: 'digipowerx.com', googl: 'abc.xyz', hood: 'robinhood.com', iren: 'iren.com', meta: 'meta.com',
  mp: 'mpmaterials.com', msft: 'microsoft.com', mstr: 'strategy.com', mu: 'micron.com', nbis: 'nebius.com',
  nuai: 'nuvve.com', nvda: 'nvidia.com', onds: 'ondas.com', open: 'opendoor.com', orcl: 'oracle.com',
  pl: 'planet.com', qbts: 'dwavequantum.com', qqq: 'invesco.com', rdw: 'redwirespace.com', rklb: 'rocketlabusa.com',
  satl: 'satellogic.com', sidu: 'sidusspace.com', sndk: 'sandisk.com', spy: 'ssga.com', tsla: 'tesla.com',
  tsm: 'tsmc.com', uber: 'uber.com', wulf: 'terawulf.com',
};

export function AssetLogo({ symbol, kind, size = 36 }: { symbol: string; kind: 'crypto' | 'stock'; size?: number }) {
  const [idx, setIdx] = useState(0);
  const lower = symbol.toLowerCase();
  const upper = symbol.toUpperCase();
  const sources = kind === 'crypto'
    ? [
        `https://assets.coincap.io/assets/icons/${lower}@2x.png`,
        `https://cdn.jsdelivr.net/npm/cryptocurrency-icons@0.18.1/svg/color/${lower}.svg`,
      ]
    : [
        `https://financialmodelingprep.com/image-stock/${upper}.png`,
        ...(STOCK_DOMAIN[lower] ? [`https://logo.clearbit.com/${STOCK_DOMAIN[lower]}`] : []),
      ];

  if (idx >= sources.length) {
    return (
      <span className="flex shrink-0 items-center justify-center rounded-full bg-ark-fill-secondary text-[9px] font-bold text-ark-text-secondary" style={{ width: size, height: size }}>
        {symbol.slice(0, 4)}
      </span>
    );
  }
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={sources[idx]} alt={symbol} onError={() => setIdx((i) => i + 1)} className="shrink-0 rounded-full bg-white object-contain" style={{ width: size, height: size }} />
  );
}

export function CryptoRiskLevelsDetail({ initialSymbol }: { initialSymbol?: string } = {}) { return <RiskLevelsDetail kind="crypto" initialSymbol={initialSymbol} />; }
export function StockRiskLevelsDetail({ initialSymbol }: { initialSymbol?: string } = {}) { return <RiskLevelsDetail kind="stock" initialSymbol={initialSymbol} />; }

function RiskLevelsDetail({ kind, initialSymbol }: { kind: 'crypto' | 'stock'; initialSymbol?: string }) {
  const { data, isLoading } = useRiskLevels(kind);
  const [sort, setSort] = useState<'band' | 'az'>('band');
  const [period, setPeriod] = useState<7 | 30>(7);
  const [selectedSym, setSelectedSym] = useState<string | null>(initialSymbol ? initialSymbol.toUpperCase() : null);

  const selected = selectedSym ? (data ?? []).find((i) => i.symbol === selectedSym) : undefined;
  if (selectedSym && selected) {
    return <AssetRiskChart kind={kind} item={selected} onBack={() => setSelectedSym(null)} />;
  }

  if (isLoading || !data) {
    return <div className="space-y-3 pb-4">{[0, 1, 2, 3, 4].map((i) => <Skeleton key={i} className="h-14 w-full rounded-xl" />)}</div>;
  }

  const items = data;
  const subtitle = kind === 'crypto' ? `Regression model · ${items.length} assets` : `Trend & momentum · ${items.length} stocks bucketed`;

  return (
    <div className="space-y-4 pb-2">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div>
          <p className="text-sm text-ark-text-secondary">{subtitle}</p>
          <p className="text-[11px] text-ark-text-disabled">Refreshes at 7 AM &amp; 5 PM ET</p>
        </div>
        <div className="flex items-center gap-2">
          <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
            <Toggle active={sort === 'band'} onClick={() => setSort('band')}>By Band</Toggle>
            <Toggle active={sort === 'az'} onClick={() => setSort('az')}>A–Z</Toggle>
          </div>
          <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
            <Toggle active={period === 7} onClick={() => setPeriod(7)}>7D</Toggle>
            <Toggle active={period === 30} onClick={() => setPeriod(30)}>30D</Toggle>
          </div>
        </div>
      </div>

      {sort === 'az' ? (
        <div className="overflow-hidden rounded-2xl border border-ark-divider bg-ark-fill-secondary/20">
          {[...items].sort((a, b) => a.symbol.localeCompare(b.symbol)).map((it, i) => (
            <Row key={it.symbol} it={it} kind={kind} period={period} divider={i > 0} onClick={() => setSelectedSym(it.symbol)} />
          ))}
        </div>
      ) : (
        BANDS.map(({ band, color }) => {
          const group = items.filter((it) => it.band === band);
          if (!group.length) return null;
          return (
            <div key={band}>
              <div className="mb-2 flex items-center gap-2">
                <span className="h-2 w-2 rounded-full" style={{ backgroundColor: color }} />
                <span className="text-sm font-bold" style={{ color }}>{band} Risk</span>
                <span className="rounded-full bg-ark-fill-secondary px-1.5 py-0.5 text-[10px] font-semibold text-ark-text-tertiary">{group.length}</span>
              </div>
              <div className="overflow-hidden rounded-2xl border border-ark-divider bg-ark-fill-secondary/20">
                {group.map((it, i) => <Row key={it.symbol} it={it} kind={kind} period={period} divider={i > 0} onClick={() => setSelectedSym(it.symbol)} />)}
              </div>
            </div>
          );
        })
      )}
    </div>
  );
}

function Toggle({ active, onClick, children }: { active: boolean; onClick: () => void; children: React.ReactNode }) {
  return (
    <button onClick={onClick} className={cn('rounded-full px-3 py-1 text-xs font-semibold transition-colors', active ? 'bg-ark-info text-white' : 'text-ark-text-tertiary')}>{children}</button>
  );
}

function Row({ it, kind, period, divider, onClick }: { it: RiskLevelItem; kind: 'crypto' | 'stock'; period: 7 | 30; divider: boolean; onClick: () => void }) {
  const color = bandColor(it.band);
  const change = period === 7 ? it.change7d : it.change30d;
  const flat = Math.abs(change) < 0.005;
  return (
    <button onClick={onClick} className={cn('flex w-full items-center gap-3 p-3 text-left transition-colors hover:bg-ark-fill-secondary/40', divider && 'border-t border-ark-divider')}>
      <AssetLogo symbol={it.symbol} kind={kind} size={36} />
      <div className="min-w-0 flex-1">
        <p className="text-sm font-bold text-ark-text">{it.symbol}</p>
        <p className="truncate text-[11px] text-ark-text-disabled">{it.name} · {it.daysAtLevel}d at level</p>
      </div>
      <div className="text-right">
        <p className="fig text-base font-bold" style={{ color }}>{it.value.toFixed(3)}</p>
        {flat ? (
          <p className="text-[11px] text-ark-text-disabled">—</p>
        ) : (
          <p className={cn('fig flex items-center justify-end gap-0.5 text-[11px] font-semibold', change > 0 ? 'text-ark-error' : 'text-ark-success')}>
            {change > 0 ? <ArrowUp className="h-2.5 w-2.5" /> : <ArrowDown className="h-2.5 w-2.5" />}
            {change > 0 ? '+' : ''}{change.toFixed(3)}
          </p>
        )}
      </div>
      <ChevronRight className="h-4 w-4 shrink-0 text-ark-text-disabled" />
    </button>
  );
}

/* ── BTC 8-factor multi-factor risk (iOS RiskFactorBreakdown parity) ── */
function MultiFactorSection() {
  const { data } = useBtcMultiFactor();
  if (!data) return null;

  const regBand = riskBandFor(data.regression);
  const compBand = riskBandFor(data.composite);
  const valueColor = (v: number) => riskBandFor(v).color;

  return (
    <div className="space-y-3">
      {/* Regression → Composite comparison (iOS "Multi-Factor BTC Risk" card) */}
      <div className="rounded-xl border border-ark-divider p-4 text-center">
        <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Multi-Factor BTC Risk</p>
        <p className="fig mt-1 font-[family-name:var(--font-urbanist)] text-3xl font-bold" style={{ color: compBand.color }}>
          {data.composite.toFixed(3)}
        </p>
        <p className="mt-0.5 text-xs font-semibold" style={{ color: compBand.color }}>● {compBand.label.replace(' Risk', '')}</p>
        <div className="mt-3 flex items-center justify-center gap-6 border-t border-ark-divider/60 pt-3">
          <div>
            <p className="text-[9px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Regression Only</p>
            <p className="fig text-base font-bold" style={{ color: regBand.color }}>{data.regression.toFixed(3)}</p>
            <p className="text-[10px] font-medium" style={{ color: regBand.color }}>{regBand.label}</p>
          </div>
          <span className="text-ark-text-disabled">→</span>
          <div>
            <p className="text-[9px] font-semibold uppercase tracking-wider text-ark-text-tertiary">{data.availableCount}-Factor Composite</p>
            <p className="fig text-base font-bold" style={{ color: compBand.color }}>{data.composite.toFixed(3)}</p>
            <p className="text-[10px] font-medium" style={{ color: compBand.color }}>{compBand.label}</p>
          </div>
        </div>
        <p className="mt-2.5 text-[10px] leading-relaxed text-ark-text-tertiary">
          The chart above shows regression risk (1 factor). This composite combines {data.availableCount} indicators for a broader assessment.
        </p>
      </div>

      {/* Risk Factor Breakdown */}
      <div className="rounded-xl border border-ark-divider p-4">
        <div className="flex items-center justify-between">
          <p className="text-sm font-semibold text-ark-text">Risk Factor Breakdown</p>
          <span className="rounded-full bg-ark-primary/10 px-2 py-0.5 text-[10px] font-semibold text-ark-primary">
            {data.availableCount} factors
          </span>
        </div>
        <div className="mt-3 space-y-3">
          {data.factors.map((f) => (
            <div key={f.key}>
              <div className="flex items-baseline justify-between">
                <span className="text-xs font-medium text-ark-text">{f.name}</span>
                <span className="fig text-xs">
                  <span className="text-ark-text-disabled">{Math.round(f.weight * 100)}%</span>
                  <span className="ml-2 font-bold" style={{ color: f.value != null ? valueColor(f.value) : 'var(--ark-text-disabled)' }}>
                    {f.value != null ? `${Math.round(f.value * 100)}%` : 'N/A'}
                  </span>
                </span>
              </div>
              <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-ark-fill-secondary">
                {f.value != null && (
                  <div className="h-full rounded-full transition-all" style={{ width: `${f.value * 100}%`, background: valueColor(f.value) }} />
                )}
              </div>
              <p className="fig mt-0.5 text-[10px] text-ark-text-tertiary">{f.raw}</p>
            </div>
          ))}
        </div>
        <div className="mt-3 border-t border-ark-divider/60 pt-2.5">
          <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Calculation Method</p>
          <p className="mt-0.5 text-[10px] leading-relaxed text-ark-text-tertiary">
            Weighted average of normalized factors. Unavailable factors have their weights redistributed proportionally.
          </p>
        </div>
      </div>
    </div>
  );
}

/* ── Risk Level Guide (iOS "About Risk Level" sheet, copy matched) ── */
function RiskLevelGuide({ kind }: { kind: 'crypto' | 'stock' }) {
  const [open, setOpen] = useState(false);

  const sections: { title: string; body: string }[] = [
    {
      title: 'What is the Risk Level?',
      body: `The Risk Level is a score from 0.00 to 1.00 that measures where an asset sits in its market cycle. It uses ${kind === 'stock' ? 'trend and momentum models' : 'logarithmic regression'} on historical price data to determine whether the current price is relatively cheap or expensive compared to its long-term trend.`,
    },
    {
      title: 'How to Use It',
      body: 'Low risk (below 0.40) suggests the asset is undervalued relative to its historical trend — a potentially good time to accumulate. Neutral (0.40 – 0.55) means the asset is fairly priced; neither a strong buy nor sell signal. High risk (above 0.70) indicates the asset may be overheated — consider taking profits or reducing exposure.',
    },
    {
      title: 'Why It Matters',
      body: 'Markets move in cycles. Buying when risk is low and being cautious when risk is high has historically led to better outcomes. This tool helps you avoid buying tops and missing bottoms by providing an objective, data-driven perspective on market conditions.',
    },
    {
      title: 'Multi-Factor Analysis',
      body: 'The Multi-Factor Risk score combines multiple on-chain and technical indicators to produce a more robust signal than any single metric alone. Each factor is weighted based on its historical reliability.',
    },
    {
      title: 'Interacting with the Chart',
      body: 'Hover over the chart to explore historical risk levels at specific dates. Use the time-range buttons (7D, 30D, 90D, 1Y, All) to zoom in or out, and the back link to switch between assets.',
    },
  ];

  return (
    <div className="rounded-xl bg-ark-fill-secondary/40">
      <button
        onClick={() => setOpen((v) => !v)}
        className="flex w-full items-center justify-between px-3.5 py-3 text-left"
      >
        <span className="flex items-center gap-2 text-sm font-semibold text-ark-text">
          <HelpCircle className="h-4 w-4 text-ark-primary" /> About Risk Levels
        </span>
        <ChevronLeft className={cn('h-4 w-4 text-ark-text-tertiary transition-transform', open ? 'rotate-90' : '-rotate-90')} />
      </button>
      {open && (
        <div className="space-y-4 border-t border-ark-divider/60 px-3.5 py-3.5">
          {/* Risk Level Guide — 6 bands, iOS copy matched */}
          <div>
            <p className="mb-2 text-xs font-semibold text-ark-text">Risk Level Guide</p>
            <div className="space-y-2.5">
              {RISK_BANDS.map((b) => (
                <div key={b.label} className="flex gap-2.5">
                  <span className="mt-1 h-2.5 w-2.5 shrink-0 rounded-full" style={{ background: b.color }} />
                  <div>
                    <p className="text-xs">
                      <span className="font-semibold" style={{ color: b.color }}>{b.label}</span>
                      <span className="fig ml-1.5 text-ark-text-tertiary">({b.range})</span>
                    </p>
                    <p className="text-[11px] leading-relaxed text-ark-text-secondary">{b.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
          {sections.map((s) => (
            <div key={s.title}>
              <p className="text-xs font-semibold text-ark-text">{s.title}</p>
              <p className="mt-1 text-[12px] leading-relaxed text-ark-text-secondary">{s.body}</p>
            </div>
          ))}
          <p className="text-[10px] text-ark-text-disabled">For informational purposes only. Not investment advice.</p>
        </div>
      )}
    </div>
  );
}

/* ── Per-asset risk history chart ── */
const PERIODS = [{ label: '7D', days: 7 }, { label: '30D', days: 30 }, { label: '90D', days: 90 }, { label: '1Y', days: 365 }, { label: 'ALL', days: 3650 }];

function AssetRiskChart({ kind, item, onBack }: { kind: 'crypto' | 'stock'; item: RiskLevelItem; onBack: () => void }) {
  const [days, setDays] = useState(90);
  const dbKey = `${kind === 'stock' ? 'stock' : 'crypto'}_risk_${item.symbol.toLowerCase()}`;
  const { data, isLoading } = useIndicatorHistory(dbKey, days);
  const series = data ?? [];
  const current = series.length ? series[series.length - 1].value : item.value;
  const color = bandColor(item.band);
  const fmtDay = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  // pad the y-domain around the actual range so movement is visible (a fixed 0–1 axis flattens it)
  const vals = series.map((p) => p.value);
  const lo = vals.length ? Math.max(0, Math.min(...vals) - 0.05) : 0;
  const hi = vals.length ? Math.min(1, Math.max(...vals) + 0.05) : 1;

  return (
    <div className="space-y-5 pb-2">
      <button onClick={onBack} className="inline-flex items-center gap-1 text-sm font-semibold text-ark-info">
        <ChevronLeft className="h-4 w-4" /> All assets
      </button>

      <div className="flex items-center gap-3">
        <AssetLogo symbol={item.symbol} kind={kind} size={44} />
        <div className="flex-1">
          <p className="text-lg font-bold text-ark-text">{item.symbol}</p>
          <p className="text-xs text-ark-text-disabled">{item.name}</p>
        </div>
        <div className="text-right">
          <p className="fig text-2xl font-bold" style={{ color }}>{current.toFixed(3)}</p>
          <span className="rounded-full px-2 py-0.5 text-[10px] font-semibold" style={{ backgroundColor: `${color}1F`, color }}>{item.band} Risk</span>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-3"><p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">7d Avg</p><p className="fig mt-0.5 text-sm font-bold text-ark-text">{item.sevenDayAvg.toFixed(3)}</p></div>
        <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-3"><p className="text-[10px] uppercase tracking-wider text-ark-text-tertiary">Days at level</p><p className="fig mt-0.5 text-sm font-bold text-ark-text">{item.daysAtLevel}</p></div>
      </div>

      <div className="flex justify-center">
        <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
          {PERIODS.map((p) => <Toggle key={p.label} active={days === p.days} onClick={() => setDays(p.days)}>{p.label}</Toggle>)}
        </div>
      </div>

      {isLoading ? (
        <Skeleton className="h-56 w-full" />
      ) : series.length > 1 ? (
        <div className="h-56 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={series} margin={{ top: 8, right: 8, bottom: 0, left: 0 }}>
              <defs>
                <linearGradient id="rl-chart" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={color} stopOpacity={0.22} />
                  <stop offset="100%" stopColor={color} stopOpacity={0} />
                </linearGradient>
              </defs>
              <XAxis dataKey="date" tickLine={false} axisLine={false} ticks={series.length ? [series[0].date, series[series.length - 1].date] : []} tickFormatter={fmtDay} tick={{ fontSize: 10, fill: 'var(--ark-text-disabled)' }} interval="preserveStartEnd" />
              <YAxis domain={[lo, hi]} hide />
              <Tooltip contentStyle={{ background: 'var(--ark-card)', border: '1px solid var(--ark-divider)', borderRadius: 8, fontSize: 12 }} labelFormatter={(l) => fmtDay(String(l))} formatter={(v) => [Number(v).toFixed(3), 'Risk']} />
              <Area type="monotone" dataKey="value" stroke={color} strokeWidth={2.5} fill="url(#rl-chart)" dot={false} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      ) : (
        <p className="py-8 text-center text-sm text-ark-text-tertiary">No risk history for this period.</p>
      )}

      <p className="text-[13px] leading-relaxed text-ark-text-secondary">
        Risk is {item.symbol}&apos;s position within its long-term {kind === 'stock' ? 'trend & momentum model' : 'logarithmic regression channel'} — 0.0 is deeply undervalued (accumulation), 1.0 is historically overextended (distribution).
      </p>

      {/* BTC 8-factor composite (iOS Multi-Factor BTC Risk parity) */}
      {kind === 'crypto' && item.symbol === 'BTC' && <MultiFactorSection />}

      <RiskLevelGuide kind={kind} />
    </div>
  );
}
