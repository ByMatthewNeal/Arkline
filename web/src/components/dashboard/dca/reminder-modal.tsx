'use client';

import { useState, useMemo, useEffect } from 'react';
import { Search, Loader2 } from 'lucide-react';
import { DetailDrawer } from '@/components/ui/detail-drawer';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import { useCreateReminder, useUpdateReminder } from '@/lib/hooks/use-dca-mutations';
import { cn, localDateISO } from '@/lib/utils/format';
import { CoinIcon } from '@/components/dashboard/shared/coin-icon';
import type { DCAReminder } from '@/types';

const FREQUENCIES = [
  { value: 'daily', label: 'Daily' },
  { value: 'twice_weekly', label: 'Twice Weekly' },
  { value: 'weekly', label: 'Weekly' },
  { value: 'biweekly', label: 'Bi-weekly' },
  { value: 'monthly', label: 'Monthly' },
];

interface Props {
  open: boolean;
  onClose: () => void;
  editing?: DCAReminder | null;
}

export function ReminderModal({ open, onClose, editing }: Props) {
  const { data: assets } = useCryptoAssets(1);
  const create = useCreateReminder();
  const update = useUpdateReminder();

  const [symbol, setSymbol] = useState('');
  const [name, setName] = useState('');
  const [search, setSearch] = useState('');
  const [amount, setAmount] = useState('');
  const [frequency, setFrequency] = useState('weekly');
  const [time, setTime] = useState('09:00');
  const [startDate, setStartDate] = useState(() => localDateISO());
  const [error, setError] = useState('');

  useEffect(() => {
    if (open) {
      setError('');
      if (editing) {
        setSymbol(editing.symbol.toUpperCase());
        setName(editing.name);
        setAmount(String(editing.amount));
        setFrequency(editing.frequency);
        setTime((editing.notification_time ?? '09:00:00').slice(0, 5));
        setStartDate(editing.start_date);
      } else {
        setSymbol(''); setName(''); setAmount(''); setFrequency('weekly'); setTime('09:00');
        setStartDate(localDateISO());
      }
      setSearch('');
    }
  }, [open, editing]);

  const results = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return [];
    return (assets ?? []).filter((a) => a.symbol.toLowerCase().includes(term) || a.name.toLowerCase().includes(term)).slice(0, 6);
  }, [search, assets]);

  const submit = async () => {
    setError('');
    const amt = parseFloat(amount);
    if (!symbol) return setError('Choose an asset.');
    if (!amt || amt <= 0) return setError('Enter a valid amount.');
    try {
      const input = { symbol, name: name || symbol, amount: amt, frequency, notification_time: time, start_date: startDate };
      if (editing) await update.mutateAsync({ id: editing.id, patch: input });
      else await create.mutateAsync(input);
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Something went wrong.');
    }
  };

  const pending = create.isPending || update.isPending;

  return (
    <DetailDrawer open={open} onClose={onClose} title={editing ? 'Edit Reminder' : 'New DCA Reminder'}>
      <div className="space-y-5 pb-2">
        {/* Asset */}
        <div>
          <label className="mb-1.5 block text-xs font-semibold text-ark-text-secondary">Asset</label>
          {symbol ? (
            <div className="flex items-center justify-between rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-3">
              <div><span className="text-sm font-bold text-ark-text">{symbol}</span> <span className="text-xs text-ark-text-disabled">{name}</span></div>
              <button onClick={() => { setSymbol(''); setName(''); }} className="text-xs font-semibold text-ark-info">Change</button>
            </div>
          ) : (
            <div className="relative">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ark-text-disabled" />
              <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search coins (BTC, ETH…)"
                className="w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 py-2.5 pl-9 pr-3 text-sm text-ark-text outline-none focus:border-ark-info" />
              {results.length > 0 && (
                <div className="mt-1 overflow-hidden rounded-xl border border-ark-divider bg-ark-card">
                  {results.map((a) => (
                    <button key={a.id} onClick={() => { setSymbol(a.symbol.toUpperCase()); setName(a.name); setSearch(''); }}
                      className="flex w-full items-center gap-2.5 px-3 py-2 text-left hover:bg-ark-fill-secondary">
                      <CoinIcon symbol={a.symbol} size="sm" />
                      <span className="text-sm text-ark-text"><b>{a.symbol.toUpperCase()}</b> <span className="text-ark-text-disabled">{a.name}</span></span>
                    </button>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        {/* Amount */}
        <div>
          <label className="mb-1.5 block text-xs font-semibold text-ark-text-secondary">Amount per purchase (USD)</label>
          <input type="number" inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="100.00"
            className="w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 px-3 py-2.5 text-sm text-ark-text outline-none focus:border-ark-info" />
        </div>

        {/* Frequency */}
        <div>
          <label className="mb-1.5 block text-xs font-semibold text-ark-text-secondary">Frequency</label>
          <div className="flex flex-wrap gap-2">
            {FREQUENCIES.map((f) => (
              <button key={f.value} onClick={() => setFrequency(f.value)}
                className={cn('rounded-lg border px-3 py-1.5 text-sm font-medium transition-colors', frequency === f.value ? 'border-ark-primary bg-ark-primary/10 text-ark-primary' : 'border-ark-divider text-ark-text-secondary')}>
                {f.label}
              </button>
            ))}
          </div>
        </div>

        {/* Time + Start date */}
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="mb-1.5 block text-xs font-semibold text-ark-text-secondary">Reminder time</label>
            <input type="time" value={time} onChange={(e) => setTime(e.target.value)}
              className="w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 px-3 py-2.5 text-sm text-ark-text outline-none focus:border-ark-info" />
          </div>
          <div>
            <label className="mb-1.5 block text-xs font-semibold text-ark-text-secondary">Start date</label>
            <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)}
              className="w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 px-3 py-2.5 text-sm text-ark-text outline-none focus:border-ark-info" />
          </div>
        </div>

        {error && <p className="rounded-lg bg-ark-error/10 px-3 py-2 text-sm text-ark-error">{error}</p>}

        <button onClick={submit} disabled={pending}
          className="flex w-full items-center justify-center gap-2 rounded-xl bg-ark-primary py-3 text-sm font-semibold text-white transition-colors hover:brightness-110 disabled:opacity-60">
          {pending && <Loader2 className="h-4 w-4 animate-spin" />}
          {editing ? 'Save Changes' : 'Create Reminder'}
        </button>
      </div>
    </DetailDrawer>
  );
}
