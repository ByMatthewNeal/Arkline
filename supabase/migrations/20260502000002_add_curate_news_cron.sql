-- Curate news pipeline: every 30 minutes at :10 and :40
-- Offset from existing crons at :00/:05/:15/:30/:35
SELECT cron.schedule(
    'curate-news-30m',
    '10,40 * * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/curate-news',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
