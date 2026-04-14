-- Add referral_code column to track who referred each signup
ALTER TABLE early_access_signups
ADD COLUMN IF NOT EXISTS referral_code TEXT DEFAULT NULL;

-- Index for fast referral count queries
CREATE INDEX IF NOT EXISTS idx_early_access_referral_code
ON early_access_signups(referral_code)
WHERE referral_code IS NOT NULL;
