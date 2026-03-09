-- Add card_analysis jsonb column for enriched signal share cards
-- Structured analysis with narrative + market context for card display.

ALTER TABLE trade_signals
ADD COLUMN IF NOT EXISTS card_analysis jsonb DEFAULT NULL;

COMMENT ON COLUMN trade_signals.card_analysis IS
  'Structured analysis for signal cards and share export. JSON with: narrative, macro_regime_label, fear_greed_label, trend_direction, confluence_strength.';
