-- Exported from the live database on 2026-07-27.
-- Originally applied directly (not via `supabase db push`), so no repo file
-- existed and the migrations could not reproduce production.
-- Filename version matches the applied migration version exactly.

-- Public Q&A board: every member sees all incoming questions (except admin-
-- dismissed) and admin answers; members can like questions and answers but
-- cannot answer. Only admins answer / dismiss / export.

-- Public read for all members (admins also see dismissed for moderation).
drop policy if exists mq_select on public.member_questions;
create policy mq_select on public.member_questions
  for select to authenticated
  using (status <> 'dismissed' or public.is_admin());

-- Denormalized like counts for fast feed rendering.
alter table public.member_questions
  add column if not exists question_like_count integer not null default 0,
  add column if not exists answer_like_count integer not null default 0;

-- Likes: one per user per target (question vs answer).
create table if not exists public.member_question_likes (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.member_questions(id) on delete cascade,
  user_id     uuid not null references auth.users(id) on delete cascade,
  target      text not null default 'question',  -- question | answer
  created_at  timestamptz not null default now(),
  unique (question_id, user_id, target)
);
create index if not exists mq_likes_question_idx on public.member_question_likes (question_id);

alter table public.member_question_likes enable row level security;

drop policy if exists mql_select on public.member_question_likes;
create policy mql_select on public.member_question_likes
  for select to authenticated using (true);

drop policy if exists mql_insert_own on public.member_question_likes;
create policy mql_insert_own on public.member_question_likes
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists mql_delete_own on public.member_question_likes;
create policy mql_delete_own on public.member_question_likes
  for delete to authenticated using (user_id = auth.uid());

-- Keep like counts in sync.
create or replace function public.member_question_like_count_trigger()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (tg_op = 'INSERT') then
    if new.target = 'answer' then
      update public.member_questions set answer_like_count = answer_like_count + 1 where id = new.question_id;
    else
      update public.member_questions set question_like_count = question_like_count + 1 where id = new.question_id;
    end if;
  elsif (tg_op = 'DELETE') then
    if old.target = 'answer' then
      update public.member_questions set answer_like_count = greatest(0, answer_like_count - 1) where id = old.question_id;
    else
      update public.member_questions set question_like_count = greatest(0, question_like_count - 1) where id = old.question_id;
    end if;
  end if;
  return null;
end $$;

drop trigger if exists member_question_like_count on public.member_question_likes;
create trigger member_question_like_count
  after insert or delete on public.member_question_likes
  for each row execute function public.member_question_like_count_trigger();
