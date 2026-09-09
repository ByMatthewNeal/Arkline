'use client';

import { useEffect, useState } from 'react';
import { DetailDrawer } from '@/components/ui';
import { getPreferredCurrency, formatCurrency, cn } from '@/lib/utils/format';

/**
 * Investment Budget calculator (web).
 *
 * A BUDGETING tool, not investment advice: it only does arithmetic on numbers
 * the user enters, and the user chooses the share of their surplus. It never
 * recommends an amount or allocation, and never projects returns (the "over a
 * year" figure is just contributions × 12). Keep it that way.
 */

interface Props {
  open: boolean;
  onClose: () => void;
  /** Called with the chosen monthly amount to hand off to a DCA reminder. */
  onSetupDca?: (amount: number) => void;
}

function currencySymbol(code: string): string {
  try {
    const parts = new Intl.NumberFormat(undefined, { style: 'currency', currency: code }).formatToParts(0);
    return parts.find((p) => p.type === 'currency')?.value ?? code;
  } catch {
    return code;
  }
}

function readLS(key: string): string {
  if (typeof window === 'undefined') return '';
  try {
    return localStorage.getItem(key) ?? '';
  } catch {
    return '';
  }
}

// Preset "how much of your surplus to invest" starting points — budgeting
// intensities the user chooses, NOT asset-risk levels or a recommendation.
const PACES = [
  { label: 'Conservative', pct: 25 },
  { label: 'Moderate', pct: 50 },
  { label: 'Aggressive', pct: 75 },
] as const;

function Field({
  label, sub, value, onChange, sym,
}: {
  label: string; sub: string; value: string; onChange: (v: string) => void; sym: string;
}) {
  return (
    <div className="flex items-center justify-between gap-3">
      <div className="min-w-0">
        <p className="text-sm font-medium text-ark-text">{label}</p>
        <p className="text-[11px] text-ark-text-tertiary">{sub}</p>
      </div>
      <div className="flex items-center gap-1 rounded-lg bg-ark-fill-secondary px-2.5 py-1.5">
        <span className="text-sm text-ark-text-tertiary">{sym}</span>
        <input
          inputMode="decimal"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder="0"
          className="w-20 bg-transparent text-right text-sm font-semibold text-ark-text outline-none"
        />
      </div>
    </div>
  );
}

