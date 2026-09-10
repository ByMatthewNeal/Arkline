-- The old manage_broadcasts policy granted ALL operations to any
-- authenticated user, so any member could edit or delete broadcasts via the
-- API (no client exposed UI for it, but the API allowed it). Writes are
-- admin-only; member reads stay covered by broadcasts_select_policy /
-- select_published, and the count-sync triggers are SECURITY DEFINER so
-- read/reaction inserts still update view_count and reaction_count.
-- Already applied to the live DB via MCP; idempotent for fresh environments.
drop policy if exists "manage_broadcasts" on public.broadcasts;
create policy "manage_broadcasts" on public.broadcasts
  for all
  using (is_admin())
  with check (is_admin());
