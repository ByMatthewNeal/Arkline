'use client';

/**
 * Full transaction history — mirrors the iOS Portfolio › History tab:
 * type filter chips, date-grouped list, tap → detail drawer (realized P/L
 * for sells, notes, emotional state), delete with holdings recalculation.
 */

import { useState } from 'react';
import { ArrowDownLeft, ArrowUpRight, ArrowRightLeft, Trash2, StickyNote } from 'lucide-react';
import { GlassCard, Badge, ConfirmDialog, DetailDrawer, useToast } from '@/components/ui';
import { useDeleteTransaction } from '@/lib/hooks/use-portfolio-mutations';
import { formatCurrency, formatDate, cn } from '@/lib/utils/format';
import type { Transaction, TransactionType } from '@/types/transaction';

const FILTERS: { key: 'all' | TransactionType; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'buy', label: 'Buys' },
  { key: 'sell', label: 'Sells' },
  { key: 'transfer_in', label: 'Transfers in' },
  { key: 'transfer_out', label: 'Transfers out' },
];

const TYPE_META: Record<TransactionType, { label: string; variant: 'success' | 'error' | 'info' | 'default'; icon: typeof ArrowDownLeft }> = {
  buy: { label: 'Buy', variant: 'success', icon: ArrowDownLeft },
  sell: { label: 'Sell', variant: 'error', icon: ArrowUpRight },
  transfer_in: { label: 'Transfer in', variant: 'info', icon: ArrowRightLeft },
  transfer_out: { label: 'Transfer out', variant: 'default', icon: ArrowRightLeft },
};

function groupLabel(dateStr: string): string {
  const d = new Date(dateStr);
  const now = new Date();
  if (d.toDateString() === now.toDateString()) return 'Today';
  const yest = new Date(now);
  yest.setDate(now.getDate() - 1);
  if (d.toDateString() === yest.toDateString()) return 'Yesterday';
  const diffDays = (now.getTime() - d.getTime()) / 86_400_000;
  if (diffDays <= 7) return 'This Week';
  return d.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
}

