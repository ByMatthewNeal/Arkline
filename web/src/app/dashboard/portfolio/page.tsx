'use client';

import { useState } from 'react';
import { Briefcase, ChevronDown } from 'lucide-react';
import {
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  Tooltip,
  Area,
  AreaChart,
  XAxis,
  YAxis,
} from 'recharts';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { usePortfolios, useHoldings, useTransactions, usePortfolioHistory } from '@/lib/hooks/use-portfolio';
import { formatCurrency, formatPercent, formatDate } from '@/lib/utils/format';
import type { PortfolioHolding } from '@/types';

const PIE_COLORS = ['#3B82F6', '#22C55E', '#F59E0B', '#DC2626', '#8B5CF6', '#06B6D4', '#EC4899', '#F97316'];

function computeStats(holdings: PortfolioHolding[]) {
  let totalValue = 0;
  let totalCost = 0;
  let dayChange = 0;

  for (const h of holdings) {
    const value = (h.current_price ?? 0) * h.quantity;
    const cost = (h.average_buy_price ?? 0) * h.quantity;
    totalValue += value;
    totalCost += cost;
    dayChange += ((h.price_change_percentage_24h ?? 0) / 100) * value;
  }

  const pnl = totalValue - totalCost;
  const pnlPct = totalCost > 0 ? (pnl / totalCost) * 100 : 0;
  const dayPct = totalValue > 0 ? (dayChange / totalValue) * 100 : 0;

  return { totalValue, totalCost, pnl, pnlPct, dayChange, dayPct };
}

