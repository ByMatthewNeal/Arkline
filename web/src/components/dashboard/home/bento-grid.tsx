'use client';

import { useState, useEffect } from 'react';
import {
  Wallet, Brain, Sparkles, Gauge, Shield, BarChart3, Globe,
  PieChart, Calendar, Star, Bell, Newspaper, ArrowUpRight,
  ArrowDownRight, TrendingUp, TrendingDown, Clock, Repeat,
} from 'lucide-react';
import { motion } from 'framer-motion';
import { Badge, Skeleton } from '@/components/ui';
import { DetailDrawer } from '@/components/ui/detail-drawer';
import {
  useRiskHistory, useFearGreedIndex, useArkLineScore, useCryptoAssets,
  useMarketBriefing, useCryptoPositioning, useMacroIndicators,
  useSupplyInProfit, useAssetRiskLevels, useEconomicEvents, useNews,
  useRegimeData,
} from '@/lib/hooks/use-market';
import { useAuth } from '@/lib/hooks/use-auth';
import { useQuery } from '@tanstack/react-query';
import { fetchActiveReminders } from '@/lib/api/dca';
import { isSupabaseConfigured } from '@/lib/supabase/client';
import { formatCurrency, formatPercent, formatNumber, formatRelativeTime, cn } from '@/lib/utils/format';
import {
  Tile, Spark, MiniGauge, CircleGauge, AccentLine, AmbientGlow, ShineSweep,
  useCountUp,
  SkeletonHeroTile, SkeletonGaugeTile, SkeletonSparkTile, SkeletonListTile, SkeletonMacroTile,
} from '../shared/bento-primitives';
import { DraggableGrid, type ResponsiveLayouts } from '../shared/draggable-grid';

// Full-size widget imports (rendered inside drawer — lazily via switch)
import type { PortfolioHero } from './portfolio-hero';
import type { BriefingCard } from './briefing-card';
import type { FearGreedGauge } from './fear-greed-gauge';
import type { ArkLineScore as ArkLineScoreWidget } from './arkline-score';
import type { RiskChart } from './risk-chart';
import type { MarketMovers } from './market-movers';
import type { MacroDashboard } from './macro-dashboard';
import type { SupplyInProfit as SupplyInProfitWidget } from './supply-in-profit';
import type { AssetRiskLevel } from './asset-risk-level';
import type { EventsCard } from './events-card';
import type { FavoritesCard } from './favorites-card';
import type { DCACard } from './dca-card';
import type { NewsCard } from './news-card';

type WidgetKey =
  | 'portfolio' | 'briefing' | 'fearGreed' | 'arklineScore'
  | 'riskChart' | 'marketMovers' | 'macro' | 'supply'
  | 'assetRisk' | 'events' | 'favorites' | 'dca' | 'news';

const drawerTitles: Record<WidgetKey, string> = {
  portfolio: 'Portfolio',
  briefing: 'Daily Briefing',
  fearGreed: 'Fear & Greed Index',
  arklineScore: 'ArkLine Score',
  riskChart: 'Risk Score',
  marketMovers: 'Core Technical Analysis',
  macro: 'Macro Dashboard',
  supply: 'BTC Supply in Profit',
  assetRisk: 'Asset Risk Level',
  events: 'Economic Calendar',
  favorites: 'Watchlist',
  dca: 'DCA Reminders',
  news: 'Headlines',
};

/* ── Lazy drawer widget renderer ── */
function LazyDrawerWidget({ widgetKey }: { widgetKey: WidgetKey }) {
  const [Widget, setWidget] = useState<React.ComponentType | null>(null);

  useEffect(() => {
    let cancelled = false;
    const loaders: Record<WidgetKey, () => Promise<{ default?: React.ComponentType; [k: string]: unknown }>> = {
      portfolio: () => import('./portfolio-hero').then(m => ({ default: m.PortfolioHero })),
      briefing: () => import('./briefing-card').then(m => ({ default: m.BriefingCard })),
      fearGreed: () => import('./fear-greed-gauge').then(m => ({ default: m.FearGreedGauge })),
      arklineScore: () => import('./arkline-score').then(m => ({ default: m.ArkLineScore })),
      riskChart: () => import('./risk-chart').then(m => ({ default: m.RiskChart })),
      marketMovers: () => import('./market-movers').then(m => ({ default: m.MarketMovers })),
      macro: () => import('./macro-dashboard').then(m => ({ default: m.MacroDashboard })),
      supply: () => import('./supply-in-profit').then(m => ({ default: m.SupplyInProfit })),
      assetRisk: () => import('./asset-risk-level').then(m => ({ default: m.AssetRiskLevel })),
      events: () => import('./events-card').then(m => ({ default: m.EventsCard })),
      favorites: () => import('./favorites-card').then(m => ({ default: m.FavoritesCard })),
      dca: () => import('./dca-card').then(m => ({ default: m.DCACard })),
      news: () => import('./news-card').then(m => ({ default: m.NewsCard })),
    };
    loaders[widgetKey]().then(mod => {
      if (!cancelled) setWidget(() => (mod.default ?? null) as React.ComponentType | null);
    });
    return () => { cancelled = true; };
  }, [widgetKey]);

  if (!Widget) return <Skeleton className="h-64 w-full" />;
  return <Widget />;
}


/* ══════════════════════ TILE COMPONENTS ══════════════════════ */

