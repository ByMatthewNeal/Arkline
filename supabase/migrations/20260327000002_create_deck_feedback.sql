-- Deck feedback table: admin rates each weekly market update (thumbs up/down + optional note).
-- Negative feedback with notes can be used to improve future deck generation quality.

CREATE TABLE deck_feedback (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  deck_id UUID NOT NULL REFERENCES public.market_update_decks(id) ON DELETE CASCADE,
  rating BOOLEAN NOT NULL,         -- true = thumbs up, false = thumbs down
  note TEXT,                        -- optional note (mainly for negative)
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(deck_id)                  -- one rating per deck
);

-- Enable RLS
ALTER TABLE deck_feedback ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read feedback
CREATE POLICY "Authenticated users can read deck feedback"
  ON deck_feedback FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can insert feedback
CREATE POLICY "Admins can insert deck feedback"
  ON deck_feedback FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

-- Only admins can update feedback
CREATE POLICY "Admins can update deck feedback"
  ON deck_feedback FOR UPDATE
  TO authenticated
  USING (public.is_admin());
