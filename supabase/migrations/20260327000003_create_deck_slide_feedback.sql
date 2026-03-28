-- Per-slide feedback for weekly market deck QA workflow
-- Admin rates and provides feedback on individual slides before publishing

CREATE TABLE IF NOT EXISTS public.deck_slide_feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    deck_id UUID NOT NULL REFERENCES public.market_update_decks(id) ON DELETE CASCADE,
    slide_type TEXT NOT NULL,
    rating BOOLEAN NOT NULL,           -- true = good, false = needs improvement
    feedback TEXT,                      -- admin's written feedback / guidance
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(deck_id, slide_type)
);

CREATE INDEX idx_deck_slide_feedback_deck ON deck_slide_feedback(deck_id);
CREATE INDEX idx_deck_slide_feedback_recent ON deck_slide_feedback(created_at DESC);

ALTER TABLE deck_slide_feedback ENABLE ROW LEVEL SECURITY;

-- Only admins can read/write slide feedback
CREATE POLICY "Admins can manage slide feedback"
    ON deck_slide_feedback FOR ALL
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));
