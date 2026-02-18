-- Add tier column to invite_codes for founding vs standard member tracking
ALTER TABLE invite_codes
ADD COLUMN IF NOT EXISTS tier TEXT DEFAULT 'standard';

-- Backfill existing paid codes as founding (all current paid signups are founding members)
UPDATE invite_codes SET tier = 'founding' WHERE payment_status = 'paid';

-- Index for counting founding members efficiently
CREATE INDEX IF NOT EXISTS idx_invite_codes_tier ON invite_codes (tier);
