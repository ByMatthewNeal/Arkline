-- Fix all cron jobs: replace current_setting() with hardcoded values
-- Supabase free tier cannot ALTER DATABASE to set app.* config params,
-- so current_setting('app.supabase_url') and current_setting('app.cron_secret') return NULL.

-- Unschedule all existing (broken) cron jobs
DO $$ BEGIN PERFORM cron.unschedule('publish-scheduled-broadcasts'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN PERFORM cron.unschedule('fibonacci-pipeline-hourly'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN PERFORM cron.unschedule('fibonacci-pipeline-sunday-afternoon'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN PERFORM cron.unschedule('fibonacci-pipeline-sunday-evening'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN PERFORM cron.unschedule('signal-monitor-30m'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN PERFORM cron.unschedule('sync-economic-events-2h'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN PERFORM cron.unschedule('sync-crypto-prices-5m'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- 1. Publish scheduled broadcasts (every minute)
SELECT cron.schedule(
    'publish-scheduled-broadcasts',
    '* * * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/publish-scheduled',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);

-- 2. Fibonacci pipeline (hourly at :05)
SELECT cron.schedule(
    'fibonacci-pipeline-hourly',
    '5 * * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/fibonacci-pipeline',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);

-- 3. Fibonacci pipeline Sunday afternoon (20:05 UTC)
SELECT cron.schedule(
    'fibonacci-pipeline-sunday-afternoon',
    '5 20 * * 0',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/fibonacci-pipeline',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{"force":true}'::jsonb
    )$$
);

-- 4. Fibonacci pipeline Sunday evening (00:05 UTC Monday)
SELECT cron.schedule(
    'fibonacci-pipeline-sunday-evening',
    '5 0 * * 1',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/fibonacci-pipeline',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{"force":true}'::jsonb
    )$$
);

-- 5. Signal monitor (every 30 min at :05 and :35)
SELECT cron.schedule(
    'signal-monitor-30m',
    '5,35 * * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/signal-monitor',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);

-- 6. Sync economic events (every 30 minutes)
SELECT cron.schedule(
    'sync-economic-events-30m',
    '*/30 * * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/sync-economic-events',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);

-- 7. Sync crypto prices (every 5 minutes)
SELECT cron.schedule(
    'sync-crypto-prices-5m',
    '*/5 * * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/sync-crypto-prices',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
