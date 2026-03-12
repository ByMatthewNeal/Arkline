-- Update economic events sync from every 2 hours to every 30 minutes (FMP Starter plan)
DO $$ BEGIN PERFORM cron.unschedule('sync-economic-events-2h'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
    'sync-economic-events-30m',
    '*/30 * * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/sync-economic-events',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
