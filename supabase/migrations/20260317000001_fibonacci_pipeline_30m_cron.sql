-- Change fibonacci pipeline from hourly to every 30 minutes for faster signal detection
-- Catches 1H bounces sooner instead of waiting for full 4H candle close

-- Unschedule existing hourly job
DO $$ BEGIN PERFORM cron.unschedule('fibonacci-pipeline-hourly'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- Schedule every 30 minutes at :05 and :35
SELECT cron.schedule(
    'fibonacci-pipeline-30m',
    '5,35 * * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/fibonacci-pipeline',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
