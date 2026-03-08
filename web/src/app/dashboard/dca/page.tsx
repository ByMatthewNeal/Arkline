'use client';

import { useState } from 'react';
import {
  Bell,
  Plus,
  Clock,
  CheckCircle2,
  Calendar,
  DollarSign,
  Repeat,
  TrendingUp,
  ChevronDown,
  ChevronUp,
} from 'lucide-react';
import { GlassCard, Badge, Skeleton } from '@/components/ui';
import { useAuth } from '@/lib/hooks/use-auth';
import { useQuery } from '@tanstack/react-query';
import { fetchDCAReminders } from '@/lib/api/dca';
import { isSupabaseConfigured } from '@/lib/supabase/client';
import { formatCurrency, formatDate, formatRelativeTime, cn } from '@/lib/utils/format';

const frequencyLabels: Record<string, string> = {
  daily: 'Daily',
  twice_weekly: 'Twice Weekly',
  weekly: 'Weekly',
  biweekly: 'Bi-weekly',
  monthly: 'Monthly',
};

export default function DCAPage() {
  const { authUser } = useAuth();
  const isDemo = !isSupabaseConfigured();
  const [showCompleted, setShowCompleted] = useState(false);

  const { data: reminders, isLoading } = useQuery({
    queryKey: ['dca-reminders-all', authUser?.id ?? 'demo'],
    queryFn: () => fetchDCAReminders(authUser?.id ?? 'demo'),
    enabled: isDemo || !!authUser?.id,
    staleTime: 300_000,
  });

  const active = (reminders ?? []).filter((r) => r.is_active);
  const completed = (reminders ?? []).filter((r) => !r.is_active);

  // Stats
  const totalWeekly = active.reduce((sum, r) => {
    const multiplier =
      r.frequency === 'daily' ? 7 :
      r.frequency === 'twice_weekly' ? 2 :
      r.frequency === 'weekly' ? 1 :
      r.frequency === 'biweekly' ? 0.5 :
      r.frequency === 'monthly' ? 7 / 30 : 1;
    return sum + r.amount * multiplier;
  }, 0);

  const totalInvested = active.reduce(
    (sum, r) => sum + r.amount * r.completed_purchases,
    0,
  );

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">
            DCA Reminders
          </h1>
          <p className="mt-1 text-sm text-ark-text-tertiary">
            Dollar-cost average into your favorite assets
          </p>
        </div>
        <button className="flex items-center gap-2 rounded-xl bg-ark-primary px-4 py-2.5 text-sm font-medium text-white shadow-md shadow-ark-primary/25 transition-all hover:shadow-lg hover:shadow-ark-primary/30 hover:brightness-110 cursor-pointer">
          <Plus className="h-4 w-4" />
          New Reminder
        </button>
      </div>

      {/* Stats */}
      <div className="grid gap-4 sm:grid-cols-3">
        <GlassCard className="relative overflow-hidden">
          <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-primary/30 to-transparent" />
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-primary/15">
              <Repeat className="h-5 w-5 text-ark-primary" />
            </div>
            <div>
              <p className="text-xs text-ark-text-tertiary">Active Reminders</p>
              <p className="text-xl font-bold text-ark-text">{active.length}</p>
            </div>
          </div>
        </GlassCard>

        <GlassCard className="relative overflow-hidden">
          <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-success/30 to-transparent" />
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-success/15">
              <DollarSign className="h-5 w-5 text-ark-success" />
            </div>
            <div>
              <p className="text-xs text-ark-text-tertiary">Weekly Investment</p>
              <p className="text-xl font-bold text-ark-text">
                {formatCurrency(totalWeekly)}
              </p>
            </div>
          </div>
        </GlassCard>

        <GlassCard className="relative overflow-hidden">
          <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-violet-500/30 to-transparent" />
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-violet-500/15">
              <TrendingUp className="h-5 w-5 text-violet-500" />
            </div>
            <div>
              <p className="text-xs text-ark-text-tertiary">Total Invested</p>
              <p className="text-xl font-bold text-ark-text">
                {formatCurrency(totalInvested)}
              </p>
            </div>
          </div>
        </GlassCard>
      </div>

      {/* Active Reminders */}
      <div>
        <h2 className="mb-3 flex items-center gap-2 text-sm font-semibold text-ark-text">
          <Bell className="h-4 w-4 text-ark-primary" />
          Upcoming
        </h2>

        {isLoading ? (
          <div className="space-y-3">
            {[0, 1, 2].map((i) => (
              <Skeleton key={i} className="h-24 w-full" />
            ))}
          </div>
        ) : active.length === 0 ? (
          <GlassCard>
            <div className="flex flex-col items-center py-8 text-center">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-ark-fill-secondary">
                <Bell className="h-7 w-7 text-ark-text-tertiary" />
              </div>
              <p className="mt-3 text-sm font-medium text-ark-text">No active reminders</p>
              <p className="mt-1 text-xs text-ark-text-tertiary">
                Create your first DCA reminder to start investing consistently
              </p>
            </div>
          </GlassCard>
        ) : (
          <div className="space-y-3">
            {active.map((r) => (
              <GlassCard key={r.id} className="group relative overflow-hidden transition-all hover:shadow-md">
                <div className="pointer-events-none absolute inset-y-0 left-0 w-1 rounded-l-xl bg-ark-primary" />
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-4">
                    <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-ark-fill-secondary text-lg font-bold text-ark-text uppercase">
                      {r.symbol.slice(0, 3)}
                    </div>
                    <div>
                      <p className="font-semibold text-ark-text">{r.name}</p>
                      <div className="mt-0.5 flex items-center gap-3 text-xs text-ark-text-tertiary">
                        <span className="flex items-center gap-1">
                          <DollarSign className="h-3 w-3" />
                          {formatCurrency(r.amount)}
                        </span>
                        <span className="flex items-center gap-1">
                          <Repeat className="h-3 w-3" />
                          {frequencyLabels[r.frequency] ?? r.frequency}
                        </span>
                        <span className="flex items-center gap-1">
                          <CheckCircle2 className="h-3 w-3" />
                          {r.completed_purchases} purchases
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-3">
                    {r.next_reminder_date && (
                      <div className="text-right">
                        <p className="text-xs text-ark-text-tertiary">Next</p>
                        <p className="text-sm font-medium text-ark-text">
                          {formatRelativeTime(r.next_reminder_date)}
                        </p>
                      </div>
                    )}
                    <button className="rounded-lg bg-ark-success/15 px-3 py-1.5 text-xs font-medium text-ark-success transition-colors hover:bg-ark-success/25 cursor-pointer">
                      Invest
                    </button>
                  </div>
                </div>
              </GlassCard>
            ))}
          </div>
        )}
      </div>

      {/* Completed */}
      {completed.length > 0 && (
        <div>
          <button
            onClick={() => setShowCompleted(!showCompleted)}
            className="mb-3 flex items-center gap-2 text-sm font-semibold text-ark-text-secondary hover:text-ark-text transition-colors cursor-pointer"
          >
            <CheckCircle2 className="h-4 w-4" />
            Completed ({completed.length})
            {showCompleted ? (
              <ChevronUp className="h-4 w-4" />
            ) : (
              <ChevronDown className="h-4 w-4" />
            )}
          </button>

          {showCompleted && (
            <div className="space-y-2">
              {completed.map((r) => (
                <GlassCard key={r.id} className="opacity-60">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-3">
                      <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-ark-fill-secondary text-sm font-bold text-ark-text-tertiary uppercase">
                        {r.symbol.slice(0, 3)}
                      </div>
                      <div>
                        <p className="text-sm font-medium text-ark-text">{r.name}</p>
                        <p className="text-xs text-ark-text-tertiary">
                          {r.completed_purchases} purchases &middot; {formatCurrency(r.amount * r.completed_purchases)} total
                        </p>
                      </div>
                    </div>
                    <Badge variant="default">Completed</Badge>
                  </div>
                </GlassCard>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
