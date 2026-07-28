-- Allow admins to post/edit portfolio targets from the app (matches
-- the admin-write pattern used on market_snapshots etc.)
-- Applied to production 2026-07-14.

do $$ begin
  create policy model_portfolio_targets_insert_admin on model_portfolio_targets
    for insert to authenticated
    with check (exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    ));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy model_portfolio_targets_update_admin on model_portfolio_targets
    for update to authenticated
    using (exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    ));
exception when duplicate_object then null; end $$;
