-- Add range compression detection columns to trade_signals
-- Tracks when signals are generated during low-volatility, tight-range periods
ALTER TABLE trade_signals
  ADD COLUMN IF NOT EXISTS range_compressed boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS compression_score smallint;
