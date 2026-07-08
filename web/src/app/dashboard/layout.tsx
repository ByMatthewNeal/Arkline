'use client';

import { useState, useEffect } from 'react';
import { Sidebar } from '@/components/dashboard/shared/sidebar';
import { Topbar } from '@/components/dashboard/shared/topbar';
import { NewsTicker } from '@/components/dashboard/shared/news-ticker';
import { MobileNav } from '@/components/dashboard/shared/mobile-nav';
import { cn, setPreferredCurrency, getPreferredCurrency } from '@/lib/utils/format';
import { useAuth } from '@/lib/hooks/use-auth';
import { useTheme } from '@/lib/hooks/use-theme';

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

  // Cross-device theme: if this device has no saved choice, adopt the theme
  // saved in the profile (Settings on another device / iOS parity).
  const { setTheme } = useTheme();
  const profileTheme = profile?.dark_mode;
  useEffect(() => {
    if (!profileTheme) return;
    try {
      if (!localStorage.getItem('ark-theme') && ['light', 'dark', 'system'].includes(profileTheme)) {
        setTheme(profileTheme as 'light' | 'dark' | 'system');
      }
    } catch { /* ignore */ }
  }, [profileTheme, setTheme]);

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
        <NewsTicker />
        <main key={currency} className="animate-fade-in p-4 pb-24 sm:p-6 md:pb-6">
          {children}
        </main>
      </div>

      {/* Mobile bottom nav */}
      <MobileNav />
    </div>
  );
}
