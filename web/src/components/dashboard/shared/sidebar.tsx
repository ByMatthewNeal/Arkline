'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Home,
  TrendingUp,
  Briefcase,
  Bell,
  Users,
  Settings,
  User,
  ChevronLeft,
  ChevronRight,
  LogOut,
} from 'lucide-react';
import { useAuth } from '@/lib/hooks/use-auth';
import { cn } from '@/lib/utils/format';
import { ArklineLogo } from '@/components/ui';

interface SidebarProps {
  collapsed: boolean;
  onToggle: () => void;
}

const mainNav = [
  { label: 'Home', href: '/dashboard', icon: Home },
  { label: 'Market', href: '/dashboard/market', icon: TrendingUp },
  { label: 'Portfolio', href: '/dashboard/portfolio', icon: Briefcase },
  { label: 'DCA', href: '/dashboard/dca', icon: Bell },
  { label: 'Community', href: '/dashboard/community', icon: Users },
];

const utilNav = [
  { label: 'Settings', href: '/dashboard/settings', icon: Settings },
  { label: 'Profile', href: '/dashboard/profile', icon: User },
];

export function Sidebar({ collapsed, onToggle }: SidebarProps) {
  const pathname = usePathname();
  const { profile, signOut } = useAuth();

  const isActive = (href: string) =>
    href === '/dashboard' ? pathname === '/dashboard' : pathname.startsWith(href);

  const renderNavItem = (item: (typeof mainNav)[0]) => {
    const active = isActive(item.href);
    return (
      <Link
        key={item.href}
        href={item.href}
        className={cn(
          'relative flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-all duration-150',
          active
            ? 'bg-ark-primary/10 text-ark-primary shadow-[0_0_12px_rgba(59,130,246,0.08)]'
            : 'text-ark-text-secondary hover:bg-ark-fill-secondary hover:text-ark-text',
        )}
      >
        {active && (
          <span className="absolute left-0 top-1/2 h-6 w-[3px] -translate-y-1/2 rounded-r-full bg-ark-primary" />
        )}
        <item.icon className={cn('h-[18px] w-[18px] shrink-0', active && 'drop-shadow-[0_0_4px_rgba(59,130,246,0.3)]')} />
        {!collapsed && <span>{item.label}</span>}
      </Link>
    );
  };

  return (
    <aside
      className={cn(
        'fixed left-0 top-0 z-40 flex h-screen flex-col border-r border-ark-divider bg-ark-surface transition-[width] duration-200',
        collapsed ? 'w-[68px]' : 'w-[240px]',
      )}
    >
      {/* Logo */}
      <div className="flex h-16 items-center border-b border-ark-divider px-4">
        <ArklineLogo size="md" showText={!collapsed} />
      </div>

      {/* Main Nav */}
      <nav className="flex-1 px-3 pt-4">
        <div className="space-y-1">
          {!collapsed && (
            <p className="mb-2 px-3 text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">
              Main
            </p>
          )}
          {mainNav.map(renderNavItem)}
        </div>

        {/* Divider */}
        <div className="my-4 border-t border-ark-divider" />

        <div className="space-y-1">
          {!collapsed && (
            <p className="mb-2 px-3 text-[10px] font-semibold uppercase tracking-wider text-ark-text-disabled">
              Account
            </p>
          )}
          {utilNav.map(renderNavItem)}
        </div>
      </nav>

      {/* Bottom */}
      <div className="border-t border-ark-divider p-3 space-y-0.5">
        {!collapsed && profile && (
          <div className="px-3 pb-2 text-xs text-ark-text-tertiary truncate">
            {profile.email}
          </div>
        )}
        <button
          onClick={signOut}
          className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium text-ark-text-secondary hover:bg-ark-fill-secondary hover:text-ark-text transition-all cursor-pointer"
        >
          <LogOut className="h-5 w-5 shrink-0" />
          {!collapsed && <span>Sign Out</span>}
        </button>
        <button
          onClick={onToggle}
          className="flex w-full items-center gap-3 rounded-xl px-3 py-2 text-sm text-ark-text-tertiary hover:bg-ark-fill-secondary transition-all cursor-pointer"
        >
          {collapsed ? (
            <ChevronRight className="h-4 w-4 shrink-0" />
          ) : (
            <>
              <ChevronLeft className="h-4 w-4 shrink-0" />
              <span>Collapse</span>
            </>
          )}
        </button>
      </div>
    </aside>
  );
}
