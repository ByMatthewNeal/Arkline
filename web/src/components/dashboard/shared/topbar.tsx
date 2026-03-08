'use client';

import { usePathname } from 'next/navigation';
import Link from 'next/link';
import { Search, Bell, ChevronRight } from 'lucide-react';
import { ThemeToggle } from '@/components/ui';
import { useAuth } from '@/lib/hooks/use-auth';

const pageNames: Record<string, string> = {
  '/dashboard': 'Overview',
  '/dashboard/market': 'Market Data',
  '/dashboard/portfolio': 'Portfolio',
  '/dashboard/dca': 'DCA Reminders',
  '/dashboard/community': 'Community',
  '/dashboard/settings': 'Settings',
  '/dashboard/profile': 'Profile',
};

export function Topbar() {
  const { profile } = useAuth();
  const pathname = usePathname();

  const pageName = pageNames[pathname] ?? 'Dashboard';
  const isSubPage = pathname !== '/dashboard';

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
          className="flex h-9 w-9 items-center justify-center rounded-xl text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary hover:text-ark-text cursor-pointer"
        >
          <Search className="h-4 w-4" />
        </button>
        <button
          aria-label="Notifications"
          className="relative flex h-9 w-9 items-center justify-center rounded-xl text-ark-text-tertiary transition-colors hover:bg-ark-fill-secondary hover:text-ark-text cursor-pointer"
        >
          <Bell className="h-4 w-4" />
          <span className="absolute right-1.5 top-1.5 h-1.5 w-1.5 rounded-full bg-ark-primary animate-pulse-dot" />
        </button>
        <ThemeToggle />
        <div className="mx-2 h-5 w-px bg-ark-divider" />
        <Link
          href="/dashboard/profile"
          className="flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-ark-primary to-ark-violet text-xs font-semibold text-white shadow-sm shadow-ark-primary/20 transition-transform hover:scale-105"
        >
          {(profile?.username || profile?.email)?.[0]?.toUpperCase() || 'U'}
        </Link>
      </div>
    </header>
  );
}
