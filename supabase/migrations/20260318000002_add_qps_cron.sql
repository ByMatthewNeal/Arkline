-- Schedule daily positioning signals computation at 00:15 UTC
DO $$ BEGIN PERFORM cron.unschedule('compute-positioning-signals-daily'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

SELECT cron.schedule(
    'compute-positioning-signals-daily',
    '15 0 * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/compute-positioning-signals',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
