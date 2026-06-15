'use client';

import { useState } from 'react';
import { TrendingUp, DollarSign, Landmark, Globe, ChevronDown, ChevronRight, ChevronLeft } from 'lucide-react';
import { Skeleton } from '@/components/ui';
import { useMacroDashboard } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';
import { VixDetail, DxyDetail, M2Detail, NetLiquidityDetail } from './macro-detail';
import type { MacroDashIndicator } from '@/types';

const INDICATOR_DETAIL: Record<string, { title: string; Comp: () => React.ReactElement }> = {
  vix: { title: 'VIX — Volatility Index', Comp: VixDetail },
  dxy: { title: 'DXY — US Dollar Index', Comp: DxyDetail },
  netLiquidity: { title: 'US Net Liquidity', Comp: NetLiquidityDetail },
  cbLiquidity: { title: 'CB Liquidity', Comp: M2Detail },
};

const ICONS = { vix: TrendingUp, dxy: DollarSign, netLiquidity: Landmark, cbLiquidity: Globe } as const;

const POSITIVE = new Set(['bullish', 'expanding']);
function sigColor(signal: string) {
  if (POSITIVE.has(signal)) return 'var(--ark-success)';
  if (signal === 'bearish' || signal === 'contracting') return 'var(--ark-error)';
  return 'var(--ark-warning)';
}

const INDICATOR_GUIDE: { title: string; body: string }[] = [
  { title: 'VIX (Volatility Index)', body: 'Measures expected market volatility. Below 15 signals complacency and a risk-on environment. Above 25 indicates elevated fear, which often pressures crypto and risk assets. Spikes above 35 can signal capitulation and potential bottoming.' },
  { title: 'DXY (US Dollar Index)', body: 'Tracks the US dollar against a basket of major currencies. A weakening dollar (below ~100) is historically bullish for crypto and commodities, while a strengthening dollar (above ~105) creates headwinds for risk assets.' },
  { title: 'US Net Liquidity', body: "Tracks the Federal Reserve's balance sheet minus money locked in the Treasury General Account and reverse repos. When Net Liquidity rises, more cash is available in financial markets. This is the #1 short-term driver of crypto and risk asset prices." },
  { title: 'Market Regime', body: 'Combines all indicators into a single signal. Risk-On means favorable conditions across the board. Risk-Off means multiple headwinds. Mixed means conflicting signals.' },
];

function fmtChange(v?: number) {
  if (v == null) return null;
  return `${v >= 0 ? '+' : ''}${v.toFixed(1)}%`;
}

