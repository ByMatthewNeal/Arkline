'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAuth } from './use-auth';
import { fetchQuestions, createQuestion, toggleQuestionLike, deleteQuestion, answerQuestion, type MemberQuestion } from '@/lib/api/qa';

export function useQuestions() {
  const { authUser } = useAuth();
  return useQuery({ queryKey: ['member-questions', authUser?.id], queryFn: () => fetchQuestions(authUser?.id), staleTime: 30_000 });
}

export function useQaMutations() {
  const { authUser, profile } = useAuth();
  const qc = useQueryClient();
  const key = ['member-questions', authUser?.id];
  const invalidate = () => qc.invalidateQueries({ queryKey: key });

  const ask = useMutation({
    mutationFn: ({ question, isAnonymous }: { question: string; isAnonymous: boolean }) =>
      createQuestion(authUser!.id, question, isAnonymous, profile?.full_name ?? profile?.username ?? 'Member'),
    onSuccess: invalidate,
  });

  const like = useMutation({
    mutationFn: (q: MemberQuestion) => toggleQuestionLike(authUser!.id, q.id, q.liked),
    onMutate: async (q: MemberQuestion) => {
      await qc.cancelQueries({ queryKey: key });
      const prev = qc.getQueryData<MemberQuestion[]>(key);
      qc.setQueryData<MemberQuestion[]>(key, (list) => (list ?? []).map((x) => x.id === q.id ? { ...x, liked: !x.liked, like_count: x.like_count + (x.liked ? -1 : 1) } : x));
      return { prev };
    },
    onError: (_e, _v, ctx) => { if (ctx?.prev) qc.setQueryData(key, ctx.prev); },
    onSettled: invalidate,
  });

  const remove = useMutation({ mutationFn: (id: string) => deleteQuestion(id), onSuccess: invalidate });

  // Admin only — RLS enforces the role server-side.
  const answer = useMutation({
    mutationFn: ({ questionId, text }: { questionId: string; text: string }) =>
      answerQuestion(questionId, text, authUser!.id),
    onSuccess: invalidate,
  });

  return { ask, like, remove, answer };
}
