-- Daily Positioning Signals (QPS) table
-- Stores daily bullish/neutral/bearish signals per asset with change detection

CREATE TABLE IF NOT EXISTS public.positioning_signals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  asset TEXT NOT NULL,
  signal_date DATE NOT NULL,
  signal TEXT NOT NULL CHECK (signal IN ('bullish', 'neutral', 'bearish')),
  prev_signal TEXT CHECK (prev_signal IS NULL OR prev_signal IN ('bullish', 'neutral', 'bearish')),
  trend_score NUMERIC NOT NULL,
  rsi NUMERIC,
  price NUMERIC NOT NULL,
  above_200_sma BOOLEAN NOT NULL DEFAULT false,
  risk_level NUMERIC,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(asset, signal_date)
);

CREATE INDEX IF NOT EXISTS idx_positioning_signals_date
  ON public.positioning_signals(signal_date DESC);

CREATE INDEX IF NOT EXISTS idx_positioning_signals_asset_date
  ON public.positioning_signals(asset, signal_date DESC);

-- RLS: read-only for authenticated users
ALTER TABLE public.positioning_signals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read positioning_signals" ON public.positioning_signals;
CREATE POLICY "Authenticated users can read positioning_signals"
  ON public.positioning_signals FOR SELECT
  USING (auth.role() = 'authenticated');
