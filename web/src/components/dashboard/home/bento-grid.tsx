'use client';

import { useState, useEffect } from 'react';
import {
  Wallet, Brain, Sparkles, Gauge, Shield, BarChart3, Globe,
  PieChart, Calendar, Star, Bell, Newspaper, ArrowUpRight,
  ArrowDownRight, TrendingUp, TrendingDown, Clock, Repeat,
  SlidersHorizontal, X, Check,
} from 'lucide-react';
import { motion } from 'framer-motion';
import { Badge, Skeleton } from '@/components/ui';
import { DetailDrawer } from '@/components/ui/detail-drawer';
import {
  useRiskHistory, useFearGreedIndex, useArkLineScore, useCryptoAssets,
  useMarketBriefing, useCryptoPositioning, useMacroIndicators,
  useSupplyInProfit, useAssetRiskLevels, useEconomicEvents, useNews,
  useRegimeData, useMarketBreadth, useSignalChanges, useStockRiskLevels,
  useTradeSignals, useRotationSignal, useModelPortfolioUpdate, useWeeklyDeck,
  useUSFutures, usePerpPremium, useFedWatch,
} from '@/lib/hooks/use-market';
import { useAuth } from '@/lib/hooks/use-auth';
import { usePortfolios, useHoldings, usePortfolioHistory } from '@/lib/hooks/use-portfolio';
import { useWidgetVisibility } from '@/lib/hooks/use-widget-visibility';
import { useDashboardPresets } from '@/lib/hooks/use-dashboard-presets';
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
  | 'assetRisk' | 'events' | 'favorites' | 'dca' | 'news'
  | 'vix' | 'dxy' | 'm2' | 'marketBreadth' | 'signalChanges' | 'stockRisk'
  | 'tradeSignals' | 'rotation' | 'modelPortfolio' | 'weeklyUpdate'
  | 'usFutures' | 'perpPremium' | 'fedWatch';

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
  vix: 'VIX — Volatility Index',
  dxy: 'DXY — US Dollar Index',
  m2: 'Global M2 — Money Supply',
  marketBreadth: 'Market Breadth',
  signalChanges: 'Signal Changes',
  stockRisk: 'Stock Risk Levels',
  tradeSignals: 'Trade Signals',
  rotation: 'Crypto / Equities Rotation',
  modelPortfolio: 'Model Portfolio Updates',
  weeklyUpdate: 'Weekly Update',
  usFutures: 'US Futures',
  perpPremium: 'Perp Premium',
  fedWatch: 'Fed Watch',
};

/* ── Lazy drawer widget renderer ── */
function LazyDrawerWidget({ widgetKey }: { widgetKey: WidgetKey }) {
  const [Widget, setWidget] = useState<React.ComponentType | null>(null);

  useEffect(() => {
    let cancelled = false;
    const loaders: Partial<Record<WidgetKey, () => Promise<{ default?: React.ComponentType; [k: string]: unknown }>>> = {
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
      vix: () => import('./macro-detail').then(m => ({ default: m.VixDetail })),
      dxy: () => import('./macro-detail').then(m => ({ default: m.DxyDetail })),
      m2: () => import('./macro-detail').then(m => ({ default: m.M2Detail })),
      marketBreadth: () => import('./market-detail').then(m => ({ default: m.MarketBreadthDetail })),
      signalChanges: () => import('./market-detail').then(m => ({ default: m.SignalChangesDetail })),
      stockRisk: () => import('./market-detail').then(m => ({ default: m.StockRiskDetail })),
      tradeSignals: () => import('./signals-detail').then(m => ({ default: m.TradeSignalsDetail })),
      rotation: () => import('./signals-detail').then(m => ({ default: m.RotationDetail })),
      modelPortfolio: () => import('./signals-detail').then(m => ({ default: m.ModelPortfolioDetail })),
      weeklyUpdate: () => import('./signals-detail').then(m => ({ default: m.WeeklyUpdateDetail })),
      usFutures: () => import('./extras-detail').then(m => ({ default: m.USFuturesDetail })),
      perpPremium: () => import('./extras-detail').then(m => ({ default: m.PerpPremiumDetail })),
      fedWatch: () => import('./extras-detail').then(m => ({ default: m.FedWatchDetail })),
    };
    const loader = loaders[widgetKey];
    if (!loader) {
      // No dedicated detail view yet — the tile itself carries the data.
      const Fallback = () => (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <p className="text-sm text-ark-text-secondary">Detailed view coming soon</p>
          <p className="mt-1 text-xs text-ark-text-disabled">This widget&apos;s data is shown on the dashboard tile.</p>
        </div>
      );
      setWidget(() => Fallback as React.ComponentType);
      return () => { cancelled = true; };
    }
    loader().then(mod => {
      if (!cancelled) setWidget(() => (mod.default ?? null) as React.ComponentType | null);
    });
    return () => { cancelled = true; };
  }, [widgetKey]);

  if (!Widget) return <Skeleton className="h-64 w-full" />;
  return <Widget />;
}


