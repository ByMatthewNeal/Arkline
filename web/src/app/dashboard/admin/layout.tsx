'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { ShieldCheck, Users, ListTodo, Activity, Radio, LayoutDashboard } from 'lucide-react';
import { useAuth } from '@/lib/hooks/use-auth';
import { Skeleton } from '@/components/ui';
import { cn } from '@/lib/utils/format';

/**
 * Admin section shell. UI gate only — every data path is enforced
 * server-side (edge-function role checks, is_admin() RLS, RPC guards).
 */

const tabs = [
  { label: 'Overview', href: '/dashboard/admin', icon: LayoutDashboard },
  { label: 'Members', href: '/dashboard/admin/members', icon: Users },
  { label: 'Backlog', href: '/dashboard/admin/backlog', icon: ListTodo },
  { label: 'Health', href: '/dashboard/admin/health', icon: Activity },
  { label: 'Compose', href: '/dashboard/admin/compose', icon: Radio },
];

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  const { profile, loading } = useAuth();
  const pathname = usePathname();

  if (loading) return <Skeleton className="h-64 w-full rounded-2xl" />;
  if (profile?.role !== 'admin') {
    return (
      <div className="flex flex-col items-center py-20 text-center">
        <ShieldCheck className="h-8 w-8 text-ark-text-tertiary" />
        <p className="mt-3 text-sm text-ark-text-secondary">This area is for Arkline admins.</p>
        <Link href="/dashboard" className="mt-2 text-sm font-medium text-ark-primary">Back to dashboard</Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-5xl space-y-6">
      <div className="flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-ark-primary/10">
          <ShieldCheck className="h-5 w-5 text-ark-primary" />
        </div>
        <div>
          <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">Admin</h1>
          <p className="text-sm text-ark-text-tertiary">Run Arkline from your desk</p>
        </div>
      </div>

      <div className="flex gap-1 overflow-x-auto rounded-xl bg-ark-fill-secondary/60 p-1">
        {tabs.map((t) => {
          const active = t.href === '/dashboard/admin' ? pathname === t.href : pathname.startsWith(t.href);
          return (
            <Link
              key={t.href}
              href={t.href}
              className={cn('flex shrink-0 items-center gap-1.5 rounded-lg px-3.5 py-2 text-sm font-semibold transition-colors',
                active ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text')}
            >
              <t.icon className="h-4 w-4" /> {t.label}
            </Link>
          );
        })}
      </div>

      {children}
    </div>
  );
}
