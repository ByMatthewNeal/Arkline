-- Daily AI-generated market summaries (one row per day, shared across all users)
CREATE TABLE market_summaries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  summary_date DATE UNIQUE NOT NULL DEFAULT CURRENT_DATE,
  summary TEXT NOT NULL,
  generated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE market_summaries ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read summaries (shared cache)
CREATE POLICY "Authenticated users can read market summaries"
  ON market_summaries FOR SELECT
  TO authenticated
  USING (true);
