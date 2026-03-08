'use client';

import { Bell, Clock, Repeat } from 'lucide-react';
import { GlassCard, Skeleton } from '@/components/ui';
import { useAuth } from '@/lib/hooks/use-auth';
import { useQuery } from '@tanstack/react-query';
import { fetchActiveReminders } from '@/lib/api/dca';
import { isSupabaseConfigured } from '@/lib/supabase/client';
import { formatCurrency, formatRelativeTime, cn } from '@/lib/utils/format';

const frequencyShort: Record<string, string> = {
  daily: 'Daily',
  weekly: 'Weekly',
  biweekly: 'Bi-wk',
  monthly: 'Monthly',
};

const frequencyDays: Record<string, number> = {
  daily: 1,
  weekly: 7,
  biweekly: 14,
  monthly: 30,
};

export function DCACard() {
  const { authUser } = useAuth();
  const isDemo = !isSupabaseConfigured();

  const { data: reminders, isLoading } = useQuery({
    queryKey: ['dca-reminders', authUser?.id ?? 'demo'],
    queryFn: () => fetchActiveReminders(authUser?.id ?? 'demo'),
    enabled: isDemo || !!authUser?.id,
    staleTime: 300_000,
  });

  const upcoming = (reminders ?? []).slice(0, 4);
  const totalMonthly = upcoming.reduce((sum, r) => {
    const multiplier = r.frequency === 'daily' ? 30 : r.frequency === 'weekly' ? 4.3 : r.frequency === 'biweekly' ? 2.15 : 1;
    return sum + r.amount * multiplier;
  }, 0);

  return (
    <GlassCard className="relative overflow-hidden">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary/20 to-transparent" />

      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-primary/10">
            <Bell className="h-5 w-5 text-ark-primary" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-ark-text">DCA</h3>
            <p className="text-[10px] text-ark-text-disabled">
              {upcoming.length > 0 ? `~${formatCurrency(totalMonthly)}/mo` : 'No reminders'}
            </p>
          </div>
        </div>
        {upcoming.length > 0 && (
          <span className="fig rounded-full bg-ark-primary/10 px-2 py-0.5 text-[10px] font-semibold text-ark-primary">
            {upcoming.length} active
          </span>
        )}
      </div>

      {isLoading ? (
        <div className="space-y-2">
          {[0, 1].map((i) => (
            <Skeleton key={i} className="h-14 w-full" />
          ))}
        </div>
      ) : upcoming.length === 0 ? (
        <div className="flex flex-col items-center py-6 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ark-fill-secondary">
            <Bell className="h-6 w-6 text-ark-text-tertiary" />
          </div>
          <p className="mt-3 text-sm text-ark-text-tertiary">No active reminders</p>
          <p className="mt-1 text-xs text-ark-text-disabled">Set up DCA strategies to invest consistently</p>
        </div>
      ) : (
        <div className="space-y-2">
          {upcoming.map((r) => {
            // Calculate days until next reminder for progress
            const nextDate = r.next_reminder_date ? new Date(r.next_reminder_date) : null;
            const now = new Date();
            const totalDays = frequencyDays[r.frequency] ?? 7;
            const daysUntil = nextDate ? Math.max(0, Math.ceil((nextDate.getTime() - now.getTime()) / 86400000)) : 0;
            const progressPct = Math.max(0, Math.min(100, ((totalDays - daysUntil) / totalDays) * 100));

            return (
              <div
                key={r.id}
                className="rounded-xl border border-ark-divider/50 bg-ark-fill-secondary/40 px-3.5 py-3 transition-all hover:border-ark-divider hover:bg-ark-fill-secondary/70"
              >
                <div className="flex items-center justify-between">
                  <div className="min-w-0">
                    <p className="text-sm font-semibold text-ark-text">{r.name}</p>
                    <div className="mt-0.5 flex items-center gap-2 text-[10px] text-ark-text-disabled">
                      <span className="flex items-center gap-0.5">
                        <Repeat className="h-2.5 w-2.5" />
                        {frequencyShort[r.frequency] ?? r.frequency}
                      </span>
                      {r.completed_purchases > 0 && (
                        <span>{r.completed_purchases} purchases</span>
                      )}
                    </div>
                  </div>
                  <p className="fig text-sm font-bold text-ark-text">
                    {formatCurrency(r.amount)}
                  </p>
                </div>
                {/* Progress bar until next */}
                {nextDate && (
                  <div className="mt-2">
                    <div className="flex items-center justify-between text-[9px] text-ark-text-disabled">
                      <span>Next in {formatRelativeTime(r.next_reminder_date!)}</span>
                    </div>
                    <div className="mt-1 h-1 overflow-hidden rounded-full bg-ark-fill-tertiary">
                      <div
                        className="h-full rounded-full bg-ark-primary/60 transition-all"
                        style={{ width: `${progressPct}%` }}
                      />
                    </div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </GlassCard>
  );
}
