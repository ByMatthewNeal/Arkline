-- Scheduled broadcasts: adds the missing scheduled_at column the editor's
-- Schedule UI writes to, plus the pg_cron job that auto-publishes due posts
-- via the publish-scheduled-broadcasts edge function.
--
-- Before this, the broadcasts table had no scheduled_at column at all, so any
-- attempt to schedule a post (new or edit) failed, and nothing ever published.

ALTER TABLE public.broadcasts
  ADD COLUMN IF NOT EXISTS scheduled_at timestamptz;

-- Partial index keeps the every-minute "due" lookup cheap.
CREATE INDEX IF NOT EXISTS idx_broadcasts_scheduled_due
  ON public.broadcasts (scheduled_at)
  WHERE status = 'scheduled';

COMMENT ON COLUMN public.broadcasts.scheduled_at IS
  'When a scheduled broadcast should auto-publish. Processed by the publish-scheduled-broadcasts cron.';

-- Every-minute publisher. Authenticates to the edge function with the shared
-- x-cron-secret (the function pins verify_jwt = false in config.toml).
SELECT cron.schedule(
  'publish-scheduled-broadcasts',
  '* * * * *',
  $$
  SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/publish-scheduled-broadcasts',
    headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
