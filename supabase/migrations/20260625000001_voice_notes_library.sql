-- Voice library: a private corpus of everything the admin speaks into the app.
-- Each row is one spoken (or typed) note that can be reused to generate content
-- in their own voice across formats. Also feeds voice-matching over time.
-- Already applied to the live DB; idempotent for fresh environments.
create table if not exists public.voice_notes (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  transcript text not null,
  title text,
  word_count integer not null default 0,
  source text not null default 'voice', -- 'voice' | 'typed'
  created_at timestamptz not null default now()
);

create index if not exists voice_notes_author_created_idx
  on public.voice_notes (author_id, created_at desc);

alter table public.voice_notes enable row level security;

-- Owner-only access. Only the author can see/manage their own notes.
drop policy if exists "voice_notes_select_own" on public.voice_notes;
create policy "voice_notes_select_own" on public.voice_notes
  for select using (auth.uid() = author_id);

drop policy if exists "voice_notes_insert_own" on public.voice_notes;
create policy "voice_notes_insert_own" on public.voice_notes
  for insert with check (auth.uid() = author_id);

drop policy if exists "voice_notes_update_own" on public.voice_notes;
create policy "voice_notes_update_own" on public.voice_notes
  for update using (auth.uid() = author_id) with check (auth.uid() = author_id);

drop policy if exists "voice_notes_delete_own" on public.voice_notes;
create policy "voice_notes_delete_own" on public.voice_notes
  for delete using (auth.uid() = author_id);
