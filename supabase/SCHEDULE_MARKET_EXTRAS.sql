-- Schedule the refresh-market-extras Edge Function with pg_cron + pg_net.
-- Run once in the Supabase SQL editor after deploying the function.
--
--   supabase functions deploy refresh-market-extras
--   (optional) set FRED_API_KEY in Project Settings → Edge Functions → Secrets
--   then run this file.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Clear any previous job first (safe to run even if none exists):
select cron.unschedule('refresh-market-extras');

-- Every 15 minutes, invoke the function. The function is verify_jwt = false, so
-- only the public (publishable) anon key is needed — no secret. Project ref and
-- key are pre-filled below.
select cron.schedule(
  'refresh-market-extras',
  '*/15 * * * *',
  $$
  select net.http_post(
    url     := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/refresh-market-extras',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'apikey', 'sb_publishable_OD56MqP74dT54PEDZNpcrQ_PPm5ug0P'
    ),
    body    := '{}'::jsonb
  );
  $$
);

-- To remove later:  select cron.unschedule('refresh-market-extras');
-- To run once now:  invoke the function URL above, or `supabase functions invoke refresh-market-extras`.
