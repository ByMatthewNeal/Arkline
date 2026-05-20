-- Add multi-timeframe return columns to rotation_signals
ALTER TABLE rotation_signals ADD COLUMN IF NOT EXISTS btc_7d_return DOUBLE PRECISION;
ALTER TABLE rotation_signals ADD COLUMN IF NOT EXISTS spy_7d_return DOUBLE PRECISION;
ALTER TABLE rotation_signals ADD COLUMN IF NOT EXISTS btc_90d_return DOUBLE PRECISION;
ALTER TABLE rotation_signals ADD COLUMN IF NOT EXISTS spy_90d_return DOUBLE PRECISION;
ALTER TABLE rotation_signals ADD COLUMN IF NOT EXISTS btc_ytd_return DOUBLE PRECISION;
ALTER TABLE rotation_signals ADD COLUMN IF NOT EXISTS spy_ytd_return DOUBLE PRECISION;
