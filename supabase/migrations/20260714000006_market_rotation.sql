-- Daily cross-market rotation signal: which market (crypto vs equities) is
-- currently favored, with the reasoning stored as data so the app can always
-- show WHY. Descriptive, never prescriptive.
-- Applied to production 2026-07-14.

create table if not exists market_rotation (
  id uuid primary key default gen_random_uuid(),
  rotation_date date not null unique,
  favored text not null check (favored in ('crypto','stocks','balanced')),
  score int not null default 0,          -- net votes: positive = crypto, negative = stocks
  factors jsonb not null default '[]'::jsonb,  -- [{"factor": "...", "vote": "crypto|stocks|neutral", "detail": "..."}]
  created_at timestamptz default now()
);

alter table market_rotation enable row level security;

do $$ begin
  create policy market_rotation_read on market_rotation
    for select to authenticated using (true);
exception when duplicate_object then null; end $$;

-- Daily at 23:00 UTC (after both markets' pipelines have run)
SELECT cron.unschedule('compute-market-rotation') WHERE EXISTS (
  SELECT 1 FROM cron.job WHERE jobname = 'compute-market-rotation'
);

SELECT cron.schedule(
  'compute-market-rotation',
  '0 23 * * *',
  $$
  SELECT net.http_post(
    url := 'https://mprbbjgrshfbupheuscn.supabase.co/functions/v1/compute-market-rotation',
    headers := '{"Content-Type": "application/json", "x-cron-secret": "arkline-cron-2026"}'::jsonb,
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
