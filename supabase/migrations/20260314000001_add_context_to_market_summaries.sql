-- Add context column to market_summaries for storing the full market data payload
-- alongside each generated briefing. This enables historical analysis and pattern
-- recognition across macro, liquidity, sentiment, and technical data over time.
ALTER TABLE market_summaries ADD COLUMN IF NOT EXISTS context JSONB;

-- Add index for querying historical context data by date range
CREATE INDEX IF NOT EXISTS idx_market_summaries_date_slot
ON market_summaries (summary_date DESC, slot);
