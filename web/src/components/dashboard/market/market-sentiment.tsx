'use client';

import { Activity, TrendingUp, TrendingDown, Bitcoin, BarChart2, Users, Landmark, ChevronRight } from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer } from 'recharts';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { useMarketSentiment } from '@/lib/hooks/use-market';
import { formatCurrency, cn } from '@/lib/utils/format';
import type { SentimentRegimeType, AssetRiskLevel } from '@/types';

/* ── Helpers ── */

const regimeConfig: Record<SentimentRegimeType, { color: string; icon: string; bgColor: string }> = {
  Panic: { color: 'text-ark-error', icon: '🔥', bgColor: 'bg-ark-error/10' },
  FOMO: { color: 'text-ark-success', icon: '🚀', bgColor: 'bg-ark-success/10' },
  Apathy: { color: 'text-ark-text-tertiary', icon: '💤', bgColor: 'bg-ark-fill-secondary' },
  Complacency: { color: 'text-ark-violet', icon: '😌', bgColor: 'bg-ark-violet/10' },
};

function riskGaugeColor(level: number): string {
  if (level < 0.2) return 'var(--ark-success)';
  if (level < 0.4) return 'var(--ark-success)';
  if (level < 0.55) return 'var(--ark-warning)';
  if (level < 0.7) return '#F97316';
  return 'var(--ark-error)';
}

function CircularGauge({ value, max, color, size = 64 }: { value: number; max: number; color: string; size?: number }) {
  const pct = Math.min(value / max, 1);
  const r = (size - 8) / 2;
  const circ = 2 * Math.PI * r;
  const dashOffset = circ * (1 - pct * 0.75); // 270-degree arc
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} className="rotate-[135deg]">
      <circle
        cx={size / 2} cy={size / 2} r={r}
        fill="none" stroke="var(--ark-divider)" strokeWidth={6}
        strokeDasharray={`${circ * 0.75} ${circ * 0.25}`}
        strokeLinecap="round"
      />
      <circle
        cx={size / 2} cy={size / 2} r={r}
        fill="none" stroke={color} strokeWidth={6}
        strokeDasharray={`${circ * 0.75} ${circ * 0.25}`}
        strokeDashoffset={dashOffset}
        strokeLinecap="round"
        className="transition-all duration-700"
      />
    </svg>
  );
}

function RiskGaugeCard({ asset }: { asset: AssetRiskLevel }) {
  const color = riskGaugeColor(asset.risk_level);
  return (
    <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-4 transition-colors hover:border-ark-text-disabled/30">
      <div className="flex items-center justify-between">
        <p className="text-xs font-medium text-ark-text-tertiary">{asset.symbol} Risk Level</p>
        <TrendingUp className="h-3.5 w-3.5 text-ark-text-disabled" />
      </div>
      <div className="mt-2 flex items-center justify-between">
        <div>
          <p className="fig text-2xl font-bold" style={{ color }}>{asset.risk_level.toFixed(3)}</p>
          <div className="mt-0.5 flex items-center gap-1.5">
            <span className="h-2 w-2 rounded-full" style={{ backgroundColor: color }} />
            <span className="text-xs font-medium" style={{ color }}>{asset.risk_category}</span>
          </div>
          <p className="mt-1 text-[10px] text-ark-text-disabled">{asset.days_at_level} days at this level</p>
        </div>
        <CircularGauge value={asset.risk_level} max={1} color={color} size={56} />
      </div>
    </div>
  );
}

/* ── Regime Quadrant ── */

