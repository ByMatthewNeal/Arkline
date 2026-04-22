-- Add pinned post and BTC price at publish time to broadcasts
ALTER TABLE broadcasts ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE broadcasts ADD COLUMN IF NOT EXISTS btc_price_at_publish DOUBLE PRECISION;

-- Index for fast pinned lookup
CREATE INDEX IF NOT EXISTS idx_broadcasts_is_pinned ON broadcasts (is_pinned) WHERE is_pinned = true;
