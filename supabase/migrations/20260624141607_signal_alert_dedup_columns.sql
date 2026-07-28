-- Dedup timestamps for the two new proactive trade-signal alerts (consider-profit
-- and Target 2) so each fires at most once per signal — mirrors proximity_notified_at.
-- Already applied to the live DB; idempotent so it's safe to re-run.
alter table public.trade_signals
  add column if not exists consider_profit_notified_at timestamptz,
  add column if not exists t2_notified_at timestamptz;
