-- Briefing feedback table: admin rates each daily briefing (thumbs up/down + optional note).
-- Negative feedback with notes gets injected into the Claude prompt for future generations.

CREATE TABLE briefing_feedback (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  summary_date DATE NOT NULL,
  slot TEXT NOT NULL DEFAULT 'morning',
  rating BOOLEAN NOT NULL,         -- true = thumbs up, false = thumbs down
  note TEXT,                        -- optional note (mainly for negative)
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(summary_date, slot)       -- one rating per briefing
);

-- Enable RLS
ALTER TABLE briefing_feedback ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read feedback
CREATE POLICY "Authenticated users can read feedback"
  ON briefing_feedback FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can insert feedback
CREATE POLICY "Admins can insert feedback"
  ON briefing_feedback FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

-- Only admins can update feedback
CREATE POLICY "Admins can update feedback"
  ON briefing_feedback FOR UPDATE
  TO authenticated
  USING (public.is_admin());
