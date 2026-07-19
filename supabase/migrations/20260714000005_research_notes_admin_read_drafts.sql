-- Admins can read drafts/archived notes (users still only see published).
-- Applied to production 2026-07-14.
do $$ begin
  create policy research_notes_read_admin on research_notes
    for select to authenticated
    using (exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    ));
exception when duplicate_object then null; end $$;
