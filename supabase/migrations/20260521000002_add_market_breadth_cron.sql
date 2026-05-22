-- Schedule compute-market-breadth daily at 01:30 UTC
-- (after compute-positioning-signals at 00:15 and compute-rotation-signals at 01:00)
SELECT cron.schedule(
    'compute-market-breadth-daily',
    '30 1 * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/compute-market-breadth',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
