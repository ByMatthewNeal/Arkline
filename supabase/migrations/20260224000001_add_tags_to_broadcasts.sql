-- Add tags column to broadcasts table
ALTER TABLE broadcasts ADD COLUMN IF NOT EXISTS tags text[] NOT NULL DEFAULT '{}';