function RegimeQuadrant({ trajectory, emotionScore, engagementScore }: {
  trajectory: { emotion_score: number; engagement_score: number; regime: SentimentRegimeType }[];
  emotionScore: number;
  engagementScore: number;
}) {
  return (
    <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-5">
      <h4 className="mb-4 text-sm font-semibold text-ark-text">Regime Quadrant</h4>
      <div className="relative aspect-square w-full max-w-[280px] mx-auto">
        {/* Background quadrants */}
        <div className="absolute inset-0 grid grid-cols-2 grid-rows-2 rounded-lg overflow-hidden">
          <div className="bg-ark-error/8 flex items-start justify-center pt-2">
            <span className="text-[10px] font-bold uppercase tracking-wider text-ark-error/60">Panic</span>
          </div>
          <div className="bg-ark-success/5 flex items-start justify-center pt-2">
            <span className="text-[10px] font-bold uppercase tracking-wider text-ark-success/60">FOMO</span>
          </div>
          <div className="bg-ark-fill-secondary/50 flex items-end justify-center pb-2">
            <span className="text-[10px] font-bold uppercase tracking-wider text-ark-text-disabled">Apathy</span>
          </div>
          <div className="bg-ark-violet/5 flex items-end justify-center pb-2">
            <span className="text-[10px] font-bold uppercase tracking-wider text-ark-violet/60">Complacency</span>
          </div>
        </div>
        {/* Crosshairs */}
        <div className="absolute left-1/2 top-0 h-full w-px border-l border-dashed border-ark-divider" />
        <div className="absolute top-1/2 left-0 w-full h-px border-t border-dashed border-ark-divider" />
        {/* Trajectory dots */}
        {trajectory.map((pt, i) => {
          const x = (pt.emotion_score / 100) * 100;
          const y = (1 - pt.engagement_score / 100) * 100;
          const isNow = i === trajectory.length - 1;
          return (
            <div
              key={i}
              className={cn(
                'absolute rounded-full transition-all',
                isNow ? 'h-3.5 w-3.5 border-2 border-ark-primary bg-ark-primary' : 'h-2 w-2 bg-ark-primary/40',
              )}
              style={{ left: `${x}%`, top: `${y}%`, transform: 'translate(-50%,-50%)' }}
            />
          );
        })}
        {/* Trajectory lines */}
        <svg className="absolute inset-0 w-full h-full pointer-events-none">
          {trajectory.slice(1).map((pt, i) => {
            const prev = trajectory[i];
            const x1 = (prev.emotion_score / 100) * 100;
            const y1 = (1 - prev.engagement_score / 100) * 100;
            const x2 = (pt.emotion_score / 100) * 100;
            const y2 = (1 - pt.engagement_score / 100) * 100;
            return (
              <line
                key={i}
                x1={`${x1}%`} y1={`${y1}%`}
                x2={`${x2}%`} y2={`${y2}%`}
                stroke="var(--ark-primary)"
                strokeWidth={1.5}
                strokeOpacity={0.5}
              />
            );
          })}
        </svg>
        {/* Axis labels */}
        <span className="absolute -left-0.5 top-1/2 -translate-y-1/2 -rotate-90 text-[9px] font-medium text-ark-text-disabled whitespace-nowrap">High Vol</span>
        <span className="absolute -left-0.5 bottom-1 text-[9px] font-medium text-ark-text-disabled">Low Vol</span>
        <span className="absolute bottom-[-18px] left-0 text-[9px] font-medium text-ark-text-disabled">Fear</span>
        <span className="absolute bottom-[-18px] right-0 text-[9px] font-medium text-ark-text-disabled">Greed</span>
      </div>
    </div>
  );
}

/* ── Main Component ── */

