-- Multi-step deck pipeline: tracks state between independent generation steps
-- Each step stores its output as JSONB so subsequent steps can read from it
-- Allows retry of individual steps without re-running the entire pipeline

CREATE TABLE IF NOT EXISTS public.deck_pipeline_runs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  deck_id UUID REFERENCES market_update_decks(id) ON DELETE SET NULL,
  week_start DATE NOT NULL,
  week_end DATE NOT NULL,

  -- Step statuses: pending | running | completed | failed
  step_gather_data TEXT NOT NULL DEFAULT 'pending',
  step_web_research TEXT NOT NULL DEFAULT 'pending',
  step_add_context TEXT NOT NULL DEFAULT 'pending',
  step_generate_slides TEXT NOT NULL DEFAULT 'pending',
  step_review TEXT NOT NULL DEFAULT 'pending',
  step_publish TEXT NOT NULL DEFAULT 'pending',

  -- Step outputs (JSONB — each step persists results independently)
  output_gather_data JSONB,
  output_web_research JSONB,
  output_context JSONB,
  output_generate_slides JSONB,

  -- Error tracking per step
  error_gather_data TEXT,
  error_web_research TEXT,
  error_add_context TEXT,
  error_generate_slides TEXT,

  -- Timestamps
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),

  UNIQUE(week_start, week_end)
);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_week ON deck_pipeline_runs(week_start DESC);

ALTER TABLE deck_pipeline_runs ENABLE ROW LEVEL SECURITY;

-- Admin-only read/write
CREATE POLICY "pipeline_runs_select" ON deck_pipeline_runs FOR SELECT TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
CREATE POLICY "pipeline_runs_insert" ON deck_pipeline_runs FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
CREATE POLICY "pipeline_runs_update" ON deck_pipeline_runs FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
CREATE POLICY "pipeline_runs_delete" ON deck_pipeline_runs FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));
