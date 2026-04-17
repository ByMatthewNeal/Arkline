-- Reset false ETH T1 hit caused by mid-candle fallback using pre-trigger lows
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
WHERE asset = 'ETH'
  AND status IN ('target_hit', 'invalidated')
  AND t1_hit_at IS NOT NULL
  AND triggered_at > now() - interval '2 days';
