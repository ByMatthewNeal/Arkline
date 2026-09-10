'use client';

import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Bug, Lightbulb, ChevronDown, Trash2 } from 'lucide-react';
import { GlassCard, Skeleton, ConfirmDialog, useToast } from '@/components/ui';
import { fetchFeatureRequests, updateFeatureRequest, deleteFeatureRequest, type FeatureRequestRow } from '@/lib/api/admin';
import { formatRelativeTime, cn } from '@/lib/utils/format';

const STATUSES = ['pending', 'approved', 'in_progress', 'done', 'rejected'] as const;
const STATUS_META: Record<string, { label: string; cls: string }> = {
  pending: { label: 'Pending', cls: 'bg-ark-warning/10 text-ark-warning' },
  approved: { label: 'Approved', cls: 'bg-ark-info/10 text-ark-info' },
  in_progress: { label: 'In progress', cls: 'bg-ark-primary/10 text-ark-primary' },
  done: { label: 'Done', cls: 'bg-ark-success/10 text-ark-success' },
  rejected: { label: 'Rejected', cls: 'bg-ark-error/10 text-ark-error' },
};

function RequestCard({ r, onDelete }: { r: FeatureRequestRow; onDelete: () => void }) {
  const [open, setOpen] = useState(false);
  const [notes, setNotes] = useState(r.admin_notes ?? '');
  const toast = useToast();
  const qc = useQueryClient();
  const isBug = r.request_type === 'bug';

  const update = useMutation({
    mutationFn: (patch: Parameters<typeof updateFeatureRequest>[1]) => updateFeatureRequest(r.id, patch),
    onSuccess: () => { toast.success('Updated'); qc.invalidateQueries({ queryKey: ['admin-feature-requests'] }); },
    onError: () => toast.error('Update failed.'),
  });

  const meta = STATUS_META[r.status] ?? STATUS_META.pending;

  return (
    <GlassCard>
      <button onClick={() => setOpen((v) => !v)} className="flex w-full items-start gap-3 text-left">
        <span className={cn('mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-lg', isBug ? 'bg-ark-error/10' : 'bg-ark-warning/10')}>
          {isBug ? <Bug className="h-3.5 w-3.5 text-ark-error" /> : <Lightbulb className="h-3.5 w-3.5 text-ark-warning" />}
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold text-ark-text">
            {r.title}
            {isBug && <span className="ml-2 rounded bg-ark-error/10 px-1.5 py-0.5 text-[9px] font-bold uppercase text-ark-error">Bug</span>}
          </p>
          <p className="mt-0.5 text-[11px] text-ark-text-tertiary">
            {r.author_email ?? 'anonymous'} · {formatRelativeTime(r.created_at)}
            {r.category ? ` · ${r.category}` : ''}{r.app_version ? ` · ${r.app_version}` : ''}
          </p>
        </div>
        <span className={cn('shrink-0 rounded-md px-2 py-0.5 text-[10px] font-bold', meta.cls)}>{meta.label}</span>
        <ChevronDown className={cn('mt-1 h-4 w-4 shrink-0 text-ark-text-tertiary transition-transform', open && 'rotate-180')} />
      </button>

      {open && (
        <div className="mt-3 space-y-3 border-t border-ark-divider pt-3">
          <p className="whitespace-pre-wrap text-[13px] leading-relaxed text-ark-text-secondary">{r.description}</p>
          {r.device_info && <p className="fig break-all text-[10px] text-ark-text-disabled">{r.device_info}</p>}
          {r.ai_analysis && (
            <div className="rounded-xl bg-ark-fill-secondary/40 px-3 py-2">
              <p className="text-[10px] font-semibold uppercase tracking-wider text-ark-text-tertiary">AI analysis</p>
              <p className="mt-0.5 text-[12px] leading-relaxed text-ark-text-secondary">{r.ai_analysis}</p>
            </div>
          )}

          {/* Status chips */}
          <div className="flex flex-wrap gap-1.5">
            {STATUSES.map((s) => (
              <button key={s} disabled={update.isPending} onClick={() => update.mutate({ status: s })}
                className={cn('rounded-full px-2.5 py-1 text-[10px] font-bold capitalize transition-colors',
                  r.status === s ? STATUS_META[s].cls : 'bg-ark-fill-secondary text-ark-text-tertiary hover:text-ark-text')}>
                {STATUS_META[s].label}
              </button>
            ))}
          </div>

          {/* Notes */}
          <div className="flex items-start gap-2">
            <textarea
              value={notes} onChange={(e) => setNotes(e.target.value)} rows={2}
              placeholder="Admin notes…"
              className="flex-1 resize-none rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-2.5 text-xs text-ark-text outline-none placeholder:text-ark-text-disabled focus:border-ark-primary"
            />
            <div className="flex flex-col gap-1.5">
              <button
                disabled={update.isPending || notes === (r.admin_notes ?? '')}
                onClick={() => update.mutate({ admin_notes: notes })}
                className="rounded-lg bg-ark-primary px-2.5 py-1.5 text-[11px] font-semibold text-white disabled:opacity-40"
              >
                Save
              </button>
              <button onClick={onDelete} title="Delete" className="flex items-center justify-center rounded-lg bg-ark-fill-secondary px-2.5 py-1.5 text-ark-text-tertiary hover:text-ark-error">
                <Trash2 className="h-3.5 w-3.5" />
              </button>
            </div>
          </div>
        </div>
      )}
    </GlassCard>
  );
}