export default function PortfolioPage() {
  const { data: portfolios, isLoading: loadingPortfolios } = usePortfolios();
  const [selectedIdx, setSelectedIdx] = useState(0);

  const portfolio = portfolios?.[selectedIdx];
  const { data: holdings, isLoading: loadingHoldings } = useHoldings(portfolio?.id);
  const { data: transactions } = useTransactions(portfolio?.id);
  const { data: history } = usePortfolioHistory(portfolio?.id, 30);

  const stats = computeStats(holdings ?? []);

  // Allocation data
  const allocations = (holdings ?? [])
    .map((h, i) => ({
      name: h.symbol.toUpperCase(),
      value: (h.current_price ?? 0) * h.quantity,
      color: PIE_COLORS[i % PIE_COLORS.length],
    }))
    .filter((a) => a.value > 0)
    .sort((a, b) => b.value - a.value);

  const historyData = (history ?? []).map((p) => ({
    date: p.date,
    value: p.value,
  }));

  const isLoading = loadingPortfolios || loadingHoldings;

  return (
    <div className="space-y-6">
      {/* Header + portfolio switcher */}
      <div className="flex items-center justify-between">
        <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text">
          Portfolio
        </h1>
        {(portfolios ?? []).length > 1 && (
          <div className="relative">
            <select
              value={selectedIdx}
              onChange={(e) => setSelectedIdx(Number(e.target.value))}
              className="appearance-none rounded-lg border border-ark-divider bg-ark-fill-secondary px-3 py-1.5 pr-8 text-sm text-ark-text cursor-pointer"
            >
              {portfolios!.map((p, i) => (
                <option key={p.id} value={i}>
                  {p.name}
                </option>
              ))}
            </select>
            <ChevronDown className="pointer-events-none absolute right-2 top-1/2 h-4 w-4 -translate-y-1/2 text-ark-text-tertiary" />
          </div>
        )}
      </div>

      {isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <Skeleton className="col-span-full h-40" />
          <Skeleton className="h-64" />
          <Skeleton className="h-64" />
          <Skeleton className="h-64" />
        </div>
      ) : (
        <>
          {/* Hero stats card */}
          <GlassCard className="relative col-span-full overflow-hidden">
            <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary/20 to-transparent" />
            <div className="flex flex-wrap items-end gap-8">
              <div>
                <p className="text-xs font-medium uppercase tracking-wider text-ark-text-tertiary">{portfolio?.name ?? 'Portfolio'}</p>
                <p className="fig font-[family-name:var(--font-urbanist)] text-4xl font-bold tracking-tight text-ark-text lg:text-5xl">
                  <span className="opacity-50 font-normal">$</span>
                  {stats.totalValue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </p>
              </div>
              <div>
                <p className="text-[10px] font-medium uppercase tracking-wider text-ark-text-tertiary">Total P&L</p>
                <p
                  className={`fig mt-0.5 text-lg font-bold ${
                    stats.pnl >= 0 ? 'text-ark-success' : 'text-ark-error'
                  }`}
                >
                  {formatCurrency(stats.pnl)} ({formatPercent(stats.pnlPct)})
                </p>
              </div>
              <div className="w-px self-stretch bg-ark-divider" />
              <div>
                <p className="text-[10px] font-medium uppercase tracking-wider text-ark-text-tertiary">24h Change</p>
                <p
                  className={`fig mt-0.5 text-lg font-bold ${
                    stats.dayChange >= 0 ? 'text-ark-success' : 'text-ark-error'
                  }`}
                >
                  {formatCurrency(stats.dayChange)} ({formatPercent(stats.dayPct)})
                </p>
              </div>
            </div>

            {/* Sparkline */}
            {historyData.length > 1 && (
              <div className="mt-5 h-32">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={historyData}>
                    <defs>
                      <linearGradient id="port-grad" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="0%" stopColor="#3B82F6" stopOpacity={0.2} />
                        <stop offset="100%" stopColor="#3B82F6" stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <XAxis dataKey="date" hide />
                    <YAxis hide domain={['dataMin', 'dataMax']} />
                    <Area
                      type="monotone"
                      dataKey="value"
                      stroke="#3B82F6"
                      strokeWidth={1.5}
                      fill="url(#port-grad)"
                    />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            )}
          </GlassCard>

          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {/* Allocation donut */}
            <GlassCard>
              <h3 className="mb-3 text-sm font-semibold text-ark-text">Allocation</h3>
              {allocations.length === 0 ? (
                <p className="text-sm text-ark-text-tertiary">No holdings.</p>
              ) : (
                <div className="h-52">
                  <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                      <Pie
                        data={allocations}
                        cx="50%"
                        cy="50%"
                        innerRadius={50}
                        outerRadius={80}
                        paddingAngle={2}
                        dataKey="value"
                      >
                        {allocations.map((a, i) => (
                          <Cell key={i} fill={a.color} />
                        ))}
                      </Pie>
                      <Tooltip
                        formatter={(val) => formatCurrency(val as number)}
                        contentStyle={{
                          background: 'var(--ark-card)',
                          border: '1px solid var(--ark-divider)',
                          borderRadius: '8px',
                          fontSize: '12px',
                        }}
                      />
                    </PieChart>
                  </ResponsiveContainer>
                </div>
              )}
              <div className="mt-2 flex flex-wrap gap-2">
                {allocations.slice(0, 6).map((a) => (
                  <div key={a.name} className="flex items-center gap-1.5 text-xs text-ark-text-secondary">
                    <div className="h-2 w-2 rounded-full" style={{ background: a.color }} />
                    {a.name}
                  </div>
                ))}
              </div>
            </GlassCard>

            {/* Holdings list */}
            <GlassCard className="sm:col-span-1 lg:col-span-2">
              <h3 className="mb-3 text-sm font-semibold text-ark-text">Holdings</h3>
              <div className="space-y-2">
                {(holdings ?? []).length === 0 && (
                  <p className="text-sm text-ark-text-tertiary">No holdings yet.</p>
                )}
                {(holdings ?? []).map((h) => {
                  const value = (h.current_price ?? 0) * h.quantity;
                  const cost = (h.average_buy_price ?? 0) * h.quantity;
                  const pnl = value - cost;
                  const isUp = pnl >= 0;
                  return (
                    <div
                      key={h.id}
                      className="flex items-center justify-between rounded-xl bg-ark-fill-secondary/60 px-4 py-3 transition-colors hover:bg-ark-fill-secondary"
                    >
                      <div className="flex items-center gap-3 min-w-0">
                        {h.icon_url && (
                          <img src={h.icon_url} alt={h.name} className="h-8 w-8 rounded-full" />
                        )}
                        <div className="min-w-0">
                          <p className="text-sm font-semibold text-ark-text">{h.symbol.toUpperCase()}</p>
                          <p className="text-xs text-ark-text-tertiary truncate">{h.name}</p>
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="fig text-sm font-bold text-ark-text">
                          {formatCurrency(value)}
                        </p>
                        <p className={`fig text-xs font-medium ${isUp ? 'text-ark-success' : 'text-ark-error'}`}>
                          {formatCurrency(pnl)} ({formatPercent(cost > 0 ? (pnl / cost) * 100 : 0)})
                        </p>
                      </div>
                    </div>
                  );
                })}
              </div>
            </GlassCard>
          </div>

          {/* Transactions */}
          <GlassCard className="relative overflow-hidden">
            <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-text-disabled/20 to-transparent" />
            <h3 className="mb-4 text-sm font-semibold text-ark-text">Recent Transactions</h3>
            <div className="space-y-2">
              {(transactions ?? []).length === 0 && (
                <p className="text-sm text-ark-text-tertiary">No transactions.</p>
              )}
              {(transactions ?? []).slice(0, 10).map((t) => (
                <div
                  key={t.id}
                  className="flex items-center justify-between rounded-xl bg-ark-fill-secondary/60 px-4 py-2.5 transition-colors hover:bg-ark-fill-secondary"
                >
                  <div className="flex items-center gap-3">
                    <Badge
                      variant={
                        t.type === 'buy' ? 'success' : t.type === 'sell' ? 'error' : 'default'
                      }
                    >
                      {t.type}
                    </Badge>
                    <div>
                      <p className="text-xs font-medium text-ark-text">{t.symbol.toUpperCase()}</p>
                      <p className="text-[10px] text-ark-text-tertiary">
                        {formatDate(t.transaction_date)}
                      </p>
                    </div>
                  </div>
                  <div className="text-right">
                    <p className="text-xs font-semibold text-ark-text">
                      {formatCurrency(t.total_value)}
                    </p>
                    <p className="text-[10px] text-ark-text-tertiary">
                      {t.quantity} @ {formatCurrency(t.price_per_unit)}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </GlassCard>
        </>
      )}
    </div>
  );
}
