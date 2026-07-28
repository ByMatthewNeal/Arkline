-- Cloud-synced app preferences (dashboard layout + all settings) so a user's
-- setup survives reinstalls and stays in sync across their devices.
-- Owner-update RLS already covers these columns (they are not in the
-- privilege-locked set: role / subscription_status / trial_end).
-- Already applied to the live DB; idempotent for fresh environments.
alter table public.profiles
  add column if not exists app_preferences jsonb,
  add column if not exists app_preferences_updated_at timestamptz;
