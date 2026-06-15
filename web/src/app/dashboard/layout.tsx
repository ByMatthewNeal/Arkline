'use client';

import { useState } from 'react';
import { Sidebar } from '@/components/dashboard/shared/sidebar';
import { Topbar } from '@/components/dashboard/shared/topbar';
import { MobileNav } from '@/components/dashboard/shared/mobile-nav';
import { cn } from '@/lib/utils/format';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const [collapsed, setCollapsed] = useState(false);

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
        <main className="animate-fade-in p-4 pb-24 sm:p-6 md:pb-6">
          {children}
        </main>
      </div>

      {/* Mobile bottom nav */}
      <MobileNav />
    </div>
  );
}
