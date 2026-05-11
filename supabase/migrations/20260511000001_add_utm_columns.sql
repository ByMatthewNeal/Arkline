-- Add UTM tracking columns to early_access_signups
-- Captures which ad campaign/creative/placement converts best
ALTER TABLE early_access_signups
ADD COLUMN IF NOT EXISTS utm_source TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS utm_medium TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS utm_campaign TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS utm_content TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS utm_term TEXT DEFAULT NULL;
