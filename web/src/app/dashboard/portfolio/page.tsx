'use client';

import { useState } from 'react';
import { ChevronDown, Plus, Trash2, TrendingUp, TrendingDown } from 'lucide-react';
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
  ReferenceLine,
} from 'recharts';
import { GlassCard, Skeleton, ConfirmDialog, PromptDialog, useToast } from '@/components/ui';
import { usePortfolios, usePricedHoldings, useTransactions, usePortfolioHistory } from '@/lib/hooks/use-portfolio';
import { useDeleteHolding, useUpdateHoldingTarget, useCreatePortfolio } from '@/lib/hooks/use-portfolio-mutations';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';
import { AddTransactionModal } from '@/components/dashboard/portfolio/add-transaction-modal';
import { PerformancePanel } from '@/components/dashboard/portfolio/performance-panel';
import { TransactionsPanel } from '@/components/dashboard/portfolio/transactions-panel';
import { ModelPortfolioCard } from '@/components/dashboard/portfolio/model-portfolio-card';
import { CoinIcon } from '@/components/dashboard/shared/coin-icon';
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
  const [modal, setModal] = useState<{ open: boolean; type: 'buy' | 'sell'; symbol?: string }>({ open: false, type: 'buy' });
  const [newPortfolioOpen, setNewPortfolioOpen] = useState(false);
  const [removeSymbol, setRemoveSymbol] = useState<string | null>(null);
  const [scrubbedIdx, setScrubbedIdx] = useState<number | null>(null);
  const toast = useToast();

  const portfolio = portfolios?.[selectedIdx];
  // Live pricing for ALL holdings (crypto beyond top-100, stocks, metals),
  // refreshed every 60 s — matches the iOS pricing path.
  const { data: holdings, isLoading: loadingHoldings } = usePricedHoldings(portfolio?.id);
  const { data: transactions } = useTransactions(portfolio?.id);
  const { data: history } = usePortfolioHistory(portfolio?.id, 365);
  const deleteHolding = useDeleteHolding(portfolio?.id);
  const updateTarget = useUpdateHoldingTarget(portfolio?.id);
  const createPortfolio = useCreatePortfolio();

  const pricedHoldings = (holdings ?? []).map((h) => ({
    ...h,
    current_price: h.current_price ?? h.average_buy_price ?? 0,
    price_change_percentage_24h: h.price_change_percentage_24h ?? 0,
  }));

  // Aggregate multiple lots of the same asset into one position (qty-weighted avg cost).
  const bySymbol = new Map<string, PortfolioHolding>();
  for (const h of pricedHoldings) {
    const key = h.symbol.toLowerCase();
    const ex = bySymbol.get(key);
    if (ex) {
      const totalQty = ex.quantity + h.quantity;
      const wCost = ((ex.average_buy_price ?? 0) * ex.quantity + (h.average_buy_price ?? 0) * h.quantity);
      ex.average_buy_price = totalQty > 0 ? wCost / totalQty : 0;
      ex.quantity = totalQty;
    } else {
      bySymbol.set(key, { ...h });
    }
  }
  const aggHoldings = [...bySymbol.values()];

  const stats = computeStats(aggHoldings);

  // Allocation data
  const allocations = aggHoldings
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

  // Scrubbing the history chart rewrites the headline value + date.
  const scrubbedPoint = scrubbedIdx != null ? historyData[scrubbedIdx] ?? null : null;

  const isLoading = loadingPortfolios || loadingHoldings;

  return (
    <div className="space-y-6">
      {/* Header + portfolio switcher */}
      <div className="flex items-center justify-between">
        <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-semibold text-ark-text">
          Portfolio
        </h1>
        <div className="flex items-center gap-2">
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
          <button
            onClick={() => setNewPortfolioOpen(true)}
            className="rounded-xl border border-ark-divider px-3 py-2 text-sm font-medium text-ark-text-secondary transition-colors hover:bg-ark-fill-secondary"
          >
            New Portfolio
          </button>
          <button
            onClick={() => setModal({ open: true, type: 'buy' })}
            disabled={!portfolio}
            className="flex items-center gap-1.5 rounded-xl bg-ark-primary px-4 py-2 text-sm font-semibold text-white shadow-md shadow-ark-primary/25 transition-all hover:brightness-110 disabled:opacity-50"
          >
            <Plus className="h-4 w-4" /> Add Transaction
          </button>
        </div>
      </div>

      <AddTransactionModal
        open={modal.open}
        onClose={() => setModal((m) => ({ ...m, open: false }))}
        portfolioId={portfolio?.id}
        holdings={aggHoldings}
        initialType={modal.type}
        initialSymbol={modal.symbol}
      />

      <PromptDialog
        open={newPortfolioOpen}
        title="New portfolio"
        message="Give your new portfolio a name."
        placeholder="e.g. Long-term, Trading, Retirement"
        confirmLabel="Create"
        loading={createPortfolio.isPending}
        onSubmit={(name) => {
          createPortfolio.mutate(name, {
            onSuccess: () => { setNewPortfolioOpen(false); toast.success(`"${name}" created`); },
            onError: () => toast.error('Could not create portfolio. Please try again.'),
          });
        }}
        onCancel={() => setNewPortfolioOpen(false)}
      />

      <ConfirmDialog
        open={removeSymbol !== null}
        title={`Remove ${removeSymbol?.toUpperCase() ?? ''}?`}
        message="This removes the holding and its lots from this portfolio. Transactions are not affected."
        confirmLabel="Remove"
        destructive
        loading={deleteHolding.isPending}
        onConfirm={() => {
          if (!removeSymbol) return;
          deleteHolding.mutate(removeSymbol, {
            onSuccess: () => { setRemoveSymbol(null); toast.success('Holding removed'); },
            onError: () => toast.error('Could not remove holding. Please try again.'),
          });
        }}
        onCancel={() => setRemoveSymbol(null)}
      />

      {isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <Skeleton className="col-span-full h-40" />
          <Skeleton className="h-64" />
          <Skeleton className="h-64" />
          <Skeleton className="h-64" />
        </div>
      ) : (
        <>
          {/* Hero stats card — scrubbing the chart rewrites the headline */}
          <GlassCard className="relative col-span-full overflow-hidden">
            <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary/20 to-transparent" />
            <div className="flex flex-wrap items-end gap-8">
              <div>
                <p className="text-xs font-medium uppercase tracking-wider text-ark-text-tertiary">
                  {scrubbedPoint
                    ? new Date(scrubbedPoint.date + 'T00:00:00').toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' })
                    : (portfolio?.name ?? 'Portfolio')}
                </p>
                <p className="fig font-[family-name:var(--font-urbanist)] text-4xl font-bold tracking-tight text-ark-text lg:text-5xl">
                  <span>$</span>
                  {(scrubbedPoint ? scrubbedPoint.value : stats.totalValue).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </p>
              </div>
              <div className={cn('transition-opacity duration-200', scrubbedPoint && 'opacity-30')}>
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
              <div className={cn('transition-opacity duration-200', scrubbedPoint && 'opacity-30')}>
                <p className="text-[10px] font-medium uppercase tracking-wider text-ark-text-tertiary">24h Change</p>
                <p
                  className={`fig mt-0.5 text-lg font-bold ${
                    stats.dayChange >= 0 ? 'text-ark-success' : 'text-ark-error'
                  }`}
                >
                  {formatCurrency(stats.dayChange)} ({formatPercent(stats.dayPct)})
                </p>
              </div>
              {scrubbedPoint && historyData[0] && (
                <div>
                  <p className="text-[10px] font-medium uppercase tracking-wider text-ark-text-tertiary">vs. year start</p>
                  <p className={`fig mt-0.5 text-lg font-bold ${scrubbedPoint.value >= historyData[0].value ? 'text-ark-success' : 'text-ark-error'}`}>
                    {formatPercent(historyData[0].value ? ((scrubbedPoint.value - historyData[0].value) / historyData[0].value) * 100 : 0)}
                  </p>
                </div>
              )}
            </div>

            {/* History — baseline at range start, scrub to explore */}
            {historyData.length > 1 && (
              <>
                <div className="mt-5 h-32 cursor-crosshair">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart
                      data={historyData}
                      margin={{ top: 4, right: 10, bottom: 0, left: 4 }}
                      onMouseMove={(state) => {
                        const idx = (state as { activeTooltipIndex?: number | null })?.activeTooltipIndex;
                        setScrubbedIdx(typeof idx === 'number' ? idx : null);
                      }}
                      onMouseLeave={() => setScrubbedIdx(null)}
                    >
                      <defs>
                        <linearGradient id="port-grad" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="0%" stopColor="var(--ark-primary)" stopOpacity={0.12} />
                          <stop offset="70%" stopColor="var(--ark-primary)" stopOpacity={0} />
                        </linearGradient>
                      </defs>
                      <XAxis dataKey="date" hide />
                      <YAxis hide domain={['dataMin', 'dataMax']} />
                      <ReferenceLine y={historyData[0].value} stroke="var(--ark-text-disabled)" strokeDasharray="2 4" strokeOpacity={0.5} />
                      <Tooltip
                        cursor={{ stroke: 'var(--ark-text-tertiary)', strokeDasharray: '3 3', strokeOpacity: 0.5 }}
                        content={() => null}
                      />
                      <Area
                        type="monotone"
                        dataKey="value"
                        stroke="var(--ark-primary)"
                        strokeWidth={1.5}
                        fill="url(#port-grad)"
                        activeDot={{ r: 4, fill: 'var(--ark-primary)', stroke: 'var(--ark-card)', strokeWidth: 2 }}
                      />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
                <div className="mt-1 flex justify-between px-1 text-[9px] font-medium uppercase tracking-wide text-ark-text-disabled">
                  <span>{new Date(historyData[0].date + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}</span>
                  <span>{new Date(historyData[historyData.length - 1].date + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}</span>
                </div>
              </>
            )}
          </GlassCard>

          <div className="grid gap-6 sm:grid-cols-2">
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
                        paddingAngle={allocations.length > 1 ? 2 : 0}
                        dataKey="value"
                        isAnimationActive={false}
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
              {/* Current vs target allocation (editable) */}
              {aggHoldings.length > 0 && stats.totalValue > 0 && (
                <div className="mt-3 space-y-1.5 border-t border-ark-divider pt-3">
                  <div className="flex items-center justify-between text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">
                    <span>Asset</span><span>Current · Target</span>
                  </div>
                  {aggHoldings.map((h, i) => {
                    const cur = ((h.current_price ?? 0) * h.quantity) / stats.totalValue * 100;
                    const tgt = h.target_percentage ?? null;
                    const drift = tgt != null ? cur - tgt : null;
                    return (
                      <div key={h.id} className="flex items-center gap-2 text-xs">
                        <span className="h-2 w-2 shrink-0 rounded-full" style={{ background: PIE_COLORS[i % PIE_COLORS.length] }} />
                        <span className="w-12 font-semibold text-ark-text">{h.symbol.toUpperCase()}</span>
                        <span className="fig w-12 text-ark-text-secondary">{cur.toFixed(1)}%</span>
                        <input
                          type="number" defaultValue={tgt ?? ''} placeholder="—" min={0} max={100}
                          onBlur={(e) => {
                            const v = e.target.value.trim();
                            const num = v === '' ? null : Math.max(0, Math.min(100, parseFloat(v)));
                            if ((num ?? null) !== (tgt ?? null)) updateTarget.mutate({ holdingId: h.id, target: num });
                          }}
                          className="fig w-14 rounded-md border border-ark-divider bg-ark-fill-secondary/40 px-1.5 py-0.5 text-right text-ark-text outline-none focus:border-ark-info"
                        />
                        {drift != null && Math.abs(drift) >= 0.5 && (
                          <span className={cn('fig text-[10px] font-semibold', drift > 0 ? 'text-ark-warning' : 'text-ark-info')}>{drift > 0 ? '+' : ''}{drift.toFixed(0)}</span>
                        )}
                      </div>
                    );
                  })}
                  <p className="pt-1 text-[10px] text-ark-text-disabled">Set a target % to track drift.</p>
                </div>
              )}
            </GlassCard>

            {/* Model portfolio strategies (iOS Overview-tab parity) */}
            <ModelPortfolioCard />

            {/* Holdings list */}
            <GlassCard className="sm:col-span-2">
              <h3 className="mb-3 text-sm font-semibold text-ark-text">Holdings</h3>
              <div className="space-y-2">
                {aggHoldings.length === 0 && (
                  <p className="text-sm text-ark-text-tertiary">No holdings yet.</p>
                )}
                {aggHoldings.map((h) => {
                  const value = (h.current_price ?? 0) * h.quantity;
                  const cost = (h.average_buy_price ?? 0) * h.quantity;
                  const pnl = value - cost;
                  const isUp = pnl >= 0;
                  return (
                    <div
                      key={h.id}
                      className="group flex items-center justify-between gap-2 rounded-xl bg-ark-fill-secondary/60 px-4 py-3 transition-colors hover:bg-ark-fill-secondary"
                    >
                      <div className="flex min-w-0 items-center gap-3">
                        <CoinIcon symbol={h.symbol} size="lg" className="h-9 w-9" />
                        <div className="min-w-0">
                          <p className="text-sm font-semibold text-ark-text">{h.symbol.toUpperCase()}</p>
                          <p className="truncate text-xs text-ark-text-tertiary">{h.name} · <span className="fig">{h.quantity}</span> @ {formatCurrency(h.average_buy_price ?? 0)}</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-3">
                        {/* Hover actions */}
                        <div className="flex items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
                          <button onClick={() => setModal({ open: true, type: 'buy', symbol: h.symbol })} title="Buy more"
                            className="flex h-7 w-7 items-center justify-center rounded-lg text-ark-success hover:bg-ark-success/10"><TrendingUp className="h-3.5 w-3.5" /></button>
                          <button onClick={() => setModal({ open: true, type: 'sell', symbol: h.symbol })} title="Sell"
                            className="flex h-7 w-7 items-center justify-center rounded-lg text-ark-error hover:bg-ark-error/10"><TrendingDown className="h-3.5 w-3.5" /></button>
                          <button onClick={() => setRemoveSymbol(h.symbol)} title="Remove"
                            className="flex h-7 w-7 items-center justify-center rounded-lg text-ark-text-tertiary hover:bg-ark-fill-secondary"><Trash2 className="h-3.5 w-3.5" /></button>
                        </div>
                        <div className="text-right">
                          <p className="fig text-sm font-bold text-ark-text">{formatCurrency(value)}</p>
                          <p className={`fig text-xs font-medium ${isUp ? 'text-ark-success' : 'text-ark-error'}`}>
                            {formatCurrency(pnl)} ({formatPercent(cost > 0 ? (pnl / cost) * 100 : 0)})
                          </p>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </GlassCard>
          </div>

          {/* Transaction history — filters, detail drawer, delete w/ recalc (iOS History-tab parity) */}
          <TransactionsPanel transactions={transactions ?? []} portfolioId={portfolio?.id} />

          {/* Performance */}
          <PerformancePanel
            history={history ?? []}
            holdings={aggHoldings}
            transactions={transactions ?? []}
            portfolioName={portfolio?.name ?? 'portfolio'}
          />
        </>
      )}
    </div>
  );
}
