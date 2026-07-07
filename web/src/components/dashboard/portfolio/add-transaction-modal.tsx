'use client';

import { useState, useMemo, useEffect } from 'react';
import { Search, Loader2 } from 'lucide-react';
import { DetailDrawer } from '@/components/ui/detail-drawer';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import { useRecordTransaction } from '@/lib/hooks/use-portfolio-mutations';
import { cn, formatCurrency } from '@/lib/utils/format';
import type { PortfolioHolding } from '@/types';

interface Props {
  open: boolean;
  onClose: () => void;
  portfolioId: string | undefined;
  holdings: PortfolioHolding[];
  initialType?: 'buy' | 'sell';
  initialSymbol?: string;
}

export function AddTransactionModal({ open, onClose, portfolioId, holdings, initialType = 'buy', initialSymbol }: Props) {
  const { data: assets } = useCryptoAssets(1);
  const record = useRecordTransaction(portfolioId);

  const [type, setType] = useState<'buy' | 'sell'>(initialType);
  const [symbol, setSymbol] = useState('');
  const [name, setName] = useState('');
  const [assetType, setAssetType] = useState('crypto');
  const [search, setSearch] = useState('');
  const [qty, setQty] = useState('');
  const [price, setPrice] = useState('');
  const [date, setDate] = useState(() => new Date().toISOString().split('T')[0]);
  const [notes, setNotes] = useState('');
  const [error, setError] = useState('');

  const priceBySymbol = useMemo(() => {
    const m = new Map<string, { price: number; name: string }>();
    for (const a of assets ?? []) m.set(a.symbol.toLowerCase(), { price: a.current_price, name: a.name });
    return m;
  }, [assets]);

  // reset when opened
  useEffect(() => {
    if (open) {
      setType(initialType);
      setError('');
      if (initialSymbol) {
        const live = priceBySymbol.get(initialSymbol.toLowerCase());
        const held = holdings.find((h) => h.symbol.toLowerCase() === initialSymbol.toLowerCase());
        setSymbol(initialSymbol.toUpperCase());
        setName(held?.name ?? live?.name ?? initialSymbol.toUpperCase());
        setAssetType(held?.asset_type ?? 'crypto');
        setPrice(live?.price ? String(live.price) : '');
      } else {
        setSymbol(''); setName(''); setPrice('');
      }
      setQty(''); setNotes(''); setSearch('');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  const results = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) return [];
    return (assets ?? [])
      .filter((a) => a.symbol.toLowerCase().includes(term) || a.name.toLowerCase().includes(term))
      .slice(0, 6);
  }, [search, assets]);

  const heldForSell = holdings.filter((h) => h.quantity > 0);
  const selectedHolding = holdings.find((h) => h.symbol.toLowerCase() === symbol.toLowerCase());
  const total = (parseFloat(qty) || 0) * (parseFloat(price) || 0);

  const pickAsset = (sym: string, nm: string, aType: string, livePrice?: number) => {
    setSymbol(sym.toUpperCase());
    setName(nm);
    setAssetType(aType);
    if (livePrice != null) setPrice(String(livePrice));
    setSearch('');
    setError('');
  };

  const submit = async () => {
    setError('');
    const q = parseFloat(qty);
    const p = parseFloat(price);
    if (!symbol) return setError('Choose an asset.');
    if (!q || q <= 0) return setError('Enter a valid quantity.');
    if (!p || p < 0) return setError('Enter a valid price.');
    if (type === 'sell' && selectedHolding && q > selectedHolding.quantity + 1e-9) {
      return setError(`You only hold ${selectedHolding.quantity} ${symbol.toUpperCase()}.`);
    }
    try {
      await record.mutateAsync({
        type, asset_type: assetType, symbol, name: name || symbol.toUpperCase(),
        quantity: q, price_per_unit: p, date: new Date(date + 'T12:00:00').toISOString(), notes: notes || undefined,
      });
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Something went wrong.');
    }
  };

  return (
    <DetailDrawer open={open} onClose={onClose} title="Add Transaction">
      <div className="space-y-5 pb-2">
        {/* Buy / Sell */}
        <div className="grid grid-cols-2 gap-2">
          {(['buy', 'sell'] as const).map((t) => (
            <button
              key={t}
              onClick={() => { setType(t); setSymbol(''); setName(''); setPrice(''); setError(''); }}
              className={cn('rounded-xl py-2.5 text-sm font-semibold capitalize transition-colors',
                type === t ? (t === 'buy' ? 'bg-ark-success text-white' : 'bg-ark-error text-white') : 'bg-ark-fill-secondary text-ark-text-tertiary')}
            >
              {t}
            </button>
          ))}
        </div>

        {/* Asset */}
        {type === 'buy' ? (
          <div>
            <label className="mb-1.5 block text-xs font-semibold text-ark-text-secondary">Asset</label>
            {symbol ? (
              <div className="flex items-center justify-between rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-3">
                <div><span className="text-sm font-bold text-ark-text">{symbol}</span> <span className="text-xs text-ark-text-disabled">{name}</span></div>
                <button onClick={() => { setSymbol(''); setName(''); setPrice(''); }} className="text-xs font-semibold text-ark-info">Change</button>
              </div>
            ) : (
              <div className="relative">
                <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ark-text-disabled" />
                <input
                  value={search} onChange={(e) => setSearch(e.target.value)}
                  placeholder="Search coins (BTC, ETH…) or type a ticker"
                  className="w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 py-2.5 pl-9 pr-3 text-sm text-ark-text outline-none focus:border-ark-info"
                />
                {results.length > 0 && (
                  <div className="mt-1 overflow-hidden rounded-xl border border-ark-divider bg-ark-card">
                    {results.map((a) => (
                      <button key={a.id} onClick={() => pickAsset(a.symbol, a.name, 'crypto', a.current_price)}
                        className="flex w-full items-center justify-between px-3 py-2 text-left hover:bg-ark-fill-secondary">
                        <span className="text-sm text-ark-text"><b>{a.symbol.toUpperCase()}</b> <span className="text-ark-text-disabled">{a.name}</span></span>
                        <span className="fig text-xs text-ark-text-tertiary">{formatCurrency(a.current_price)}</span>
                      </button>
                    ))}
                  </div>
                )}
                {search.trim() && results.length === 0 && (
                  <button onClick={() => pickAsset(search.trim(), search.trim().toUpperCase(), 'crypto')}
                    className="mt-1 w-full rounded-xl border border-dashed border-ark-divider px-3 py-2 text-left text-xs text-ark-text-secondary hover:bg-ark-fill-secondary">
                    Use &ldquo;{search.trim().toUpperCase()}&rdquo; as a custom ticker
                  </button>
                )}
              </div>
            )}
          </div>
        ) : (
          <div>
            <label className="mb-1.5 block text-xs font-semibold text-ark-text-secondary">Holding to sell</label>
            {heldForSell.length === 0 ? (
              <p className="text-sm text-ark-text-tertiary">No holdings to sell.</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {heldForSell.map((h) => (
                  <button key={h.id}
                    onClick={() => pickAsset(h.symbol, h.name, h.asset_type, priceBySymbol.get(h.symbol.toLowerCase())?.price)}
                    className={cn('rounded-lg border px-3 py-1.5 text-sm font-semibold', symbol.toLowerCase() === h.symbol.toLowerCase() ? 'border-ark-error bg-ark-error/10 text-ark-error' : 'border-ark-divider text-ark-text-secondary')}>
                    {h.symbol.toUpperCase()} <span className="fig text-[11px] text-ark-text-disabled">×{h.quantity}</span>
                  </button>
                ))}
              </div>
            )}
          </div>
        )}

        {/* Quantity + Price */}
        <div className="grid grid-cols-2 gap-3">
          <div>
            <label className="mb-1.5 block text-xs font-semibold text-ark-text-secondary">Quantity</label>
            <input type="number" inputMode="decimal" value={qty} onChange={(e) => setQty(e.target.value)} placeholder="0.00"
              className="w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 px-3 py-2.5 text-sm text-ark-text outline-none focus:border-ark-info" />
          </div>
          <div>
            <label className="mb-1.5 block text-xs font-semibold text-ark-text-secondary">Price / unit (USD)</label>
            <input type="number" inputMode="decimal" value={price} onChange={(e) => setPrice(e.target.value)} placeholder="0.00"
              className="w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 px-3 py-2.5 text-sm text-ark-text outline-none focus:border-ark-info" />
          </div>
        </div>

        {/* Date */}
        <div>
          <label className="mb-1.5 block text-xs font-semibold text-ark-text-secondary">Date</label>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)}
            className="w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 px-3 py-2.5 text-sm text-ark-text outline-none focus:border-ark-info" />
        </div>

        {/* Total */}
        <div className="flex items-center justify-between rounded-xl bg-ark-fill-secondary/40 px-4 py-3">
          <span className="text-sm text-ark-text-secondary">Total {type === 'buy' ? 'cost' : 'proceeds'}</span>
          <span className="fig text-lg font-bold text-ark-text">{formatCurrency(total)}</span>
        </div>

        {error && <p className="rounded-lg bg-ark-error/10 px-3 py-2 text-sm text-ark-error">{error}</p>}

        <button onClick={submit} disabled={record.isPending}
          className={cn('flex w-full items-center justify-center gap-2 rounded-xl py-3 text-sm font-semibold text-white transition-colors disabled:opacity-60',
            type === 'buy' ? 'bg-ark-success' : 'bg-ark-error')}>
          {record.isPending && <Loader2 className="h-4 w-4 animate-spin" />}
          {type === 'buy' ? 'Add Purchase' : 'Record Sale'}
        </button>
      </div>
    </DetailDrawer>
  );
}
