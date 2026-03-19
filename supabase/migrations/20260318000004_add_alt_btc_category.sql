-- Add alt_btc to the category CHECK constraint
ALTER TABLE public.positioning_signals
  DROP CONSTRAINT IF EXISTS positioning_signals_category_check;

ALTER TABLE public.positioning_signals
  ADD CONSTRAINT positioning_signals_category_check
  CHECK (category IS NULL OR category IN ('crypto', 'index', 'macro', 'commodity', 'stock', 'alt_btc'));
