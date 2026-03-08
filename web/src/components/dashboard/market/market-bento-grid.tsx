'use client';

import { useState, useEffect } from 'react';
import {
  Globe, Gauge, Compass, Activity, BarChart3, Target,
  Landmark, Bitcoin, Search, Newspaper, Users, DollarSign,
  ArrowUpRight, ArrowDownRight, TrendingUp, TrendingDown,
} from 'lucide-react';
import { motion } from 'framer-motion';
import { Badge, Skeleton } from '@/components/ui';
import { DetailDrawer } from '@/components/ui/detail-drawer';
import {
  Tile, Spark, MiniGauge, AccentLine, AmbientGlow, ShineSweep,
  useCountUp,
  SkeletonHeroTile, SkeletonGaugeTile, SkeletonSparkTile, SkeletonListTile, SkeletonMacroTile,
} from '../shared/bento-primitives';
import { DraggableGrid, type ResponsiveLayouts } from '../shared/draggable-grid';
import {
  useGlobalMarketData, useFearGreedIndex, useMarketSentiment,
  useMacroIndicators, useRegimeData, useCryptoPositioning,
  useTraditionalMarkets, useCryptoAssets, useAltcoinScanner, useNews,
} from '@/lib/hooks/use-market';
import { formatCurrency, formatPercent, formatNumber, formatRelativeTime, cn } from '@/lib/utils/format';

/* ── Widget keys & drawer titles ── */

type MarketWidgetKey =
  | 'marketOverview' | 'fearGreed' | 'regime' | 'sentiment'
  | 'macro' | 'positioning' | 'tradMarkets' | 'topCoins'
  | 'altcoinScanner' | 'news' | 'retailSentiment' | 'funding';

const drawerTitles: Record<MarketWidgetKey, string> = {
  marketOverview: 'Market Overview',
  fearGreed: 'Fear & Greed Index',
  regime: 'Market Regime',
  sentiment: 'Market Sentiment',
  macro: 'Macro Dashboard',
  positioning: 'Crypto Positioning',
  tradMarkets: 'Traditional Markets',
  topCoins: 'Top Coins',
  altcoinScanner: 'Altcoin Scanner',
  news: 'Headlines',
  retailSentiment: 'Retail Sentiment',
  funding: 'Funding Rates',
};

/* ── Lazy drawer loader ── */

function LazyMarketWidget({ widgetKey }: { widgetKey: MarketWidgetKey }) {
  const [Widget, setWidget] = useState<React.ComponentType | null>(null);

  useEffect(() => {
    let cancelled = false;
    const loaders: Record<MarketWidgetKey, () => Promise<{ default?: React.ComponentType; [k: string]: unknown }>> = {
      marketOverview: () => Promise.resolve({ default: MarketOverviewDetail }),
      fearGreed: () => import('../home/fear-greed-gauge').then(m => ({ default: m.FearGreedGauge })),
      regime: () => import('./market-sentiment').then(m => ({ default: m.MarketSentiment })),
      sentiment: () => import('./market-sentiment').then(m => ({ default: m.MarketSentiment })),
      macro: () => import('../home/macro-dashboard').then(m => ({ default: m.MacroDashboard })),
      positioning: () => import('./crypto-positioning').then(m => ({ default: m.CryptoPositioning })),
      tradMarkets: () => import('./traditional-markets').then(m => ({ default: m.TraditionalMarkets })),
      topCoins: () => import('./top-coins').then(m => ({ default: m.TopCoins })),
      altcoinScanner: () => import('./altcoin-scanner').then(m => ({ default: m.AltcoinScanner })),
      news: () => import('../home/news-card').then(m => ({ default: m.NewsCard })),
      retailSentiment: () => import('./market-sentiment').then(m => ({ default: m.MarketSentiment })),
      funding: () => import('./market-sentiment').then(m => ({ default: m.MarketSentiment })),
    };
    loaders[widgetKey]().then(mod => {
      if (!cancelled) setWidget(() => (mod.default ?? null) as React.ComponentType | null);
    });
    return () => { cancelled = true; };
  }, [widgetKey]);

  if (!Widget) return <Skeleton className="h-64 w-full" />;
  return <Widget />;
}

/* ── Inline detail for Market Overview drawer ── */

