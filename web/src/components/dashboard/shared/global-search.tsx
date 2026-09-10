'use client';

import { useState, useEffect, useMemo, useRef } from 'react';
import { createPortal } from 'react-dom';
import { useRouter } from 'next/navigation';
import {
  Search, Home, LineChart, Briefcase, Bell, Radio, Settings, User,
  GraduationCap, MessagesSquare, BookOpen, ShieldCheck, CornerDownLeft, TrendingUp,
} from 'lucide-react';
import { useCryptoAssets } from '@/lib/hooks/use-market';
import { useAuth } from '@/lib/hooks/use-auth';
import { formatCurrency, formatPercent, cn } from '@/lib/utils/format';
import { useMounted } from '@/lib/hooks/use-mounted';

const PAGES = [
  { label: 'Home', href: '/dashboard', icon: Home },
  { label: 'Market', href: '/dashboard/market', icon: LineChart },
  { label: 'Portfolio', href: '/dashboard/portfolio', icon: Briefcase },
  { label: 'DCA Reminders', href: '/dashboard/dca', icon: Bell },
  { label: 'Learn', href: '/dashboard/learn', icon: GraduationCap },
  { label: 'Broadcasts', href: '/dashboard/broadcasts', icon: Radio },
  { label: 'Member Q&A', href: '/dashboard/qa', icon: MessagesSquare },
  { label: 'Dictionary', href: '/dashboard/dictionary', icon: BookOpen },
  { label: 'Settings', href: '/dashboard/settings', icon: Settings },
  { label: 'Profile', href: '/dashboard/profile', icon: User },
];

const ADMIN_PAGE = { label: 'Admin', href: '/dashboard/admin', icon: ShieldCheck };

interface Item {
  key: string;
  href: string;
  section: 'coins' | 'trending' | 'pages';
}

export function GlobalSearch({ open, onClose }: { open: boolean; onClose: () => void }) {
  const mounted = useMounted();
  if (!mounted || !open) return null;
  // Inner component mounts fresh on every open, so query + selection reset
  // without any setState-in-effect.
  return <Palette onClose={onClose} />;
}

