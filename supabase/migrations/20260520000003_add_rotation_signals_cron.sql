-- Schedule daily rotation signal computation at 01:00 UTC
SELECT cron.schedule(
    'compute-rotation-signals-daily',
    '0 1 * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/compute-rotation-signals',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
