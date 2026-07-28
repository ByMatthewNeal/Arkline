-- Exported from the live database on 2026-07-27.
-- Originally applied directly (not via `supabase db push`), so no repo file
-- existed and the migrations could not reproduce production.
-- Filename version matches the applied migration version exactly.

-- Shadow scoring. composite_score (v1) proved anti-predictive on 229 closed
-- trades: its 80+ bucket won 40.5% (-0.50 expectancy) while its <65 bucket won
-- 60.6%. v2 keeps only the components that actually separated outcomes
-- (volume confluence, volume spike, mid-range R:R) and drops the ones that were
-- neutral or inverted (wick rejection, consecutive closes, the counter-trend
-- penalty, and the max-points-for-RR>=3 rule).
--
-- v2 is recorded alongside v1 and drives NOTHING. Its weights were fitted on the
-- same history used to evaluate them, so it needs out-of-sample confirmation on
-- fresh signals before it's allowed to influence ranking or filtering.
ALTER TABLE public.trade_signals
  ADD COLUMN IF NOT EXISTS composite_score_v2 integer;

COMMENT ON COLUMN public.trade_signals.composite_score_v2 IS
  'Shadow score for out-of-sample evaluation against composite_score (v1). Not used for ranking or filtering.';
