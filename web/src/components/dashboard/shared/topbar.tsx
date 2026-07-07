'use client';

import { useState, useEffect } from 'react';
import { usePathname } from 'next/navigation';
import Link from 'next/link';
import { Search, Bell, ChevronRight } from 'lucide-react';
import { ThemeToggle } from '@/components/ui';
import { useAuth } from '@/lib/hooks/use-auth';
import { GlobalSearch } from './global-search';
import { NotificationsPanel, useNotifications } from './notifications';

const pageNames: Record<string, string> = {
  '/dashboard': 'Overview',
  '/dashboard/market': 'Market Data',
  '/dashboard/portfolio': 'Portfolio',
  '/dashboard/dca': 'DCA Reminders',
  '/dashboard/broadcasts': 'Broadcasts',
  '/dashboard/settings': 'Settings',
  '/dashboard/profile': 'Profile',
};

export function Topbar() {
  const { profile } = useAuth();
  const pathname = usePathname();
  const [searchOpen, setSearchOpen] = useState(false);
  const [notifOpen, setNotifOpen] = useState(false);
  const { items, unreadCount, markSeen, lastSeen } = useNotifications();

  const pageName = pageNames[pathname] ?? 'Dashboard';
  const isSubPage = pathname !== '/dashboard';

  // ⌘K / Ctrl+K opens global search
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); setSearchOpen((v) => !v); }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, []);

  return (
    <header className="sticky top-0 z-30 flex h-16 items-center justify-between border-b border-ark-divider bg-ark-surface/80 px-4 backdrop-blur-xl sm:px-6">
      {/* Breadcrumbs */}
      <nav className="flex items-center gap-1.5 text-sm">
        <Link
          href="/dashboard"
          className={`font-medium transition-colors ${
            isSubPage
              ? 'text-ark-text-tertiary hover:text-ark-text-secondary'
              : 'text-ark-text'
          }`}
        >
          Dashboard
        </Link>
        {isSubPage && (
          <>
            <ChevronRight className="h-3 w-3 text-ark-text-disabled" />
            <span className="font-semibold text-ark-text">{pageName}</span>
          </>
        )}
      </nav>

      {/* Actions */}
      <div className="flex items-center gap-1">
        <button
          aria-label="Search"
          onClick={() => setSearchOpen(true)}
          className="flex items-center gap-2 rounded-xl px-2.5 py-1.5 text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary hover:text-ark-text sm:border sm:border-ark-divider"
        >
          <Search className="h-4 w-4" />
          <span className="hidden text-xs text-ark-text-disabled sm:inline">Search</span>
          <kbd className="hidden rounded border border-ark-divider px-1 text-[10px] text-ark-text-disabled md:inline">⌘K</kbd>
        </button>
        <div className="relative">
          <button
            aria-label="Notifications"
            onClick={() => setNotifOpen((v) => !v)}
            className="relative flex h-9 w-9 items-center justify-center rounded-xl text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary hover:text-ark-text"
          >
            <Bell className="h-4 w-4" />
            {unreadCount > 0 && (
              <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-ark-primary px-1 text-[9px] font-bold text-white">{unreadCount > 9 ? '9+' : unreadCount}</span>
            )}
          </button>
          <NotificationsPanel open={notifOpen} onClose={() => setNotifOpen(false)} items={items} lastSeen={lastSeen} onMarkSeen={markSeen} />
        </div>
        <ThemeToggle />
        <div className="mx-2 h-5 w-px bg-ark-divider" />
        <Link
          href="/dashboard/profile"
          className="flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-ark-primary to-ark-violet text-xs font-semibold text-white shadow-sm shadow-ark-primary/20 transition-transform hover:scale-105"
        >
          {(profile?.username || profile?.email)?.[0]?.toUpperCase() || 'U'}
        </Link>
      </div>

      <GlobalSearch open={searchOpen} onClose={() => setSearchOpen(false)} />
    </header>
  );
}
