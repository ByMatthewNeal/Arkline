'use client';

import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Search } from 'lucide-react';
import { GlassCard, Skeleton, Badge } from '@/components/ui';
import { fetchMembers, type AdminMember, type MemberFilter } from '@/lib/api/admin';
import { formatRelativeTime, cn } from '@/lib/utils/format';

const FILTERS: { key: MemberFilter; label: string }[] = [
  { key: 'all', label: 'All' },
  { key: 'paying', label: 'Paying' },
  { key: 'comp', label: 'Comped' },
  { key: 'none', label: 'No Access' },
  { key: 'canceled', label: 'Canceled' },
];

function accessOf(mem: AdminMember): { label: string; tone: 'success' | 'info' | 'warning' | 'error' | 'default' } {
  const now = new Date().toISOString();
  const valid = mem.subscriptions.filter(
    (s) => (s.status === 'active' || s.status === 'trialing') && (s.current_period_end === null || s.current_period_end > now),
  );
  const paying = valid.find((s) => s.source === 'apple' || s.source === 'stripe');
  if (paying) return { label: paying.status === 'trialing' ? `Trial · ${paying.source}` : `Paying · ${paying.source}`, tone: paying.status === 'trialing' ? 'info' : 'success' };
  if (valid.some((s) => s.source === 'comp')) return { label: 'Comped', tone: 'warning' };
  if (mem.subscriptions.length > 0) return { label: 'Lapsed', tone: 'error' };
  return { label: 'No access', tone: 'default' };
}

export default function AdminMembersPage() {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<MemberFilter>('all');
  const { data, isLoading, isError } = useQuery({
    queryKey: ['admin-members', search, filter],
    queryFn: () => fetchMembers({ search, status: filter }),
    staleTime: 60_000,
  });

  const members = data?.members ?? [];

  return (
    <div className="space-y-4">
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

      <p className="fig text-[11px] text-ark-text-tertiary">{data?.total ?? 0} member{(data?.total ?? 0) === 1 ? '' : 's'}</p>

      {isLoading ? (
        <div className="space-y-2">{[0, 1, 2, 3].map((i) => <Skeleton key={i} className="h-16 w-full rounded-2xl" />)}</div>
      ) : isError ? (
        <p className="py-10 text-center text-sm text-ark-error">Could not load members — check that the admin-members function allows this origin.</p>
      ) : members.length === 0 ? (
        <p className="py-10 text-center text-sm text-ark-text-tertiary">No members match.</p>
      ) : (
        <div className="space-y-2">
          {members.map((mem) => {
            const access = accessOf(mem);
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
                    <p className="truncate text-[11px] text-ark-text-tertiary">{mem.email ?? '—'} · joined {formatRelativeTime(mem.created_at)}</p>
                  </div>
                  <Badge variant={access.tone}>{access.label}</Badge>
                </div>
              </GlassCard>
            );
          })}
        </div>
      )}
    </div>
  );
}
