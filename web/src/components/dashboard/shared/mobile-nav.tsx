'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Home, TrendingUp, Briefcase, Bell, Users } from 'lucide-react';
import { cn } from '@/lib/utils/format';

const items = [
  { label: 'Home', href: '/dashboard', icon: Home },
  { label: 'Market', href: '/dashboard/market', icon: TrendingUp },
  { label: 'Portfolio', href: '/dashboard/portfolio', icon: Briefcase },
  { label: 'DCA', href: '/dashboard/dca', icon: Bell },
  { label: 'Community', href: '/dashboard/community', icon: Users },
];

export function MobileNav() {
  const pathname = usePathname();

  const isActive = (href: string) =>
    href === '/dashboard' ? pathname === '/dashboard' : pathname.startsWith(href);

  return (
    <nav className="fixed bottom-0 left-0 z-50 w-full border-t border-ark-divider bg-ark-surface/90 backdrop-blur-xl md:hidden">
      <div className="flex items-center justify-around py-2 pb-[env(safe-area-inset-bottom,8px)]">
        {items.map((item) => {
          const active = isActive(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'relative flex flex-col items-center gap-1 px-3 py-1 text-[10px] font-medium transition-colors',
                active ? 'text-ark-primary' : 'text-ark-text-tertiary',
              )}
            >
              {active && (
                <span className="absolute -top-2 h-[3px] w-7 rounded-full bg-ark-primary shadow-sm shadow-ark-primary/50" />
              )}
              <item.icon className={cn('h-5 w-5 transition-transform', active && 'scale-110')} />
              {item.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
