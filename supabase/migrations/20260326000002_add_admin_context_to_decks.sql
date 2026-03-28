-- Add admin_context JSONB column for per-slide admin commentary and global insights
-- admin_context stores: { "slide_notes": { "cover": "...", "rundown": "..." }, "insights": "..." }
ALTER TABLE market_update_decks ADD COLUMN IF NOT EXISTS admin_context JSONB DEFAULT '{}'::jsonb;