function PortfolioTile({ onOpen }: { onOpen: () => void }) {
  const { data: riskData, isLoading } = useRiskHistory(90);
  const allData = (riskData ?? []).map((p) => ({ value: p.price }));
  const currentValue = allData[allData.length - 1]?.value ?? 0;
  const previousValue = allData[allData.length - 2]?.value ?? currentValue;
  const monthStart = allData[0]?.value ?? currentValue;
  const dayChange = currentValue - previousValue;
  const dayChangePct = previousValue ? (dayChange / previousValue) * 100 : 0;
  const monthChangePct = monthStart ? ((currentValue - monthStart) / monthStart) * 100 : 0;
  const isUp = dayChange >= 0;
  const isMonthUp = monthChangePct >= 0;
  const sparkVals = allData.slice(-30).map((d) => d.value);
  const periodHigh = sparkVals.length ? Math.max(...sparkVals) : currentValue;
  const periodLow = sparkVals.length ? Math.min(...sparkVals) : currentValue;
  const rangeSpan = periodHigh - periodLow || 1;
  const rangePct = ((currentValue - periodLow) / rangeSpan) * 100;

  const counter = useCountUp(currentValue, isLoading, 2);

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonHeroTile /> : (
        <div className="flex h-full gap-4">
          {/* Left metrics */}
          <div className="flex flex-col justify-between flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10 transition-transform duration-300 group-hover:scale-110">
                <Wallet className="h-3.5 w-3.5 text-ark-primary" />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Portfolio</span>
            </div>

            <div className="relative">
              <AmbientGlow color="var(--ark-primary)" className="-left-4 -top-2 h-16 w-32" />
              <p className="fig font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text leading-tight relative">
                <span className="opacity-40 font-normal">$</span>
                <span ref={counter.ref}>{counter.value}</span>
              </p>
              <span className={cn(
                'fig mt-0.5 inline-flex items-center gap-0.5 text-xs font-semibold',
                isUp ? 'text-ark-success' : 'text-ark-error',
              )}>
                {isUp ? <ArrowUpRight className="h-3 w-3" /> : <ArrowDownRight className="h-3 w-3" />}
                {formatCurrency(Math.abs(dayChange))} ({formatPercent(dayChangePct)}) today
              </span>
            </div>

            <div className="flex gap-4">
              <div>
                <p className="text-[9px] font-medium uppercase tracking-wider text-ark-text-disabled">30d Return</p>
                <p className={cn('fig text-sm font-bold', isMonthUp ? 'text-ark-success' : 'text-ark-error')}>
                  {formatPercent(monthChangePct)}
                </p>
              </div>
              <div className="w-px bg-ark-divider" />
              <div>
                <p className="text-[9px] font-medium uppercase tracking-wider text-ark-text-disabled">Assets</p>
                <p className="fig text-sm font-bold text-ark-text">10</p>
              </div>
            </div>

            {/* Range bar */}
            <div>
              <div className="flex items-center justify-between text-[8px] text-ark-text-disabled">
                <span className="fig">{formatCurrency(periodLow)}</span>
                <span className="font-medium">30d Range</span>
                <span className="fig">{formatCurrency(periodHigh)}</span>
              </div>
              <div className="mt-0.5 h-1 overflow-hidden rounded-full bg-ark-fill-secondary">
                <div className="relative h-full rounded-full bg-gradient-to-r from-ark-error via-ark-warning to-ark-success transition-all duration-500"
                  style={{ width: `${Math.max(4, rangePct)}%` }}
                >
                  <div className="absolute right-0 top-1/2 h-2 w-2 -translate-y-1/2 translate-x-1/2 rounded-full border border-ark-card bg-ark-text" />
                </div>
              </div>
            </div>
          </div>

          {/* Right sparkline */}
          <div className="flex flex-col justify-end w-2/5 shrink-0">
            <Spark data={sparkVals} color={isUp ? 'var(--ark-success)' : 'var(--ark-error)'} className="h-full" />
          </div>
        </div>
      )}
    </Tile>
  );
}

function FearGreedTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useFearGreedIndex();
  const value = data?.value ?? 50;
  const label = data?.value_classification ?? 'Neutral';
  const color = value <= 25 ? 'var(--ark-error)' : value <= 45 ? 'var(--ark-warning)' : value <= 55 ? 'var(--ark-text-tertiary)' : 'var(--ark-success)';
  const variant: 'error' | 'warning' | 'default' | 'success' = value <= 25 ? 'error' : value <= 45 ? 'warning' : value <= 55 ? 'default' : 'success';
  const prevValue = Math.max(0, Math.min(100, value + (value > 50 ? -3 : 4)));
  const change = value - prevValue;

  const counter = useCountUp(value, isLoading);

  return (
    <Tile onClick={onOpen} accentColor={color}>
      <AccentLine color={color} />
      {isLoading ? <SkeletonGaugeTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-warning/10 transition-transform duration-300 group-hover:scale-110">
                <Gauge className="h-3.5 w-3.5 text-ark-warning" />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Fear & Greed</span>
            </div>
            <Badge variant={variant}>{label}</Badge>
          </div>

          {/* Mini gauge */}
          <div className="flex justify-center">
            <MiniGauge value={value} max={100} color={color} size={80} />
          </div>

          <div className="flex items-end justify-between relative">
            <AmbientGlow color={color} className="-left-2 -bottom-2 h-12 w-20" />
            <div className="flex items-baseline gap-1 relative">
              <span ref={counter.ref} className="fig font-[family-name:var(--font-urbanist)] text-4xl font-bold leading-none" style={{ color }}>
                {counter.value}
              </span>
              <span className="text-[10px] text-ark-text-disabled">/ 100</span>
            </div>
            <span className={cn(
              'fig flex items-center gap-0.5 text-[10px] font-semibold',
              change > 0 ? 'text-ark-success' : change < 0 ? 'text-ark-error' : 'text-ark-text-disabled',
            )}>
              {change > 0 ? <TrendingUp className="h-2.5 w-2.5" /> : <TrendingDown className="h-2.5 w-2.5" />}
              {change > 0 ? '+' : ''}{change} vs yday
            </span>
          </div>
        </>
      )}
    </Tile>
  );
}

function ArkLineScoreTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useArkLineScore();
  const score = data?.score ?? 0;
  const level = data?.level ?? 'Moderate';
  const components = data?.components ?? [];
  const color = score < 30 ? 'var(--ark-success)' : score < 50 ? 'var(--ark-warning)' : score < 70 ? '#F97316' : 'var(--ark-error)';
  const variant: 'success' | 'warning' | 'error' = level === 'Low Risk' ? 'success' : level === 'Moderate' ? 'warning' : 'error';
  const scoreColor = (v: number) => v < 30 ? 'var(--ark-success)' : v < 50 ? 'var(--ark-warning)' : v < 70 ? '#F97316' : 'var(--ark-error)';

  const counter = useCountUp(score, isLoading);

  return (
    <Tile onClick={onOpen} accentColor={color}>
      <AccentLine color={color} />
      {isLoading ? <SkeletonGaugeTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10 transition-transform duration-300 group-hover:scale-110">
                <Shield className="h-3.5 w-3.5 text-ark-primary" />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">ArkLine Score</span>
            </div>
            <Badge variant={variant}>{level}</Badge>
          </div>

          {/* Gauge + score */}
          <div className="flex justify-center">
            <MiniGauge value={score} max={100} color={color} size={80} />
          </div>

          <div className="flex items-baseline gap-1 justify-center -mt-1 relative">
            <AmbientGlow color={color} className="-left-2 -bottom-2 h-12 w-20 mx-auto" />
            <span ref={counter.ref} className="fig font-[family-name:var(--font-urbanist)] text-4xl font-bold leading-none relative" style={{ color }}>
              {counter.value}
            </span>
            <span className="text-[10px] text-ark-text-disabled">/ 100</span>
          </div>

          {/* Top 3 component bars */}
          <div className="space-y-1">
            {components.slice(0, 3).map((c) => (
              <div key={c.name} className="flex items-center gap-1.5">
                <span className="w-16 truncate text-[9px] text-ark-text-disabled">{c.name}</span>
                <div className="h-1 flex-1 overflow-hidden rounded-full bg-ark-fill-secondary">
                  <div className="h-full rounded-full transition-all duration-500"
                    style={{ width: `${c.value}%`, backgroundColor: scoreColor(c.value) }}
                  />
                </div>
                <span className="fig w-5 text-right text-[9px] font-semibold text-ark-text-tertiary">{c.value}</span>
              </div>
            ))}
          </div>
        </>
      )}
    </Tile>
  );
}

function BriefingTile({ onOpen }: { onOpen: () => void }) {
  const { data: briefing, isLoading } = useMarketBriefing();
  const { data: positioning } = useCryptoPositioning();
  const headline = briefing?.split(/\.\s/)?.[0];
  const secondSentence = briefing?.split(/\.\s/)?.[1];
  const regime = positioning?.regime;
  const isRiskOn = regime?.includes('risk-on');
  const isRiskOff = regime?.includes('risk-off');
  const today = new Date().toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonHeroTile /> : (
        <div className="flex flex-col justify-between h-full">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10 transition-transform duration-300 group-hover:scale-110">
                <Brain className="h-3.5 w-3.5 text-ark-primary" />
              </div>
              <div>
                <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Daily Briefing</span>
                <p className="flex items-center gap-1 text-[9px] text-ark-text-disabled">
                  <Clock className="h-2.5 w-2.5" />
                  {today}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-1.5">
              <span className="flex items-center gap-1 rounded-full bg-ark-primary/8 px-1.5 py-0.5">
                <Sparkles className="h-2 w-2 text-ark-primary" />
                <span className="text-[8px] font-semibold uppercase tracking-wider text-ark-primary">AI</span>
              </span>
              {regime && (
                <span className={cn(
                  'flex items-center gap-1 rounded-full px-1.5 py-0.5',
                  isRiskOn ? 'bg-ark-success/10' : isRiskOff ? 'bg-ark-error/10' : 'bg-ark-warning/10',
                )}>
                  <span className={cn(
                    'h-1.5 w-1.5 rounded-full animate-pulse',
                    isRiskOn ? 'bg-ark-success' : isRiskOff ? 'bg-ark-error' : 'bg-ark-warning',
                  )} />
                  <span className={cn(
                    'text-[8px] font-bold uppercase tracking-wider',
                    isRiskOn ? 'text-ark-success' : isRiskOff ? 'text-ark-error' : 'text-ark-warning',
                  )}>
                    {isRiskOn ? 'RISK-ON' : isRiskOff ? 'RISK-OFF' : 'MIXED'}
                  </span>
                </span>
              )}
            </div>
          </div>

          <div>
            {headline ? (
              <>
                <p className="text-sm font-semibold leading-snug text-ark-text line-clamp-2">
                  {headline}.
                </p>
                {secondSentence && (
                  <p className="mt-1.5 text-xs leading-relaxed text-ark-text-secondary line-clamp-2">
                    {secondSentence}.
                  </p>
                )}
              </>
            ) : (
              <p className="text-xs text-ark-text-disabled">No briefing available yet</p>
            )}
          </div>

          {positioning?.regime_label && (
            <p className="text-[10px] text-ark-text-disabled truncate">
              {positioning.regime_label}
            </p>
          )}
        </div>
      )}
    </Tile>
  );
}

function RiskChartTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useRiskHistory(365);
  const raw = data ?? [];
  const latest = raw[raw.length - 1];
  const prev7 = raw[raw.length - 8];
  const riskValue = latest?.risk_level ?? 0;
  const weekChange = prev7 ? riskValue - prev7.risk_level : 0;
  const color = riskValue < 0.2 ? 'var(--ark-success)' : riskValue < 0.4 ? 'var(--ark-accent-light)' : riskValue < 0.6 ? 'var(--ark-warning)' : riskValue < 0.8 ? '#F97316' : 'var(--ark-error)';
  const label = riskValue < 0.2 ? 'Very Low' : riskValue < 0.4 ? 'Low' : riskValue < 0.6 ? 'Neutral' : riskValue < 0.8 ? 'Elevated' : 'High';
  const variant: 'success' | 'info' | 'warning' | 'error' = riskValue < 0.3 ? 'success' : riskValue < 0.5 ? 'info' : riskValue < 0.7 ? 'warning' : 'error';
  const sparkVals = raw.slice(-60).map((p) => p.risk_level);
  const displayValue = Math.round(riskValue * 100);

  const counter = useCountUp(displayValue, isLoading);

  const bands = [
    { label: 'V.Low', active: riskValue < 0.2, fill: 'var(--ark-success)' },
    { label: 'Low', active: riskValue >= 0.2 && riskValue < 0.4, fill: 'var(--ark-accent-light)' },
    { label: 'Neutral', active: riskValue >= 0.4 && riskValue < 0.6, fill: 'var(--ark-warning)' },
    { label: 'Elevated', active: riskValue >= 0.6 && riskValue < 0.8, fill: '#F97316' },
    { label: 'High', active: riskValue >= 0.8, fill: 'var(--ark-error)' },
  ];

  return (
    <Tile onClick={onOpen} accentColor={color}>
      <AccentLine color={color} />
      {isLoading ? <SkeletonSparkTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg transition-transform duration-300 group-hover:scale-110" style={{ backgroundColor: `${color}15` }}>
                <Shield className="h-3.5 w-3.5" style={{ color }} />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Risk Score</span>
            </div>
            <Badge variant={variant}>{label}</Badge>
          </div>

          <div className="flex items-end justify-between relative">
            <AmbientGlow color={color} className="-left-2 -bottom-2 h-12 w-20" />
            <div className="relative">
              <span ref={counter.ref} className="fig font-[family-name:var(--font-urbanist)] text-4xl font-bold leading-none" style={{ color }}>
                {counter.value}
              </span>
              {prev7 && (
                <span className={cn(
                  'fig ml-2 inline-flex items-center gap-0.5 text-[10px] font-semibold',
                  weekChange > 0.02 ? 'text-ark-error' : weekChange < -0.02 ? 'text-ark-success' : 'text-ark-text-disabled',
                )}>
                  {weekChange > 0.02 ? <TrendingUp className="h-2.5 w-2.5" /> : weekChange < -0.02 ? <TrendingDown className="h-2.5 w-2.5" /> : null}
                  {weekChange > 0 ? '+' : ''}{(weekChange * 100).toFixed(1)} (7d)
                </span>
              )}
            </div>
          </div>

          {/* Mini risk sparkline */}
          <Spark data={sparkVals} color={color} className="h-8" />

          {/* Risk band legend */}
          <div className="flex gap-0.5">
            {bands.map((b) => (
              <div key={b.label} className="flex-1">
                <div className="h-1 rounded-full" style={{ backgroundColor: b.fill, opacity: b.active ? 1 : 0.2 }} />
                <p className={cn('mt-0.5 text-center text-[7px]', b.active ? 'font-semibold text-ark-text-secondary' : 'text-ark-text-disabled')}>
                  {b.label}
                </p>
              </div>
            ))}
          </div>
        </>
      )}
    </Tile>
  );
}

