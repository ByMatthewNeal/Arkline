-- Add cron job for collect-trends (daily at 02:00 UTC)
-- Fetches Wikipedia Bitcoin pageviews and normalizes to search interest index.

DO $$ BEGIN PERFORM cron.unschedule('collect-trends-daily'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
    'collect-trends-daily',
    '0 2 * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/collect-trends',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
