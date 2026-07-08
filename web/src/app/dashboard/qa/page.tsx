'use client';

import { useState } from 'react';
import { MessagesSquare, Heart, Trash2, CheckCircle2, Loader2 } from 'lucide-react';
import { GlassCard, Skeleton, ConfirmDialog, useToast } from '@/components/ui';
import { useAuth } from '@/lib/hooks/use-auth';
import { useQuestions, useQaMutations } from '@/lib/hooks/use-qa';
import { formatRelativeTime, cn } from '@/lib/utils/format';
import type { MemberQuestion } from '@/lib/api/qa';

export default function QAPage() {
  const { authUser } = useAuth();
  const { data: questions, isLoading } = useQuestions();
  const { ask, like, remove } = useQaMutations();

  const [text, setText] = useState('');
  const [anon, setAnon] = useState(false);
  const [sort, setSort] = useState<'newest' | 'top'>('newest');
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const toast = useToast();

  const list = [...(questions ?? [])].sort((a, b) => sort === 'top' ? b.like_count - a.like_count : (a.created_at < b.created_at ? 1 : -1));

  const submit = async () => {
    if (!text.trim()) return;
    await ask.mutateAsync({ question: text.trim(), isAnonymous: anon });
    setText(''); setAnon(false);
  };

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div className="flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-ark-primary/10"><MessagesSquare className="h-5 w-5 text-ark-primary" /></div>
        <div>
          <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">Member Q&amp;A</h1>
          <p className="text-sm text-ark-text-tertiary">Ask a question — answers come from the Arkline team</p>
        </div>
      </div>

      {/* Ask box */}
      <GlassCard>
        <textarea
          value={text} onChange={(e) => setText(e.target.value)} rows={3}
          placeholder="What would you like to ask?"
          className="w-full resize-none rounded-xl border border-ark-divider bg-ark-fill-secondary/40 p-3 text-sm text-ark-text outline-none placeholder:text-ark-text-disabled focus:border-ark-primary"
        />
        <div className="mt-3 flex items-center justify-between">
          <label className="flex cursor-pointer items-center gap-2 text-xs text-ark-text-secondary">
            <input type="checkbox" checked={anon} onChange={(e) => setAnon(e.target.checked)} className="h-4 w-4 rounded border-ark-divider" />
            Ask anonymously
          </label>
          <button onClick={submit} disabled={!text.trim() || ask.isPending}
            className="flex items-center gap-2 rounded-xl bg-ark-primary px-4 py-2 text-sm font-semibold text-white transition-colors hover:brightness-110 disabled:opacity-50">
            {ask.isPending && <Loader2 className="h-4 w-4 animate-spin" />} Post Question
          </button>
        </div>
      </GlassCard>

      {/* Sort */}
      <div className="flex items-center justify-between">
        <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-disabled">{list.length} question{list.length === 1 ? '' : 's'}</p>
        <div className="inline-flex rounded-full bg-ark-fill-secondary p-0.5">
          {(['newest', 'top'] as const).map((s) => (
            <button key={s} onClick={() => setSort(s)} className={cn('rounded-full px-3 py-1 text-xs font-semibold capitalize transition-colors', sort === s ? 'bg-ark-info text-white' : 'text-ark-text-tertiary')}>{s}</button>
          ))}
        </div>
      </div>

      {isLoading ? (
        <div className="space-y-3">{[0, 1, 2].map((i) => <Skeleton key={i} className="h-24 w-full rounded-2xl" />)}</div>
      ) : list.length === 0 ? (
        <div className="flex flex-col items-center py-12 text-center">
          <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-ark-fill-secondary"><MessagesSquare className="h-6 w-6 text-ark-text-tertiary" /></div>
          <p className="mt-3 text-sm text-ark-text-tertiary">No questions yet — be the first to ask.</p>
        </div>
      ) : (
        <div className="space-y-3">
          {list.map((q) => <QuestionCard key={q.id} q={q} mine={q.user_id === authUser?.id} onLike={() => like.mutate(q)} onDelete={() => setDeleteId(q.id)} />)}
        </div>
      )}

      <ConfirmDialog
        open={deleteId !== null}
        title="Delete your question?"
        message="This permanently removes your question and any answer it received."
        confirmLabel="Delete"
        destructive
        loading={remove.isPending}
        onConfirm={() => {
          if (!deleteId) return;
          remove.mutate(deleteId, {
            onSuccess: () => { setDeleteId(null); toast.success('Question deleted'); },
            onError: () => toast.error('Could not delete question. Please try again.'),
          });
        }}
        onCancel={() => setDeleteId(null)}
      />
    </div>
  );
}

function QuestionCard({ q, mine, onLike, onDelete }: { q: MemberQuestion; mine: boolean; onLike: () => void; onDelete: () => void }) {
  const author = q.is_anonymous ? 'Anonymous' : (q.author_name ?? 'Member');
  return (
    <GlassCard className="group">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2 text-[11px] text-ark-text-disabled">
            <span className="font-semibold text-ark-text-secondary">{author}</span>
            <span>· {formatRelativeTime(q.created_at)}</span>
            {q.answer && <span className="flex items-center gap-1 rounded-full bg-ark-success/10 px-1.5 py-0.5 font-semibold text-ark-success"><CheckCircle2 className="h-2.5 w-2.5" /> Answered</span>}
          </div>
          <p className="mt-1.5 text-sm text-ark-text">{q.question}</p>
          {q.answer && (
            <div className="mt-3 rounded-xl border-l-2 border-ark-success/40 bg-ark-fill-secondary/40 px-3 py-2">
              <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-success">Arkline</p>
              <p className="mt-0.5 text-[13px] leading-relaxed text-ark-text-secondary">{q.answer}</p>
            </div>
          )}
        </div>
        {mine && (
          <button onClick={onDelete} title="Delete" className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg text-ark-text-tertiary opacity-0 transition-opacity hover:bg-ark-fill-secondary group-hover:opacity-100"><Trash2 className="h-3.5 w-3.5" /></button>
        )}
      </div>
      <div className="mt-3">
        <button onClick={onLike} className={cn('flex items-center gap-1.5 rounded-lg px-2 py-1 text-xs font-medium transition-colors hover:bg-ark-fill-secondary', q.liked ? 'text-ark-error' : 'text-ark-text-tertiary')}>
          <Heart className={cn('h-3.5 w-3.5', q.liked && 'fill-current')} /> {q.like_count}
        </button>
      </div>
    </GlassCard>
  );
}
