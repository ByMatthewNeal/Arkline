-- Add video_url column to broadcasts table (for Loom/Zoom recording links)
ALTER TABLE broadcasts ADD COLUMN IF NOT EXISTS video_url TEXT;
