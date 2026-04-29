-- Add protection feature columns to trade_signals
-- low_conviction: soft regime filter badge (EMA slope flat but signal still generated)
-- volatility_regime: BTC ATR-based regime (normal/elevated/extreme)
-- suggested_risk_pct: auto-scaled risk percentage based on conditions

ALTER TABLE trade_signals
  ADD COLUMN IF NOT EXISTS low_conviction boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS volatility_regime text DEFAULT 'normal',
  ADD COLUMN IF NOT EXISTS suggested_risk_pct numeric DEFAULT 2.0;
