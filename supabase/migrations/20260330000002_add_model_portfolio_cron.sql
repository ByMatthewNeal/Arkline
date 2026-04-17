-- Schedule compute-model-portfolios to run daily at 00:30 UTC
-- (after compute-positioning-signals at 00:15 UTC)

SELECT cron.unschedule('compute-model-portfolios') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'compute-model-portfolios'
);

SELECT cron.schedule(
  'compute-model-portfolios',
  '30 0 * * *',
  $$
  SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/compute-model-portfolios',
    headers := '{"Content-Type": "application/json", "x-cron-secret": "arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
