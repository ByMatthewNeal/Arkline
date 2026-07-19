-- Schedule compute-stock-portfolios weekdays at 22:05 UTC (after US market close,
-- FMP EOD data available). Mirrors compute-model-portfolios cron pattern.

SELECT cron.unschedule('compute-stock-portfolios') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'compute-stock-portfolios'
);

SELECT cron.schedule(
  'compute-stock-portfolios',
  '5 22 * * 1-5',
  $$
  SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/compute-stock-portfolios',
    headers := '{"Content-Type": "application/json", "x-cron-secret": "arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