function MarketOverviewDetail() {
  const { data: global } = useGlobalMarketData();
  const { data: fng } = useFearGreedIndex();
  const { data: regime } = useRegimeData();

  const stats = [
    { label: 'Total Market Cap', value: global ? formatCurrency(global.total_market_cap, 'USD', { compact: true }) : '—', change: global?.market_cap_change_percentage_24h },
    { label: '24h Volume', value: global ? formatCurrency(global.total_volume, 'USD', { compact: true }) : '—' },
    { label: 'BTC Dominance', value: global ? `${global.btc_dominance.toFixed(1)}%` : '—', sub: global?.eth_dominance !== undefined ? `ETH ${global.eth_dominance.toFixed(1)}%` : undefined },
    { label: 'Fear & Greed', value: fng?.value?.toString() ?? '—', badge: fng?.value_classification },
  ];

  return (
    <div className="space-y-4">
      {regime && (
        <div className={cn(
          'inline-flex items-center gap-1.5 rounded-full px-3 py-1',
          regime.regime === 'risk-on' ? 'bg-ark-success/10' : regime.regime === 'risk-off' ? 'bg-ark-error/10' : 'bg-ark-fill-secondary',
        )}>
          <span className={cn(
            'h-1.5 w-1.5 rounded-full animate-status',
            regime.regime === 'risk-on' ? 'bg-ark-success' : regime.regime === 'risk-off' ? 'bg-ark-error' : 'bg-ark-text-tertiary',
          )} />
          <span className={cn(
            'text-[10px] font-semibold uppercase tracking-wider',
            regime.regime === 'risk-on' ? 'text-ark-success' : regime.regime === 'risk-off' ? 'text-ark-error' : 'text-ark-text-tertiary',
          )}>
            {regime.regime === 'risk-on' ? 'Risk On' : regime.regime === 'risk-off' ? 'Risk Off' : 'Neutral'}
          </span>
        </div>
      )}
      <div className="grid gap-4 sm:grid-cols-2">
        {stats.map((s) => (
          <div key={s.label} className="rounded-xl border border-ark-divider bg-ark-surface px-4 py-4">
            <p className="text-xs font-medium uppercase tracking-wider text-ark-text-tertiary">{s.label}</p>
            <p className="fig mt-2 text-2xl font-bold text-ark-text">{s.value}</p>
            {s.change !== undefined && (
              <p className={cn('fig mt-1 flex items-center gap-0.5 text-sm font-medium',
                s.change >= 0 ? 'text-ark-success' : 'text-ark-error',
              )}>
                {s.change >= 0 ? <ArrowUpRight className="h-3.5 w-3.5" /> : <ArrowDownRight className="h-3.5 w-3.5" />}
                {formatPercent(s.change)}
              </p>
            )}
            {s.sub && <p className="fig mt-1 text-xs text-ark-text-tertiary">{s.sub}</p>}
            {s.badge && <Badge className="mt-1" variant={fng && fng.value > 55 ? 'success' : fng && fng.value < 45 ? 'error' : 'default'}>{s.badge}</Badge>}
          </div>
        ))}
      </div>
    </div>
  );
}

/* ══════════════════════ TILE COMPONENTS ══════════════════════ */

