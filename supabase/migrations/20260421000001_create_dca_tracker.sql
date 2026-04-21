-- DCA Tracker: plans + entries tables
-- Replaces simple reminder system with full DCA tracking

-- =============================================================================
-- Table: dca_plans
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.dca_plans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Asset config
  asset_symbol TEXT NOT NULL,
  asset_name TEXT NOT NULL,

  -- Allocation targets
  target_allocation_pct NUMERIC NOT NULL DEFAULT 80,
  cash_allocation_pct NUMERIC NOT NULL DEFAULT 20,

  -- Starting position
  starting_capital NUMERIC NOT NULL DEFAULT 0,
  starting_qty NUMERIC NOT NULL DEFAULT 0,
  pre_dca_avg_cost NUMERIC,

  -- Schedule
  frequency TEXT NOT NULL DEFAULT 'weekly',
  start_date DATE NOT NULL,
  end_date DATE,
  total_weeks INTEGER DEFAULT 26,

  -- Current state (updated by app)
  current_qty NUMERIC NOT NULL DEFAULT 0,
  total_invested NUMERIC NOT NULL DEFAULT 0,
  cash_remaining NUMERIC NOT NULL DEFAULT 0,

  -- Streak
  streak_current INTEGER NOT NULL DEFAULT 0,
  streak_best INTEGER NOT NULL DEFAULT 0,

  -- Status
  status TEXT NOT NULL DEFAULT 'active',

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================================
-- Table: dca_entries
-- =============================================================================
CREATE TABLE IF NOT EXISTS public.dca_entries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  plan_id UUID NOT NULL REFERENCES dca_plans(id) ON DELETE CASCADE,

  -- Entry data
  week_number INTEGER NOT NULL,
  entry_date DATE NOT NULL,

  -- Planned vs actual
  planned_amount NUMERIC NOT NULL DEFAULT 0,
  actual_amount NUMERIC,
  price_paid NUMERIC,
  qty_bought NUMERIC,

  -- Running totals
  cumulative_invested NUMERIC NOT NULL DEFAULT 0,
  cumulative_qty NUMERIC NOT NULL DEFAULT 0,

  -- Variance
  variance NUMERIC,

  -- Meta
  is_completed BOOLEAN NOT NULL DEFAULT false,
  is_capital_injection BOOLEAN NOT NULL DEFAULT false,
  injection_amount NUMERIC,
  notes TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT now(),

  UNIQUE(plan_id, week_number)
);

-- =============================================================================
-- Indexes
-- =============================================================================
CREATE INDEX idx_dca_plans_user_status ON public.dca_plans(user_id, status);
CREATE INDEX idx_dca_entries_plan_week ON public.dca_entries(plan_id, week_number);

-- =============================================================================
-- RLS
-- =============================================================================
ALTER TABLE public.dca_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dca_entries ENABLE ROW LEVEL SECURITY;

-- dca_plans: users can only access their own plans
CREATE POLICY "Users can select own dca_plans"
  ON public.dca_plans FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own dca_plans"
  ON public.dca_plans FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own dca_plans"
  ON public.dca_plans FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own dca_plans"
  ON public.dca_plans FOR DELETE
  USING (auth.uid() = user_id);

-- dca_entries: users can only access entries for their own plans
CREATE POLICY "Users can select own dca_entries"
  ON public.dca_entries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.dca_plans
      WHERE dca_plans.id = dca_entries.plan_id
        AND dca_plans.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can insert own dca_entries"
  ON public.dca_entries FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.dca_plans
      WHERE dca_plans.id = dca_entries.plan_id
        AND dca_plans.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own dca_entries"
  ON public.dca_entries FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.dca_plans
      WHERE dca_plans.id = dca_entries.plan_id
        AND dca_plans.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.dca_plans
      WHERE dca_plans.id = dca_entries.plan_id
        AND dca_plans.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own dca_entries"
  ON public.dca_entries FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.dca_plans
      WHERE dca_plans.id = dca_entries.plan_id
        AND dca_plans.user_id = auth.uid()
    )
  );

-- =============================================================================
-- updated_at trigger for dca_plans
-- =============================================================================
CREATE OR REPLACE FUNCTION public.update_dca_plans_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_dca_plans_updated_at
  BEFORE UPDATE ON public.dca_plans
  FOR EACH ROW
  EXECUTE FUNCTION public.update_dca_plans_updated_at();
