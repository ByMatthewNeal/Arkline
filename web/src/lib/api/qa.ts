import { createClient, isSupabaseConfigured } from '@/lib/supabase/client';

export interface MemberQuestion {
  id: string;
  user_id: string;
  author_name: string | null;
  is_anonymous: boolean;
  question: string;
  answer: string | null;
  answered_at: string | null;
  status: string;
  created_at: string;
  like_count: number;
  liked: boolean;
}

export async function fetchQuestions(userId: string | undefined): Promise<MemberQuestion[]> {
  if (!isSupabaseConfigured()) return [];
  const supabase = createClient();
  const [qRes, lRes] = await Promise.all([
    supabase.from('member_questions').select('*').order('created_at', { ascending: false }).limit(200),
    supabase.from('member_question_likes').select('question_id, user_id').limit(5000),
  ]);
  const questions = (qRes.data ?? []) as Array<Record<string, unknown>>;
  const likes = (lRes.data ?? []) as Array<{ question_id: string; user_id: string }>;

  const countByQ: Record<string, number> = {};
  const likedByMe = new Set<string>();
  for (const l of likes) {
    countByQ[l.question_id] = (countByQ[l.question_id] ?? 0) + 1;
    if (userId && l.user_id === userId) likedByMe.add(l.question_id);
  }

  return questions.map((q) => ({
    id: String(q.id),
    user_id: String(q.user_id),
    author_name: (q.author_name as string | null) ?? null,
    is_anonymous: Boolean(q.is_anonymous),
    question: String(q.question ?? ''),
    answer: (q.answer as string | null) ?? null,
    answered_at: (q.answered_at as string | null) ?? null,
    status: String(q.status ?? 'pending'),
    created_at: String(q.created_at),
    like_count: countByQ[String(q.id)] ?? 0,
    liked: likedByMe.has(String(q.id)),
  }));
}

/** Admin: answer (or update the answer of) a member question — iOS parity. */
export async function answerQuestion(questionId: string, answer: string, adminId: string): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = createClient();
  const { error } = await supabase
    .from('member_questions')
    .update({
      answer: answer.trim(),
      answered_by: adminId,
      answered_at: new Date().toISOString(),
      status: 'answered',
      updated_at: new Date().toISOString(),
    })
    .eq('id', questionId);
  if (error) throw error;
}

export async function createQuestion(userId: string, question: string, isAnonymous: boolean, authorName: string | null): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = createClient();
  const { error } = await supabase.from('member_questions').insert({
    user_id: userId,
    question: question.trim(),
    is_anonymous: isAnonymous,
    author_name: isAnonymous ? null : authorName,
    status: 'pending',
  });
  if (error) throw error;
}

export async function toggleQuestionLike(userId: string, questionId: string, liked: boolean): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = createClient();
  if (liked) await supabase.from('member_question_likes').delete().eq('user_id', userId).eq('question_id', questionId);
  else await supabase.from('member_question_likes').insert({ user_id: userId, question_id: questionId });
}

export async function deleteQuestion(id: string): Promise<void> {
  if (!isSupabaseConfigured()) throw new Error('Not available in demo mode.');
  const supabase = createClient();
  const { error } = await supabase.from('member_questions').delete().eq('id', id);
  if (error) throw error;
}
