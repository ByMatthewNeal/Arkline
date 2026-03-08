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
    <div className="min-h-screen bg-ark-bg">
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
