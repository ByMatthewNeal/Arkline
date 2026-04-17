-- Reset false AVAX T1 hit caused by Coinbase-only wick detection (no Binance confirmation).
-- Signal: AVAX Short from Mar 30, 2026 ~9:40 PM ET. T1 was falsely triggered, causing
-- the runner to immediately close at breakeven. Reset to triggered status so it can be
-- properly monitored going forward.

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
  duration_hours = NULL,
  resolution_source = NULL
WHERE asset = 'AVAX'
  AND signal_type IN ('sell', 'strong_sell')
  AND generated_at >= '2026-03-30T00:00:00Z'
  AND status = 'target_hit'
  AND t1_hit_at IS NOT NULL;
