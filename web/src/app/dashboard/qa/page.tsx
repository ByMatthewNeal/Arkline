'use client';

import { useState } from 'react';
import { MessagesSquare, Heart, Trash2, CheckCircle2, Loader2, ShieldCheck, Eye, Pencil } from 'lucide-react';
import { GlassCard, Skeleton, ConfirmDialog, useToast } from '@/components/ui';
import { useAuth } from '@/lib/hooks/use-auth';
import { useQuestions, useQaMutations } from '@/lib/hooks/use-qa';
import { formatRelativeTime, cn } from '@/lib/utils/format';
import type { MemberQuestion } from '@/lib/api/qa';

export default function QAPage() {
  const { authUser, profile } = useAuth();
  const { data: questions, isLoading } = useQuestions();
  const { ask, like, remove, answer } = useQaMutations();

  const isAdmin = profile?.role === 'admin';
  // Multiview: admins can preview the exact member experience.
  const [viewAs, setViewAs] = useState<'admin' | 'member'>('admin');
  const adminMode = isAdmin && viewAs === 'admin';

  const [text, setText] = useState('');
  const [anon, setAnon] = useState(false);
  const [sort, setSort] = useState<'newest' | 'top'>('newest');
  const [deleteId, setDeleteId] = useState<string | null>(null);
  const toast = useToast();

  const list = [...(questions ?? [])].sort((a, b) => sort === 'top' ? b.like_count - a.like_count : (a.created_at < b.created_at ? 1 : -1));
  const openCount = list.filter((q) => !q.answer).length;

  const submit = async () => {
    if (!text.trim()) return;
    await ask.mutateAsync({ question: text.trim(), isAnonymous: anon });
    setText(''); setAnon(false);
  };

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div className="flex items-center gap-3">
        <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-ark-primary/10"><MessagesSquare className="h-5 w-5 text-ark-primary" /></div>
        <div className="flex-1">
          <h1 className="font-[family-name:var(--font-urbanist)] text-2xl font-bold text-ark-text">Member Q&amp;A</h1>
          <p className="text-sm text-ark-text-tertiary">
            {adminMode
              ? `${openCount} awaiting an answer`
              : 'Ask a question — answers come from the Arkline team'}
          </p>
        </div>
        {isAdmin && (
          <div className="inline-flex shrink-0 items-center rounded-full bg-ark-fill-secondary p-0.5" title="Preview how members see this page">
            <button
              onClick={() => setViewAs('admin')}
              className={cn('flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold transition-colors',
                viewAs === 'admin' ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text')}
            >
              <ShieldCheck className="h-3.5 w-3.5" /> Admin
            </button>
            <button
              onClick={() => setViewAs('member')}
              className={cn('flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold transition-colors',
                viewAs === 'member' ? 'bg-ark-primary text-white shadow-sm' : 'text-ark-text-tertiary hover:text-ark-text')}
            >
              <Eye className="h-3.5 w-3.5" /> Member view
            </button>
          </div>
        )}
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
        <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-text-tertiary">{list.length} question{list.length === 1 ? '' : 's'}</p>
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
          {list.map((q) => (
            <QuestionCard
              key={q.id}
              q={q}
              mine={q.user_id === authUser?.id}
              adminMode={adminMode}
              onLike={() => like.mutate(q)}
              onDelete={() => setDeleteId(q.id)}
              onAnswer={(t, done) =>
                answer.mutate(
                  { questionId: q.id, text: t },
                  {
                    onSuccess: () => { toast.success('Answer posted'); done(); },
                    onError: () => toast.error('Could not post answer. Please try again.'),
                  },
                )}
              answerPending={answer.isPending && answer.variables?.questionId === q.id}
            />
          ))}
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

function QuestionCard({ q, mine, adminMode, onLike, onDelete, onAnswer, answerPending }: {
  q: MemberQuestion;
  mine: boolean;
  adminMode: boolean;
  onLike: () => void;
  onDelete: () => void;
  onAnswer: (text: string, done: () => void) => void;
  answerPending: boolean;
}) {
  const author = q.is_anonymous ? 'Anonymous' : (q.author_name ?? 'Member');
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');

  const startEditing = () => { setDraft(q.answer ?? ''); setEditing(true); };

  return (
    <GlassCard className="group">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-2 text-[11px] text-ark-text-disabled">
            <span className="font-semibold text-ark-text-secondary">{author}</span>
            <span>· {formatRelativeTime(q.created_at)}</span>
            {q.answer ? (
              <span className="flex items-center gap-1 rounded-full bg-ark-success/10 px-1.5 py-0.5 font-semibold text-ark-success"><CheckCircle2 className="h-2.5 w-2.5" /> Answered</span>
            ) : adminMode ? (
              <span className="rounded-full bg-ark-warning/10 px-1.5 py-0.5 font-semibold text-ark-warning">Awaiting answer</span>
            ) : null}
          </div>
          <p className="mt-1.5 text-sm text-ark-text">{q.question}</p>

          {q.answer && !editing && (
            <div className="mt-3 rounded-xl border-l-2 border-ark-success/40 bg-ark-fill-secondary/40 px-3 py-2">
              <p className="text-[11px] font-semibold uppercase tracking-wider text-ark-success">Arkline</p>
              <p className="mt-0.5 text-[13px] leading-relaxed text-ark-text-secondary">{q.answer}</p>
            </div>
          )}

          {/* Admin: inline answer composer */}
          {adminMode && editing && (
            <div className="mt-3">
              <textarea
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                rows={3}
                autoFocus
                placeholder="Write the Arkline team's answer…"
                className="w-full resize-none rounded-xl border border-ark-primary/40 bg-ark-fill-secondary/40 p-3 text-[13px] text-ark-text outline-none placeholder:text-ark-text-disabled focus:border-ark-primary"
              />
              <div className="mt-2 flex items-center justify-end gap-2">
                <button onClick={() => setEditing(false)} className="rounded-lg px-3 py-1.5 text-xs font-medium text-ark-text-tertiary hover:bg-ark-fill-secondary">Cancel</button>
                <button
                  onClick={() => onAnswer(draft, () => setEditing(false))}
                  disabled={!draft.trim() || answerPending}
                  className="flex items-center gap-1.5 rounded-lg bg-ark-primary px-3 py-1.5 text-xs font-semibold text-white transition-colors hover:brightness-110 disabled:opacity-50"
                >
                  {answerPending && <Loader2 className="h-3 w-3 animate-spin" />} {q.answer ? 'Update answer' : 'Post answer'}
                </button>
              </div>
            </div>
          )}
        </div>
        {mine && (
          <button onClick={onDelete} title="Delete" className="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg text-ark-text-tertiary opacity-0 transition-opacity hover:bg-ark-fill-secondary group-hover:opacity-100"><Trash2 className="h-3.5 w-3.5" /></button>
        )}
      </div>
      <div className="mt-3 flex items-center gap-2">
        <button onClick={onLike} className={cn('flex items-center gap-1.5 rounded-lg px-2 py-1 text-xs font-medium transition-colors hover:bg-ark-fill-secondary', q.liked ? 'text-ark-error' : 'text-ark-text-tertiary')}>
          <Heart className={cn('h-3.5 w-3.5', q.liked && 'fill-current')} /> {q.like_count}
        </button>
        {adminMode && !editing && (
          <button
            onClick={startEditing}
            className={cn('flex items-center gap-1.5 rounded-lg px-2 py-1 text-xs font-semibold transition-colors',
              q.answer ? 'text-ark-text-tertiary hover:bg-ark-fill-secondary' : 'text-ark-primary hover:bg-ark-primary/10')}
          >
            <Pencil className="h-3 w-3" /> {q.answer ? 'Edit answer' : 'Answer'}
          </button>
        )}
      </div>
    </GlassCard>
  );
}
