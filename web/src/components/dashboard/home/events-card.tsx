'use client';

import { Calendar, Clock } from 'lucide-react';
import { GlassCard, Skeleton } from '@/components/ui';
import { useEconomicEvents } from '@/lib/hooks/use-market';
import { cn } from '@/lib/utils/format';

const impactStyles: Record<string, { dot: string; label: string; bg: string; border: string }> = {
  high: { dot: 'bg-ark-error', label: 'text-ark-error', bg: 'bg-ark-error/8', border: 'border-ark-error/20' },
  medium: { dot: 'bg-ark-warning', label: 'text-ark-warning', bg: 'bg-ark-warning/8', border: 'border-ark-warning/20' },
  low: { dot: 'bg-ark-text-disabled', label: 'text-ark-text-tertiary', bg: 'bg-ark-fill-secondary', border: 'border-ark-divider' },
};

export function EventsCard() {
  const { data: events, isLoading } = useEconomicEvents();

  const todayStr = new Date().toISOString().split('T')[0];
  const todayEvents = (events ?? []).filter((e) => e.date?.startsWith(todayStr)).slice(0, 5);

  // If no events today, show upcoming this week
  const weekEnd = new Date();
  weekEnd.setDate(weekEnd.getDate() + 7);
  const weekStr = weekEnd.toISOString().split('T')[0];
  const upcomingEvents = todayEvents.length > 0
    ? todayEvents
    : (events ?? []).filter((e) => e.date > todayStr && e.date <= weekStr).slice(0, 5);
  const isShowingUpcoming = todayEvents.length === 0 && upcomingEvents.length > 0;

  const highImpactCount = upcomingEvents.filter((e) => e.impact === 'high').length;

  return (
    <GlassCard className="relative overflow-hidden">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-px bg-gradient-to-r from-transparent via-ark-info/20 to-transparent" />

      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-ark-info/10">
            <Calendar className="h-5 w-5 text-ark-info" />
          </div>
          <div>
            <h3 className="text-sm font-semibold text-ark-text">Calendar</h3>
            <p className="text-[10px] text-ark-text-disabled">
              {isShowingUpcoming ? 'Upcoming this week' : 'Today\'s events'}
            </p>
          </div>
        </div>
        {highImpactCount > 0 && (
          <span className="flex items-center gap-1 rounded-full bg-ark-error/10 px-2 py-0.5 text-[10px] font-semibold text-ark-error">
            {highImpactCount} high impact
          </span>
        )}
      </div>

      {isLoading ? (
        <div className="space-y-2">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-12 w-full" />
          ))}
        </div>
      ) : upcomingEvents.length === 0 ? (
        <div className="flex flex-col items-center py-6 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ark-fill-secondary">
            <Calendar className="h-6 w-6 text-ark-text-tertiary" />
          </div>
          <p className="mt-3 text-sm text-ark-text-tertiary">No upcoming events</p>
          <p className="mt-1 text-xs text-ark-text-disabled">Calendar is clear this week</p>
        </div>
      ) : (
        <div className="space-y-1.5">
          {upcomingEvents.map((e) => {
            const style = impactStyles[e.impact] ?? impactStyles.low;
            const eventDate = new Date(e.date);
            const isToday = e.date?.startsWith(todayStr);
            return (
              <div
                key={e.id}
                className={cn(
                  'flex items-center gap-3 rounded-xl border px-3 py-2.5 transition-colors hover:bg-ark-fill-secondary',
                  e.impact === 'high' ? style.border : 'border-transparent',
                )}
              >
                {/* Time column */}
                <div className="w-12 shrink-0 text-center">
                  {isToday ? (
                    <p className="flex items-center justify-center gap-0.5 text-[10px] font-semibold text-ark-text-secondary">
                      <Clock className="h-2.5 w-2.5" />
                      {e.time}
                    </p>
                  ) : (
                    <p className="text-[10px] font-medium text-ark-text-disabled">
                      {eventDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
                    </p>
                  )}
                </div>
                <span className={cn('h-2 w-2 shrink-0 rounded-full', style.dot)} />
                <div className="min-w-0 flex-1">
                  <p className="text-xs font-medium text-ark-text truncate">{e.title}</p>
                  <p className="text-[10px] text-ark-text-disabled">{e.country}</p>
                </div>
                <span className={cn('shrink-0 rounded-md px-1.5 py-0.5 text-[9px] font-semibold uppercase tracking-wider', style.label, style.bg)}>
                  {e.impact}
                </span>
              </div>
            );
          })}
        </div>
      )}
    </GlassCard>
  );
}
