-- Automate the Weekly Market Update: generate Sunday morning (draft, admin
-- review window), auto-publish + push at exactly 12pm ET every Sunday.
--
-- Fixes two pre-existing problems with 'generate-market-deck-weekly':
--   1. It pointed at the WRONG project ref (fgwmsjspxgeamxbkvhlb — every other
--      cron uses mprbbjgrshfbupheuscn), so it has been a silent no-op.
--   2. Nothing ever published the draft — publishing was manual-only in the app.
--
-- DST handling: pg_cron runs in UTC. 12pm ET is 16:00 UTC during EDT and
-- 17:00 UTC during EST, so TWO publish jobs are scheduled; each passes
-- et_guard_hour=12 and the publish-market-deck function no-ops unless it is
-- actually 12pm in America/New_York. Exactly one fires year-round.

-- ── Remove the broken/stale jobs ────────────────────────────────────────────
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname IN (
  'generate-market-deck-weekly',
  'publish-market-deck-edt',
  'publish-market-deck-est'
);

-- ── Generate the draft: Sunday 13:00 UTC (9am EDT / 8am EST) ────────────────
-- Draft is upserted on week_start, so re-runs are safe. Admin can review/edit
-- in the app any time before noon ET; the publisher takes whatever is latest.
SELECT cron.schedule(
    'generate-market-deck-weekly',
    '0 13 * * 0',
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/generate-market-deck',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb,
        timeout_milliseconds := 300000
    )$$
);

-- ── Publish + push: exactly 12pm ET (dual-entry DST guard) ──────────────────
SELECT cron.schedule(
    'publish-market-deck-edt',
    '0 16 * * 0',  -- 12pm ET while daylight saving (EDT); guard no-ops in winter
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/publish-market-deck',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{"et_guard_hour":12}'::jsonb,
        timeout_milliseconds := 120000
    )$$
);

SELECT cron.schedule(
    'publish-market-deck-est',
    '0 17 * * 0',  -- 12pm ET in winter (EST); guard no-ops while daylight saving
    $$SELECT net.http_post(
        url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/publish-market-deck',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{"et_guard_hour":12}'::jsonb,
        timeout_milliseconds := 120000
    )$$
);
