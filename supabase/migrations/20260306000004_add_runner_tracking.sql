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
-- NOTE: Schedule updated in 20260308000001 — full pipeline now runs on ALL
-- six 4H candle closes (0:05, 4:05, 8:05, 12:05, 16:05, 20:05 UTC).
-- See that migration for the current cron setup.
