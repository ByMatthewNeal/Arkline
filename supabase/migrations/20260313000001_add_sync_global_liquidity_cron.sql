-- Add cron job for sync-global-liquidity edge function
-- Runs daily at 08:00 UTC (after BIS/FRED data updates)
DO $$ BEGIN PERFORM cron.unschedule('sync-global-liquidity-daily'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
    'sync-global-liquidity-daily',
    '0 8 * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/sync-global-liquidity',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
