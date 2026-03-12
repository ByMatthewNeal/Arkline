-- Economic events sync cron job (every 2 hours at :15)
--
-- Fetches economic calendar data from FMP, upserts into economic_events,
-- and triggers Claude analysis for events with actual values.

-- Remove old schedule if it existed
DO $$
BEGIN
    PERFORM cron.unschedule('sync-economic-events-2h');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- Schedule every 2 hours at :15
DO $outer$
BEGIN
    PERFORM cron.schedule(
        'sync-economic-events-2h',
        '15 */2 * * *',
        $$
        SELECT net.http_post(
            url := current_setting('app.supabase_url') || '/functions/v1/sync-economic-events',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-cron-secret', current_setting('app.cron_secret')
            ),
            body := '{}'::jsonb
        );
        $$
    );
END $outer$;
