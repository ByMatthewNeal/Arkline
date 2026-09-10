'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Radio, Eye, X, Pin } from 'lucide-react';
import { GlassCard, Skeleton, Button, Badge, useToast } from '@/components/ui';
import { useAuth } from '@/lib/hooks/use-auth';
import { createBroadcast, fetchBroadcastsAdmin, fetchBroadcastReaders, fetchBroadcastReach } from '@/lib/api/admin';
import { Markdown } from '@/components/dashboard/shared/markdown';
import { formatRelativeTime, cn } from '@/lib/utils/format';

/* ── Seen-by modal (iOS SeenBy sheet parity: opens vs reach) ── */
function SeenByModal({ broadcastId, title, onClose }: { broadcastId: string; title: string; onClose: () => void }) {
  const { data: readers, isLoading } = useQuery({
    queryKey: ['broadcast-readers', broadcastId],
    queryFn: () => fetchBroadcastReaders(broadcastId),
  });
  const { data: reach } = useQuery({
    queryKey: ['broadcast-reach', broadcastId],
    queryFn: () => fetchBroadcastReach(broadcastId),
  });

  return (
    <div className="fixed inset-0 z-[150] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm" onClick={onClose}>
      <div className="max-h-[80vh] w-full max-w-md overflow-y-auto rounded-2xl border border-ark-divider bg-ark-card p-5 shadow-2xl" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <h3 className="text-base font-semibold text-ark-text">Seen by</h3>
            <p className="mt-0.5 line-clamp-1 text-xs text-ark-text-tertiary">{title}</p>
          </div>
          <button onClick={onClose} className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg text-ark-text-tertiary hover:bg-ark-fill-secondary">
            <X className="h-4 w-4" />
          </button>
        </div>
        <p className="fig mt-2 text-[11px] font-semibold text-ark-text-secondary">
          {readers?.length ?? '—'} opened · {reach ?? '—'} reached
        </p>
        <div className="mt-3 space-y-1.5">
          {isLoading ? (
            [0, 1, 2].map((i) => <Skeleton key={i} className="h-10 w-full rounded-xl" />)
          ) : (readers ?? []).length === 0 ? (
            <p className="py-6 text-center text-sm text-ark-text-tertiary">No opens yet.</p>
          ) : (
            (readers ?? []).map((r) => (
              <div key={r.user_id} className="flex items-center gap-2.5 rounded-xl bg-ark-fill-secondary/40 px-3 py-2">
                <div className="flex h-7 w-7 items-center justify-center rounded-full bg-ark-primary/10 text-[10px] font-bold uppercase text-ark-primary">
                  {(r.display_name ?? '?').slice(0, 2)}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-xs font-semibold text-ark-text">{r.display_name ?? 'Member'}</p>
                  <p className="truncate text-[10px] text-ark-text-disabled">{r.email ?? ''}</p>
                </div>
                <span className="shrink-0 text-[10px] text-ark-text-tertiary">{formatRelativeTime(r.read_at)}</span>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}

export default function AdminComposePage() {
  const { authUser } = useAuth();
  const toast = useToast();
  const qc = useQueryClient();

  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');
  const [tags, setTags] = useState('');
  const [pinned, setPinned] = useState(false);
  const [mode, setMode] = useState<'now' | 'scheduled' | 'draft'>('now');
  const [publishAt, setPublishAt] = useState('');
  const [preview, setPreview] = useState(false);
  const [seenBy, setSeenBy] = useState<{ id: string; title: string } | null>(null);

  const { data: recent, isLoading: loadingRecent } = useQuery({
    queryKey: ['admin-broadcasts'],
    queryFn: fetchBroadcastsAdmin,
    staleTime: 60_000,
  });

  const valid = title.trim().length > 0 && content.trim().length > 0 && (mode !== 'scheduled' || publishAt.length > 0);

  const publish = useMutation({
    mutationFn: () => createBroadcast({
      title,
      content,
      tags: tags.split(',').map((t) => t.trim().toUpperCase()).filter(Boolean),
      is_pinned: pinned,
      mode,
      publishAt: mode === 'scheduled' ? new Date(publishAt).toISOString() : null,
      author_id: authUser!.id,
    }),
    onSuccess: () => {
      toast.success(
        mode === 'draft' ? 'Draft saved'
          : mode === 'scheduled' ? 'Scheduled — publishes automatically with a push'
          : 'Queued — goes live with a push within a minute',
      );
      setTitle(''); setContent(''); setTags(''); setPinned(false); setPublishAt('');
      qc.invalidateQueries({ queryKey: ['admin-broadcasts'] });
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save broadcast.'),
  });

  return (
    <div className="space-y-6">
      <GlassCard>
        <div className="mb-3 flex items-center gap-2">
          <Radio className="h-4 w-4 text-ark-primary" />
          <h2 className="text-sm font-semibold text-ark-text">New insight</h2>
          <button onClick={() => setPreview((v) => !v)} className="ml-auto text-xs font-semibold text-ark-info">
            {preview ? 'Edit' : 'Preview'}
          </button>
        </div>

        {preview ? (
          <div className="rounded-xl border border-ark-divider p-4">
            <p className="text-base font-semibold text-ark-text">{title || 'Untitled'}</p>
            <Markdown content={content || '_Nothing yet._'} className="mt-2" />
          </div>
        ) : (
          <div className="space-y-3">
            <input
              value={title} onChange={(e) => setTitle(e.target.value)}
              placeholder="Title"
              className="h-10 w-full rounded-xl border border-ark-divider bg-ark-fill-secondary/40 px-3 text-sm font-semibold text-ark-text outline-none placeholder:text-ark-text-disabled focus:border-ark-primary"
            />
            <textarea
              value={content} onChange={(e) => setContent(e.target.value)} rows={10}
              placeholder={'Write in markdown — **bold**, headers, > quotes, lists…'}
              className="w-full resize-y rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-3 font-mono text-[13px] leading-relaxed text-ark-text outline-none placeholder:text-ark-text-disabled focus:border-ark-primary"
            />
            <div className="flex flex-wrap items-center gap-2">
              <input
                value={tags} onChange={(e) => setTags(e.target.value)}
                placeholder="Tags (comma separated: BTC, MACRO)"
                className="h-9 flex-1 rounded-xl border border-ark-divider bg-ark-fill-secondary/40 px-3 text-xs text-ark-text outline-none placeholder:text-ark-text-disabled focus:border-ark-primary"
              />
              <button onClick={() => setPinned((v) => !v)}
                className={cn('flex items-center gap-1.5 rounded-xl px-3 py-2 text-xs font-semibold transition-colors',
                  pinned ? 'bg-ark-primary/10 text-ark-primary' : 'bg-ark-fill-secondary text-ark-text-tertiary')}>
                <Pin className="h-3.5 w-3.5" /> {pinned ? 'Pinned' : 'Pin'}
              </button>
            </div>
          </div>
        )}

        <div className="mt-4 flex flex-wrap items-center gap-2 border-t border-ark-divider pt-3">
          <div className="flex rounded-lg bg-ark-fill-secondary p-0.5">
            {([['now', 'Publish now'], ['scheduled', 'Schedule'], ['draft', 'Draft']] as const).map(([m, label]) => (
              <button key={m} onClick={() => setMode(m)}
                className={cn('rounded-md px-3 py-1.5 text-[11px] font-semibold transition-colors',
                  mode === m ? 'bg-ark-card text-ark-text shadow-sm' : 'text-ark-text-tertiary')}>
                {label}
              </button>
            ))}
          </div>
          {mode === 'scheduled' && (
            <input
              type="datetime-local" value={publishAt} onChange={(e) => setPublishAt(e.target.value)}
              className="fig h-9 rounded-lg border border-ark-divider bg-ark-fill-secondary px-2 text-xs text-ark-text outline-none focus:border-ark-primary"
            />
          )}
          <Button size="sm" className="ml-auto" loading={publish.isPending} disabled={!valid} onClick={() => publish.mutate()}>
            {mode === 'draft' ? 'Save draft' : mode === 'scheduled' ? 'Schedule' : 'Publish'}
          </Button>
        </div>
        <p className="mt-2 text-[10px] leading-relaxed text-ark-text-disabled">
          Publishing routes through the same pipeline as iOS scheduling — the post goes live and members get the push within a minute. Members who turned off Insights notifications are skipped automatically.
        </p>
      </GlassCard>

      {/* Recent broadcasts + Seen-by */}
      <div>
        <p className="mb-2 text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">Recent broadcasts</p>
        {loadingRecent ? (
          <div className="space-y-2">{[0, 1, 2].map((i) => <Skeleton key={i} className="h-14 w-full rounded-2xl" />)}</div>
        ) : (
          <div className="space-y-2">
            {(recent ?? []).map((b) => (
              <GlassCard key={b.id}>
                <div className="flex items-center gap-3">
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold text-ark-text">{b.title}</p>
                    <p className="text-[11px] text-ark-text-tertiary">
                      {b.published_at ? formatRelativeTime(b.published_at) : b.scheduled_at ? `scheduled · ${new Date(b.scheduled_at).toLocaleString()}` : formatRelativeTime(b.created_at)}
                    </p>
                  </div>
                  <Badge variant={b.status === 'published' ? 'success' : b.status === 'scheduled' ? 'info' : 'default'}>{b.status}</Badge>
                  <button
                    onClick={() => setSeenBy({ id: b.id, title: b.title })}
                    className="fig flex items-center gap-1 rounded-lg bg-ark-fill-secondary px-2.5 py-1.5 text-xs font-semibold text-ark-text-secondary transition-colors hover:text-ark-text"
                    title="See who read this"
                  >
                    <Eye className="h-3.5 w-3.5" /> {b.view_count}
                  </button>
                </div>
              </GlassCard>
            ))}
          </div>
        )}
      </div>

      {seenBy && <SeenByModal broadcastId={seenBy.id} title={seenBy.title} onClose={() => setSeenBy(null)} />}
    </div>
  );
}
