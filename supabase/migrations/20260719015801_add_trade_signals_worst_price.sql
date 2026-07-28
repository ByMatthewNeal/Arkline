-- Exported from the live database on 2026-07-27.
-- Originally applied directly (not via `supabase db push`), so no repo file
-- existed and the migrations could not reproduce production.
-- Filename version matches the applied migration version exactly.

-- Max adverse excursion: the worst price a signal reached against the position
-- while open. Paired with best_price (max favorable excursion), this is what
-- makes stop-loss tuning data-driven instead of guesswork — right now we can see
-- how far winners run, but not how much heat they take before working.
ALTER TABLE public.trade_signals
  ADD COLUMN IF NOT EXISTS worst_price numeric;

COMMENT ON COLUMN public.trade_signals.worst_price IS
  'Max adverse excursion while the signal was open (lowest price for longs, highest for shorts).';