function MarketOverviewTile({ onOpen }: { onOpen: () => void }) {
  const { data: global, isLoading } = useGlobalMarketData();
  const mktCap = global?.total_market_cap ?? 0;
  const change = global?.market_cap_change_percentage_24h ?? 0;
  const isUp = change >= 0;

  const counter = useCountUp(mktCap / 1e12, isLoading, 2);

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonHeroTile /> : (
        <div className="flex h-full gap-4">
          <div className="flex flex-col justify-between flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10 transition-transform duration-300 group-hover:scale-110">
                <Globe className="h-3.5 w-3.5 text-ark-primary" />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Market Overview</span>
            </div>

            <div className="relative">
              <AmbientGlow color="var(--ark-primary)" className="-left-4 -top-2 h-16 w-32" />
              <p className="fig font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text leading-tight relative">
                <span className="opacity-40 font-normal">$</span>
                <span ref={counter.ref}>{counter.value}</span>
                <span className="text-sm opacity-40 font-normal">T</span>
              </p>
              <span className={cn(
                'fig mt-0.5 inline-flex items-center gap-0.5 text-xs font-semibold',
                isUp ? 'text-ark-success' : 'text-ark-error',
              )}>
                {isUp ? <ArrowUpRight className="h-3 w-3" /> : <ArrowDownRight className="h-3 w-3" />}
                {formatPercent(change)} 24h
              </span>
            </div>

            <div className="flex gap-4">
              <div>
                <p className="text-[9px] font-medium uppercase tracking-wider text-ark-text-disabled">24h Vol</p>
                <p className="fig text-sm font-bold text-ark-text">
                  {global ? formatCurrency(global.total_volume, 'USD', { compact: true }) : '—'}
                </p>
              </div>
              <div className="w-px bg-ark-divider" />
              <div>
                <p className="text-[9px] font-medium uppercase tracking-wider text-ark-text-disabled">BTC Dom</p>
                <p className="fig text-sm font-bold text-ark-text">
                  {global ? `${global.btc_dominance.toFixed(1)}%` : '—'}
                </p>
              </div>
            </div>
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

          <div className="flex justify-center">
            <MiniGauge value={value} max={100} color={color} size={80} />
          </div>

          <div className="flex items-end justify-between relative">
            <AmbientGlow color={color} className="-left-2 -bottom-2 h-12 w-20" />
            <span ref={counter.ref} className="fig font-[family-name:var(--font-urbanist)] text-4xl font-bold leading-none relative" style={{ color }}>
              {counter.value}
            </span>
            <span className="text-[10px] text-ark-text-disabled">/ 100</span>
          </div>
        </>
      )}
    </Tile>
  );
}

function RegimeTile({ onOpen }: { onOpen: () => void }) {
  const { data: regime, isLoading: regimeLoading } = useRegimeData();
  const { data: pos, isLoading: posLoading } = useCryptoPositioning();
  const isLoading = regimeLoading || posLoading;
  const regimeLabel = regime?.regime === 'risk-on' ? 'Risk On' : regime?.regime === 'risk-off' ? 'Risk Off' : 'Neutral';
  const color = regime?.regime === 'risk-on' ? 'var(--ark-success)' : regime?.regime === 'risk-off' ? 'var(--ark-error)' : 'var(--ark-text-tertiary)';
  const variant: 'success' | 'error' | 'default' = regime?.regime === 'risk-on' ? 'success' : regime?.regime === 'risk-off' ? 'error' : 'default';
  const growth = pos?.growth_score ?? 50;
  const inflation = pos?.inflation_score ?? 50;

  return (
    <Tile onClick={onOpen} accentColor={color}>
      <AccentLine color={color} />
      {isLoading ? <SkeletonGaugeTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg transition-transform duration-300 group-hover:scale-110" style={{ backgroundColor: `${color}15` }}>
                <Compass className="h-3.5 w-3.5" style={{ color }} />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Regime</span>
            </div>
            <Badge variant={variant}>{regimeLabel}</Badge>
          </div>

          <div className="flex items-center gap-1.5">
            <span className="h-2 w-2 rounded-full animate-status" style={{ backgroundColor: color }} />
            <span className="font-[family-name:var(--font-urbanist)] text-lg font-bold" style={{ color }}>
              {regimeLabel}
            </span>
          </div>

          <div className="space-y-1.5">
            <div>
              <div className="flex items-center justify-between text-[9px] text-ark-text-disabled mb-0.5">
                <span>Growth</span>
                <span className="fig font-semibold">{growth.toFixed(0)}</span>
              </div>
              <div className="h-1 overflow-hidden rounded-full bg-ark-fill-secondary">
                <div className="h-full rounded-full bg-ark-success transition-all duration-500" style={{ width: `${growth}%` }} />
              </div>
            </div>
            <div>
              <div className="flex items-center justify-between text-[9px] text-ark-text-disabled mb-0.5">
                <span>Inflation</span>
                <span className="fig font-semibold">{inflation.toFixed(0)}</span>
              </div>
              <div className="h-1 overflow-hidden rounded-full bg-ark-fill-secondary">
                <div className="h-full rounded-full bg-ark-warning transition-all duration-500" style={{ width: `${inflation}%` }} />
              </div>
            </div>
          </div>
        </>
      )}
    </Tile>
  );
}

