'use client';

/**
 * Drawer detail view for the "Portfolio" widget.
 *
 * Charts the user's ACTUAL portfolio (holdings × live prices + daily history),
 * matching the pinned PortfolioHero on the dashboard and the iOS hero card.
 * (A previous version of this component incorrectly charted BTC price from
 * `model_portfolio_risk_history` — do not reintroduce that.)
 */

import { useState } from 'react';
import Link from 'next/link';
import { ArrowUpRight, ArrowDownRight, Wallet, ChevronDown } from 'lucide-react';
import { Area, AreaChart, ResponsiveContainer, Tooltip, YAxis } from 'recharts';
import { Skeleton } from '@/components/ui';
import { formatCurrency, formatPercent, cn, localDateISO } from '@/lib/utils/format';
import { usePortfolios, usePricedHoldings, usePortfolioHistory } from '@/lib/hooks/use-portfolio';
import { CoinIcon } from '@/components/dashboard/shared/coin-icon';

const PERIODS = ['1H', '1D', '1W', '1M', 'YTD', '1Y', 'ALL'] as const;
type Period = (typeof PERIODS)[number];

export function PortfolioHero() {
  const { data: portfolios, isLoading: portfoliosLoading } = usePortfolios();
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const portfolioId = selectedId ?? portfolios?.[0]?.id;
  // Live pricing for ALL holdings (beyond top-100, stocks, metals), 60 s refresh.
  const { data: holdings, isLoading: holdingsLoading } = usePricedHoldings(portfolioId);
  const { data: history } = usePortfolioHistory(portfolioId, 365);
  const [period, setPeriod] = useState<Period>('1M');

  const isLoading = portfoliosLoading || (!!portfolioId && holdingsLoading);

  const valued = (holdings ?? []).map((h) => {
    const price = h.current_price ?? h.average_buy_price ?? 0;
    return { ...h, value: h.quantity * price, livePrice: price, change24h: h.price_change_percentage_24h ?? 0 };
  });
  const currentValue = valued.reduce((sum, h) => sum + h.value, 0);
  const dayChange = valued.reduce((sum, h) => sum + (h.value - h.value / (1 + h.change24h / 100)), 0);
  const dayChangePct = currentValue - dayChange ? (dayChange / (currentValue - dayChange)) * 100 : 0;

  // Period window over daily history (1H/1D fall back to live 24h — history is daily).
  const todayISO = localDateISO();
  const allPts = (history ?? []).map((p) => ({ date: p.date, value: p.value }));
  const ptsNow = allPts.length ? [...allPts, { date: todayISO, value: currentValue }] : [];
  const windowPts = (() => {
    if (!ptsNow.length) return ptsNow;
    if (period === 'ALL') return ptsNow;
    if (period === 'YTD') {
      const ys = `${new Date().getFullYear()}-01-01`;
      return ptsNow.filter((x) => x.date >= ys);
    }
    const days = period === '1H' || period === '1D' ? 1 : period === '1W' ? 7 : period === '1M' ? 30 : 365;
    return ptsNow.slice(-(days + 1));
  })();
  const periodStart = windowPts[0]?.value ?? currentValue;
  const periodChange = currentValue - periodStart;
  const periodChangePct = periodStart ? (periodChange / periodStart) * 100 : 0;
  const useDayLive = period === '1H' || period === '1D';
  const change = useDayLive ? dayChange : periodChange;
  const changePct = useDayLive ? dayChangePct : periodChangePct;
  const isUp = change >= 0;

  const topHoldings = [...valued].sort((a, b) => b.value - a.value).slice(0, 6);

  if (isLoading) {
    return (
      <div className="space-y-4">
        <Skeleton className="h-20 w-full" />
        <Skeleton className="h-40 w-full" />
        <Skeleton className="h-32 w-full" />
      </div>
    );
  }

  if (!valued.length) {
    return (
      <div className="flex flex-col items-center justify-center py-12 text-center">
        <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ark-primary/10">
          <Wallet className="h-6 w-6 text-ark-primary" />
        </div>
        <p className="mt-3 text-sm font-medium text-ark-text">No holdings yet</p>
        <p className="mt-1 text-xs text-ark-text-tertiary">Add positions to track your portfolio here.</p>
        <Link
          href="/dashboard/portfolio"
          className="mt-4 rounded-lg bg-ark-primary px-4 py-2 text-xs font-semibold text-white hover:bg-ark-accent-dark"
        >
          Go to Portfolio
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-5">
      {/* Header: portfolio picker + period selector */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        {portfolios && portfolios.length > 1 ? (
          <div className="relative inline-flex items-center">
            <select
              value={portfolioId}
              onChange={(e) => setSelectedId(e.target.value)}
              className="appearance-none rounded-lg bg-ark-fill-secondary/60 py-1.5 pl-3 pr-8 text-sm font-semibold text-ark-text outline-none"
            >
              {portfolios.map((p) => (
                <option key={p.id} value={p.id}>{p.name}</option>
              ))}
            </select>
            <ChevronDown className="pointer-events-none absolute right-2 h-3.5 w-3.5 text-ark-text-tertiary" />
          </div>
        ) : (
          <span className="text-sm font-semibold text-ark-text">{portfolios?.[0]?.name ?? 'Portfolio'}</span>
        )}
        <div className="flex gap-1 overflow-x-auto rounded-full bg-ark-fill-secondary/60 p-1">
          {PERIODS.map((p) => (
            <button
              key={p}
              onClick={() => setPeriod(p)}
              className={cn(
                'shrink-0 rounded-full px-2.5 py-1 text-[10px] font-semibold transition-colors',
                period === p ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text',
              )}
            >
              {p}
            </button>
          ))}
        </div>
      </div>

      {/* Value + change */}
      <div>
        <p className="fig font-[family-name:var(--font-urbanist)] text-4xl font-bold tracking-tight text-ark-text">
          <span>$</span>
          {currentValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
        </p>
        <span
          className={cn(
            'fig mt-2 inline-flex items-center gap-1 rounded-full px-2.5 py-1 text-sm font-semibold',
            isUp ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-error/10 text-ark-error',
          )}
        >
          {isUp ? <ArrowUpRight className="h-3.5 w-3.5" /> : <ArrowDownRight className="h-3.5 w-3.5" />}
          {formatCurrency(Math.abs(change))} ({formatPercent(changePct)})
        </span>
      </div>

      {/* History chart */}
      {windowPts.length > 1 && (
        <div className="h-44 w-full">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={windowPts} margin={{ top: 4, right: 0, bottom: 0, left: 0 }}>
              <defs>
                <linearGradient id="pfHeroFill" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor={isUp ? 'var(--ark-success)' : 'var(--ark-error)'} stopOpacity={0.25} />
                  <stop offset="100%" stopColor={isUp ? 'var(--ark-success)' : 'var(--ark-error)'} stopOpacity={0} />
                </linearGradient>
              </defs>
              <YAxis domain={['dataMin', 'dataMax']} hide />
              <Tooltip
                cursor={{ stroke: 'var(--ark-divider)', strokeDasharray: '3 3' }}
                content={({ active, payload }) =>
                  active && payload?.[0] ? (
                    <div className="rounded-lg border border-ark-divider bg-ark-card px-3 py-2 text-xs shadow-lg">
                      <p className="text-ark-text-tertiary">{(payload[0].payload as { date: string }).date}</p>
                      <p className="fig font-semibold text-ark-text">{formatCurrency(payload[0].value as number)}</p>
                    </div>
                  ) : null
                }
              />
              <Area
                type="monotone"
                dataKey="value"
                stroke={isUp ? 'var(--ark-success)' : 'var(--ark-error)'}
                strokeWidth={2}
                fill="url(#pfHeroFill)"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Top holdings */}
      <div>
        <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Top holdings</p>
        <div className="space-y-1">
          {topHoldings.map((h) => {
            const pct = currentValue ? (h.value / currentValue) * 100 : 0;
            const up = h.change24h >= 0;
            return (
              <div key={h.id} className="flex items-center justify-between rounded-lg px-2 py-1.5 hover:bg-ark-fill-secondary/40">
                <div className="flex min-w-0 items-center gap-2.5">
                  <CoinIcon symbol={h.symbol} size="md" />
                  <div className="min-w-0">
                  <p className="truncate text-sm font-medium text-ark-text">{h.name || h.symbol.toUpperCase()}</p>
                  <p className="fig text-[11px] text-ark-text-tertiary">
                    {h.quantity} {h.symbol.toUpperCase()} · {pct.toFixed(1)}%
                  </p>
                  </div>
                </div>
                <div className="text-right">
                  <p className="fig text-sm font-semibold text-ark-text">{formatCurrency(h.value)}</p>
                  <p className={cn('fig text-[11px] font-medium', up ? 'text-ark-success' : 'text-ark-error')}>
                    {formatPercent(h.change24h)}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <div className="border-t border-ark-divider pt-3 text-right">
        <Link href="/dashboard/portfolio" className="text-xs font-medium text-ark-primary hover:text-ark-accent-light">
          View full portfolio →
        </Link>
      </div>
    </div>
  );
}
