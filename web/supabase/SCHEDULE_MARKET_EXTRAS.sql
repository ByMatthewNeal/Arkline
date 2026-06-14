-- Schedule the refresh-market-extras Edge Function with pg_cron + pg_net.
-- Run once in the Supabase SQL editor after deploying the function.
--
--   supabase functions deploy refresh-market-extras
--   (optional) set FRED_API_KEY in Project Settings → Edge Functions → Secrets
--   then run this file.

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Every 15 minutes, invoke the function. Replace <PROJECT_REF> and the service
-- role key (or use a Vault secret) with your values.
select cron.schedule(
  'refresh-market-extras',
  '*/15 * * * *',
  $$
  select net.http_post(
    url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/refresh-market-extras',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <SUPABASE_SERVICE_ROLE_KEY>'
    ),
    body    := '{}'::jsonb
  );
  $$
);

-- To remove later:  select cron.unschedule('refresh-market-extras');
-- To run once now:  invoke the function URL above, or `supabase functions invoke refresh-market-extras`.