function SentimentTile({ onOpen }: { onOpen: () => void }) {
  const { data: sent, isLoading } = useMarketSentiment();
  const score = sent?.risk_score ?? 0;
  const seasonIdx = sent?.season_index ?? 50;
  const season = sent?.season ?? 'bitcoin';
  const sparkData = sent?.market_cap_sparkline ?? [];
  const color = score < 30 ? 'var(--ark-success)' : score < 50 ? 'var(--ark-warning)' : score < 70 ? '#F97316' : 'var(--ark-error)';

  const counter = useCountUp(score, isLoading);

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonSparkTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10 transition-transform duration-300 group-hover:scale-110">
                <Activity className="h-3.5 w-3.5 text-ark-primary" />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Sentiment</span>
            </div>
            <Badge variant={season === 'altcoin' ? 'info' : 'default'}>
              {season === 'altcoin' ? 'Alt Season' : 'BTC Season'}
            </Badge>
          </div>

          <div className="flex items-end justify-between relative">
            <AmbientGlow color={color} className="-left-2 -bottom-2 h-12 w-20" />
            <div className="relative">
              <p className="text-[9px] font-medium uppercase tracking-wider text-ark-text-disabled">ArkLine Score</p>
              <span ref={counter.ref} className="fig font-[family-name:var(--font-urbanist)] text-3xl font-bold leading-none" style={{ color }}>
                {counter.value}
              </span>
              <span className="text-[10px] text-ark-text-disabled ml-0.5">/ 100</span>
            </div>
            <div className="w-24 h-7">
              {sparkData.length > 2 && <Spark data={sparkData} color="var(--ark-primary)" className="h-7" />}
            </div>
          </div>

          {/* Season bar */}
          <div>
            <div className="flex items-center justify-between text-[9px] text-ark-text-disabled mb-0.5">
              <span>BTC</span>
              <span className="fig font-semibold">{seasonIdx.toFixed(0)}</span>
              <span>ALT</span>
            </div>
            <div className="h-1 overflow-hidden rounded-full bg-ark-fill-secondary">
              <div className="h-full rounded-full bg-gradient-to-r from-[#F7931A] to-ark-primary transition-all duration-500" style={{ width: `${seasonIdx}%` }} />
            </div>
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
                <BarChart3 className="h-3.5 w-3.5 text-ark-success" />
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

function PositioningTile({ onOpen }: { onOpen: () => void }) {
  const { data: pos, isLoading } = useCryptoPositioning();
  const regimeLabel = pos?.regime_label ?? '';
  const assets = pos?.assets ?? [];
  const top3 = assets.slice(0, 3);

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-primary)">
      <AccentLine color="var(--ark-primary)" />
      {isLoading ? <SkeletonListTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-primary/10 transition-transform duration-300 group-hover:scale-110">
                <Target className="h-3.5 w-3.5 text-ark-primary" />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Positioning</span>
            </div>
          </div>

          {regimeLabel && (
            <p className="text-[10px] font-semibold text-ark-text-secondary truncate">{regimeLabel}</p>
          )}

          <div className="space-y-1.5">
            {top3.map((a) => {
              const signalColor = a.signal === 'bullish' ? 'text-ark-success' : a.signal === 'bearish' ? 'text-ark-error' : 'text-ark-primary';
              const signalBg = a.signal === 'bullish' ? 'bg-ark-success/10' : a.signal === 'bearish' ? 'bg-ark-error/10' : 'bg-ark-primary/10';
              return (
                <div key={a.symbol} className="flex items-center gap-2 rounded-lg bg-ark-fill-secondary/40 px-2 py-1">
                  <span className="text-[10px] font-bold text-ark-text w-8">{a.symbol}</span>
                  <span className={cn('rounded-full px-1.5 py-0.5 text-[8px] font-bold uppercase', signalBg, signalColor)}>
                    {a.signal}
                  </span>
                  <span className="flex-1" />
                  <span className="fig text-[10px] font-bold text-ark-text">{a.target_allocation}%</span>
                </div>
              );
            })}
          </div>
        </>
      )}
    </Tile>
  );
}