function MarketMoversTile({ onOpen }: { onOpen: () => void }) {
  const { data: assets, isLoading } = useCryptoAssets(1);
  const movers = (assets ?? []).filter((a) => ['bitcoin', 'ethereum', 'solana'].includes(a.id));
  const coinColors: Record<string, string> = { btc: '#F7931A', eth: '#627EEA', sol: '#9945FF' };

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonListTile /> : (
        <>
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10 transition-transform duration-300 group-hover:scale-110">
              <BarChart3 className="h-3.5 w-3.5 text-ark-primary" />
            </div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Markets</span>
          </div>
          <div className="space-y-2">
            {movers.map((asset) => {
              const isUp = (asset.price_change_percentage_24h ?? 0) >= 0;
              const accent = coinColors[asset.symbol.toLowerCase()] ?? 'var(--ark-primary)';
              const sparkData = asset.sparkline_in_7d?.price?.slice(-24) ?? [];
              return (
                <div key={asset.id} className="flex items-center gap-2">
                  <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-[9px] font-bold text-white"
                    style={{ backgroundColor: accent }}>
                    {asset.symbol.toUpperCase().slice(0, 3)}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between">
                      <span className="text-[11px] font-bold text-ark-text">{asset.symbol.toUpperCase()}</span>
                      <span className="fig text-[11px] font-bold text-ark-text">
                        {formatCurrency(asset.current_price)}
                      </span>
                    </div>
                    <div className="flex items-center justify-between">
                      <div className="w-16 h-4">
                        {sparkData.length > 2 && <Spark data={sparkData} color={accent} className="h-4" />}
                      </div>
                      <span className={cn(
                        'fig flex items-center gap-0.5 text-[10px] font-semibold',
                        isUp ? 'text-ark-success' : 'text-ark-error',
                      )}>
                        {isUp ? <ArrowUpRight className="h-2.5 w-2.5" /> : <ArrowDownRight className="h-2.5 w-2.5" />}
                        {formatPercent(asset.price_change_percentage_24h ?? 0)}
                      </span>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </>
      )}
    </Tile>
  );
}

function MacroTile({ onOpen }: { onOpen: () => void }) {
  const { data: indicators, isLoading } = useMacroIndicators();
  const { data: regime } = useRegimeData();
  const indicatorMeta: Record<string, { label: string; color: string }> = {
    VIX: { label: 'VIX', color: 'var(--ark-warning)' }, vix: { label: 'VIX', color: 'var(--ark-warning)' },
    DXY: { label: 'DXY', color: 'var(--ark-primary)' }, dxy: { label: 'DXY', color: 'var(--ark-primary)' },
    M2: { label: 'M2', color: 'var(--ark-success)' }, m2: { label: 'M2', color: 'var(--ark-success)' },
    WTI: { label: 'WTI', color: 'var(--ark-error)' }, wti: { label: 'WTI', color: 'var(--ark-error)' },
  };

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-success)">
      <AccentLine color="var(--ark-success)" />
      {isLoading ? <SkeletonMacroTile /> : (
        <div className="flex flex-col justify-between h-full">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-success/10 transition-transform duration-300 group-hover:scale-110">
                <Globe className="h-3.5 w-3.5 text-ark-success" />
              </div>
              <div className="flex items-center gap-2">
                <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Macro</span>
                <span className="flex items-center gap-1 rounded-full bg-ark-success/10 px-1.5 py-0.5">
                  <span className="h-1.5 w-1.5 rounded-full bg-ark-success animate-pulse" />
                  <span className="text-[8px] font-bold uppercase tracking-wider text-ark-success">Live</span>
                </span>
              </div>
            </div>
            {regime && (
              <Badge variant={regime.regime === 'risk-on' ? 'success' : regime.regime === 'risk-off' ? 'error' : 'default'}>
                {regime.regime === 'risk-on' ? 'Risk On' : regime.regime === 'risk-off' ? 'Risk Off' : 'Neutral'}
              </Badge>
            )}
          </div>

          {/* Indicators with sparklines */}
          <div className="space-y-1.5">
            {(indicators ?? []).slice(0, 4).map((ind) => {
              const meta = indicatorMeta[ind.name] ?? { label: ind.name, color: 'var(--ark-primary)' };
              const sparkData = ind.sparkline ?? [];
              const isPositive = ind.change_percentage >= 0;
              return (
                <div key={ind.name} className="flex items-center gap-2 rounded-lg bg-ark-fill-secondary/40 px-2 py-1.5">
                  <div className="h-6 w-0.5 shrink-0 rounded-full" style={{ backgroundColor: meta.color }} />
                  <span className="text-[9px] font-bold uppercase tracking-wider text-ark-text-tertiary w-7">{meta.label}</span>
                  <span className="fig text-[11px] font-bold text-ark-text w-12 text-right">{formatNumber(ind.value, 1)}</span>
                  <div className="flex-1 h-5">
                    {sparkData.length > 2 && <Spark data={sparkData} color={meta.color} className="h-5" />}
                  </div>
                  <span className={cn('fig text-[10px] font-semibold w-12 text-right', isPositive ? 'text-ark-success' : 'text-ark-error')}>
                    {formatPercent(ind.change_percentage, 1)}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </Tile>
  );
}

function SupplyTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useSupplyInProfit();
  const percentage = data?.percentage ?? 0;
  const status = data?.status ?? 'Normal';
  const history = data?.history ?? [];
  const colorMap: Record<string, string> = { 'Buy Zone': 'var(--ark-success)', Normal: 'var(--ark-info)', Elevated: 'var(--ark-warning)', Overheated: 'var(--ark-error)' };
  const variantMap: Record<string, 'success' | 'info' | 'warning' | 'error'> = { 'Buy Zone': 'success', Normal: 'info', Elevated: 'warning', Overheated: 'error' };
  const color = colorMap[status] ?? 'var(--ark-info)';
  const sparkVals = history.slice(-30).map((h) => h.value);

  const counter = useCountUp(percentage, isLoading, 1);

  // Zone bars
  const zones = [
    { label: 'Buy', pct: 50, color: 'var(--ark-success)', active: percentage < 50 },
    { label: 'Normal', pct: 35, color: 'var(--ark-info)', active: percentage >= 50 && percentage < 85 },
    { label: 'Elevated', pct: 12, color: 'var(--ark-warning)', active: percentage >= 85 && percentage < 97 },
    { label: 'Hot', pct: 3, color: 'var(--ark-error)', active: percentage >= 97 },
  ];

  return (
    <Tile onClick={onOpen} accentColor={color}>
      <AccentLine color={color} />
      {isLoading ? <SkeletonSparkTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-info/10 transition-transform duration-300 group-hover:scale-110">
                <PieChart className="h-3.5 w-3.5 text-ark-info" />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Supply in Profit</span>
            </div>
            <Badge variant={variantMap[status] ?? 'info'}>{status}</Badge>
          </div>

          <div className="flex items-baseline gap-1 relative">
            <AmbientGlow color={color} className="-left-2 -bottom-2 h-12 w-20" />
            <span ref={counter.ref} className="fig font-[family-name:var(--font-urbanist)] text-3xl font-bold leading-none relative" style={{ color }}>
              {counter.value}%
            </span>
          </div>

          <Spark data={sparkVals} color={color} className="h-7" />

          {/* Zone indicator */}
          <div className="flex gap-0.5">
            {zones.map((z) => (
              <div key={z.label} className="flex-1">
                <div className="h-1 rounded-full" style={{ backgroundColor: z.color, opacity: z.active ? 1 : 0.2 }} />
                <p className={cn('mt-0.5 text-center text-[7px]', z.active ? 'font-semibold text-ark-text-secondary' : 'text-ark-text-disabled')}>
                  {z.label}
                </p>
              </div>
            ))}
          </div>
        </>
      )}
    </Tile>
  );
}

function AssetRiskTile({ onOpen }: { onOpen: () => void }) {
  const { data: assets, isLoading } = useAssetRiskLevels();
  const active = assets?.[0];
  const riskVal = active?.risk_value ?? 0;
  const color = riskVal < 0.3 ? 'var(--ark-success)' : riskVal < 0.5 ? 'var(--ark-warning)' : riskVal < 0.7 ? '#F97316' : 'var(--ark-error)';
  const variant: 'success' | 'warning' | 'error' = active?.level === 'Low' ? 'success' : active?.level === 'Moderate' ? 'warning' : 'error';
  const delta = active ? riskVal - active.seven_day_avg : 0;

  return (
    <Tile onClick={onOpen} accentColor={color}>
      <AccentLine color={color} />
      {isLoading ? <SkeletonGaugeTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg transition-transform duration-300 group-hover:scale-110" style={{ backgroundColor: `${color}15` }}>
                <Shield className="h-3.5 w-3.5" style={{ color }} />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Asset Risk</span>
            </div>
            {active && <Badge variant={variant}>{active.level}</Badge>}
          </div>

          <div className="flex items-center gap-3">
            <CircleGauge value={riskVal} color={color} />
            <div className="flex-1 space-y-1">
              {active && (
                <>
                  <p className="text-[10px] text-ark-text-disabled">{active.days_at_level}d at {active.level}</p>
                  <div className="flex items-center gap-1.5">
                    <span className="text-[9px] text-ark-text-disabled">7d avg</span>
                    <span className="fig text-xs font-semibold text-ark-text">{active.seven_day_avg.toFixed(3)}</span>
                    <span className={cn(
                      'fig text-[9px] font-semibold',
                      delta > 0.01 ? 'text-ark-error' : delta < -0.01 ? 'text-ark-success' : 'text-ark-text-disabled',
                    )}>
                      {delta > 0 ? '+' : ''}{delta.toFixed(3)}
                    </span>
                  </div>
                </>
              )}
            </div>
          </div>

          {/* Top 3 factor bars */}
          {active && (
            <div className="space-y-0.5">
              {active.factors.slice(0, 3).map((f) => {
                const val = f.normalized_value ?? 0;
                const fColor = val < 0.3 ? 'var(--ark-success)' : val < 0.5 ? 'var(--ark-warning)' : val < 0.7 ? '#F97316' : 'var(--ark-error)';
                return (
                  <div key={f.type} className="flex items-center gap-1">
                    <span className="w-14 truncate text-[8px] text-ark-text-disabled">{f.type}</span>
                    <div className="h-1 flex-1 overflow-hidden rounded-full bg-ark-fill-secondary">
                      <div className="h-full rounded-full" style={{ width: `${val * 100}%`, backgroundColor: fColor }} />
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </>
      )}
    </Tile>
  );
}

function EventsTile({ onOpen }: { onOpen: () => void }) {
  const { data: events, isLoading } = useEconomicEvents();
  const todayStr = new Date().toISOString().split('T')[0];
  const todayEvents = (events ?? []).filter((e) => e.date?.startsWith(todayStr));
  const weekEnd = new Date();
  weekEnd.setDate(weekEnd.getDate() + 7);
  const weekStr = weekEnd.toISOString().split('T')[0];
  const upcoming = todayEvents.length > 0
    ? todayEvents
    : (events ?? []).filter((e) => e.date > todayStr && e.date <= weekStr);
  const highCount = upcoming.filter((e) => e.impact === 'high').length;
  const impactDot: Record<string, string> = { high: 'bg-ark-error', medium: 'bg-ark-warning', low: 'bg-ark-text-disabled' };

  const counter = useCountUp(upcoming.length, isLoading);

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-info)">
      <AccentLine color="var(--ark-info)" />
      {isLoading ? <SkeletonListTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-info/10 transition-transform duration-300 group-hover:scale-110">
                <Calendar className="h-3.5 w-3.5 text-ark-info" />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Events</span>
            </div>
            {highCount > 0 && (
              <span className="rounded-full bg-ark-error/10 px-1.5 py-0.5 text-[9px] font-semibold text-ark-error">
                {highCount} high
              </span>
            )}
          </div>

          <div>
            <span ref={counter.ref} className="fig text-3xl font-bold text-ark-text">{counter.value}</span>
            <span className="text-xs text-ark-text-disabled ml-1">
              {todayEvents.length > 0 ? 'today' : 'this week'}
            </span>
          </div>

          <div className="space-y-1">
            {upcoming.slice(0, 3).map((e) => (
              <div key={e.id} className="flex items-center gap-1.5">
                <span className={cn('h-1.5 w-1.5 shrink-0 rounded-full', impactDot[e.impact] ?? impactDot.low)} />
                <span className="text-[10px] text-ark-text-secondary truncate flex-1">{e.title}</span>
              </div>
            ))}
          </div>
        </>
      )}
    </Tile>
  );
}

function FavoritesTile({ onOpen }: { onOpen: () => void }) {
  const { profile } = useAuth();
  const { data: assets, isLoading } = useCryptoAssets(1);
  const riskCoins = profile?.risk_coins ?? ['bitcoin', 'ethereum'];
  const favorites = (assets ?? []).filter((a) =>
    riskCoins.some((rc) => rc.toLowerCase() === a.id.toLowerCase()),
  );

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-warning)">
      <AccentLine color="var(--ark-warning)" />
      {isLoading ? <SkeletonListTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-warning/10 transition-transform duration-300 group-hover:scale-110">
                <Star className="h-3.5 w-3.5 text-ark-warning" />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Watchlist</span>
            </div>
            <span className="text-[9px] text-ark-text-disabled">{favorites.length} tracked</span>
          </div>

          <div className="space-y-1.5">
            {favorites.slice(0, 3).map((asset) => {
              const isUp = (asset.price_change_percentage_24h ?? 0) >= 0;
              const sparkData = asset.sparkline_in_7d?.price?.slice(-24) ?? [];
              return (
                <div key={asset.id} className="flex items-center gap-2 rounded-lg bg-ark-fill-secondary/40 px-2 py-1">
                  {asset.image ? (
                    <img src={asset.image} alt={asset.name} className="h-5 w-5 rounded-full" />
                  ) : (
                    <div className="flex h-5 w-5 items-center justify-center rounded-full bg-ark-primary/15 text-[8px] font-bold text-ark-primary uppercase">
                      {asset.symbol.slice(0, 2)}
                    </div>
                  )}
                  <span className="text-[10px] font-bold text-ark-text">{asset.symbol.toUpperCase()}</span>
                  <div className="flex-1 h-3">
                    {sparkData.length > 2 && <Spark data={sparkData} color={isUp ? 'var(--ark-success)' : 'var(--ark-error)'} className="h-3" />}
                  </div>
                  <span className="fig text-[10px] font-bold text-ark-text">{formatCurrency(asset.current_price)}</span>
                  <span className={cn('fig text-[9px] font-semibold', isUp ? 'text-ark-success' : 'text-ark-error')}>
                    {formatPercent(asset.price_change_percentage_24h ?? 0)}
                  </span>
                </div>
              );
            })}
          </div>

          {favorites.length === 0 && (
            <p className="text-[10px] text-ark-text-disabled text-center">No favorites set</p>
          )}
        </>
      )}
    </Tile>
  );
}

function DCATile({ onOpen }: { onOpen: () => void }) {
  const { authUser } = useAuth();
  const isDemo = !isSupabaseConfigured();
  const { data: reminders, isLoading } = useQuery({
    queryKey: ['dca-reminders', authUser?.id ?? 'demo'],
    queryFn: () => fetchActiveReminders(authUser?.id ?? 'demo'),
    enabled: isDemo || !!authUser?.id,
    staleTime: 300_000,
  });
  const upcoming = (reminders ?? []).slice(0, 4);
  const totalMonthly = upcoming.reduce((sum, r) => {
    const multiplier = r.frequency === 'daily' ? 30 : r.frequency === 'weekly' ? 4.3 : r.frequency === 'biweekly' ? 2.15 : 1;
    return sum + r.amount * multiplier;
  }, 0);
  const freqShort: Record<string, string> = { daily: 'D', weekly: 'W', biweekly: '2W', monthly: 'M' };

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonListTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10 transition-transform duration-300 group-hover:scale-110">
                <Bell className="h-3.5 w-3.5 text-ark-primary" />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">DCA</span>
            </div>
            <span className="fig rounded-full bg-ark-primary/10 px-1.5 py-0.5 text-[9px] font-semibold text-ark-primary">
              {upcoming.length} active
            </span>
          </div>

          {totalMonthly > 0 && (
            <div>
              <span className="fig text-lg font-bold text-ark-text">~{formatCurrency(totalMonthly)}</span>
              <span className="text-[10px] text-ark-text-disabled">/mo</span>
            </div>
          )}

          <div className="space-y-1">
            {upcoming.slice(0, 3).map((r) => {
              const nextDate = r.next_reminder_date ? new Date(r.next_reminder_date) : null;
              const totalDays = r.frequency === 'daily' ? 1 : r.frequency === 'weekly' ? 7 : r.frequency === 'biweekly' ? 14 : 30;
              const daysUntil = nextDate ? Math.max(0, Math.ceil((nextDate.getTime() - Date.now()) / 86400000)) : 0;
              const progressPct = Math.max(0, Math.min(100, ((totalDays - daysUntil) / totalDays) * 100));
              return (
                <div key={r.id} className="rounded-lg bg-ark-fill-secondary/40 px-2 py-1">
                  <div className="flex items-center justify-between">
                    <span className="text-[10px] font-semibold text-ark-text truncate">{r.name}</span>
                    <div className="flex items-center gap-1">
                      <span className="flex items-center gap-0.5 text-[8px] text-ark-text-disabled">
                        <Repeat className="h-2 w-2" />
                        {freqShort[r.frequency] ?? r.frequency}
                      </span>
                      <span className="fig text-[10px] font-bold text-ark-text">{formatCurrency(r.amount)}</span>
                    </div>
                  </div>
                  {nextDate && (
                    <div className="mt-0.5 h-0.5 overflow-hidden rounded-full bg-ark-fill-tertiary">
                      <div className="h-full rounded-full bg-ark-primary/60" style={{ width: `${progressPct}%` }} />
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </>
      )}
    </Tile>
  );
}

function NewsTile({ onOpen }: { onOpen: () => void }) {
  const { data: news, isLoading } = useNews(4);
  const articles = news ?? [];

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-violet)">
      <AccentLine color="var(--ark-violet)" />
      {isLoading ? <SkeletonListTile /> : (
        <>
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-violet/10 transition-transform duration-300 group-hover:scale-110">
              <Newspaper className="h-3.5 w-3.5 text-ark-violet" />
            </div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Headlines</span>
          </div>

          <div className="space-y-1.5">
            {articles.slice(0, 3).map((article, i) => (
              <div key={article.id} className={cn(
                'rounded-lg px-2 py-1',
                i === 0 ? 'bg-ark-violet/[0.04] border border-ark-violet/10' : 'bg-ark-fill-secondary/30',
              )}>
                <p className={cn(
                  'font-medium leading-snug text-ark-text line-clamp-1',
                  i === 0 ? 'text-[11px]' : 'text-[10px]',
                )}>
                  {article.title}
                </p>
                <div className="mt-0.5 flex items-center gap-1 text-[8px] text-ark-text-disabled">
                  <span className="font-semibold text-ark-text-tertiary">{article.source}</span>
                  <span className="h-0.5 w-0.5 rounded-full bg-ark-text-disabled" />
                  <span>{formatRelativeTime(article.published_at)}</span>
                </div>
              </div>
            ))}
          </div>

          {articles.length === 0 && (
            <p className="text-[10px] text-ark-text-disabled text-center">No news available</p>
          )}
        </>
      )}
    </Tile>
  );
}

/* ══════════════════════ BENTO GRID ══════════════════════ */

// rowHeight = 80px. h:2 = 168px (compact), h:3 = 248px (hero)
const HOME_DEFAULT_LAYOUTS: ResponsiveLayouts = {
  lg: [
    { i: 'portfolio',    x: 0, y: 0,  w: 2, h: 3, minW: 2, minH: 2, maxW: 4, maxH: 6 },
    { i: 'fearGreed',    x: 2, y: 0,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'arklineScore', x: 3, y: 0,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'briefing',     x: 0, y: 3,  w: 2, h: 3, minW: 2, minH: 2, maxW: 4, maxH: 6 },
    { i: 'riskChart',    x: 2, y: 3,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'marketMovers', x: 3, y: 3,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'macro',        x: 0, y: 6,  w: 2, h: 3, minW: 2, minH: 2, maxW: 4, maxH: 6 },
    { i: 'supply',       x: 2, y: 6,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'assetRisk',    x: 3, y: 6,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'events',       x: 0, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'favorites',    x: 1, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'dca',          x: 2, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'news',         x: 3, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
  ],
  md: [
    { i: 'portfolio',    x: 0, y: 0,  w: 2, h: 3, minW: 2, minH: 2, maxW: 3, maxH: 6 },
    { i: 'fearGreed',    x: 2, y: 0,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'arklineScore', x: 0, y: 3,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'briefing',     x: 1, y: 3,  w: 2, h: 3, minW: 2, minH: 2, maxW: 3, maxH: 6 },
    { i: 'riskChart',    x: 0, y: 6,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'marketMovers', x: 1, y: 6,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'macro',        x: 2, y: 6,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'supply',       x: 0, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'assetRisk',    x: 1, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'events',       x: 2, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'favorites',    x: 0, y: 12, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'dca',          x: 1, y: 12, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'news',         x: 2, y: 12, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
  ],
  sm: [
    { i: 'portfolio',    x: 0, y: 0,  w: 2, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'fearGreed',    x: 0, y: 3,  w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'arklineScore', x: 1, y: 3,  w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'briefing',     x: 0, y: 6,  w: 2, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'riskChart',    x: 0, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'marketMovers', x: 1, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'macro',        x: 0, y: 12, w: 2, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'supply',       x: 0, y: 15, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'assetRisk',    x: 1, y: 15, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'events',       x: 0, y: 18, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'favorites',    x: 1, y: 18, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'dca',          x: 0, y: 21, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'news',         x: 1, y: 21, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
  ],
};

const widgetKeys: WidgetKey[] = [
  'portfolio', 'fearGreed', 'arklineScore', 'briefing', 'riskChart',
  'marketMovers', 'macro', 'supply', 'assetRisk', 'events',
  'favorites', 'dca', 'news',
];

const tileComponents: Record<WidgetKey, React.ComponentType<{ onOpen: () => void }>> = {
  portfolio: PortfolioTile,
  fearGreed: FearGreedTile,
  arklineScore: ArkLineScoreTile,
  briefing: BriefingTile,
  riskChart: RiskChartTile,
  marketMovers: MarketMoversTile,
  macro: MacroTile,
  supply: SupplyTile,
  assetRisk: AssetRiskTile,
  events: EventsTile,
  favorites: FavoritesTile,
  dca: DCATile,
  news: NewsTile,
};

export function BentoGrid() {
  const [activeWidget, setActiveWidget] = useState<WidgetKey | null>(null);
  const open = (key: WidgetKey) => () => setActiveWidget(key);

  return (
    <>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.4 }}
      >
        <DraggableGrid layoutKey="home" defaultLayouts={HOME_DEFAULT_LAYOUTS}>
          {widgetKeys.map((key, i) => {
            const TileComp = tileComponents[key];
            return (
              <div key={key} className="h-full [&>*]:h-full">
                {i === 0 && <ShineSweep />}
                <TileComp onOpen={open(key)} />
              </div>
            );
          })}
        </DraggableGrid>
      </motion.div>

      <DetailDrawer
        open={activeWidget !== null}
        onClose={() => setActiveWidget(null)}
        title={activeWidget ? drawerTitles[activeWidget] : ''}
      >
        {activeWidget && <LazyDrawerWidget widgetKey={activeWidget} />}
      </DetailDrawer>
    </>
  );
}
