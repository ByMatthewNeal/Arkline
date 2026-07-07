'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { Radio, Repeat, Bell, Check } from 'lucide-react';
import { useSignalChanges } from '@/lib/hooks/use-market';
import { useAuth } from '@/lib/hooks/use-auth';
import { fetchBroadcasts } from '@/lib/api/broadcasts';
import { fetchActiveReminders } from '@/lib/api/dca';
import { signalChangeHint, formatRelativeTime, cn } from '@/lib/utils/format';

export interface NotifItem {
  id: string;
  kind: 'broadcast' | 'signal' | 'dca';
  title: string;
  subtitle: string;
  time: string; // ISO
  href: string;
}

export function useNotifications() {
  const { authUser } = useAuth();
  const { data: broadcasts } = useQuery({ queryKey: ['notif-broadcasts'], queryFn: fetchBroadcasts, staleTime: 120_000 });
  const { data: signals } = useSignalChanges();
  const { data: reminders } = useQuery({ queryKey: ['notif-dca', authUser?.id], queryFn: () => fetchActiveReminders(authUser!.id), enabled: !!authUser?.id, staleTime: 120_000 });

  const [lastSeen, setLastSeen] = useState<string>('');
  useEffect(() => { setLastSeen(localStorage.getItem('notif_seen') ?? '2000-01-01'); }, []);

  const items: NotifItem[] = [];

  for (const b of (broadcasts ?? []).slice(0, 5)) {
    items.push({ id: `b-${b.id}`, kind: 'broadcast', title: b.title, subtitle: 'New broadcast', time: b.published_at ?? b.created_at, href: '/dashboard/broadcasts' });
  }
  const today = new Date().toISOString();
  for (const s of (signals ?? []).slice(0, 4)) {
    items.push({ id: `s-${s.asset}`, kind: 'signal', title: `${s.asset}: ${s.prev_signal} → ${s.signal}`, subtitle: signalChangeHint(s.prev_signal, s.signal), time: today, href: '/dashboard' });
  }
  const soon = new Date(); soon.setDate(soon.getDate() + 2);
  for (const r of (reminders ?? [])) {
    if (r.next_reminder_date && new Date(r.next_reminder_date) <= soon) {
      items.push({ id: `d-${r.id}`, kind: 'dca', title: `${r.symbol.toUpperCase()} DCA due`, subtitle: `${formatRelativeTime(r.next_reminder_date)}`, time: r.next_reminder_date, href: '/dashboard/dca' });
    }
  }

  items.sort((a, b) => (a.time < b.time ? 1 : -1));
  const unreadCount = items.filter((i) => i.time > lastSeen).length;
  const markSeen = () => { const now = new Date().toISOString(); localStorage.setItem('notif_seen', now); setLastSeen(now); };

  return { items, unreadCount, markSeen, lastSeen };
}

const ICONS = { broadcast: Radio, signal: Repeat, dca: Bell };

export function NotificationsPanel({ open, onClose, items, lastSeen, onMarkSeen }: { open: boolean; onClose: () => void; items: NotifItem[]; lastSeen: string; onMarkSeen: () => void }) {
  const router = useRouter();
  if (!open) return null;
  return (
    <>
      <div className="fixed inset-0 z-40" onClick={onClose} />
      <div className="absolute right-0 top-11 z-50 w-80 overflow-hidden rounded-2xl border border-ark-divider bg-ark-bg shadow-2xl">
        <div className="flex items-center justify-between border-b border-ark-divider px-4 py-3">
          <span className="text-sm font-semibold text-ark-text">Notifications</span>
          <button onClick={onMarkSeen} className="flex items-center gap-1 text-xs font-medium text-ark-info"><Check className="h-3 w-3" /> Mark all read</button>
        </div>
        <div className="max-h-[60vh] overflow-y-auto">
          {items.length === 0 ? (
            <p className="px-4 py-8 text-center text-sm text-ark-text-tertiary">You&apos;re all caught up.</p>
          ) : items.map((it) => {
            const Icon = ICONS[it.kind];
            const unread = it.time > lastSeen;
            return (
              <button key={it.id} onClick={() => { router.push(it.href); onClose(); }}
                className={cn('flex w-full items-start gap-3 border-b border-ark-divider/60 px-4 py-3 text-left transition-colors hover:bg-ark-fill-secondary', unread && 'bg-ark-primary/[0.04]')}>
                <div className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-ark-fill-secondary"><Icon className="h-4 w-4 text-ark-text-tertiary" /></div>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold text-ark-text">{it.title}</p>
                  <p className="truncate text-xs text-ark-text-disabled">{it.subtitle}</p>
                </div>
                {unread && <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-ark-primary" />}
              </button>
            );
          })}
        </div>
      </div>
    </>
  );
}
