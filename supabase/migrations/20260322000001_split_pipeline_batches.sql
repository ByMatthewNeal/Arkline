-- Split fibonacci pipeline into 2 batches to stay within free tier compute limits
-- 26 assets total: batch 0 = first 13, batch 1 = last 13

-- Remove old single-job schedules
DO $$ BEGIN PERFORM cron.unschedule('fibonacci-pipeline-30m'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN PERFORM cron.unschedule('fibonacci-pipeline-hourly'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- Batch 0: runs at :05 and :35 past each hour
SELECT cron.schedule(
    'fibonacci-pipeline-batch0',
    '5,35 * * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/fibonacci-pipeline',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{"batch":0}'::jsonb
    )$$
);

-- Batch 1: runs at :10 and :40 past each hour (5 min offset)
SELECT cron.schedule(
    'fibonacci-pipeline-batch1',
    '10,40 * * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/fibonacci-pipeline',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{"batch":1}'::jsonb
    )$$
);
