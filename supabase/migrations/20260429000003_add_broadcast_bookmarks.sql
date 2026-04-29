-- Broadcast bookmarks: let users save/bookmark insights for later
CREATE TABLE IF NOT EXISTS broadcast_bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    broadcast_id UUID NOT NULL REFERENCES broadcasts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(broadcast_id, user_id)
);

-- Index for fast user bookmark lookups
CREATE INDEX IF NOT EXISTS idx_broadcast_bookmarks_user ON broadcast_bookmarks (user_id);

-- RLS: users can only see and manage their own bookmarks
ALTER TABLE broadcast_bookmarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bookmarks"
    ON broadcast_bookmarks FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own bookmarks"
    ON broadcast_bookmarks FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own bookmarks"
    ON broadcast_bookmarks FOR DELETE
    USING (auth.uid() = user_id);
