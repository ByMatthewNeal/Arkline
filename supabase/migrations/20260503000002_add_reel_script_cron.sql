-- Generate Reel scripts daily at 9:15 AM ET (13:15 UTC during EDT)
SELECT cron.schedule(
    'generate-reel-script-daily',
    '15 13 * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/generate-reel-script',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
