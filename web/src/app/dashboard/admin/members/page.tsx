'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Search, Users, Sparkles, CheckCircle2, MoonStar } from 'lucide-react';
import { GlassCard, Skeleton, Badge } from '@/components/ui';
import { fetchMembers, fetchAdminMetrics, type AdminMember, type MemberFilter } from '@/lib/api/admin';
import { formatRelativeTime, cn } from '@/lib/utils/format';

const FILTERS: { key: MemberFilter; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'new', label: 'New' },
  { key: 'active', label: 'Active' },
  { key: 'dormant', label: 'Dormant' },
];

const DAY = 864e5;

/** Free-era growth/engagement bucket for a member: New (recent signup) wins,
 *  else Active (seen in 30d), else Dormant. Mirrors iOS AdminMember.activityStatus. */
function activityOf(mem: AdminMember): {
  status: 'new' | 'active' | 'dormant';
  label: string;
  tone: 'info' | 'success' | 'default';
  sub: string;
} {
  const now = Date.now();
  const joined = new Date(mem.created_at).getTime();
  const last = mem.last_active_at ? new Date(mem.last_active_at).getTime() : null;
  if (now - joined < 7 * DAY) {
    return { status: 'new', label: 'New', tone: 'info', sub: `joined ${formatRelativeTime(mem.created_at)}` };
  }
  if (last !== null && now - last < 30 * DAY) {
    return { status: 'active', label: 'Active', tone: 'success', sub: `seen ${formatRelativeTime(mem.last_active_at!)}` };
  }
  return {
    status: 'dormant',
    label: 'Dormant',
    tone: 'default',
    sub: last ? `seen ${formatRelativeTime(mem.last_active_at!)}` : 'no activity',
  };
}

export default function AdminMembersPage() {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<MemberFilter>('all');

  // Fetch every member once; growth/engagement filters are applied client-side.
  const { data, isLoading, isError } = useQuery({
    queryKey: ['admin-members', search],
    queryFn: () => fetchMembers({ search }),
    staleTime: 60_000,
  });
  const { data: metrics } = useQuery({
    queryKey: ['admin-metrics'],
    queryFn: fetchAdminMetrics,
    staleTime: 60_000,
  });

  const g = metrics?.growth;
  const cards = [
    { label: 'Total', value: g?.total_members ?? 0, icon: Users, tone: 'text-ark-primary' },
    { label: 'New this week', value: g?.new_this_week ?? 0, icon: Sparkles, tone: 'text-ark-info' },
    { label: 'Active (30d)', value: g?.active_30d ?? 0, icon: CheckCircle2, tone: 'text-ark-success' },
    { label: 'Dormant', value: g?.dormant ?? 0, icon: MoonStar, tone: 'text-ark-text-tertiary' },
  ];

  const all = data?.members ?? [];
  const members = filter === 'all' ? all : all.filter((m) => activityOf(m).status === filter);

  return (
    <div className="space-y-4">
      {/* Growth & engagement */}
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
        {cards.map((c) => (
          <GlassCard key={c.label} className="p-3">
            <c.icon className={cn('h-4 w-4', c.tone)} />
            <p className="fig mt-1.5 text-2xl font-bold text-ark-text">{metrics ? c.value : '—'}</p>
            <p className="text-[11px] text-ark-text-tertiary">{c.label}</p>
          </GlassCard>
        ))}
      </div>

      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-ark-text-tertiary" />
          <input
            value={search} onChange={(e) => setSearch(e.target.value)}
            placeholder="Search email, username, name…"
            className="h-10 w-full rounded-xl border border-ark-divider bg-ark-fill-secondary pl-9 pr-3 text-sm text-ark-text outline-none placeholder:text-ark-text-tertiary focus:border-ark-primary"
          />
        </div>
        <div className="flex gap-1 overflow-x-auto rounded-full bg-ark-fill-secondary/60 p-1">
          {FILTERS.map((f) => (
            <button key={f.key} onClick={() => setFilter(f.key)}
              className={cn('shrink-0 rounded-full px-3 py-1.5 text-[11px] font-semibold transition-colors',
                filter === f.key ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text')}>
              {f.label}
            </button>
          ))}
        </div>
      </div>

      <p className="fig text-[11px] text-ark-text-tertiary">{members.length} member{members.length === 1 ? '' : 's'}</p>

      {isLoading ? (
        <div className="space-y-2">{[0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-16 w-full rounded-2xl" />)}</div>
      ) : isError ? (
        <p className="py-10 text-center text-sm text-ark-error">Could not load members — check that the admin-members function allows this origin.</p>
      ) : members.length === 0 ? (
        <p className="py-10 text-center text-sm text-ark-text-tertiary">No members match.</p>
      ) : (
        <div className="space-y-2">
          {members.map((mem) => {
            const activity = activityOf(mem);
            const name = mem.full_name || mem.username || (mem.email ? mem.email.split('@')[0] : 'Member');
            return (
              <GlassCard key={mem.id} className={cn(mem.is_internal && 'opacity-60')}>
                <div className="flex items-center gap-3">
                  <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-ark-primary/10 text-xs font-bold uppercase text-ark-primary">
                    {name.slice(0, 2)}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-ark-text">
                      {name}
                      {mem.is_internal && <span className="ml-2 rounded bg-ark-fill-secondary px-1.5 py-0.5 text-[9px] font-semibold uppercase text-ark-text-tertiary">internal</span>}
                      {mem.role === 'admin' && <span className="ml-2 rounded bg-ark-primary/10 px-1.5 py-0.5 text-[9px] font-semibold uppercase text-ark-primary">admin</span>}
                    </p>
                    <p className="truncate text-[11px] text-ark-text-tertiary">{mem.email ?? '—'} · {activity.sub}</p>
                  </div>
                  <Badge variant={activity.tone}>{activity.label}</Badge>
                </div>
              </GlassCard>
            );
          })}
        </div>
      )}
    </div>
  );
}
