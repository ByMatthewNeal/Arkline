-- Signal-monitor cron job (every 30 minutes)
--
-- Lightweight price checker that runs twice per hour to catch SL/T1/runner
-- resolution faster than the 4H pipeline alone. Aggregates last 4 1H candles
-- from Binance and resolves triggered signals accordingly.

-- Remove old schedule if it existed
DO $$
BEGIN
    PERFORM cron.unschedule('signal-monitor-hourly');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- Schedule every 30 minutes at :05 and :35 (offset from pipeline at :00)
DO $outer$
BEGIN
    PERFORM cron.schedule(
        'signal-monitor-30m',
        '5,35 * * * *',
        $$
        SELECT net.http_post(
            url := current_setting('app.supabase_url') || '/functions/v1/signal-monitor',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-cron-secret', current_setting('app.cron_secret')
            ),
            body := '{}'::jsonb
        );
        $$
    );
END $outer$;