export function MarketSentiment() {
  const { data, isLoading } = useMarketSentiment();

  if (isLoading) {
    return (
      <div className="space-y-6">
        <GlassCard><Skeleton className="h-6 w-40" /><Skeleton className="mt-4 h-48 w-full" /></GlassCard>
        <GlassCard><Skeleton className="h-6 w-40" /><Skeleton className="mt-4 h-64 w-full" /></GlassCard>
      </div>
    );
  }

  if (!data) return null;

  const regime = regimeConfig[data.sentiment_regime];
  const isBtcSeason = data.season === 'bitcoin';
  const sparkData = data.market_cap_sparkline.map((v, i) => ({ i, v }));

  return (
    <div className="space-y-6">
      {/* ── Header + Overall Market ── */}
      <GlassCard className="relative overflow-hidden p-6">
        <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-warning/20 to-transparent" />

        <div className="mb-5 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-warning/10">
              <Activity className="h-5 w-5 text-ark-warning" />
            </div>
            <div>
              <h3 className="text-base font-semibold text-ark-text">Market Sentiment</h3>
              <p className="text-xs text-ark-text-disabled">Upd: {new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</p>
            </div>
          </div>
          <Badge variant={data.risk_score <= 40 ? 'success' : data.risk_score <= 60 ? 'warning' : 'error'}>
            {data.risk_score <= 30 ? 'Bearish' : data.risk_score <= 60 ? 'Neutral' : 'Bullish'}
          </Badge>
        </div>

        {/* Section: Overall Market */}
        <div className="mb-5 flex items-center gap-2">
          <TrendingUp className="h-4 w-4 text-ark-text-secondary" />
          <h4 className="text-sm font-semibold text-ark-text">Overall Market</h4>
        </div>

        <div className="grid grid-cols-2 gap-4">
          {/* ArkLine Score */}
          <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-4">
            <div className="flex items-center justify-between">
              <p className="text-xs font-medium text-ark-text-tertiary">ArkLine Score</p>
              <span className="text-xs text-ark-text-disabled">✦</span>
            </div>
            <div className="mt-2 flex items-end justify-between">
              <div>
                <p className={cn('fig text-3xl font-bold', data.risk_score <= 40 ? 'text-ark-error' : data.risk_score <= 60 ? 'text-ark-warning' : 'text-ark-success')}>
                  {data.risk_score}
                </p>
                <p className="text-xs text-ark-text-tertiary">
                  {data.risk_score <= 25 ? 'Very Bearish' : data.risk_score <= 40 ? 'Bearish' : data.risk_score <= 60 ? 'Neutral' : 'Bullish'}
                </p>
              </div>
              <CircularGauge value={data.risk_score} max={100} color={data.risk_score <= 40 ? 'var(--ark-primary)' : data.risk_score <= 60 ? 'var(--ark-warning)' : 'var(--ark-success)'} />
            </div>
          </div>

          {/* Fear & Greed */}
          <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-4">
            <p className="text-xs font-medium text-ark-text-tertiary">Fear & Greed</p>
            <div className="mt-2 flex items-end justify-between">
              <div>
                <p className={cn('fig text-3xl font-bold', data.fear_greed <= 25 ? 'text-ark-error' : data.fear_greed <= 45 ? 'text-ark-warning' : data.fear_greed <= 55 ? 'text-ark-text' : 'text-ark-success')}>
                  {data.fear_greed}
                </p>
                <p className="text-xs text-ark-text-tertiary">{data.fear_greed_label}</p>
              </div>
              <CircularGauge value={data.fear_greed} max={100} color={data.fear_greed <= 25 ? 'var(--ark-error)' : data.fear_greed <= 50 ? 'var(--ark-warning)' : 'var(--ark-success)'} />
            </div>
          </div>

          {/* Season Indicator */}
          <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-4">
            <div className="flex items-center justify-between">
              <p className="text-xs font-medium text-ark-text-tertiary">Season Indicator</p>
              <span className="rounded bg-ark-fill-secondary px-1.5 py-0.5 text-[9px] font-semibold text-ark-text-disabled">30d</span>
            </div>
            <div className="mt-2 flex items-center gap-2">
              <Bitcoin className={cn('h-4 w-4', isBtcSeason ? 'text-[#F7931A]' : 'text-[#627EEA]')} />
              <p className="text-sm font-bold text-ark-text">
                {isBtcSeason ? 'BTC Leaning' : 'ALT Leaning'}
              </p>
            </div>
            <div className="mt-2.5">
              <div className="h-2 overflow-hidden rounded-full bg-ark-fill-secondary">
                <div
                  className="h-full rounded-full bg-ark-primary transition-all"
                  style={{ width: `${data.season_index}%` }}
                />
              </div>
              <div className="mt-1 flex justify-between text-[10px] text-ark-text-disabled">
                <span>BTC</span>
                <span className="fig font-semibold text-ark-text-secondary">{data.season_index}/100</span>
                <span>ALT</span>
              </div>
            </div>
          </div>

          {/* Market Cap */}
          <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-4">
            <p className="text-xs font-medium text-ark-text-tertiary">Market Cap</p>
            <div className="mt-2 flex items-end justify-between">
              <div>
                <p className="fig text-xl font-bold text-ark-text">
                  {formatCurrency(data.total_market_cap, 'USD', { compact: true })}
                </p>
                <p className={cn('fig mt-0.5 flex items-center gap-0.5 text-xs font-medium', data.market_cap_change >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                  {data.market_cap_change >= 0 ? <TrendingUp className="h-3 w-3" /> : <TrendingDown className="h-3 w-3" />}
                  {data.market_cap_change.toFixed(2)}%
                </p>
              </div>
              <div className="h-10 w-20">
                {sparkData.length > 1 && (
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={sparkData}>
                      <Area type="monotone" dataKey="v" stroke={data.market_cap_change >= 0 ? 'var(--ark-success)' : 'var(--ark-error)'} strokeWidth={1.5} fill="transparent" dot={false} />
                    </AreaChart>
                  </ResponsiveContainer>
                )}
              </div>
            </div>
          </div>

          {/* BTC Dominance */}
          <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-4">
            <p className="text-xs font-medium text-ark-text-tertiary">BTC Dominance</p>
            <p className="fig mt-2 text-2xl font-bold text-ark-text">{data.btc_dominance.toFixed(2)}%</p>
            <p className={cn('fig mt-0.5 flex items-center gap-0.5 text-xs font-medium', data.btc_dominance_change >= 0 ? 'text-ark-success' : 'text-ark-error')}>
              {data.btc_dominance_change >= 0 ? '↑' : '↓'} {Math.abs(data.btc_dominance_change).toFixed(2)}%
            </p>
          </div>

          {/* Sentiment Regime */}
          <div className={cn('rounded-xl border border-ark-divider p-4', regime.bgColor)}>
            <div className="flex items-center justify-between">
              <p className="text-xs font-medium text-ark-text-tertiary">Sentiment Regime</p>
              <span className="text-lg">{regime.icon}</span>
            </div>
            <p className={cn('mt-1 text-xl font-bold', regime.color)}>{data.sentiment_regime}</p>
            <p className="fig mt-0.5 text-xs text-ark-text-tertiary">Emotion: {data.emotion_score}</p>
          </div>
        </div>
      </GlassCard>

      {/* ── Sentiment Regime Detail ── */}
      <GlassCard className="p-6">
        <div className={cn('rounded-xl p-5', regime.bgColor)}>
          <div className="flex items-center gap-3">
            <span className="text-3xl">{regime.icon}</span>
            <div>
              <h4 className={cn('text-xl font-bold', regime.color)}>{data.sentiment_regime}</h4>
              <p className="mt-1 text-sm leading-relaxed text-ark-text-tertiary">
                {data.sentiment_regime_description}
              </p>
            </div>
          </div>
          <div className="mt-4 grid grid-cols-2 gap-3">
            <div className="rounded-lg bg-ark-card/50 px-4 py-3 text-center">
              <p className="fig text-2xl font-bold text-ark-text">{data.emotion_score}</p>
              <p className="text-xs text-ark-text-tertiary">Emotion</p>
            </div>
            <div className="rounded-lg bg-ark-card/50 px-4 py-3 text-center">
              <p className="fig text-2xl font-bold text-ark-text">{data.engagement_score}</p>
              <p className="text-xs text-ark-text-tertiary">Engagement</p>
            </div>
          </div>
        </div>

        {/* Quadrant + Trajectory */}
        <div className="mt-6 grid gap-5 lg:grid-cols-2">
          <RegimeQuadrant
            trajectory={data.regime_trajectory}
            emotionScore={data.emotion_score}
            engagementScore={data.engagement_score}
          />

          <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-5">
            <h4 className="mb-3 text-sm font-semibold text-ark-text">Trajectory</h4>
            <div className="space-y-3">
              {[
                { label: 'Now', idx: data.regime_trajectory.length - 1 },
                { label: '1 Week Ago', idx: data.regime_trajectory.length - 2 },
                { label: '1 Month Ago', idx: data.regime_trajectory.length - 3 },
                { label: '3 Months Ago', idx: data.regime_trajectory.length - 4 },
              ].map((item) => {
                const pt = data.regime_trajectory[item.idx];
                if (!pt) return null;
                const rc = regimeConfig[pt.regime];
                return (
                  <div key={item.label} className="flex items-center gap-3">
                    <span className={cn('h-2.5 w-2.5 rounded-full', rc.color === 'text-ark-error' ? 'bg-ark-error' : rc.color === 'text-ark-success' ? 'bg-ark-success' : rc.color === 'text-ark-violet' ? 'bg-ark-violet' : 'bg-ark-primary')} />
                    <span className="flex-1 text-sm font-medium text-ark-text">{item.label}</span>
                    <Badge variant={pt.regime === 'Panic' ? 'error' : pt.regime === 'FOMO' ? 'success' : pt.regime === 'Complacency' ? 'info' : 'default'}>
                      {pt.regime}
                    </Badge>
                    <span className="w-16 text-right text-xs text-ark-text-disabled">
                      {new Date(pt.date).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                    </span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </GlassCard>

      {/* ── Asset Risk Levels ── */}
      <GlassCard className="p-6">
        <div className="mb-4 flex items-center gap-2">
          <TrendingUp className="h-4 w-4 text-ark-text-secondary" />
          <h4 className="text-sm font-semibold text-ark-text">Asset Risk Levels</h4>
        </div>
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
          {data.asset_risk_levels.map((asset) => (
            <RiskGaugeCard key={asset.symbol} asset={asset} />
          ))}
        </div>
      </GlassCard>

      {/* ── Retail Sentiment + Institutional ── */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Retail Sentiment */}
        <GlassCard className="p-6">
          <div className="mb-4 flex items-center gap-2">
            <Users className="h-4 w-4 text-ark-text-secondary" />
            <h4 className="text-sm font-semibold text-ark-text">Retail Sentiment</h4>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-4">
              <div className="flex items-center justify-between">
                <p className="text-xs font-medium text-ark-text-tertiary">Coinbase iOS</p>
                <ChevronRight className="h-3.5 w-3.5 text-ark-text-disabled" />
              </div>
              <p className="fig mt-2 text-2xl font-bold text-ark-text">
                {data.retail_sentiment.coinbase_rank ? `#${data.retail_sentiment.coinbase_rank}` : '>200'}
              </p>
              <p className="text-xs text-ark-text-disabled">US App Store</p>
            </div>
            <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-4">
              <p className="text-xs font-medium text-ark-text-tertiary">Bitcoin Search</p>
              <div className="mt-2 flex items-baseline gap-1">
                <span className="fig text-2xl font-bold text-ark-text">{data.retail_sentiment.btc_search_index}</span>
                <span className="text-sm text-ark-text-disabled">/100</span>
              </div>
              <p className={cn('fig mt-0.5 flex items-center gap-0.5 text-xs font-medium', data.retail_sentiment.btc_search_change >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                {data.retail_sentiment.btc_search_change >= 0 ? '↑' : '↓'} {data.retail_sentiment.btc_search_change}
              </p>
            </div>
          </div>
        </GlassCard>

        {/* Institutional */}
        <GlassCard className="p-6">
          <div className="mb-4 flex items-center gap-2">
            <Landmark className="h-4 w-4 text-ark-text-secondary" />
            <h4 className="text-sm font-semibold text-ark-text">Institutional</h4>
          </div>
          <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/30 p-5">
            <div className="flex items-center justify-between">
              <p className="text-xs font-medium text-ark-text-tertiary">Funding Rate</p>
              <span className="text-xs text-ark-text-disabled">{data.funding_rate.exchange}</span>
            </div>
            <p className={cn(
              'fig mt-3 text-2xl font-bold',
              data.funding_rate.rate >= 0 ? 'text-ark-success' : 'text-ark-error',
            )}>
              {(data.funding_rate.rate * 100).toFixed(4)}%
            </p>
            <p className="mt-1 text-xs text-ark-text-tertiary">
              {data.funding_rate.sentiment} &middot; {data.funding_rate.annualized_rate.toFixed(1)}% APR
            </p>
          </div>
        </GlassCard>
      </div>
    </div>
  );
}

