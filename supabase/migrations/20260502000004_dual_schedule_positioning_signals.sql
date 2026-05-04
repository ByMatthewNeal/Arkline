-- Split positioning signals into dual schedule:
--   Equities panel: 20:20 UTC (shortly after US market close at 4 PM ET)
--   Crypto panel:   00:15 UTC (daily UTC candle close)

-- Remove the old single schedule
SELECT cron.unschedule('compute-positioning-signals-daily');

-- Equities panel: fires at 20:20 UTC (4:20 PM ET) — 20 min after US market close
SELECT cron.schedule(
    'positioning-signals-equities',
    '20 20 * * 1-5',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/compute-positioning-signals',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{"panel":"equities"}'::jsonb
    )$$
);

-- Crypto panel: fires at 00:15 UTC daily (including weekends)
SELECT cron.schedule(
    'positioning-signals-crypto',
    '15 0 * * *',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/compute-positioning-signals',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{"panel":"crypto"}'::jsonb
    )$$
);
