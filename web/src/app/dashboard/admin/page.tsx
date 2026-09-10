'use client';

import { useState } from 'react';
import { useQuery, useMutation } from '@tanstack/react-query';
import { DollarSign, Users, Gift, Link2, Copy, Loader2 } from 'lucide-react';
import { GlassCard, Skeleton, Button, useToast } from '@/components/ui';
import { useAuth } from '@/lib/hooks/use-auth';
import { fetchAdminMetrics, grantComp, generateInvite } from '@/lib/api/admin';
import { formatCurrency, cn } from '@/lib/utils/format';

function Metric({ label, value, tone }: { label: string; value: string; tone?: string }) {
  return (
    <div className="rounded-xl bg-ark-fill-secondary/40 px-3 py-2.5 text-center">
      <p className={cn('fig text-lg font-bold', tone ?? 'text-ark-text')}>{value}</p>
      <p className="mt-0.5 text-[10px] uppercase tracking-wider text-ark-text-tertiary">{label}</p>
    </div>
  );
}

export default function AdminOverviewPage() {
  const { authUser } = useAuth();
  const toast = useToast();
  const { data: m, isLoading } = useQuery({ queryKey: ['admin-metrics'], queryFn: fetchAdminMetrics, staleTime: 120_000 });

  // Comp form
  const [compEmail, setCompEmail] = useState('');
  const [compTier, setCompTier] = useState<'founding' | 'standard'>('standard');
  const [compDays, setCompDays] = useState('0');
  const comp = useMutation({
    mutationFn: () => grantComp({ email: compEmail.trim(), tier: compTier, plan: 'monthly', days: Number(compDays) || 0 }),
    onSuccess: (r) => { toast.success(r.message ?? 'Comp granted'); setCompEmail(''); },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not grant comp.'),
  });

  // Invite form
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteCode, setInviteCode] = useState<string | null>(null);
  const invite = useMutation({
    mutationFn: () => generateInvite({ email: inviteEmail.trim() || undefined, created_by: authUser?.id }),
    onSuccess: (r) => {
      const code = (r.code ?? r.invite_code) as string | undefined;
      if (code) { setInviteCode(code); toast.success('Invite code generated'); }
      else toast.error('No code returned.');
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not generate invite.'),
  });

  return (
    <div className="space-y-6">
      {/* Revenue */}
      <GlassCard>
        <div className="mb-3 flex items-center gap-2">
          <DollarSign className="h-4 w-4 text-ark-success" />
          <h2 className="text-sm font-semibold text-ark-text">Revenue</h2>
        </div>
        {isLoading || !m ? <Skeleton className="h-24 w-full" /> : (
          <>
            <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
              <Metric label="MRR" value={formatCurrency(m.mrr)} tone="text-ark-success" />
              <Metric label="ARR" value={formatCurrency(m.arr)} tone="text-ark-success" />
              <Metric label="Churn" value={`${m.churn_rate}%`} tone={m.churn_rate > 5 ? 'text-ark-error' : 'text-ark-text'} />
              <Metric label="Trials" value={String(m.trials_active)} />
            </div>
            <div className="mt-2 grid grid-cols-2 gap-2 sm:grid-cols-4">
              <Metric label="Comped active" value={String(m.comped_active)} />
              <Metric label="Comp potential MRR" value={formatCurrency(m.comped_potential_mrr)} tone="text-ark-info" />
              <Metric label="Trial potential MRR" value={formatCurrency(m.trial_potential_mrr)} tone="text-ark-info" />
              <Metric label="Founding left" value={String(m.founding_remaining)} tone="text-ark-warning" />
            </div>
          </>
        )}
      </GlassCard>

      {/* Members snapshot */}
      <GlassCard>
        <div className="mb-3 flex items-center gap-2">
          <Users className="h-4 w-4 text-ark-primary" />
          <h2 className="text-sm font-semibold text-ark-text">Members</h2>
        </div>
        {isLoading || !m ? <Skeleton className="h-16 w-full" /> : (
          <div className="grid grid-cols-3 gap-2 sm:grid-cols-5">
            <Metric label="Total" value={String(m.total_members)} />
            <Metric label="Active" value={String(m.active_members)} tone="text-ark-success" />
            <Metric label="Trialing" value={String(m.trialing_members)} tone="text-ark-info" />
            <Metric label="Past due" value={String(m.past_due_members)} tone={m.past_due_members > 0 ? 'text-ark-warning' : 'text-ark-text'} />
            <Metric label="Canceled" value={String(m.canceled_members)} tone="text-ark-text-tertiary" />
          </div>
        )}
      </GlassCard>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Comp a member */}
        <GlassCard>
          <div className="mb-3 flex items-center gap-2">
            <Gift className="h-4 w-4 text-ark-violet" />
            <h2 className="text-sm font-semibold text-ark-text">Comp a member</h2>
          </div>
          <input
            type="email" value={compEmail} onChange={(e) => setCompEmail(e.target.value)}
            placeholder="member@email.com"
            className="h-10 w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 px-3 text-sm text-ark-text outline-none placeholder:text-ark-text-disabled focus:border-ark-primary"
          />
          <div className="mt-2 flex items-center gap-2">
            <div className="flex rounded-lg bg-ark-fill-secondary p-0.5">
              {(['standard', 'founding'] as const).map((t) => (
                <button key={t} onClick={() => setCompTier(t)}
                  className={cn('rounded-md px-2.5 py-1 text-[11px] font-semibold capitalize transition-colors',
                    compTier === t ? 'bg-ark-card text-ark-text shadow-sm' : 'text-ark-text-tertiary')}>
                  {t}
                </button>
              ))}
            </div>
            <input
              type="number" min={0} value={compDays} onChange={(e) => setCompDays(e.target.value)}
              className="fig h-8 w-20 rounded-lg border border-ark-divider bg-ark-fill-secondary px-2 text-xs text-ark-text outline-none focus:border-ark-primary"
            />
            <span className="text-[11px] text-ark-text-tertiary">days (0 = forever)</span>
          </div>
          <Button size="sm" className="mt-3" loading={comp.isPending} disabled={!compEmail.trim()} onClick={() => comp.mutate()}>
            Grant access
          </Button>
          <p className="mt-2 text-[10px] leading-relaxed text-ark-text-disabled">
            Works for existing accounts and pre-comps an email that hasn&apos;t signed up yet.
          </p>
        </GlassCard>

        {/* Invite code */}
        <GlassCard>
          <div className="mb-3 flex items-center gap-2">
            <Link2 className="h-4 w-4 text-ark-info" />
            <h2 className="text-sm font-semibold text-ark-text">Send an invite</h2>
          </div>
          <input
            type="email" value={inviteEmail} onChange={(e) => setInviteEmail(e.target.value)}
            placeholder="Recipient email (optional)"
            className="h-10 w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 px-3 text-sm text-ark-text outline-none placeholder:text-ark-text-disabled focus:border-ark-primary"
          />
          <Button size="sm" className="mt-3" loading={invite.isPending} onClick={() => invite.mutate()}>
            {invite.isPending ? <Loader2 className="h-4 w-4 animate-spin" /> : 'Generate code'}
          </Button>
          {inviteCode && (
            <button
              onClick={() => { navigator.clipboard.writeText(inviteCode); toast.success('Copied'); }}
              className="fig mt-3 flex w-full items-center justify-between rounded-xl border border-ark-info/30 bg-ark-info/5 px-3 py-2 text-sm font-bold text-ark-info"
            >
              {inviteCode} <Copy className="h-3.5 w-3.5" />
            </button>
          )}
          <p className="mt-2 text-[10px] leading-relaxed text-ark-text-disabled">
            Codes expire in 15 days by default (format ARK-XXXXXX).
          </p>
        </GlassCard>
      </div>
    </div>
  );
}
