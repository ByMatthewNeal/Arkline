-- Broader reset for AVAX signal — previous migration may have missed due to age filter
-- Find the most recent AVAX signal that was falsely closed and reset it
UPDATE trade_signals
SET
  status = 'triggered',
  outcome = NULL,
  outcome_pct = NULL,
  t1_hit_at = NULL,
  t1_pnl_pct = NULL,
  runner_stop = NULL,
  runner_exit_price = NULL,
  runner_pnl_pct = NULL,
  best_price = NULL,
  closed_at = NULL,
  duration_hours = NULL
WHERE asset = 'AVAX'
  AND t1_hit_at IS NOT NULL
  AND status != 'triggered'
  AND triggered_at > now() - interval '14 days';