export function MacroDashboard() {
  const { data, isLoading } = useMacroDashboard();
  const [whatExpanded, setWhatExpanded] = useState(false);
  const [guideExpanded, setGuideExpanded] = useState(false);
  const [alerts, setAlerts] = useState(true);
  const [detailKey, setDetailKey] = useState<string | null>(null);

  if (detailKey && INDICATOR_DETAIL[detailKey]) {
    const { title, Comp } = INDICATOR_DETAIL[detailKey];
    return (
      <div>
        <button onClick={() => setDetailKey(null)} className="mb-3 inline-flex items-center gap-1 text-sm font-semibold text-ark-info">
          <ChevronLeft className="h-4 w-4" /> Macro Dashboard
        </button>
        <p className="mb-2 text-sm font-semibold text-ark-text">{title}</p>
        <Comp />
      </div>
    );
  }

  if (isLoading || !data) {
    return (
      <div className="space-y-4 pb-4">
        <Skeleton className="h-28 w-full rounded-2xl" />
        <Skeleton className="h-56 w-full rounded-2xl" />
      </div>
    );
  }

  const accent = data.regimeBullish ? 'var(--ark-success)' : 'var(--ark-error)';
  const asOf = new Date(data.asOf + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });

  return (
    <div className="space-y-6 pb-2">
      {/* Regime banner */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-5 text-center">
        <div className="flex items-center justify-center gap-2">
          <span className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: accent }} />
          <h2 className="font-[family-name:var(--font-urbanist)] text-2xl font-bold" style={{ color: accent }}>{data.regimeLabel}</h2>
        </div>
        <p className="mt-2 text-sm leading-relaxed text-ark-text-secondary">{data.regimeDescription}</p>
        <p className="mt-2 text-xs text-ark-text-disabled">As of {asOf}</p>
        <button onClick={() => setWhatExpanded((v) => !v)} className="mt-2 inline-flex items-center gap-1 text-sm font-semibold text-ark-info">
          What does this mean? <ChevronDown className={cn('h-3.5 w-3.5 transition-transform', whatExpanded && 'rotate-180')} />
        </button>
        {whatExpanded && (
          <p className="mt-2 text-left text-[13px] leading-relaxed text-ark-text-secondary">
            The market regime blends volatility, the dollar, and liquidity into one read on the macro backdrop.
            {data.regimeBullish
              ? ' Conditions currently favor risk assets — low fear, a stable or weakening dollar, and expanding liquidity.'
              : ' Conditions currently favor caution — elevated fear, a strengthening dollar, or contracting liquidity.'}
          </p>
        )}
      </div>

      {/* Current values */}
      <div>
        <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Current Values</p>
        <div className="overflow-hidden rounded-2xl border border-ark-divider bg-ark-fill-secondary/20">
          {data.indicators.map((ind, i) => (
            <IndicatorRow key={ind.key} ind={ind} divider={i > 0} onClick={() => setDetailKey(ind.key)} />
          ))}
        </div>
      </div>

      {/* Alerts */}
      <div>
        <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Alerts</p>
        <div className="flex items-center justify-between rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
          <div>
            <p className="text-sm font-semibold text-ark-text">Regime Change Alerts</p>
            <p className="text-xs text-ark-text-disabled">Get notified when conditions shift</p>
          </div>
          <button
            onClick={() => setAlerts((v) => !v)}
            className={cn('relative h-6 w-11 shrink-0 rounded-full transition-colors', alerts ? 'bg-ark-info' : 'bg-ark-fill-secondary')}
            role="switch" aria-checked={alerts}
          >
            <span className={cn('absolute top-0.5 h-5 w-5 rounded-full bg-white transition-all', alerts ? 'left-[22px]' : 'left-0.5')} />
          </button>
        </div>
      </div>

      {/* Investment insight */}
      <div className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
        <h4 className="text-sm font-bold text-ark-text">Investment Insight</h4>
        <p className="mt-1.5 text-[13px] leading-relaxed text-ark-text-secondary">{data.insight}</p>
        <p className="mt-2 text-[11px] text-ark-text-disabled">For informational purposes only. Not investment advice. Always do your own research.</p>

        <button onClick={() => setGuideExpanded((v) => !v)} className="mt-3 flex w-full items-center justify-between text-sm font-semibold text-ark-info">
          Understanding the Indicators
          <ChevronDown className={cn('h-4 w-4 transition-transform', guideExpanded && 'rotate-180')} />
        </button>
        {guideExpanded && (
          <div className="mt-3 space-y-3 border-t border-ark-divider pt-3">
            {INDICATOR_GUIDE.map((g) => (
              <div key={g.title}>
                <p className="text-sm font-semibold text-ark-text">{g.title}</p>
                <p className="mt-0.5 text-[13px] leading-relaxed text-ark-text-tertiary">{g.body}</p>
              </div>
            ))}
            <p className="text-[11px] text-ark-text-disabled">This is not financial advice. Always do your own research.</p>
          </div>
        )}
      </div>
    </div>
  );
}

function IndicatorRow({ ind, divider, onClick }: { ind: MacroDashIndicator; divider: boolean; onClick: () => void }) {
  const Icon = ICONS[ind.key];
  const color = sigColor(ind.signal);
  const change = fmtChange(ind.changePct);
  return (
    <button onClick={onClick} className={cn('flex w-full items-center gap-3 p-3.5 text-left transition-colors hover:bg-ark-fill-secondary/40', divider && 'border-t border-ark-divider')}>
      <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-ark-info/10">
        <Icon className="h-4 w-4 text-ark-info" />
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold text-ark-text">{ind.label}</p>
        <p className="text-[12px] text-ark-text-disabled">
          <span className="fig">{ind.formattedValue}</span>
          {change && <span className={cn('fig ml-1.5 font-semibold', (ind.changePct ?? 0) >= 0 ? 'text-ark-success' : 'text-ark-error')}>{change}</span>}
        </p>
      </div>
      <span className="rounded-full px-2.5 py-1 text-[11px] font-bold" style={{ backgroundColor: `${color}1F`, color }}>{ind.signalLabel}</span>
      <ChevronRight className="h-4 w-4 text-ark-text-disabled" />
    </button>
  );
}
