-- Add runner tracking columns for split exit strategy (50% at T1, trail runner)

ALTER TABLE public.trade_signals
  ADD COLUMN IF NOT EXISTS best_price NUMERIC,
  ADD COLUMN IF NOT EXISTS runner_stop NUMERIC,
  ADD COLUMN IF NOT EXISTS runner_exit_price NUMERIC,
  ADD COLUMN IF NOT EXISTS risk_1r NUMERIC,
  ADD COLUMN IF NOT EXISTS t1_pnl_pct NUMERIC,
  ADD COLUMN IF NOT EXISTS runner_pnl_pct NUMERIC,
  ADD COLUMN IF NOT EXISTS ema_trend_aligned BOOLEAN DEFAULT false;

-- Relax RR constraint from 1.5 to 1.0 for the new strategy
ALTER TABLE public.trade_signals
  DROP CONSTRAINT IF EXISTS valid_rr;
ALTER TABLE public.trade_signals
  ADD CONSTRAINT valid_rr CHECK (risk_reward_ratio >= 1.0);

-- pg_cron jobs: configure manually in Supabase Dashboard SQL Editor.
-- Supabase does not support custom app.* config parameters, so cron jobs
-- must hardcode the project URL and CRON_SECRET directly.
--
-- Full pipeline (US session 4h candles — 7:05am + 11:05am EST):
--   SELECT cron.schedule('fibonacci-pipeline-4h', '5 12,16 * * *', $$
--     SELECT net.http_post(
--       url := 'https://<project-ref>.supabase.co/functions/v1/fibonacci-pipeline',
--       headers := '{"Content-Type":"application/json","x-cron-secret":"<CRON_SECRET>"}'::jsonb,
--       body := '{}'::jsonb
--     );
--   $$);
--
-- Resolve-only (off-candle hours):
--   SELECT cron.schedule('fibonacci-resolver-4h', '5 0,4,8,20 * * *', $$
--     SELECT net.http_post(
--       url := 'https://<project-ref>.supabase.co/functions/v1/fibonacci-pipeline',
--       headers := '{"Content-Type":"application/json","x-cron-secret":"<CRON_SECRET>"}'::jsonb,
--       body := '{"resolve_only":true}'::jsonb
--     );
--   $$);
