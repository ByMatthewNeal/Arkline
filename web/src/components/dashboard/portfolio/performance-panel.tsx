'use client';

import { Area, AreaChart, ResponsiveContainer, XAxis, YAxis, Tooltip } from 'recharts';
import { Download } from 'lucide-react';
import { GlassCard } from '@/components/ui';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';
import type { PortfolioHolding, PortfolioHistoryPoint } from '@/types';
import type { Transaction } from '@/types/transaction';

function computePerf(history: PortfolioHistoryPoint[]) {
  if (history.length < 2) return null;
  const vals = history.map((h) => h.value);
  const first = vals[0], last = vals[vals.length - 1];
  const totalReturn = last - first;
  const totalReturnPct = first > 0 ? (totalReturn / first) * 100 : 0;

  const rets: number[] = [];
  for (let i = 1; i < vals.length; i++) if (vals[i - 1] > 0) rets.push(vals[i] / vals[i - 1] - 1);
  const mean = rets.length ? rets.reduce((s, r) => s + r, 0) / rets.length : 0;
  const variance = rets.length ? rets.reduce((s, r) => s + (r - mean) ** 2, 0) / rets.length : 0;
  const sd = Math.sqrt(variance);
  const volatility = sd * Math.sqrt(365) * 100;
  const sharpe = sd > 0 ? (mean / sd) * Math.sqrt(365) : 0;

  let peak = vals[0], maxDD = 0;
  for (const v of vals) { if (v > peak) peak = v; const dd = peak > 0 ? (v - peak) / peak : 0; if (dd < maxDD) maxDD = dd; }

  return { totalReturn, totalReturnPct, volatility, sharpe, maxDrawdown: maxDD * 100 };
}

function downloadCSV(filename: string, rows: (string | number)[][]) {
  const csv = rows.map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(',')).join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = filename; a.click();
  URL.revokeObjectURL(url);
}

interface Props {
  history: PortfolioHistoryPoint[];
  holdings: PortfolioHolding[];
  transactions: Transaction[];
  portfolioName: string;
}

export function PerformancePanel({ history, holdings, transactions, portfolioName }: Props) {
  const perf = computePerf(history);
  const realized = transactions.filter((t) => t.type === 'sell').reduce((s, t) => s + (t.realized_profit_loss ?? 0), 0);

  const withPnl = holdings.map((h) => {
    const cost = (h.average_buy_price ?? 0) * h.quantity;
    const value = (h.current_price ?? 0) * h.quantity;
    const pnlPct = cost > 0 ? ((value - cost) / cost) * 100 : 0;
    return { symbol: h.symbol.toUpperCase(), pnlPct };
  }).filter((h) => Number.isFinite(h.pnlPct));
  const best = withPnl.length ? withPnl.reduce((a, b) => (b.pnlPct > a.pnlPct ? b : a)) : null;
  const worst = withPnl.length ? withPnl.reduce((a, b) => (b.pnlPct < a.pnlPct ? b : a)) : null;

  const exportTransactions = () => {
    const header = ['Date', 'Type', 'Symbol', 'Quantity', 'Price', 'Total', 'Realized P&L', 'Notes'];
    const rows = transactions.map((t) => [
      new Date(t.transaction_date).toISOString().split('T')[0], t.type, t.symbol.toUpperCase(),
      t.quantity, t.price_per_unit, t.total_value, t.realized_profit_loss ?? '', t.notes ?? '',
    ]);
    downloadCSV(`${portfolioName.replace(/\s+/g, '-').toLowerCase()}-transactions.csv`, [header, ...rows]);
  };

  const metric = (label: string, value: string, color?: string) => (
    <div className="rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-3">
      <p className="text-[10px] uppercase tracking-wider text-ark-text-disabled">{label}</p>
      <p className="fig mt-0.5 text-sm font-bold" style={{ color: color ?? 'var(--ark-text)' }}>{value}</p>
    </div>
  );

  const curve = history.map((h) => ({ date: h.date, value: h.value }));
  const curveColor = perf && perf.totalReturn >= 0 ? 'var(--ark-success)' : 'var(--ark-error)';

  return (
    <GlassCard className="relative overflow-hidden">
      <div className="mb-4 flex items-center justify-between">
        <h3 className="text-sm font-semibold text-ark-text">Performance</h3>
        <button onClick={exportTransactions} disabled={!transactions.length}
          className="flex items-center gap-1.5 rounded-lg border border-ark-divider px-2.5 py-1.5 text-xs font-medium text-ark-text-secondary transition-colors hover:bg-ark-fill-secondary disabled:opacity-40">
          <Download className="h-3.5 w-3.5" /> Export CSV
        </button>
      </div>

      {perf ? (
        <>
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-6">
            {metric('Total Return', formatPercent(perf.totalReturnPct), perf.totalReturnPct >= 0 ? 'var(--ark-success)' : 'var(--ark-error)')}
            {metric('Realized P&L', formatCurrency(realized), realized >= 0 ? 'var(--ark-success)' : 'var(--ark-error)')}
            {metric('Max Drawdown', `${perf.maxDrawdown.toFixed(1)}%`, 'var(--ark-error)')}
            {metric('Volatility', `${perf.volatility.toFixed(1)}%`)}
            {metric('Sharpe', perf.sharpe.toFixed(2), perf.sharpe >= 1 ? 'var(--ark-success)' : perf.sharpe >= 0 ? 'var(--ark-text)' : 'var(--ark-error)')}
            {best && metric('Best / Worst', `${best.symbol} ${formatPercent(best.pnlPct)}`, 'var(--ark-success)')}
          </div>

          <div className="mt-4 h-40 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={curve} margin={{ top: 6, right: 6, bottom: 0, left: 6 }}>
                <defs>
                  <linearGradient id="perf-curve" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor={curveColor} stopOpacity={0.25} />
                    <stop offset="100%" stopColor={curveColor} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="date" tickLine={false} axisLine={false}
                  ticks={curve.length ? [curve[0].date, curve[curve.length - 1].date] : []}
                  tickFormatter={(d) => new Date(String(d)).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                  tick={{ fontSize: 10, fill: 'var(--ark-text-disabled)' }} interval="preserveStartEnd" />
                <YAxis domain={['dataMin', 'dataMax']} hide />
                <Tooltip contentStyle={{ background: 'var(--ark-card)', border: '1px solid var(--ark-divider)', borderRadius: 8, fontSize: 11 }}
                  labelFormatter={(l) => new Date(String(l)).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                  formatter={(v) => [formatCurrency(Number(v)), 'Value']} />
                <Area type="monotone" dataKey="value" stroke={curveColor} strokeWidth={2} fill="url(#perf-curve)" dot={false} />
              </AreaChart>
            </ResponsiveContainer>
          </div>

          {worst && (
            <p className={cn('mt-2 text-xs text-ark-text-tertiary')}>
              Best performer <span className="font-semibold text-ark-success">{best?.symbol} {formatPercent(best?.pnlPct ?? 0)}</span> · Worst <span className="font-semibold text-ark-error">{worst.symbol} {formatPercent(worst.pnlPct)}</span>
            </p>
          )}
        </>
      ) : (
        <p className="py-6 text-center text-sm text-ark-text-tertiary">Not enough history yet to compute performance metrics.</p>
      )}
    </GlassCard>
  );
}
