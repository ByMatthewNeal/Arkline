-- Add cron job for compute-signal-analytics (daily at 01:00 UTC)
-- Computes rolling performance analytics and adaptive parameters for the fibonacci pipeline.

DO $$ BEGIN PERFORM cron.unschedule('compute-signal-analytics-daily'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
    'compute-signal-analytics-daily',
    '0 1 * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/compute-signal-analytics',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
