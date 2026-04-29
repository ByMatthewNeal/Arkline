-- Schedule health-check to run every hour at :45 past
-- (offset from other crons to avoid contention)

DO $$ BEGIN PERFORM cron.unschedule('health-check-hourly'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
    'health-check-hourly',
    '45 * * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/health-check',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
