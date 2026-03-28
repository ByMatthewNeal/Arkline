-- Create market_update_decks table for weekly slide deck feature
CREATE TABLE IF NOT EXISTS public.market_update_decks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  week_start DATE NOT NULL,
  week_end DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  slides JSONB NOT NULL,
  admin_notes TEXT,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(week_start)
);

CREATE INDEX idx_market_decks_week ON market_update_decks(week_start DESC);
ALTER TABLE market_update_decks ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read published decks
CREATE POLICY "Users can read published decks"
  ON market_update_decks FOR SELECT
  USING (status = 'published' AND auth.role() = 'authenticated');

-- Admins can do everything
CREATE POLICY "Admins can manage decks"
  ON market_update_decks FOR ALL
  USING (public.is_admin());

-- Add cron job for Saturday 15:00 UTC (10am ET)
SELECT cron.schedule(
    'generate-market-deck-weekly',
    '0 15 * * 6',
    $$SELECT net.http_post(
        url := 'https://fgwmsjspxgeamxbkvhlb.supabase.co/functions/v1/generate-market-deck',
        headers := '{"Content-Type":"application/json","x-cron-secret":"arkline-cron-2026"}'::jsonb,
        body := '{}'::jsonb
    )$$
);
