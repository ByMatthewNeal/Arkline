-- Add portfolio_attachment JSONB column to broadcasts table
-- This was missing — the Broadcast model encodes it but the column never existed
ALTER TABLE broadcasts ADD COLUMN IF NOT EXISTS portfolio_attachment JSONB;
