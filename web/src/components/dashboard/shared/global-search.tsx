'use client';

import { useState, useEffect, useRef } from 'react';
import { createPortal } from 'react-dom';
import { useRouter } from 'next/navigation';
import { Search, Home, LineChart, Briefcase, Bell, Radio, Settings, User, CornerDownLeft } from 'lucide-react';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';

const PAGES = [
  { label: 'Home', href: '/dashboard', icon: Home },
  { label: 'Market', href: '/dashboard/market', icon: LineChart },
  { label: 'Portfolio', href: '/dashboard/portfolio', icon: Briefcase },
  { label: 'DCA Reminders', href: '/dashboard/dca', icon: Bell },
  { label: 'Broadcasts', href: '/dashboard/broadcasts', icon: Radio },
  { label: 'Settings', href: '/dashboard/settings', icon: Settings },
  { label: 'Profile', href: '/dashboard/profile', icon: User },
];

export function GlobalSearch({ open, onClose }: { open: boolean; onClose: () => void }) {
  const router = useRouter();
  const { data: assets } = useCryptoAssets(1);
  const [q, setQ] = useState('');
  const [mounted, setMounted] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  useEffect(() => setMounted(true), []);

  useEffect(() => {
    if (open) { setQ(''); setTimeout(() => inputRef.current?.focus(), 40); }
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!mounted || !open) return null;

  const term = q.trim().toLowerCase();
  const coins = term
    ? (assets ?? []).filter((a) => a.symbol.toLowerCase().includes(term) || a.name.toLowerCase().includes(term)).slice(0, 7)
    : [];
  const pages = PAGES.filter((p) => !term || p.label.toLowerCase().includes(term));

  const go = (href: string) => { router.push(href); onClose(); };
  const onEnter = () => {
    if (coins.length) go(`/dashboard/market/${coins[0].id}`);
    else if (pages.length) go(pages[0].href);
  };

  return createPortal(
    <div className="fixed inset-0 z-[60] flex items-start justify-center bg-black/50 px-4 pt-[12vh] backdrop-blur-sm" onClick={onClose}>
      <div className="w-full max-w-xl overflow-hidden rounded-2xl border border-ark-divider bg-ark-bg shadow-2xl" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center gap-2 border-b border-ark-divider px-4">
          <Search className="h-4 w-4 text-ark-text-disabled" />
          <input
            ref={inputRef} value={q} onChange={(e) => setQ(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') onEnter(); }}
            placeholder="Search coins or jump to a page…"
            className="h-14 w-full bg-transparent text-sm text-ark-text outline-none placeholder:text-ark-text-disabled"
          />
          <kbd className="hidden rounded border border-ark-divider px-1.5 py-0.5 text-[10px] text-ark-text-disabled sm:inline">esc</kbd>
        </div>

        <div className="max-h-[50vh] overflow-y-auto p-2">
          {coins.length > 0 && (
            <div className="mb-1">
              <p className="px-2 py-1 text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">Coins</p>
              {coins.map((a) => {
                const up = (a.price_change_percentage_24h ?? 0) >= 0;
                return (
                  <button key={a.id} onClick={() => go(`/dashboard/market/${a.id}`)}
                    className="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-ark-fill-secondary">
                    {a.image ? <img src={a.image} alt={a.name} className="h-6 w-6 rounded-full" /> : <span className="h-6 w-6 rounded-full bg-ark-fill-secondary" />}
                    <span className="flex-1 text-sm text-ark-text"><b>{a.symbol.toUpperCase()}</b> <span className="text-ark-text-disabled">{a.name}</span></span>
                    <span className="fig text-xs text-ark-text-secondary">{formatCurrency(a.current_price)}</span>
                    <span className={cn('fig w-14 text-right text-xs font-semibold', up ? 'text-ark-success' : 'text-ark-error')}>{formatPercent(a.price_change_percentage_24h ?? 0)}</span>
                  </button>
                );
              })}
            </div>
          )}

          <div>
            <p className="px-2 py-1 text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">Pages</p>
            {pages.map((p) => (
              <button key={p.href} onClick={() => go(p.href)}
                className="flex w-full items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-ark-fill-secondary">
                <p.icon className="h-4 w-4 text-ark-text-tertiary" />
                <span className="flex-1 text-sm text-ark-text">{p.label}</span>
              </button>
            ))}
          </div>

          {term && coins.length === 0 && pages.length === 0 && (
            <p className="px-2 py-6 text-center text-sm text-ark-text-tertiary">No results for &ldquo;{q}&rdquo;.</p>
          )}
        </div>

        <div className="flex items-center gap-2 border-t border-ark-divider px-4 py-2 text-[11px] text-ark-text-disabled">
          <CornerDownLeft className="h-3 w-3" /> to open
        </div>
      </div>
    </div>,
    document.body,
  );
}
