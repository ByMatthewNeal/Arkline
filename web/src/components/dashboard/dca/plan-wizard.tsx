'use client';

/**
 * DCA Plan Wizard — desktop version of the iOS DCA calculator.
 * Steps: budget → assets & split → schedule → review.
 * Creates one time-based reminder per asset. (Risk-based strategies remain
 * iOS-only until the risk-reminder infra lands on web.)
 */

import { useMemo, useState } from 'react';
import { createPortal } from 'react-dom';
import { AnimatePresence, motion } from 'framer-motion';
import { X, Search, ChevronLeft, ChevronRight, Check, CalendarDays, Wallet, PieChart } from 'lucide-react';
import { Button, useToast } from '@/components/ui';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import { useCreateReminder } from '@/lib/hooks/use-dca-mutations';
import { formatCurrency, cn, localDateISO } from '@/lib/utils/format';
import { useMounted } from '@/lib/hooks/use-mounted';

const FREQUENCIES = [
  { key: 'daily', label: 'Daily', perMonth: 30 },
  { key: 'twice_weekly', label: 'Twice weekly', perMonth: 8.7 },
  { key: 'weekly', label: 'Weekly', perMonth: 4.33 },
  { key: 'biweekly', label: 'Bi-weekly', perMonth: 2.17 },
  { key: 'monthly', label: 'Monthly', perMonth: 1 },
] as const;

const DURATIONS = [
  { label: '3 months', months: 3 },
  { label: '6 months', months: 6 },
  { label: '1 year', months: 12 },
  { label: 'Ongoing', months: 0 },
] as const;

interface PlanAsset {
  symbol: string;
  name: string;
  split: number; // percent
}

const STEPS = ['Budget', 'Assets', 'Schedule', 'Review'] as const;

