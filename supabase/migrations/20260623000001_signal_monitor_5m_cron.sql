-- Tighten the trade-signal resolver cadence from every 30 minutes (:05/:35) to
-- every 5 minutes. The monitor reads the live forming candle, so detection is
-- accurate the moment it runs — the old 30-minute schedule was the sole source
-- of the 10–15 minute notification lag on T1 / stop / runner events.

DO $$ BEGIN PERFORM cron.unschedule('signal-monitor-30m'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN PERFORM cron.unschedule('signal-monitor-5m'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
    'signal-monitor-5m',
    '*/5 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/signal-monitor',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-cron-secret', 'arkline-cron-2026'
        ),
        body := '{}'::jsonb
    );
    $$
);