function Palette({ onClose }: { onClose: () => void }) {
  const router = useRouter();
  const { data: assets } = useCryptoAssets(1);
  const { profile } = useAuth();
  const [q, setQ] = useState('');
  const [sel, setSel] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [onClose]);

  const term = q.trim().toLowerCase();

  const coins = useMemo(() => {
    const all = assets ?? [];
    if (term) {
      return all
        .filter((a) => a.symbol.toLowerCase().includes(term) || a.name.toLowerCase().includes(term))
        .slice(0, 7);
    }
    // Empty query: biggest 24h movers among the top 20 — something worth
    // glancing at, instead of an empty pane.
    return [...all.slice(0, 20)]
      .sort((a, b) => Math.abs(b.price_change_percentage_24h ?? 0) - Math.abs(a.price_change_percentage_24h ?? 0))
      .slice(0, 4);
  }, [assets, term]);

  const allPages = useMemo(
    () => (profile?.role === 'admin' ? [...PAGES, ADMIN_PAGE] : PAGES),
    [profile?.role],
  );
  const pages = useMemo(
    () => allPages.filter((p) => !term || p.label.toLowerCase().includes(term)),
    [allPages, term],
  );

  // Flat item list for arrow-key navigation (coins first, then pages).
  const items: Item[] = useMemo(() => [
    ...coins.map((a) => ({ key: `coin-${a.id}`, href: `/dashboard/market/${a.id}`, section: (term ? 'coins' : 'trending') as Item['section'] })),
    ...pages.map((p) => ({ key: `page-${p.href}`, href: p.href, section: 'pages' as const })),
  ], [coins, pages, term]);

  const clampedSel = Math.min(sel, Math.max(0, items.length - 1));

  const go = (href: string) => { router.push(href); onClose(); };

  const onInputKey = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setSel((s) => (s + 1) % Math.max(1, items.length));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setSel((s) => (s - 1 + Math.max(1, items.length)) % Math.max(1, items.length));
    } else if (e.key === 'Enter') {
      const item = items[clampedSel];
      if (item) go(item.href);
    } else {
      // Typing changes results — reset the highlight to the top hit.
      setSel(0);
    }
  };

  const rowCls = (idx: number) => cn(
    'flex w-full items-center gap-3 rounded-lg px-2.5 py-2 text-left transition-colors',
    idx === clampedSel ? 'bg-ark-primary/10' : 'hover:bg-ark-fill-secondary',
  );

  return createPortal(
    <div className="fixed inset-0 z-[60] flex items-start justify-center bg-black/50 px-4 pt-[12vh] backdrop-blur-sm" onClick={onClose}>
      <div className="w-full max-w-xl overflow-hidden rounded-2xl border border-ark-divider bg-ark-bg shadow-2xl" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center gap-2.5 border-b border-ark-divider px-4">
          <Search className="h-4 w-4 shrink-0 text-ark-text-disabled" />
          <input
            ref={inputRef} autoFocus value={q} onChange={(e) => setQ(e.target.value)}
            onKeyDown={onInputKey}
            placeholder="Search coins or jump to a page…"
            // The dialog frame is the visual affordance. The app's global
            // :focus-visible ring lives OUTSIDE Tailwind's cascade layers, so
            // utility classes can't override it — inline style can.
            style={{ outline: 'none' }}
            className="h-14 w-full bg-transparent text-sm text-ark-text placeholder:text-ark-text-disabled"
          />
          <kbd className="hidden shrink-0 rounded border border-ark-divider px-1.5 py-0.5 text-[10px] text-ark-text-disabled sm:inline">esc</kbd>
        </div>

        <div ref={listRef} className="max-h-[50vh] overflow-y-auto p-2">
          {coins.length > 0 && (
            <div className="mb-1">
              <p className="flex items-center gap-1.5 px-2.5 py-1.5 text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">
                {term ? 'Coins' : <><TrendingUp className="h-3 w-3" /> Moving today</>}
              </p>
              {coins.map((a, j) => {
                const i = j;
                const up = (a.price_change_percentage_24h ?? 0) >= 0;
                return (
                  <button key={a.id} onClick={() => go(`/dashboard/market/${a.id}`)} onMouseMove={() => setSel(i)}
                    className={rowCls(i)}>
                    {a.image ? <img src={a.image} alt={a.name} className="h-6 w-6 rounded-full" /> : <span className="h-6 w-6 rounded-full bg-ark-fill-secondary" />}
                    <span className="flex-1 truncate text-sm text-ark-text"><b>{a.symbol.toUpperCase()}</b> <span className="text-ark-text-disabled">{a.name}</span></span>
                    <span className="fig text-xs text-ark-text-secondary">{formatCurrency(a.current_price)}</span>
                    <span className={cn('fig w-14 text-right text-xs font-semibold', up ? 'text-ark-success' : 'text-ark-error')}>{formatPercent(a.price_change_percentage_24h ?? 0)}</span>
                  </button>
                );
              })}
            </div>
          )}

          {pages.length > 0 && (
            <div>
              <p className="px-2.5 py-1.5 text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Pages</p>
              {pages.map((p, j) => {
                const i = coins.length + j;
                return (
                  <button key={p.href} onClick={() => go(p.href)} onMouseMove={() => setSel(i)} className={rowCls(i)}>
                    <p.icon className="h-4 w-4 text-ark-text-tertiary" />
                    <span className="flex-1 text-sm text-ark-text">{p.label}</span>
                    {i === clampedSel && <CornerDownLeft className="h-3.5 w-3.5 text-ark-text-disabled" />}
                  </button>
                );
              })}
            </div>
          )}

          {term && coins.length === 0 && pages.length === 0 && (
            <p className="px-2 py-8 text-center text-sm text-ark-text-tertiary">No results for &ldquo;{q}&rdquo;.</p>
          )}
        </div>

        <div className="flex items-center gap-4 border-t border-ark-divider px-4 py-2.5 text-[11px] text-ark-text-disabled">
          <span className="flex items-center gap-1.5"><kbd className="rounded border border-ark-divider px-1 py-0.5 text-[9px]">↑</kbd><kbd className="rounded border border-ark-divider px-1 py-0.5 text-[9px]">↓</kbd> navigate</span>
          <span className="flex items-center gap-1.5"><CornerDownLeft className="h-3 w-3" /> open</span>
          <span className="flex items-center gap-1.5"><kbd className="rounded border border-ark-divider px-1 py-0.5 text-[9px]">esc</kbd> close</span>
        </div>
      </div>
    </div>,
    document.body,
  );
}