export function PlanWizard({ open, onClose }: { open: boolean; onClose: () => void }) {
  const mounted = useMounted();
  const toast = useToast();
  const createReminder = useCreateReminder();
  const { data: coins } = useCryptoAssets(1);

  const [step, setStep] = useState(0);
  const [amount, setAmount] = useState(100); // per-purchase budget
  const [assets, setAssets] = useState<PlanAsset[]>([]);
  const [search, setSearch] = useState('');
  const [frequency, setFrequency] = useState<(typeof FREQUENCIES)[number]>(FREQUENCIES[2]);
  const [time, setTime] = useState('09:00');
  const [startDate, setStartDate] = useState(() => localDateISO());
  const [durationMonths, setDurationMonths] = useState(0);
  const [saving, setSaving] = useState(false);

  const results = useMemo(() => {
    if (!search.trim()) return [];
    const q = search.toLowerCase();
    return (coins ?? [])
      .filter((c) => c.symbol.toLowerCase().includes(q) || c.name.toLowerCase().includes(q))
      .filter((c) => !assets.some((a) => a.symbol === c.symbol.toUpperCase()))
      .slice(0, 6);
  }, [search, coins, assets]);

  const splitTotal = assets.reduce((s, a) => s + a.split, 0);
  const totalPurchases = durationMonths > 0 ? Math.round(durationMonths * frequency.perMonth) : 0;
  const projectedTotal = totalPurchases * amount;

  const rebalanceSplits = (list: PlanAsset[]): PlanAsset[] => {
    const even = Math.floor(100 / (list.length || 1));
    return list.map((a, i) => ({ ...a, split: i === 0 ? 100 - even * (list.length - 1) : even }));
  };

  const addAsset = (symbol: string, name: string) => {
    if (assets.length >= 5) return;
    setAssets((prev) => rebalanceSplits([...prev, { symbol: symbol.toUpperCase(), name, split: 0 }]));
    setSearch('');
  };

  const removeAsset = (symbol: string) => {
    setAssets((prev) => rebalanceSplits(prev.filter((a) => a.symbol !== symbol)));
  };

  const setSplit = (symbol: string, split: number) => {
    setAssets((prev) => prev.map((a) => (a.symbol === symbol ? { ...a, split } : a)));
  };

  const canNext =
    step === 0 ? amount > 0 :
    step === 1 ? assets.length > 0 && Math.abs(splitTotal - 100) < 0.5 :
    true;

  const finish = async () => {
    setSaving(true);
    try {
      for (const a of assets) {
        await createReminder.mutateAsync({
          symbol: a.symbol,
          name: a.name,
          amount: Math.round(amount * (a.split / 100) * 100) / 100,
          frequency: frequency.key,
          notification_time: time,
          start_date: startDate,
          total_purchases: totalPurchases || undefined,
        });
      }
      toast.success(`Plan created — ${assets.length} reminder${assets.length > 1 ? 's' : ''} scheduled`);
      onClose();
      setStep(0);
      setAssets([]);
    } catch {
      toast.error('Could not create the plan. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  if (!mounted) return null;

  return createPortal(
    <AnimatePresence>
      {open && (
        <motion.div
          initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
          className="fixed inset-0 z-[150] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm"
          onClick={onClose}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.96, y: 10 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={{ opacity: 0, scale: 0.96, y: 10 }}
            transition={{ type: 'spring', stiffness: 380, damping: 32 }}
            className="flex max-h-[90vh] w-full max-w-lg flex-col overflow-hidden rounded-2xl border border-ark-divider bg-ark-card shadow-2xl"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header + progress */}
            <div className="border-b border-ark-divider p-4">
              <div className="flex items-center justify-between">
                <h3 className="font-[family-name:var(--font-urbanist)] text-base font-semibold text-ark-text">DCA Plan</h3>
                <button onClick={onClose} className="flex h-8 w-8 items-center justify-center rounded-lg text-ark-text-tertiary hover:bg-ark-fill-secondary">
                  <X className="h-4 w-4" />
                </button>
              </div>
              <div className="mt-3 flex items-center gap-1.5">
                {STEPS.map((s, i) => (
                  <div key={s} className="flex flex-1 flex-col gap-1">
                    <div className={cn('h-1 rounded-full transition-colors', i <= step ? 'bg-ark-primary' : 'bg-ark-fill-secondary')} />
                    <span className={cn('text-[10px] font-medium', i === step ? 'text-ark-primary' : 'text-ark-text-disabled')}>{s}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Step body */}
            <div className="flex-1 overflow-y-auto p-5">
              {step === 0 && (
                <div className="space-y-4">
                  <div className="flex items-center gap-2 text-sm text-ark-text-secondary">
                    <Wallet className="h-4 w-4 text-ark-primary" /> How much per purchase?
                  </div>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-lg font-semibold text-ark-text-tertiary">$</span>
                    <input
                      type="number" min={1} value={amount || ''}
                      onChange={(e) => setAmount(Number(e.target.value))}
                      className="fig h-14 w-full rounded-xl border border-ark-divider bg-ark-fill-secondary pl-8 pr-3 text-2xl font-bold text-ark-text outline-none focus:border-ark-primary"
                    />
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {[25, 50, 100, 250, 500].map((v) => (
                      <button key={v} onClick={() => setAmount(v)}
                        className={cn('rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors',
                          amount === v ? 'bg-ark-primary text-white' : 'bg-ark-fill-secondary text-ark-text-secondary hover:bg-ark-divider')}>
                        ${v}
                      </button>
                    ))}
                  </div>
                  <p className="text-xs text-ark-text-tertiary">
                    This budget is split across the assets you pick next. Risk-based strategies (buy when BTC risk is low) are currently available in the iOS app.
                  </p>
                </div>
              )}

              {step === 1 && (
                <div className="space-y-4">
                  <div className="flex items-center gap-2 text-sm text-ark-text-secondary">
                    <PieChart className="h-4 w-4 text-ark-primary" /> Pick up to 5 assets and set the split
                  </div>
                  <div className="relative">
                    <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ark-text-tertiary" />
                    <input
                      value={search} onChange={(e) => setSearch(e.target.value)}
                      placeholder="Search coins…"
                      className="h-10 w-full rounded-xl border border-ark-divider bg-ark-fill-secondary pl-9 pr-3 text-sm text-ark-text outline-none focus:border-ark-primary"
                    />
                    {results.length > 0 && (
                      <div className="absolute inset-x-0 top-11 z-10 overflow-hidden rounded-xl border border-ark-divider bg-ark-card shadow-xl">
                        {results.map((c) => (
                          <button key={c.id} onClick={() => addAsset(c.symbol, c.name)}
                            className="flex w-full items-center justify-between px-3 py-2 text-left hover:bg-ark-fill-secondary">
                            <span className="text-sm text-ark-text">{c.name}</span>
                            <span className="fig text-xs text-ark-text-tertiary">{c.symbol.toUpperCase()}</span>
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                  <div className="space-y-2">
                    {assets.map((a) => (
                      <div key={a.symbol} className="flex items-center gap-3 rounded-xl border border-ark-divider p-2.5">
                        <span className="w-14 text-sm font-semibold text-ark-text">{a.symbol}</span>
                        <input
                          type="range" min={5} max={100} step={5} value={a.split}
                          onChange={(e) => setSplit(a.symbol, Number(e.target.value))}
                          className="flex-1 accent-[var(--ark-primary)]"
                        />
                        <span className="fig w-12 text-right text-sm font-medium text-ark-text-secondary">{a.split}%</span>
                        <span className="fig w-16 text-right text-xs text-ark-text-tertiary">{formatCurrency(amount * (a.split / 100))}</span>
                        <button onClick={() => removeAsset(a.symbol)} className="text-ark-text-tertiary hover:text-ark-error"><X className="h-3.5 w-3.5" /></button>
                      </div>
                    ))}
                  </div>
                  {assets.length > 0 && Math.abs(splitTotal - 100) >= 0.5 && (
                    <p className="text-xs font-medium text-ark-warning">Splits total {splitTotal}% — adjust to 100%.</p>
                  )}
                  {assets.length === 0 && <p className="text-xs text-ark-text-tertiary">Search above to add your first asset.</p>}
                </div>
              )}

              {step === 2 && (
                <div className="space-y-4">
                  <div className="flex items-center gap-2 text-sm text-ark-text-secondary">
                    <CalendarDays className="h-4 w-4 text-ark-primary" /> When should purchases happen?
                  </div>
                  <div className="flex flex-wrap gap-2">
                    {FREQUENCIES.map((f) => (
                      <button key={f.key} onClick={() => setFrequency(f)}
                        className={cn('rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors',
                          frequency.key === f.key ? 'bg-ark-primary text-white' : 'bg-ark-fill-secondary text-ark-text-secondary hover:bg-ark-divider')}>
                        {f.label}
                      </button>
                    ))}
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <label className="block">
                      <span className="text-xs font-medium text-ark-text-secondary">Reminder time</span>
                      <input type="time" value={time} onChange={(e) => setTime(e.target.value)}
                        className="fig mt-1 h-10 w-full rounded-xl border border-ark-divider bg-ark-fill-secondary px-3 text-sm text-ark-text outline-none focus:border-ark-primary" />
                    </label>
                    <label className="block">
                      <span className="text-xs font-medium text-ark-text-secondary">Start date</span>
                      <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)}
                        className="fig mt-1 h-10 w-full rounded-xl border border-ark-divider bg-ark-fill-secondary px-3 text-sm text-ark-text outline-none focus:border-ark-primary" />
                    </label>
                  </div>
                  <div>
                    <span className="text-xs font-medium text-ark-text-secondary">Plan length</span>
                    <div className="mt-1 flex flex-wrap gap-2">
                      {DURATIONS.map((d) => (
                        <button key={d.label} onClick={() => setDurationMonths(d.months)}
                          className={cn('rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors',
                            durationMonths === d.months ? 'bg-ark-primary text-white' : 'bg-ark-fill-secondary text-ark-text-secondary hover:bg-ark-divider')}>
                          {d.label}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              )}

              {step === 3 && (
                <div className="space-y-4">
                  <div className="rounded-xl bg-ark-fill-secondary/40 p-4">
                    <p className="fig text-2xl font-bold text-ark-text">{formatCurrency(amount)} <span className="text-sm font-normal text-ark-text-tertiary">per purchase · {frequency.label.toLowerCase()}</span></p>
                    <p className="mt-1 text-xs text-ark-text-tertiary">
                      Starting {startDate} at {time}
                      {totalPurchases > 0 && <> · {totalPurchases} purchases ≈ <span className="fig font-semibold text-ark-text-secondary">{formatCurrency(projectedTotal)}</span> total</>}
                      {totalPurchases === 0 && ' · ongoing until paused'}
                    </p>
                  </div>
                  <div className="space-y-1.5">
                    {assets.map((a) => (
                      <div key={a.symbol} className="flex items-center justify-between rounded-lg border border-ark-divider px-3 py-2">
                        <span className="text-sm font-medium text-ark-text">{a.name} <span className="fig text-xs text-ark-text-tertiary">{a.symbol}</span></span>
                        <span className="fig text-sm font-semibold text-ark-text">{formatCurrency(amount * (a.split / 100))} <span className="text-xs font-normal text-ark-text-tertiary">({a.split}%)</span></span>
                      </div>
                    ))}
                  </div>
                  <p className="text-[10px] leading-relaxed text-ark-text-disabled">
                    Creates one reminder per asset. Reminders appear in your notification feed and on the DCA page — this does not place trades automatically.
                  </p>
                </div>
              )}
            </div>

            {/* Footer nav */}
            <div className="flex items-center justify-between border-t border-ark-divider p-4">
              <Button variant="ghost" size="sm" onClick={() => (step === 0 ? onClose() : setStep(step - 1))} disabled={saving}>
                <ChevronLeft className="h-4 w-4" /> {step === 0 ? 'Cancel' : 'Back'}
              </Button>
              {step < STEPS.length - 1 ? (
                <Button size="sm" onClick={() => setStep(step + 1)} disabled={!canNext}>
                  Next <ChevronRight className="h-4 w-4" />
                </Button>
              ) : (
                <Button size="sm" onClick={finish} loading={saving}>
                  <Check className="h-4 w-4" /> Create plan
                </Button>
              )}
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>,
    document.body,
  );
}
