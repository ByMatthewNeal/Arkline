-- Add chart_pattern JSONB column to trade_signals
-- Stores detected chart pattern data (e.g., double bottom, head & shoulders)
-- JSON structure:
-- {
--   "name": "Bullish Double Bottom",
--   "type": "reversal",         -- reversal | continuation
--   "bias": "bullish",          -- bullish | bearish
--   "timeframe": "4h",
--   "confidence": 75,           -- 0-100
--   "description": "...",
--   "neckline": 0.9496,         -- optional
--   "target": 0.9762            -- optional
-- }

ALTER TABLE trade_signals
ADD COLUMN chart_pattern JSONB DEFAULT NULL;

COMMENT ON COLUMN trade_signals.chart_pattern IS 'Detected chart pattern data (name, type, bias, timeframe, confidence, description, neckline, target)';