export function BudgetCalculatorDrawer({ open, onClose, onSetupDca }: Props) {
  const currency = getPreferredCurrency();
  const sym = currencySymbol(currency);

  const [income, setIncome] = useState(() => readLS('ark_budget_income'));
  const [expenses, setExpenses] = useState(() => readLS('ark_budget_expenses'));
  const [savings, setSavings] = useState(() => readLS('ark_budget_savings'));
  const [fun, setFun] = useState(() => readLS('ark_budget_fun'));
  const [sharePct, setSharePct] = useState<number>(() => Number(readLS('ark_budget_share')) || 0);

  // Persist inputs on-device only (no financial data leaves the browser).
  useEffect(() => {
    try {
      localStorage.setItem('ark_budget_income', income);
      localStorage.setItem('ark_budget_expenses', expenses);
      localStorage.setItem('ark_budget_savings', savings);
      localStorage.setItem('ark_budget_fun', fun);
      localStorage.setItem('ark_budget_share', String(sharePct));
    } catch { /* ignore */ }
  }, [income, expenses, savings, fun, sharePct]);

  const num = (s: string) => {
    const n = parseFloat(s.replace(',', '.'));
    return Number.isFinite(n) ? n : 0;
  };
  const surplus = Math.max(0, num(income) - num(expenses) - num(savings) - num(fun));
  const investMonthly = (surplus * sharePct) / 100;
  const investAnnual = investMonthly * 12;

  return (
    <DetailDrawer open={open} onClose={onClose} title="Investment Budget">
      <div className="space-y-5">
        <div>
          <h2 className="text-lg font-bold text-ark-text">What can I invest?</h2>
          <p className="mt-1 text-sm text-ark-text-tertiary">
            Enter your own numbers to see what&apos;s left over each month. You decide how much of that surplus to
            put toward investing — nothing here is a recommendation.
          </p>
        </div>

        <div className="space-y-3 rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
          <Field label="Monthly income" sub="Your take-home pay" value={income} onChange={setIncome} sym={sym} />
          <Field label="Fixed expenses" sub="Rent, insurance, bills, gas, subscriptions" value={expenses} onChange={setExpenses} sym={sym} />
          <Field label="Monthly savings" sub="Cash you set aside" value={savings} onChange={setSavings} sym={sym} />
          <Field label="Fun money" sub="Eating out, gifts, trips (optional)" value={fun} onChange={setFun} sym={sym} />
        </div>

        {surplus > 0 ? (
          <div className="space-y-4 rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4">
            <div className="flex items-center justify-between">
              <span className="text-xs text-ark-text-tertiary">Left over to invest</span>
              <span className="fig text-base font-bold text-ark-text">{formatCurrency(surplus, currency)}</span>
            </div>

            <div className="space-y-2.5">
              <span className="text-sm font-medium text-ark-text">How much of your surplus to invest?</span>
              <div className="grid grid-cols-3 gap-2">
                {PACES.map((p) => {
                  const selected = Math.round(sharePct) === p.pct;
                  return (
                    <button
                      key={p.label}
                      onClick={() => setSharePct(p.pct)}
                      className={cn(
                        'rounded-lg py-2 text-center transition-colors',
                        selected ? 'bg-ark-primary text-white' : 'bg-ark-primary/10 text-ark-primary hover:bg-ark-primary/20',
                      )}
                    >
                      <span className="block text-xs font-semibold">{p.label}</span>
                      <span className="block text-[11px] opacity-85">{p.pct}%</span>
                    </button>
                  );
                })}
              </div>
              <div className="flex items-center gap-3">
                <input
                  type="range" min={0} max={100} step={5} value={sharePct}
                  onChange={(e) => setSharePct(Number(e.target.value))}
                  className="w-full accent-[var(--ark-primary)]"
                />
                <span className="fig w-10 text-right text-sm font-bold text-ark-primary">{Math.round(sharePct)}%</span>
              </div>
              <p className="text-[11px] text-ark-text-disabled">A starting point — slide to fine-tune. Your call, not a recommendation.</p>
            </div>

            <div>
              <p className="text-xs text-ark-text-tertiary">You&apos;d invest</p>
              <p className="fig text-3xl font-bold text-ark-primary">
                {formatCurrency(investMonthly, currency)} <span className="text-lg font-semibold">/ mo</span>
              </p>
              <p className="mt-0.5 text-xs text-ark-text-disabled">
                ≈ {formatCurrency(investAnnual, currency)} contributed over a year at this pace
              </p>
            </div>

            <button
              onClick={() => { if (investMonthly > 0) onSetupDca?.(investMonthly); }}
              disabled={investMonthly <= 0}
              className={cn(
                'w-full rounded-xl bg-ark-primary py-3 text-sm font-semibold text-white transition-all',
                investMonthly <= 0 ? 'opacity-50' : 'hover:brightness-110',
              )}
            >
              Set up a monthly DCA reminder
            </button>
            <p className="text-xs text-ark-text-disabled">
              Then choose a strategy — the Model Portfolios card on this page shows what each one holds.
            </p>
          </div>
        ) : (
          <p className="rounded-2xl border border-ark-divider bg-ark-fill-secondary/20 p-4 text-sm text-ark-text-tertiary">
            Enter your income and expenses above to see your investable surplus.
          </p>
        )}

        <p className="text-[11px] leading-relaxed text-ark-text-disabled">
          This is a budgeting tool, not financial advice. It only does math on the numbers you enter and the share
          you choose — it doesn&apos;t recommend an amount or an allocation, and it doesn&apos;t project investment
          returns. Always do your own research.
        </p>
      </div>
    </DetailDrawer>
  );
}