export default function AdminBacklogPage() {
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [typeFilter, setTypeFilter] = useState<'all' | 'feature' | 'bug'>('all');
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const toast = useToast();
  const qc = useQueryClient();

  const { data, isLoading } = useQuery({ queryKey: ['admin-feature-requests'], queryFn: fetchFeatureRequests, staleTime: 60_000 });

  const remove = useMutation({
    mutationFn: (id: string) => deleteFeatureRequest(id),
    onSuccess: () => { setDeleteId(null); toast.success('Deleted'); qc.invalidateQueries({ queryKey: ['admin-feature-requests'] }); },
    onError: () => toast.error('Delete failed.'),
  });

  const rows = useMemo(() => {
    let list = data ?? [];
    if (statusFilter !== 'all') list = list.filter((r) => r.status === statusFilter);
    if (typeFilter !== 'all') list = list.filter((r) => (r.request_type === 'bug') === (typeFilter === 'bug'));
    return list;
  }, [data, statusFilter, typeFilter]);

  const openBugs = (data ?? []).filter((r) => r.request_type === 'bug' && r.status === 'pending').length;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-2">
        <div className="flex gap-1 rounded-full bg-ark-fill-secondary/60 p-1">
          {(['all', ...STATUSES] as const).map((s) => (
            <button key={s} onClick={() => setStatusFilter(s)}
              className={cn('rounded-full px-3 py-1.5 text-[11px] font-semibold capitalize transition-colors',
                statusFilter === s ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text')}>
              {s === 'all' ? 'All' : STATUS_META[s].label}
            </button>
          ))}
        </div>
        <div className="flex gap-1 rounded-full bg-ark-fill-secondary/60 p-1">
          {(['all', 'feature', 'bug'] as const).map((t) => (
            <button key={t} onClick={() => setTypeFilter(t)}
              className={cn('rounded-full px-3 py-1.5 text-[11px] font-semibold capitalize transition-colors',
                typeFilter === t ? 'bg-ark-info text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text')}>
              {t === 'all' ? 'Both' : t}
            </button>
          ))}
        </div>
        {openBugs > 0 && <span className="rounded-full bg-ark-error/10 px-2.5 py-1 text-[11px] font-bold text-ark-error">{openBugs} open bug{openBugs === 1 ? '' : 's'}</span>}
      </div>

      {isLoading ? (
        <div className="space-y-2">{[0, 1, 2].map((i) => <Skeleton key={i} className="h-20 w-full rounded-2xl" />)}</div>
      ) : rows.length === 0 ? (
        <p className="py-10 text-center text-sm text-ark-text-tertiary">Nothing here.</p>
      ) : (
        <div className="space-y-2">
          {rows.map((r) => <RequestCard key={r.id} r={r} onDelete={() => setDeleteId(r.id)} />)}
        </div>
      )}

      <ConfirmDialog
        open={deleteId !== null}
        title="Delete this request?"
        message="This permanently removes the request from the backlog."
        confirmLabel="Delete"
        destructive
        loading={remove.isPending}
        onConfirm={() => { if (deleteId) remove.mutate(deleteId); }}
        onCancel={() => setDeleteId(null)}
      />
    </div>
  );
}
