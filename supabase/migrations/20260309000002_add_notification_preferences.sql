-- Add notification_preferences jsonb column to profiles
-- Stores per-user granular signal notification preferences.
-- Default: all enabled (null = all on, edge function treats missing keys as true).

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS notification_preferences jsonb DEFAULT NULL;

COMMENT ON COLUMN profiles.notification_preferences IS
  'Per-user notification preferences. Keys: signal_new, signal_t1_hit, signal_stop_loss, signal_runner_close, signal_expiry. Values: boolean. Null/missing key = enabled.';
