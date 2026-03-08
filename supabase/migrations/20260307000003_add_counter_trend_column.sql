-- Add counter_trend flag for Bull Market Support Band regime check
-- TRUE when signal direction conflicts with 20W SMA / 21W EMA macro regime
ALTER TABLE trade_signals ADD COLUMN IF NOT EXISTS counter_trend BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN trade_signals.counter_trend IS 'True when signal goes against the Bull Market Support Band regime (20W SMA + 21W EMA)';
