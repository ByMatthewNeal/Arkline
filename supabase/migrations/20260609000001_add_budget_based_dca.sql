-- Add budget-based DCA columns to dca_plans
-- recurring_amount: the fixed dollar amount per purchase (null for capital-based plans)
-- is_ongoing: true means no end date, runs indefinitely

ALTER TABLE dca_plans
  ADD COLUMN IF NOT EXISTS recurring_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS is_ongoing BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN dca_plans.recurring_amount IS 'Fixed recurring investment amount per purchase (budget-based plans only)';
COMMENT ON COLUMN dca_plans.is_ongoing IS 'Whether the plan runs indefinitely with no end date';
