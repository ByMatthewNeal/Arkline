-- Add meeting_link column to broadcasts table
ALTER TABLE broadcasts ADD COLUMN IF NOT EXISTS meeting_link TEXT;
