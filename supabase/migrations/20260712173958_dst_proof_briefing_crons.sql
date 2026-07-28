-- DST-proof the daily briefing crons.
--
-- pg_cron runs on UTC, so briefings pinned to a single UTC hour drift an hour
-- EARLIER on the ET clock every winter when daylight saving ends: the "after
-- market open" briefing would fire 9:00 AM ET (before the 9:30 open) and the
-- "after close" briefing at 4:00 PM ET (at the bell, before closes settle).
-- The old plan was a comment saying "update UTC times in November" — a manual
-- ritual that fails silently.
--
-- Fix (same pattern as publish-market-deck): schedule each briefing at BOTH
-- candidate UTC hours (EDT-aligned + EST-aligned) and guard the http_post in
-- SQL with the DST-aware wall clock — `now() AT TIME ZONE 'America/New_York'`.
-- Exactly one of each pair matches the intended ET hour year-round; the other
-- selects zero rows and does nothing.
--
-- Intended ET schedule (unchanged): Mon–Fri 10:00 AM + 5:00 PM,
-- Saturday 12:00 PM, Sunday 7:00 PM.
-- Note the Sunday-EST pair runs at 00:00 UTC MONDAY (= Sunday 7 PM EST),
-- hence its different day-of-week; the ET dow guard keeps it honest.

-- ── Remove the old single-entry jobs (and any prior guarded versions) ───────
SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname IN (
  'daily-briefing-morning', 'daily-briefing-evening',
  'daily-briefing-saturday', 'daily-briefing-sunday',
  'daily-briefing-morning-edt', 'daily-briefing-morning-est',
  'daily-briefing-evening-edt', 'daily-briefing-evening-est',
  'daily-briefing-saturday-edt', 'daily-briefing-saturday-est',
  'daily-briefing-sunday-edt', 'daily-briefing-sunday-est'
);

-- ── Mon–Fri morning briefing: 10:00 AM ET ───────────────────────────────────
SELECT cron.schedule('daily-briefing-morning-edt', '0 14 * * 1-5',
$$SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/market-summary',
    headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb)
  WHERE EXTRACT(HOUR FROM now() AT TIME ZONE 'America/New_York') = 10
    AND EXTRACT(DOW FROM now() AT TIME ZONE 'America/New_York') BETWEEN 1 AND 5$$);

SELECT cron.schedule('daily-briefing-morning-est', '0 15 * * 1-5',
$$SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/market-summary',
    headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb)
  WHERE EXTRACT(HOUR FROM now() AT TIME ZONE 'America/New_York') = 10
    AND EXTRACT(DOW FROM now() AT TIME ZONE 'America/New_York') BETWEEN 1 AND 5$$);

-- ── Mon–Fri evening briefing: 5:00 PM ET ────────────────────────────────────
SELECT cron.schedule('daily-briefing-evening-edt', '0 21 * * 1-5',
$$SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/market-summary',
    headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb)
  WHERE EXTRACT(HOUR FROM now() AT TIME ZONE 'America/New_York') = 17
    AND EXTRACT(DOW FROM now() AT TIME ZONE 'America/New_York') BETWEEN 1 AND 5$$);

SELECT cron.schedule('daily-briefing-evening-est', '0 22 * * 1-5',
$$SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/market-summary',
    headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb)
  WHERE EXTRACT(HOUR FROM now() AT TIME ZONE 'America/New_York') = 17
    AND EXTRACT(DOW FROM now() AT TIME ZONE 'America/New_York') BETWEEN 1 AND 5$$);

-- ── Saturday briefing: 12:00 PM ET ──────────────────────────────────────────
SELECT cron.schedule('daily-briefing-saturday-edt', '0 16 * * 6',
$$SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/market-summary',
    headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb)
  WHERE EXTRACT(HOUR FROM now() AT TIME ZONE 'America/New_York') = 12
    AND EXTRACT(DOW FROM now() AT TIME ZONE 'America/New_York') = 6$$);

SELECT cron.schedule('daily-briefing-saturday-est', '0 17 * * 6',
$$SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/market-summary',
    headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb)
  WHERE EXTRACT(HOUR FROM now() AT TIME ZONE 'America/New_York') = 12
    AND EXTRACT(DOW FROM now() AT TIME ZONE 'America/New_York') = 6$$);

-- ── Sunday briefing: 7:00 PM ET ─────────────────────────────────────────────
SELECT cron.schedule('daily-briefing-sunday-edt', '0 23 * * 0',
$$SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/market-summary',
    headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb)
  WHERE EXTRACT(HOUR FROM now() AT TIME ZONE 'America/New_York') = 19
    AND EXTRACT(DOW FROM now() AT TIME ZONE 'America/New_York') = 0$$);

-- 00:00 UTC Monday = 7:00 PM EST Sunday (winter); ET-dow guard keeps it Sunday-only
SELECT cron.schedule('daily-briefing-sunday-est', '0 0 * * 1',
$$SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/market-summary',
    headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb)
  WHERE EXTRACT(HOUR FROM now() AT TIME ZONE 'America/New_York') = 19
    AND EXTRACT(DOW FROM now() AT TIME ZONE 'America/New_York') = 0$$);
