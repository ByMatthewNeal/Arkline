-- Reset false AVAX T1 hit (triggered by fibonacci-pipeline single-source check)
-- Pipeline now uses dual-source (Coinbase + Binance) verification
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
  AND status IN ('target_hit', 'invalidated')
  AND t1_hit_at IS NOT NULL
  AND triggered_at > now() - interval '3 days';
