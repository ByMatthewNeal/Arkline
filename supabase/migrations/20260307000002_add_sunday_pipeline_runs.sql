-- Add Sunday full pipeline runs for crypto action during extended hours
-- Sunday 8am-10pm EST = 13:00 Sunday - 03:00 Monday UTC
--
-- Already covered by existing schedule:
--   12:05 UTC (7:05am EST) - full pipeline
--   16:05 UTC (11:05am EST) - full pipeline
--
-- Adding:
--   20:05 UTC Sunday (3:05pm EST) - full pipeline (was resolve-only)
--   00:05 UTC Monday (7:05pm EST Sunday) - full pipeline (was resolve-only)

-- Sunday afternoon full pipeline (3:05pm EST)
DO $outer$
BEGIN
    PERFORM cron.unschedule('fibonacci-pipeline-sunday-afternoon');
EXCEPTION WHEN OTHERS THEN NULL;
END $outer$;

DO $outer$
BEGIN
    PERFORM cron.schedule(
        'fibonacci-pipeline-sunday-afternoon',
        '5 20 * * 0',
        $$
        SELECT net.http_post(
            url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/fibonacci-pipeline',
            headers := '{"Content-Type":"application/json","x-cron-secret":"' || current_setting('app.cron_secret') || '"}'::jsonb,
            body := '{}'::jsonb
        );
        $$
    );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Sunday afternoon cron scheduling failed — add manually in Dashboard';
END $outer$;

-- Sunday evening full pipeline (7:05pm EST = 00:05 Monday UTC)
DO $outer$
BEGIN
    PERFORM cron.unschedule('fibonacci-pipeline-sunday-evening');
EXCEPTION WHEN OTHERS THEN NULL;
END $outer$;

DO $outer$
BEGIN
    PERFORM cron.schedule(
        'fibonacci-pipeline-sunday-evening',
        '5 0 * * 1',
        $$
        SELECT net.http_post(
            url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/fibonacci-pipeline',
            headers := '{"Content-Type":"application/json","x-cron-secret":"' || current_setting('app.cron_secret') || '"}'::jsonb,
            body := '{}'::jsonb
        );
        $$
    );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Sunday evening cron scheduling failed — add manually in Dashboard';
END $outer$;
