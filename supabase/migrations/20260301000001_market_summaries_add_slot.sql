-- Support twice-daily briefings (morning + evening slots)
-- Drop the old unique constraint on date-only, add a slot column
ALTER TABLE market_summaries ADD COLUMN slot TEXT NOT NULL DEFAULT 'morning';

-- Drop old unique constraint and add new one on (date, slot)
ALTER TABLE market_summaries DROP CONSTRAINT IF EXISTS market_summaries_summary_date_key;
CREATE UNIQUE INDEX market_summaries_date_slot_idx ON market_summaries (summary_date, slot);
