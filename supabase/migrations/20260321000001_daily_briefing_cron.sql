-- Schedule daily briefing generation
-- Weekdays: 10:00 AM ET (morning) + 5:00 PM ET (evening)
-- Weekends: 12:00 PM ET (weekend) — crypto-focused, shorter
-- Currently DST (EDT = UTC-4): 14:00/21:00/16:00 UTC
-- In winter (EST = UTC-5): these shift to 9am/4pm/11am EST
-- Update UTC times in November if exact EST times matter

-- Unschedule if already exists
DO $$ BEGIN PERFORM cron.unschedule('daily-briefing-morning'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN PERFORM cron.unschedule('daily-briefing-evening'); EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN PERFORM cron.unschedule('daily-briefing-weekend'); EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- Morning briefing: 10:00 AM EDT (14:00 UTC) — Mon-Fri only
SELECT cron.schedule(
    'daily-briefing-morning',
    '0 14 * * 1-5',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/market-summary',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{"slot":"morning"}'::jsonb
    )$$
);

-- Evening briefing: 5:00 PM EDT (21:00 UTC) — Mon-Fri only
SELECT cron.schedule(
    'daily-briefing-evening',
    '0 21 * * 1-5',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/market-summary',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{"slot":"evening"}'::jsonb
    )$$
);

-- Weekend briefing: 12:00 PM EDT (16:00 UTC) — Sat-Sun only
SELECT cron.schedule(
    'daily-briefing-weekend',
    '0 16 * * 0,6',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/market-summary',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{"slot":"weekend"}'::jsonb
    )$$
);