/* ══════════════════════ TILE COMPONENTS ══════════════════════ */

function PortfolioTile({ onOpen }: { onOpen: () => void }) {
  const { data: portfolios, isLoading: portfoliosLoading } = usePortfolios();
  const portfolioId = portfolios?.[0]?.id;
  const { data: holdings, isLoading: holdingsLoading } = useHoldings(portfolioId);
  const { data: assets } = useCryptoAssets(1);
  const { data: history } = usePortfolioHistory(portfolioId, 30);

  const isLoading = portfoliosLoading || (!!portfolioId && holdingsLoading);

  // Live price lookup by symbol (from the cached top-coins list).
  const priceBySymbol = new Map<string, { current_price: number; price_change_percentage_24h: number }>();
  for (const a of assets ?? []) {
    priceBySymbol.set(a.symbol.toLowerCase(), {
      current_price: a.current_price,
      price_change_percentage_24h: a.price_change_percentage_24h ?? 0,
    });
  }

  // Current value + 24h change, summed across holdings (quantity × live price;
  // falls back to average buy price for anything without a live quote).
  let currentValue = 0;
  let dayChange = 0;
  for (const h of holdings ?? []) {
    const live = priceBySymbol.get(h.symbol.toLowerCase());
    const price = live?.current_price ?? h.average_buy_price ?? 0;
    const value = h.quantity * price;
    currentValue += value;
    const pct = live?.price_change_percentage_24h ?? 0;
    dayChange += value - value / (1 + pct / 100);
  }
  const dayChangePct = currentValue - dayChange ? (dayChange / (currentValue - dayChange)) * 100 : 0;
  const isUp = dayChange >= 0;

  // 30-day history (portfolio_history) for the sparkline + 30d return.
  const histVals = (history ?? []).map((p) => p.value);
  const sparkVals = histVals.length ? [...histVals, currentValue] : [];
  const monthStart = histVals[0] ?? currentValue;
  const monthChangePct = monthStart ? ((currentValue - monthStart) / monthStart) * 100 : 0;
  const isMonthUp = monthChangePct >= 0;
  const periodHigh = sparkVals.length ? Math.max(...sparkVals) : currentValue;
  const periodLow = sparkVals.length ? Math.min(...sparkVals) : currentValue;
  const rangeSpan = periodHigh - periodLow || 1;
  const rangePct = ((currentValue - periodLow) / rangeSpan) * 100;

  const assetCount = holdings?.length ?? 0;
  const hasHoldings = assetCount > 0;
  const counter = useCountUp(currentValue, isLoading, 2);

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonHeroTile /> : !hasHoldings ? (
        // Empty state — no holdings yet.
        <div className="flex h-full flex-col">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10 transition-transform duration-300 group-hover:scale-110">
              <Wallet className="h-3.5 w-3.5 text-ark-primary" />
            </div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Portfolio</span>
          </div>
          <div className="flex flex-1 flex-col items-center justify-center text-center">
            <p className="fig font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text leading-tight">
              <span className="opacity-40 font-normal">$</span>0.00
            </p>
            <p className="mt-1 text-[11px] text-ark-text-tertiary">No holdings yet</p>
            <p className="mt-0.5 text-[10px] text-ark-text-disabled">Add holdings to track your portfolio</p>
          </div>
        </div>
      ) : (
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
                <p className="fig text-sm font-bold text-ark-text">{assetCount}</p>
              </div>
            </div>

            {/* Range bar */}
            {sparkVals.length > 1 && (
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
            )}
          </div>

          {/* Right sparkline — colored by the period (30d) trend */}
          {sparkVals.length > 1 && (
            <div className="flex flex-col justify-end w-2/5 shrink-0">
              <Spark data={sparkVals} color={isMonthUp ? 'var(--ark-success)' : 'var(--ark-error)'} className="h-full" />
            </div>
          )}
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
    { i: 'vix',          x: 0, y: 12, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'dxy',          x: 1, y: 12, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'm2',           x: 2, y: 12, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'marketBreadth',x: 3, y: 12, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'signalChanges',x: 0, y: 15, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'stockRisk',    x: 1, y: 15, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'tradeSignals', x: 2, y: 15, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'rotation',     x: 3, y: 15, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'modelPortfolio',x: 0, y: 18, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'weeklyUpdate', x: 1, y: 18, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'usFutures',    x: 2, y: 18, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'perpPremium',  x: 3, y: 18, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'fedWatch',     x: 0, y: 21, w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
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
    { i: 'vix',          x: 0, y: 15, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'dxy',          x: 1, y: 15, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'm2',           x: 2, y: 15, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'marketBreadth',x: 0, y: 18, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'signalChanges',x: 1, y: 18, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'stockRisk',    x: 2, y: 18, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'tradeSignals', x: 0, y: 21, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'rotation',     x: 1, y: 21, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'modelPortfolio',x: 2, y: 21, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'weeklyUpdate', x: 0, y: 24, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'usFutures',    x: 1, y: 24, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'perpPremium',  x: 2, y: 24, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'fedWatch',     x: 0, y: 27, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
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
    { i: 'vix',          x: 0, y: 24, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'dxy',          x: 1, y: 24, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'm2',           x: 0, y: 27, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'marketBreadth',x: 1, y: 27, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'signalChanges',x: 0, y: 30, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'stockRisk',    x: 1, y: 30, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'tradeSignals', x: 0, y: 33, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'rotation',     x: 1, y: 33, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'modelPortfolio',x: 0, y: 36, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'weeklyUpdate', x: 1, y: 36, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'usFutures',    x: 0, y: 39, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'perpPremium',  x: 1, y: 39, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'fedWatch',     x: 0, y: 42, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
  ],
};

/* ── Standalone macro indicator tiles (VIX / DXY / Global M2) ──
 * Matches the iOS VIXWidget / DXYWidget / GlobalLiquidityWidget: value, subtitle,
 * and a Bullish / Neutral / Bearish level label. Reuses the macro indicator feed.
 */
function makeMacroTile(cfg: {
  indicator: string;
  title: string;
  subtitle: string;
  decimals: number;
  prefix?: string;
  suffix?: string;
  level: (v: number, changePct: number) => { label: string; color: string };
}) {
  function MacroSingleTile({ onOpen }: { onOpen: () => void }) {
    const { data, isLoading } = useMacroIndicators();
    const ind = (data ?? []).find((d) => d.name === cfg.indicator);
    const value = ind?.value ?? 0;
    const changePct = ind?.change_percentage ?? 0;
    const spark = ind?.sparkline ?? [];
    const lvl = cfg.level(value, changePct);
    const counter = useCountUp(value, isLoading, cfg.decimals);

    return (
      <Tile onClick={onOpen} accentColor={lvl.color}>
        <AccentLine color={lvl.color} />
        {isLoading ? <SkeletonSparkTile /> : (
          <div className="flex h-full flex-col">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">{cfg.title}</span>
              </div>
              <span className="h-2 w-2 rounded-full" style={{ backgroundColor: lvl.color }} />
            </div>

            <div className="relative mt-1 flex items-baseline gap-1.5">
              <AmbientGlow color={lvl.color} className="-left-2 -bottom-2 h-12 w-20" />
              <span ref={counter.ref} className="fig font-[family-name:var(--font-urbanist)] text-3xl font-bold leading-none text-ark-text relative">
                {cfg.prefix}{counter.value}{cfg.suffix}
              </span>
              <span className={cn('fig text-xs font-semibold', changePct >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                {formatPercent(changePct)}
              </span>
            </div>

            {spark.length > 1 && (
              <div className="my-2 h-8">
                <Spark data={spark} color={lvl.color} className="h-full" />
              </div>
            )}

            <div className="mt-auto flex items-center justify-between">
              <span className="text-[10px] text-ark-text-disabled">{cfg.subtitle}</span>
              <span className="text-[11px] font-semibold" style={{ color: lvl.color }}>{lvl.label}</span>
            </div>
          </div>
        )}
      </Tile>
    );
  }
  return MacroSingleTile;
}

const VIX = { success: 'var(--ark-success)', warning: 'var(--ark-warning)', error: 'var(--ark-error)' };

const VixTile = makeMacroTile({
  indicator: 'VIX', title: 'VIX', subtitle: 'Volatility Index', decimals: 2,
  level: (v) => v < 20 ? { label: 'Bullish', color: VIX.success } : v < 25 ? { label: 'Neutral', color: VIX.warning } : { label: 'Bearish', color: VIX.error },
});
const DxyTile = makeMacroTile({
  indicator: 'DXY', title: 'DXY', subtitle: 'US Dollar Index', decimals: 2,
  level: (v) => v < 100 ? { label: 'Bullish', color: VIX.success } : v < 105 ? { label: 'Neutral', color: VIX.warning } : { label: 'Bearish', color: VIX.error },
});
const M2Tile = makeMacroTile({
  indicator: 'M2', title: 'Global M2', subtitle: 'Money Supply', decimals: 1, prefix: '$', suffix: 'T',
  level: (_v, chg) => chg > 0 ? { label: 'Bullish', color: VIX.success } : chg > -1 ? { label: 'Neutral', color: VIX.warning } : { label: 'Bearish', color: VIX.error },
});

/* ── Market Breadth tile (market_breadth) ── */
const SIG_COLORS: Record<string, string> = {
  bullish: 'var(--ark-success)', neutral: 'var(--ark-warning)', bearish: 'var(--ark-error)',
};
function breadthColor(pct: number): string {
  if (pct >= 70) return 'var(--ark-success)';
  if (pct >= 40) return 'var(--ark-warning)';
  return 'var(--ark-error)';
}

function MarketBreadthTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useMarketBreadth();
  const pct = data?.breadth_pct ?? 0;
  const trend = (data?.trend ?? 'neutral').toLowerCase();
  const color = breadthColor(pct);
  const counter = useCountUp(pct, isLoading, 1);
  return (
    <Tile onClick={onOpen} accentColor={color}>
      <AccentLine color={color} />
      {isLoading ? <SkeletonSparkTile /> : (
        <div className="flex h-full flex-col">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Market Breadth</span>
            <Badge variant={trend === 'bullish' ? 'success' : trend === 'bearish' ? 'error' : 'warning'}>
              {trend.charAt(0).toUpperCase() + trend.slice(1)}
            </Badge>
          </div>
          <div className="relative mt-1 flex items-baseline gap-1.5">
            <AmbientGlow color={color} className="-left-2 -bottom-2 h-12 w-20" />
            <span ref={counter.ref} className="fig font-[family-name:var(--font-urbanist)] text-3xl font-bold leading-none relative" style={{ color }}>
              {counter.value}%
            </span>
            <span className="fig text-[11px] text-ark-text-disabled">{data?.trending_tokens ?? 0}/{data?.total_tokens ?? 0} trending</span>
          </div>
          {(data?.history?.length ?? 0) > 1 && (
            <div className="my-2 h-8"><Spark data={data!.history} color={color} className="h-full" /></div>
          )}
          <div className="mt-auto flex items-center justify-between">
            <span className="text-[10px] text-ark-text-disabled">% tokens in uptrend</span>
            {data?.crossover && (
              <span className="text-[10px] font-semibold" style={{ color }}>{data.crossover} cross</span>
            )}
          </div>
        </div>
      )}
    </Tile>
  );
}

/* ── Signal Changes tile (positioning_signals) ── */
function SignalChangesTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useSignalChanges();
  const changes = data ?? [];
  const cap = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonListTile /> : (
        <div className="flex h-full flex-col">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10">
              <Repeat className="h-3.5 w-3.5 text-ark-primary" />
            </div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Signal Changes</span>
          </div>
          {changes.length === 0 ? (
            <div className="flex flex-1 flex-col items-center justify-center text-center">
              <p className="text-xs text-ark-text-tertiary">No signal changes today</p>
            </div>
          ) : (
            <div className="mt-2 space-y-1.5 overflow-hidden">
              {changes.slice(0, 5).map((c) => (
                <div key={c.asset} className="flex items-center gap-2">
                  <span className="w-12 truncate text-[11px] font-semibold text-ark-text">{c.asset}</span>
                  <span className="rounded px-1.5 py-0.5 text-[9px] font-bold text-white" style={{ backgroundColor: SIG_COLORS[c.prev_signal] }}>{cap(c.prev_signal)}</span>
                  <ArrowUpRight className="h-3 w-3 rotate-45 text-ark-text-disabled" />
                  <span className="rounded px-1.5 py-0.5 text-[9px] font-bold text-white" style={{ backgroundColor: SIG_COLORS[c.signal] }}>{cap(c.signal)}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </Tile>
  );
}

/* ── Stock Risk Levels tile (indicator_snapshots stock_risk_*) ── */
function StockRiskTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useStockRiskLevels();
  const stocks = data ?? [];
  const riskColor = (v: number) => v < 0.3 ? 'var(--ark-success)' : v < 0.5 ? 'var(--ark-warning)' : v < 0.7 ? '#F97316' : 'var(--ark-error)';
  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonListTile /> : (
        <div className="flex h-full flex-col">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10">
              <BarChart3 className="h-3.5 w-3.5 text-ark-primary" />
            </div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Stock Risk Levels</span>
          </div>
          {stocks.length === 0 ? (
            <div className="flex flex-1 items-center justify-center"><p className="text-xs text-ark-text-disabled">No data</p></div>
          ) : (
            <div className="mt-2 space-y-1.5">
              {stocks.slice(0, 6).map((s) => (
                <div key={s.symbol} className="flex items-center gap-2">
                  <span className="w-12 truncate text-[11px] font-semibold text-ark-text">{s.symbol}</span>
                  <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-ark-fill-secondary">
                    <div className="h-full rounded-full" style={{ width: `${s.risk_value * 100}%`, backgroundColor: riskColor(s.risk_value) }} />
                  </div>
                  <span className="fig w-8 text-right text-[10px] font-semibold text-ark-text">{s.risk_value.toFixed(2)}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </Tile>
  );
}

/* ── Trade Signals tile (trade_signals) ── */
function TradeSignalsTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useTradeSignals();
  const signals = data ?? [];
  const outcomeColor = (s: string) => s === 'target_hit' ? 'var(--ark-success)' : s === 'invalidated' ? 'var(--ark-error)' : 'var(--ark-warning)';
  const outcomeLabel = (s: string) => s === 'target_hit' ? 'Win' : s === 'invalidated' ? 'Stopped' : s.charAt(0).toUpperCase() + s.slice(1);
  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonListTile /> : (
        <div className="flex h-full flex-col">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10"><BarChart3 className="h-3.5 w-3.5 text-ark-primary" /></div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Trade Signals</span>
          </div>
          {signals.length === 0 ? (
            <div className="flex flex-1 items-center justify-center"><p className="text-xs text-ark-text-disabled">No recent signals</p></div>
          ) : (
            <div className="mt-2 space-y-1.5">
              {signals.slice(0, 5).map((s) => (
                <div key={s.id} className="flex items-center gap-2">
                  <span className={cn('rounded px-1.5 py-0.5 text-[9px] font-bold text-white', s.signal_type === 'buy' ? 'bg-ark-success' : 'bg-ark-error')}>{s.signal_type.toUpperCase()}</span>
                  <span className="w-10 truncate text-[11px] font-semibold text-ark-text">{s.asset}</span>
                  {s.timeframe && <span className="text-[10px] text-ark-text-disabled">{s.timeframe}</span>}
                  {s.risk_reward_ratio != null && <span className="fig text-[10px] text-ark-text-tertiary">{s.risk_reward_ratio.toFixed(1)}x</span>}
                  <span className="ml-auto text-[10px] font-semibold" style={{ color: outcomeColor(s.status) }}>{outcomeLabel(s.status)}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </Tile>
  );
}

/* ── Rotation Signal tile (rotation_signals) ── */
function RotationTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useRotationSignal();
  const score = data?.rotation_score ?? 0;
  const favors = score < 0 ? 'Crypto' : score > 0 ? 'Equities' : 'Neutral';
  const color = score < 0 ? 'var(--ark-primary)' : score > 0 ? 'var(--ark-violet)' : 'var(--ark-text-tertiary)';
  const regimeLabel = (data?.regime ?? '').split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
  return (
    <Tile onClick={onOpen} accentColor={color}>
      <AccentLine color={color} />
      {isLoading ? <SkeletonListTile /> : !data ? (
        <div className="flex h-full items-center justify-center"><p className="text-xs text-ark-text-disabled">No rotation data</p></div>
      ) : (
        <div className="flex h-full flex-col">
          <div className="flex items-center justify-between">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Rotation Signal</span>
            {regimeLabel && <Badge variant="default">{regimeLabel}</Badge>}
          </div>
          <div className="mt-1 flex items-baseline gap-2">
            <span className="font-[family-name:var(--font-urbanist)] text-2xl font-bold leading-none" style={{ color }}>→ {favors}</span>
          </div>
          <div className="mt-2 flex items-center gap-3 text-[10px]">
            <span className="text-ark-text-disabled">BTC 30d <span className={cn('fig font-semibold', (data.btc_30d_return ?? 0) >= 0 ? 'text-ark-success' : 'text-ark-error')}>{formatPercent(data.btc_30d_return ?? 0)}</span></span>
            <span className="text-ark-text-disabled">SPY 30d <span className={cn('fig font-semibold', (data.spy_30d_return ?? 0) >= 0 ? 'text-ark-success' : 'text-ark-error')}>{formatPercent(data.spy_30d_return ?? 0)}</span></span>
          </div>
          {data.sectors.length > 0 && (
            <div className="mt-2">
              <p className="text-[9px] font-medium uppercase tracking-wider text-ark-text-disabled">Top Sectors</p>
              <div className="mt-1 space-y-0.5">
                {data.sectors.map((s) => (
                  <div key={s.name} className="flex items-center justify-between text-[10px]">
                    <span className="truncate text-ark-text-secondary">{s.name}</span>
                    <span className="fig font-semibold text-ark-success">{formatPercent(s.return_30d)}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </Tile>
  );
}

/* ── Model Portfolio Update tile (model_portfolio_trades) ── */
function ModelPortfolioTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useModelPortfolioUpdate();
  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonListTile /> : !data ? (
        <div className="flex h-full items-center justify-center"><p className="text-xs text-ark-text-disabled">No updates</p></div>
      ) : (
        <div className="flex h-full flex-col">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10"><PieChart className="h-3.5 w-3.5 text-ark-primary" /></div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Model Portfolio</span>
          </div>
          <div className="mt-1.5 flex items-center justify-between">
            <span className="text-sm font-semibold text-ark-text">{data.portfolio_name}</span>
            <span className="text-[10px] text-ark-text-disabled">{data.trigger}</span>
          </div>
          {data.changes.length === 0 ? (
            <p className="mt-2 text-[11px] text-ark-text-tertiary">No allocation changes</p>
          ) : (
            <div className="mt-2 space-y-1">
              {data.changes.slice(0, 5).map((c) => (
                <div key={c.asset} className="flex items-center gap-2 text-[10px]">
                  <span className="w-12 font-semibold text-ark-text">{c.asset}</span>
                  <span className="fig text-ark-text-disabled">{c.from.toFixed(0)}%</span>
                  <ArrowUpRight className={cn('h-3 w-3', c.to >= c.from ? 'text-ark-success' : 'text-ark-error rotate-90')} />
                  <span className="fig font-semibold text-ark-text">{c.to.toFixed(0)}%</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </Tile>
  );
}

/* ── Weekly Update deck tile (market_update_decks) ── */
function WeeklyUpdateTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useWeeklyDeck();
  const fmt = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  return (
    <Tile onClick={onOpen} accentColor="var(--ark-violet)">
      <AccentLine color="var(--ark-violet)" />
      {isLoading ? <SkeletonListTile /> : !data ? (
        <div className="flex h-full items-center justify-center"><p className="text-xs text-ark-text-disabled">No deck yet</p></div>
      ) : (
        <div className="flex h-full flex-col">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-violet/10"><Newspaper className="h-3.5 w-3.5 text-ark-violet" /></div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Weekly Update</span>
          </div>
          <div className="flex flex-1 flex-col items-center justify-center text-center">
            <p className="font-[family-name:var(--font-urbanist)] text-lg font-bold text-ark-text">{fmt(data.week_start)} – {fmt(data.week_end)}</p>
            <p className="mt-1 text-[11px] text-ark-text-tertiary">{data.slide_count} slides</p>
            <span className="mt-2 rounded-full bg-ark-violet/10 px-2.5 py-0.5 text-[10px] font-semibold text-ark-violet capitalize">{data.status}</span>
          </div>
        </div>
      )}
    </Tile>
  );
}

/* ── US Futures tile (market_data_cache 'us_futures' via edge cron) ── */
function USFuturesTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useUSFutures();
  const futures = data ?? [];
  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonListTile /> : (
        <div className="flex h-full flex-col">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10"><TrendingUp className="h-3.5 w-3.5 text-ark-primary" /></div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">US Futures</span>
          </div>
          {futures.length === 0 ? (
            <div className="flex flex-1 flex-col items-center justify-center text-center">
              <p className="text-xs text-ark-text-tertiary">Awaiting data</p>
              <p className="mt-0.5 text-[10px] text-ark-text-disabled">Updates when the market-extras job runs</p>
            </div>
          ) : (
            <div className="mt-2 space-y-2">
              {futures.map((f) => (
                <div key={f.symbol} className="flex items-center justify-between">
                  <span className="text-[11px] font-semibold text-ark-text">{f.name}</span>
                  <div className="flex items-baseline gap-2">
                    <span className="fig text-sm font-bold text-ark-text">{f.price.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                    <span className={cn('fig text-[11px] font-semibold', f.change_percent >= 0 ? 'text-ark-success' : 'text-ark-error')}>{formatPercent(f.change_percent)}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </Tile>
  );
}

/* ── Perp Premium tile (market_data_cache 'perp_premium' via edge cron) ── */
function PerpPremiumTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = usePerpPremium();
  const perps = data ?? [];
  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonListTile /> : (
        <div className="flex h-full flex-col">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10"><Gauge className="h-3.5 w-3.5 text-ark-primary" /></div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Perp Premium</span>
          </div>
          {perps.length === 0 ? (
            <div className="flex flex-1 flex-col items-center justify-center text-center">
              <p className="text-xs text-ark-text-tertiary">Awaiting data</p>
              <p className="mt-0.5 text-[10px] text-ark-text-disabled">Updates when the market-extras job runs</p>
            </div>
          ) : (
            <div className="mt-2 space-y-2">
              {perps.map((p) => {
                const bullish = p.funding_rate >= 0;
                return (
                  <div key={p.symbol} className="flex items-center justify-between">
                    <span className="text-[11px] font-semibold text-ark-text">{p.symbol}</span>
                    <div className="flex items-baseline gap-2">
                      <span className={cn('fig text-sm font-bold', bullish ? 'text-ark-success' : 'text-ark-error')}>{(p.funding_rate * 100).toFixed(4)}%</span>
                      <span className="text-[10px] text-ark-text-disabled">{bullish ? 'longs pay' : 'shorts pay'}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </Tile>
  );
}

/* ── Fed Watch tile (market_data_cache 'fed_watch' via edge cron) ── */
function FedWatchTile({ onOpen }: { onOpen: () => void }) {
  const { data, isLoading } = useFedWatch();
  const meetings = data ?? [];
  const fmt = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonListTile /> : (
        <div className="flex h-full flex-col">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10"><Globe className="h-3.5 w-3.5 text-ark-primary" /></div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Fed Watch</span>
          </div>
          {meetings.length === 0 ? (
            <div className="flex flex-1 flex-col items-center justify-center text-center">
              <p className="text-xs text-ark-text-tertiary">Awaiting data</p>
              <p className="mt-0.5 text-[10px] text-ark-text-disabled">Updates when the market-extras job runs</p>
            </div>
          ) : (
            <div className="mt-2 space-y-2">
              {meetings.slice(0, 3).map((m) => (
                <div key={m.meeting_date}>
                  <div className="flex items-center justify-between text-[10px]">
                    <span className="font-semibold text-ark-text">{fmt(m.meeting_date)}</span>
                    <span className="text-ark-text-disabled">cut {m.cut_probability}% · hold {m.hold_probability}%</span>
                  </div>
                  <div className="mt-1 flex h-1.5 overflow-hidden rounded-full bg-ark-fill-secondary">
                    <div className="h-full bg-ark-success" style={{ width: `${m.cut_probability}%` }} />
                    <div className="h-full bg-ark-text-tertiary" style={{ width: `${m.hold_probability}%` }} />
                    <div className="h-full bg-ark-error" style={{ width: `${m.hike_probability}%` }} />
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </Tile>
  );
}

const widgetKeys: WidgetKey[] = [
  'portfolio', 'fearGreed', 'arklineScore', 'briefing', 'riskChart',
  'marketMovers', 'macro', 'supply', 'assetRisk', 'events',
  'favorites', 'dca', 'news',
  'vix', 'dxy', 'm2', 'marketBreadth', 'signalChanges', 'stockRisk',
  'tradeSignals', 'rotation', 'modelPortfolio', 'weeklyUpdate',
  'usFutures', 'perpPremium', 'fedWatch',
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
  vix: VixTile,
  dxy: DxyTile,
  m2: M2Tile,
  marketBreadth: MarketBreadthTile,
  signalChanges: SignalChangesTile,
  stockRisk: StockRiskTile,
  tradeSignals: TradeSignalsTile,
  rotation: RotationTile,
  modelPortfolio: ModelPortfolioTile,
  weeklyUpdate: WeeklyUpdateTile,
  usFutures: USFuturesTile,
  perpPremium: PerpPremiumTile,
  fedWatch: FedWatchTile,
};

function CustomizePanel({
  isEnabled,
  toggle,
  setAll,
  onClose,
}: {
  isEnabled: (k: string) => boolean;
  toggle: (k: string) => void;
  setAll: (on: boolean) => void;
  onClose: () => void;
}) {
  const enabledCount = widgetKeys.filter(isEnabled).length;
  const { presets, saveCurrent, apply, remove, canSave } = useDashboardPresets('home');
  const [presetName, setPresetName] = useState('');
  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={onClose} />
      <motion.div
        initial={{ x: 24, opacity: 0 }}
        animate={{ x: 0, opacity: 1 }}
        transition={{ duration: 0.25 }}
        className="relative flex h-full w-full max-w-sm flex-col border-l border-ark-divider bg-ark-bg shadow-2xl"
      >
        <div className="flex items-center justify-between border-b border-ark-divider p-4">
          <div>
            <h3 className="font-[family-name:var(--font-urbanist)] text-base font-semibold text-ark-text">Customize Home</h3>
            <p className="text-[11px] text-ark-text-disabled">{enabledCount} of {widgetKeys.length} widgets shown</p>
          </div>
          <button onClick={onClose} className="flex h-8 w-8 items-center justify-center rounded-lg text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary">
            <X className="h-4 w-4" />
          </button>
        </div>

        {/* Presets */}
        <div className="border-b border-ark-divider px-4 py-3">
          <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">Presets</p>
          {presets.length > 0 && (
            <div className="mt-2 space-y-1.5">
              {presets.map((p) => (
                <div key={p.name} className="flex items-center gap-2">
                  <button onClick={() => apply(p.name)} className="flex-1 rounded-lg bg-ark-fill-secondary/50 px-3 py-1.5 text-left text-sm text-ark-text transition-colors hover:bg-ark-fill-secondary">{p.name}</button>
                  <button onClick={() => remove(p.name)} className="flex h-7 w-7 items-center justify-center rounded-lg text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary"><X className="h-3.5 w-3.5" /></button>
                </div>
              ))}
            </div>
          )}
          <div className="mt-2 flex items-center gap-2">
            <input
              value={presetName}
              onChange={(e) => setPresetName(e.target.value)}
              placeholder={canSave ? 'Save current as…' : 'Max 2 presets'}
              disabled={!canSave}
              className="h-8 flex-1 rounded-lg border border-ark-divider bg-ark-fill-secondary px-2.5 text-xs text-ark-text outline-none placeholder:text-ark-text-tertiary focus:border-ark-primary disabled:opacity-50"
            />
            <button
              onClick={() => { saveCurrent(presetName); setPresetName(''); }}
              disabled={!canSave || !presetName.trim()}
              className="rounded-lg bg-ark-primary px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-ark-accent-dark disabled:opacity-40"
            >Save</button>
          </div>
        </div>

        <div className="flex items-center gap-2 border-b border-ark-divider px-4 py-2">
          <button onClick={() => setAll(true)} className="rounded-lg px-2.5 py-1 text-[11px] font-medium text-ark-primary transition-colors hover:bg-ark-fill-secondary">Show all</button>
          <button onClick={() => setAll(false)} className="rounded-lg px-2.5 py-1 text-[11px] font-medium text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary">Hide all</button>
        </div>
        <div className="flex-1 overflow-y-auto p-2">
          {widgetKeys.map((key) => {
            const on = isEnabled(key);
            return (
              <button
                key={key}
                onClick={() => toggle(key)}
                className="flex w-full items-center justify-between rounded-xl px-3 py-2.5 text-left transition-colors hover:bg-ark-fill-secondary"
              >
                <span className={cn('text-sm', on ? 'text-ark-text' : 'text-ark-text-tertiary')}>{drawerTitles[key]}</span>
                <span className={cn('flex h-5 w-9 items-center rounded-full px-0.5 transition-colors', on ? 'justify-end bg-ark-primary' : 'justify-start bg-ark-fill-secondary')}>
                  <span className="flex h-4 w-4 items-center justify-center rounded-full bg-white">
                    {on && <Check className="h-2.5 w-2.5 text-ark-primary" />}
                  </span>
                </span>
              </button>
            );
          })}
        </div>
      </motion.div>
    </div>
  );
}

export function BentoGrid() {
  const [activeWidget, setActiveWidget] = useState<WidgetKey | null>(null);
  const [showCustomize, setShowCustomize] = useState(false);
  const { isEnabled, toggle, setAll } = useWidgetVisibility('home', widgetKeys);
  const { profile } = useAuth();
  const open = (key: WidgetKey) => () => setActiveWidget(key);

  const enabledKeys = widgetKeys.filter(isEnabled);

  const [header, setHeader] = useState<{ greeting: string; date: string }>({ greeting: '', date: '' });
  useEffect(() => {
    const h = new Date().getHours();
    const greeting = h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening';
    const date = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
    setHeader({ greeting, date }); // eslint-disable-line react-hooks/set-state-in-effect
  }, []);
  const name = profile?.full_name?.split(' ')[0] || profile?.username || '';

  return (
    <>
      <div className="mb-4 flex items-end justify-between">
        <div>
          <p suppressHydrationWarning className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">{header.date}</p>
          <h1 suppressHydrationWarning className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">
            {header.greeting || 'Welcome'}{name ? `, ${name}` : ''}
          </h1>
        </div>
        <button
          onClick={() => setShowCustomize(true)}
          className="flex items-center gap-1.5 rounded-lg border border-ark-divider px-3 py-1.5 text-xs font-medium text-ark-text-secondary transition-colors hover:bg-ark-fill-secondary hover:text-ark-text"
        >
          <SlidersHorizontal className="h-3.5 w-3.5" />
          Customize
        </button>
      </div>

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.4 }}
      >
        <DraggableGrid layoutKey="home" defaultLayouts={HOME_DEFAULT_LAYOUTS}>
          {enabledKeys.map((key, i) => {
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

      {showCustomize && (
        <CustomizePanel
          isEnabled={isEnabled}
          toggle={toggle}
          setAll={setAll}
          onClose={() => setShowCustomize(false)}
        />
      )}
    </>
  );
}
