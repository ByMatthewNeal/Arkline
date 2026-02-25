-- Auto-publish scheduled broadcasts every minute.
-- Uses pg_cron if available; the edge function handles the actual update
-- and triggers push notifications.

-- Attempt to enable pg_cron (may already be enabled or unavailable)
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron not available — use an external scheduler instead';
END $$;

-- Schedule the cron job if pg_cron is available
DO $$
BEGIN
    -- Remove existing job if present (idempotent)
    PERFORM cron.unschedule('publish-scheduled-broadcasts');
EXCEPTION WHEN OTHERS THEN
    NULL; -- Job didn't exist, that's fine
END $$;

DO $$
BEGIN
    PERFORM cron.schedule(
        'publish-scheduled-broadcasts',
        '* * * * *', -- every minute
        $$
        SELECT net.http_post(
            url := current_setting('app.supabase_url') || '/functions/v1/publish-scheduled',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-cron-secret', current_setting('app.cron_secret')
            ),
            body := '{}'::jsonb
        );
        $$
    );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron scheduling failed — configure an external cron or use the SQL fallback below';
END $$;

-- Fallback: pure-SQL cron that can be run directly without the edge function.
-- This is simpler but cannot trigger push notifications.
-- Uncomment and schedule externally if pg_cron is not available:
--
-- UPDATE broadcasts
--    SET status = 'published', published_at = now()
--  WHERE status = 'scheduled'
--    AND scheduled_at <= now();
