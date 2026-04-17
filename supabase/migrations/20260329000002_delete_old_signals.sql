-- Delete old trade signals that predate the current strategy (2026-03-24)
-- and all scalp-tier signals (timeframe = '1h'), which are no longer generated.
--
-- This cleans up the database so WR/performance stats reflect only the current
-- pipeline configuration (swing-only, top 10 assets by backtest PF).

-- Count before (for logging in migration output)
DO $$
DECLARE
  pre_cutoff_count INT;
  scalp_count INT;
  total_before INT;
BEGIN
  SELECT COUNT(*) INTO total_before FROM trade_signals;
  SELECT COUNT(*) INTO pre_cutoff_count FROM trade_signals WHERE generated_at < '2026-03-24T00:00:00Z';
  SELECT COUNT(*) INTO scalp_count FROM trade_signals WHERE timeframe = '1h' AND generated_at >= '2026-03-24T00:00:00Z';
  RAISE NOTICE 'Total signals before: %, pre-cutoff: %, scalp (post-cutoff): %', total_before, pre_cutoff_count, scalp_count;
END $$;

-- Delete signals generated before the current strategy locked in
DELETE FROM trade_signals WHERE generated_at < '2026-03-24T00:00:00Z';

-- Delete any scalp-tier signals (shouldn't be many post-3/24 since scalps were disabled)
DELETE FROM trade_signals WHERE timeframe = '1h';
