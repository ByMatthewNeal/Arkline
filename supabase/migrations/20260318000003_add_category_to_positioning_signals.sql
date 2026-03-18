-- Add category column to positioning_signals for UI grouping
ALTER TABLE public.positioning_signals
  ADD COLUMN IF NOT EXISTS category TEXT
  CHECK (category IS NULL OR category IN ('crypto', 'index', 'macro', 'commodity', 'stock'));

CREATE INDEX IF NOT EXISTS idx_positioning_signals_category
  ON public.positioning_signals(category, signal_date DESC);