function TradMarketsTile({ onOpen }: { onOpen: () => void }) {
  const { data: assets, isLoading } = useTraditionalMarkets();
  const top3 = (assets ?? []).slice(0, 3);

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-info)">
      <AccentLine color="var(--ark-info)" />
      {isLoading ? <SkeletonListTile /> : (
        <>
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-info/10 transition-transform duration-300 group-hover:scale-110">
              <Landmark className="h-3.5 w-3.5 text-ark-info" />
            </div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Trad Markets</span>
          </div>
          <div className="space-y-1.5">
            {top3.map((asset) => {
              const isUp = (asset.price_change_percentage_24h ?? 0) >= 0;
              const sparkData = asset.sparkline ?? [];
              return (
                <div key={asset.id} className="flex items-center gap-2 rounded-lg bg-ark-fill-secondary/40 px-2 py-1">
                  <span className="text-[10px] font-bold text-ark-text w-8">{asset.symbol}</span>
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
        </>
      )}
    </Tile>
  );
}

function TopCoinsTile({ onOpen }: { onOpen: () => void }) {
  const { data: assets, isLoading } = useCryptoAssets(1);
  const movers = (assets ?? []).filter((a) => ['bitcoin', 'ethereum', 'solana'].includes(a.id));
  const coinColors: Record<string, string> = { btc: '#F7931A', eth: '#627EEA', sol: '#9945FF' };

  return (
    <Tile onClick={onOpen} accentColor="#F7931A">
      <AccentLine color="#F7931A" />
      {isLoading ? <SkeletonListTile /> : (
        <>
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-[#F7931A]/10 transition-transform duration-300 group-hover:scale-110">
              <Bitcoin className="h-3.5 w-3.5 text-[#F7931A]" />
            </div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Top Coins</span>
          </div>
          <div className="space-y-1.5">
            {movers.map((asset) => {
              const isUp = (asset.price_change_percentage_24h ?? 0) >= 0;
              const accent = coinColors[asset.symbol.toLowerCase()] ?? 'var(--ark-primary)';
              return (
                <div key={asset.id} className="flex items-center gap-2">
                  <div className="flex h-5 w-5 shrink-0 items-center justify-center rounded-full text-[7px] font-bold text-white"
                    style={{ backgroundColor: accent }}>
                    {asset.symbol.toUpperCase().slice(0, 3)}
                  </div>
                  <span className="text-[10px] font-bold text-ark-text flex-1">{asset.symbol.toUpperCase()}</span>
                  <span className="fig text-[10px] font-bold text-ark-text">{formatCurrency(asset.current_price)}</span>
                  <span className={cn('fig text-[9px] font-semibold', isUp ? 'text-ark-success' : 'text-ark-error')}>
                    {formatPercent(asset.price_change_percentage_24h ?? 0)}
                  </span>
                </div>
              );
            })}
          </div>
        </>
      )}
    </Tile>
  );
}

function AltcoinScannerTile({ onOpen }: { onOpen: () => void }) {
  const { data: alts, isLoading } = useAltcoinScanner();
  const top3 = (alts ?? []).slice(0, 3);

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-violet)">
      <AccentLine color="var(--ark-violet)" />
      {isLoading ? <SkeletonListTile /> : (
        <>
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-violet/10 transition-transform duration-300 group-hover:scale-110">
              <Search className="h-3.5 w-3.5 text-ark-violet" />
            </div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Alt Scanner</span>
          </div>
          <div className="space-y-1.5">
            {top3.map((alt) => {
              const isUp = alt.return_7d >= 0;
              return (
                <div key={alt.id} className="flex items-center gap-2 rounded-lg bg-ark-fill-secondary/40 px-2 py-1">
                  {alt.image ? (
                    <img src={alt.image} alt={alt.name} className="h-5 w-5 rounded-full" />
                  ) : (
                    <div className="flex h-5 w-5 items-center justify-center rounded-full bg-ark-violet/15 text-[8px] font-bold text-ark-violet uppercase">
                      {alt.symbol.slice(0, 2)}
                    </div>
                  )}
                  <span className="text-[10px] font-bold text-ark-text">{alt.symbol.toUpperCase()}</span>
                  <span className="flex-1" />
                  <span className={cn('fig text-[10px] font-semibold', isUp ? 'text-ark-success' : 'text-ark-error')}>
                    {formatPercent(alt.return_7d)} 7d
                  </span>
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
  const { data: news, isLoading } = useNews(6);
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

function RetailSentimentTile({ onOpen }: { onOpen: () => void }) {
  const { data: sent, isLoading } = useMarketSentiment();
  const retail = sent?.retail_sentiment;
  const cbRank = retail?.coinbase_rank;
  const searchIdx = retail?.btc_search_index ?? 0;

  const counter = useCountUp(searchIdx, isLoading);

  return (
    <Tile onClick={onOpen} accentColor="var(--ark-warning)">
      <AccentLine color="var(--ark-warning)" />
      {isLoading ? <SkeletonSparkTile /> : (
        <>
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-ark-warning/10 transition-transform duration-300 group-hover:scale-110">
              <Users className="h-3.5 w-3.5 text-ark-warning" />
            </div>
            <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Retail</span>
          </div>

          <div className="space-y-2">
            <div>
              <p className="text-[9px] font-medium uppercase tracking-wider text-ark-text-disabled">Coinbase Rank</p>
              <div className="flex items-baseline gap-1.5">
                <span className="fig font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">
                  #{cbRank ?? '>200'}
                </span>
                {retail?.coinbase_rank_change !== undefined && retail.coinbase_rank_change !== 0 && (
                  <span className={cn('fig text-[10px] font-semibold flex items-center gap-0.5',
                    retail.coinbase_rank_change < 0 ? 'text-ark-success' : 'text-ark-error',
                  )}>
                    {retail.coinbase_rank_change < 0 ? <TrendingUp className="h-2.5 w-2.5" /> : <TrendingDown className="h-2.5 w-2.5" />}
                    {Math.abs(retail.coinbase_rank_change)}
                  </span>
                )}
              </div>
            </div>
            <div>
              <p className="text-[9px] font-medium uppercase tracking-wider text-ark-text-disabled">BTC Search Index</p>
              <span ref={counter.ref} className="fig text-lg font-bold text-ark-text">{counter.value}</span>
              <span className="text-[10px] text-ark-text-disabled ml-0.5">/ 100</span>
            </div>
          </div>
        </>
      )}
    </Tile>
  );
}

function FundingTile({ onOpen }: { onOpen: () => void }) {
  const { data: sent, isLoading } = useMarketSentiment();
  const funding = sent?.funding_rate;
  const rate = funding?.rate ?? 0;
  const annualized = funding?.annualized_rate ?? 0;
  const sentiment = funding?.sentiment ?? 'Neutral';
  const color = rate > 0.01 ? 'var(--ark-success)' : rate < -0.01 ? 'var(--ark-error)' : 'var(--ark-text-tertiary)';
  const variant: 'success' | 'error' | 'default' = rate > 0.01 ? 'success' : rate < -0.01 ? 'error' : 'default';

  return (
    <Tile onClick={onOpen} accentColor={color}>
      <AccentLine color={color} />
      {isLoading ? <SkeletonSparkTile /> : (
        <>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="flex h-7 w-7 items-center justify-center rounded-lg transition-transform duration-300 group-hover:scale-110" style={{ backgroundColor: `${color}15` }}>
                <DollarSign className="h-3.5 w-3.5" style={{ color }} />
              </div>
              <span className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">Funding</span>
            </div>
            <Badge variant={variant}>{sentiment}</Badge>
          </div>

          <div className="relative">
            <AmbientGlow color={color} className="-left-2 -bottom-2 h-12 w-20" />
            <p className="text-[9px] font-medium uppercase tracking-wider text-ark-text-disabled">Funding Rate</p>
            <span className="fig font-[family-name:var(--font-urbanist)] text-3xl font-bold leading-none relative" style={{ color }}>
              {(rate * 100).toFixed(4)}%
            </span>
          </div>

          <div>
            <p className="text-[9px] font-medium uppercase tracking-wider text-ark-text-disabled">Annualized</p>
            <span className={cn('fig text-sm font-bold', annualized >= 0 ? 'text-ark-success' : 'text-ark-error')}>
              {formatPercent(annualized, 1)}
            </span>
            {funding?.exchange && (
              <span className="text-[9px] text-ark-text-disabled ml-1.5">{funding.exchange}</span>
            )}
          </div>
        </>
      )}
    </Tile>
  );
}

/* ══════════════════════ BENTO GRID ══════════════════════ */

// rowHeight = 80px. h:2 = 168px (compact), h:3 = 248px (hero)
const MARKET_DEFAULT_LAYOUTS: ResponsiveLayouts = {
  lg: [
    { i: 'marketOverview',  x: 0, y: 0,  w: 2, h: 3, minW: 2, minH: 2, maxW: 4, maxH: 6 },
    { i: 'fearGreed',       x: 2, y: 0,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'regime',          x: 3, y: 0,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'sentiment',       x: 0, y: 3,  w: 2, h: 3, minW: 2, minH: 2, maxW: 4, maxH: 6 },
    { i: 'macro',           x: 2, y: 3,  w: 2, h: 3, minW: 2, minH: 2, maxW: 4, maxH: 6 },
    { i: 'positioning',     x: 0, y: 6,  w: 2, h: 3, minW: 2, minH: 2, maxW: 4, maxH: 6 },
    { i: 'tradMarkets',     x: 2, y: 6,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'topCoins',        x: 3, y: 6,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'altcoinScanner',  x: 0, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'news',            x: 1, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'retailSentiment', x: 2, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
    { i: 'funding',         x: 3, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 4, maxH: 6 },
  ],
  md: [
    { i: 'marketOverview',  x: 0, y: 0,  w: 2, h: 3, minW: 2, minH: 2, maxW: 3, maxH: 6 },
    { i: 'fearGreed',       x: 2, y: 0,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'regime',          x: 0, y: 3,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'sentiment',       x: 1, y: 3,  w: 2, h: 3, minW: 2, minH: 2, maxW: 3, maxH: 6 },
    { i: 'macro',           x: 0, y: 6,  w: 2, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'positioning',     x: 2, y: 6,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'tradMarkets',     x: 0, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'topCoins',        x: 1, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'altcoinScanner',  x: 2, y: 9,  w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'news',            x: 0, y: 12, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'retailSentiment', x: 1, y: 12, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
    { i: 'funding',         x: 2, y: 12, w: 1, h: 3, minW: 1, minH: 2, maxW: 3, maxH: 6 },
  ],
  sm: [
    { i: 'marketOverview',  x: 0, y: 0,  w: 2, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'fearGreed',       x: 0, y: 3,  w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'regime',          x: 1, y: 3,  w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'sentiment',       x: 0, y: 6,  w: 2, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'macro',           x: 0, y: 9,  w: 2, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'positioning',     x: 0, y: 12, w: 2, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'tradMarkets',     x: 0, y: 15, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'topCoins',        x: 1, y: 15, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'altcoinScanner',  x: 0, y: 18, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'news',            x: 1, y: 18, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'retailSentiment', x: 0, y: 21, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
    { i: 'funding',         x: 1, y: 21, w: 1, h: 3, minW: 1, minH: 2, maxW: 2, maxH: 6 },
  ],
};

const widgetKeys: MarketWidgetKey[] = [
  'marketOverview', 'fearGreed', 'regime', 'sentiment', 'macro',
  'positioning', 'tradMarkets', 'topCoins', 'altcoinScanner',
  'news', 'retailSentiment', 'funding',
];

const tileComponents: Record<MarketWidgetKey, React.ComponentType<{ onOpen: () => void }>> = {
  marketOverview: MarketOverviewTile,
  fearGreed: FearGreedTile,
  regime: RegimeTile,
  sentiment: SentimentTile,
  macro: MacroTile,
  positioning: PositioningTile,
  tradMarkets: TradMarketsTile,
  topCoins: TopCoinsTile,
  altcoinScanner: AltcoinScannerTile,
  news: NewsTile,
  retailSentiment: RetailSentimentTile,
  funding: FundingTile,
};

export function MarketBentoGrid() {
  const [activeWidget, setActiveWidget] = useState<MarketWidgetKey | null>(null);
  const open = (key: MarketWidgetKey) => () => setActiveWidget(key);

  return (
    <>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ duration: 0.4 }}
      >
        <DraggableGrid layoutKey="market" defaultLayouts={MARKET_DEFAULT_LAYOUTS}>
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
        {activeWidget && <LazyMarketWidget widgetKey={activeWidget} />}
      </DetailDrawer>
    </>
  );
}