export function TransactionsPanel({
  transactions,
  portfolioId,
}: {
  transactions: Transaction[];
  portfolioId: string | undefined;
}) {
  const [filter, setFilter] = useState<'all' | TransactionType>('all');
  const [selected, setSelected] = useState<Transaction | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Transaction | null>(null);
  const deleteTx = useDeleteTransaction(portfolioId);
  const toast = useToast();

  const filtered = transactions.filter((t) => filter === 'all' || t.type === filter);

  // Date-grouped, newest first (input is already newest-first from the API).
  const groups: { label: string; items: Transaction[] }[] = [];
  for (const t of filtered) {
    const label = groupLabel(t.transaction_date);
    const g = groups[groups.length - 1];
    if (g && g.label === label) g.items.push(t);
    else groups.push({ label, items: [t] });
  }

  return (
    <GlassCard>
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <h2 className="text-sm font-semibold text-ark-text">Transactions</h2>
        <div className="flex gap-1 overflow-x-auto rounded-full bg-ark-fill-secondary/60 p-1">
          {FILTERS.map((f) => (
            <button
              key={f.key}
              onClick={() => setFilter(f.key)}
              className={cn(
                'shrink-0 rounded-full px-2.5 py-1 text-[10px] font-semibold transition-colors',
                filter === f.key ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text',
              )}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {filtered.length === 0 ? (
        <p className="py-8 text-center text-sm text-ark-text-tertiary">
          {filter === 'all' ? 'No transactions yet.' : 'No transactions match this filter.'}
        </p>
      ) : (
        <div className="mt-3 space-y-4">
          {groups.map((g) => (
            <div key={g.label}>
              <p className="mb-1 text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">{g.label}</p>
              <div className="divide-y divide-ark-divider/50">
                {g.items.map((t) => {
                  const meta = TYPE_META[t.type] ?? TYPE_META.buy;
                  const Icon = meta.icon;
                  const isSell = t.type === 'sell';
                  return (
                    <div
                      key={t.id}
                      className="group flex cursor-pointer items-center justify-between gap-3 py-2.5 transition-colors hover:bg-ark-fill-secondary/30"
                      onClick={() => setSelected(t)}
                    >
                      <div className="flex min-w-0 items-center gap-3">
                        <div className={cn(
                          'flex h-8 w-8 shrink-0 items-center justify-center rounded-lg',
                          isSell ? 'bg-ark-error/10 text-ark-error' : t.type === 'buy' ? 'bg-ark-success/10 text-ark-success' : 'bg-ark-info/10 text-ark-info',
                        )}>
                          <Icon className="h-3.5 w-3.5" />
                        </div>
                        <div className="min-w-0">
                          <p className="text-sm font-medium text-ark-text">
                            {meta.label} {t.symbol.toUpperCase()}
                            {t.notes && <StickyNote className="ml-1.5 inline h-3 w-3 text-ark-text-disabled" />}
                          </p>
                          <p className="fig text-[11px] text-ark-text-tertiary">
                            {t.quantity} @ {formatCurrency(t.price_per_unit)} · {formatDate(t.transaction_date)}
                          </p>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <button
                          onClick={(e) => { e.stopPropagation(); setDeleteTarget(t); }}
                          title="Delete transaction"
                          className="flex h-7 w-7 items-center justify-center rounded-lg text-ark-text-tertiary opacity-0 transition-opacity hover:bg-ark-fill-secondary group-hover:opacity-100"
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                        </button>
                        <div className="text-right">
                          <p className="fig text-sm font-semibold text-ark-text">{formatCurrency(t.total_value)}</p>
                          {isSell && t.realized_profit_loss != null && (
                            <p className={cn('fig text-[11px] font-medium', t.realized_profit_loss >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                              {formatCurrency(t.realized_profit_loss, undefined, { sign: true })} realized
                            </p>
                          )}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Detail drawer */}
      <DetailDrawer
        open={selected !== null}
        onClose={() => setSelected(null)}
        title={selected ? `${TYPE_META[selected.type]?.label ?? 'Transaction'} · ${selected.symbol.toUpperCase()}` : ''}
      >
        {selected && (
          <div className="space-y-4">
            <div className="flex items-center gap-2">
              <Badge variant={TYPE_META[selected.type]?.variant ?? 'default'}>{TYPE_META[selected.type]?.label}</Badge>
              <span className="text-xs text-ark-text-tertiary">{formatDate(selected.transaction_date)}</span>
            </div>

            <div className="grid grid-cols-2 gap-3">
              {[
                { label: 'Quantity', value: `${selected.quantity} ${selected.symbol.toUpperCase()}` },
                { label: 'Price per unit', value: formatCurrency(selected.price_per_unit) },
                { label: 'Total value', value: formatCurrency(selected.total_value) },
                { label: 'Fee', value: formatCurrency(selected.gas_fee ?? 0) },
              ].map((row) => (
                <div key={row.label} className="rounded-xl bg-ark-fill-secondary/40 px-3 py-2.5">
                  <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">{row.label}</p>
                  <p className="fig mt-0.5 text-sm font-semibold text-ark-text">{row.value}</p>
                </div>
              ))}
            </div>

            {selected.type === 'sell' && selected.realized_profit_loss != null && (
              <div className={cn(
                'rounded-xl border px-3 py-3',
                selected.realized_profit_loss >= 0 ? 'border-ark-success/30 bg-ark-success/5' : 'border-ark-error/30 bg-ark-error/5',
              )}>
                <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">Realized P/L</p>
                <p className={cn('fig mt-0.5 text-lg font-bold', selected.realized_profit_loss >= 0 ? 'text-ark-success' : 'text-ark-error')}>
                  {formatCurrency(selected.realized_profit_loss, undefined, { sign: true })}
                </p>
                {selected.cost_basis_per_unit != null && (
                  <p className="fig text-[11px] text-ark-text-tertiary">Cost basis {formatCurrency(selected.cost_basis_per_unit)} / unit</p>
                )}
              </div>
            )}

            {selected.emotional_state && (
              <div className="rounded-xl bg-ark-fill-secondary/40 px-3 py-2.5">
                <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">Emotional state</p>
                <p className="mt-0.5 text-sm capitalize text-ark-text">{selected.emotional_state}</p>
              </div>
            )}

            {selected.notes && (
              <div className="rounded-xl bg-ark-fill-secondary/40 px-3 py-2.5">
                <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">Notes</p>
                <p className="mt-0.5 text-sm text-ark-text-secondary">{selected.notes}</p>
              </div>
            )}

            <div className="flex justify-end border-t border-ark-divider pt-3">
              <button
                onClick={() => { setDeleteTarget(selected); setSelected(null); }}
                className="flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-xs font-medium text-ark-error transition-colors hover:bg-ark-error/10"
              >
                <Trash2 className="h-3.5 w-3.5" /> Delete transaction
              </button>
            </div>
          </div>
        )}
      </DetailDrawer>

      {/* Delete confirmation */}
      <ConfirmDialog
        open={deleteTarget !== null}
        title={`Delete this ${deleteTarget ? TYPE_META[deleteTarget.type]?.label.toLowerCase() : 'transaction'}?`}
        message="This removes the transaction and recalculates your holdings for this asset. This cannot be undone."
        confirmLabel="Delete"
        destructive
        loading={deleteTx.isPending}
        onConfirm={() => {
          if (!deleteTarget) return;
          deleteTx.mutate({ txId: deleteTarget.id, symbol: deleteTarget.symbol }, {
            onSuccess: () => { setDeleteTarget(null); toast.success('Transaction deleted — holdings recalculated'); },
            onError: () => toast.error('Could not delete transaction. Please try again.'),
          });
        }}
        onCancel={() => setDeleteTarget(null)}
      />
    </GlassCard>
  );
}
