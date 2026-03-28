-- Daily Fear & Greed Index history for accurate weekly market deck generation
CREATE TABLE IF NOT EXISTS public.fear_greed_history (
  date DATE PRIMARY KEY,
  value INTEGER NOT NULL CHECK (value >= 0 AND value <= 100),
  classification TEXT NOT NULL,  -- "Extreme Fear", "Fear", "Neutral", "Greed", "Extreme Greed"
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_fear_greed_date ON fear_greed_history(date DESC);

ALTER TABLE fear_greed_history ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read
CREATE POLICY "Users can read fear greed history"
  ON fear_greed_history FOR SELECT
  USING (auth.role() = 'authenticated');

-- Only edge functions (service role) can write
CREATE POLICY "Service role can insert fear greed"
  ON fear_greed_history FOR INSERT
  WITH CHECK (true);
