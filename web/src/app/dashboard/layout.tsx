'use client';

import { useState } from 'react';
import { Sidebar } from '@/components/dashboard/shared/sidebar';
import { Topbar } from '@/components/dashboard/shared/topbar';
import { MobileNav } from '@/components/dashboard/shared/mobile-nav';
import { cn, setPreferredCurrency, getPreferredCurrency } from '@/lib/utils/format';
import { useAuth } from '@/lib/hooks/use-auth';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const [collapsed, setCollapsed] = useState(false);

  // Apply the user's preferred currency (Settings) app-wide. Keying <main>
  // on the currency re-renders pages when the preference loads or changes.
  const { profile } = useAuth();
  setPreferredCurrency(profile?.preferred_currency);
  const currency = getPreferredCurrency();

  return (
    <div
      className="min-h-screen"
      style={{
        backgroundColor: 'var(--ark-bg)',
        backgroundImage:
          'radial-gradient(1100px 550px at 50% -8%, color-mix(in srgb, var(--ark-primary) 8%, transparent), transparent 60%)',
        backgroundAttachment: 'fixed',
        backgroundRepeat: 'no-repeat',
      }}
    >
      {/* Desktop sidebar */}
      <div className="hidden md:block">
        <Sidebar collapsed={collapsed} onToggle={() => setCollapsed(!collapsed)} />
      </div>

      {/* Main content */}
      <div
        className={cn(
          'transition-[margin-left] duration-200 md:ml-[240px]',
          collapsed && 'md:ml-[68px]',
        )}
      >
        <Topbar />
        <main key={currency} className="animate-fade-in p-4 pb-24 sm:p-6 md:pb-6">
          {children}
        </main>
      </div>

      {/* Mobile bottom nav */}
      <MobileNav />
    </div>
  );
}
