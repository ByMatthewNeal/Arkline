-- Exported from the live database on 2026-07-27.
-- Originally applied directly (not via `supabase db push`), so no repo file
-- existed and the migrations could not reproduce production.
-- Filename version matches the applied migration version exactly.

-- Web onboarding parity: track completion + store the soft preference data
-- (investment interests, experience, portfolio size, crypto approach, goals)
-- that the iOS flow collects. Additive + nullable, safe for existing rows.
alter table public.profiles
  add column if not exists onboarding_complete boolean not null default false,
  add column if not exists onboarding_data jsonb;

-- Backfill: existing users with a name and an active/trialing sub are already
-- "onboarded" — don't trap them in the new flow.
update public.profiles
set onboarding_complete = true
where onboarding_complete = false
  and full_name is not null
  and subscription_status in ('active', 'trialing');
