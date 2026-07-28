-- Exported from the live database on 2026-07-27.
-- Originally applied directly (not via `supabase db push`), so no repo file
-- existed and the migrations could not reproduce production.
-- Filename version matches the applied migration version exactly.

create table if not exists public.member_questions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  author_name text,
  is_anonymous boolean not null default false,
  question text not null,
  answer text,
  answered_at timestamptz,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

create table if not exists public.member_question_likes (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.member_questions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (question_id, user_id)
);

create index if not exists idx_mq_created on public.member_questions(created_at desc);
create index if not exists idx_mql_question on public.member_question_likes(question_id);

alter table public.member_questions enable row level security;
alter table public.member_question_likes enable row level security;

drop policy if exists mq_select on public.member_questions;
create policy mq_select on public.member_questions for select using (auth.uid() is not null);
drop policy if exists mq_insert on public.member_questions;
create policy mq_insert on public.member_questions for insert with check (auth.uid() = user_id);
drop policy if exists mq_update on public.member_questions;
create policy mq_update on public.member_questions for update using (auth.uid() = user_id);
drop policy if exists mq_delete on public.member_questions;
create policy mq_delete on public.member_questions for delete using (auth.uid() = user_id);

drop policy if exists mql_select on public.member_question_likes;
create policy mql_select on public.member_question_likes for select using (auth.uid() is not null);
drop policy if exists mql_insert on public.member_question_likes;
create policy mql_insert on public.member_question_likes for insert with check (auth.uid() = user_id);
drop policy if exists mql_delete on public.member_question_likes;
create policy mql_delete on public.member_question_likes for delete using (auth.uid() = user_id);
