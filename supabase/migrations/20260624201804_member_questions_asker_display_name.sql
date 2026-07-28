-- Exported from the live database on 2026-07-27.
-- Originally applied directly (not via `supabase db push`), so no repo file
-- existed and the migrations could not reproduce production.
-- Filename version matches the applied migration version exactly.

-- Per-question identity choice: the name to show publicly (their full name or
-- first name), or NULL to post anonymously. Captured at submit time so we never
-- need to read other members' profiles to render the board.
alter table public.member_questions
  add column if not exists asker_display_name text;
