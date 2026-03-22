-- Add missing columns to broadcasts table
ALTER TABLE broadcasts ADD COLUMN IF NOT EXISTS reaction_count INTEGER DEFAULT 0;
ALTER TABLE broadcasts ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0;

-- Trigger to keep broadcasts.reaction_count in sync with broadcast_reactions

-- Function to update reaction_count on insert/delete
CREATE OR REPLACE FUNCTION update_broadcast_reaction_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE broadcasts
        SET reaction_count = (
            SELECT COUNT(*) FROM broadcast_reactions WHERE broadcast_id = NEW.broadcast_id
        )
        WHERE id = NEW.broadcast_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE broadcasts
        SET reaction_count = (
            SELECT COUNT(*) FROM broadcast_reactions WHERE broadcast_id = OLD.broadcast_id
        )
        WHERE id = OLD.broadcast_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS trg_update_broadcast_reaction_count ON broadcast_reactions;
CREATE TRIGGER trg_update_broadcast_reaction_count
    AFTER INSERT OR DELETE ON broadcast_reactions
    FOR EACH ROW
    EXECUTE FUNCTION update_broadcast_reaction_count();

-- Backfill existing reaction counts
UPDATE broadcasts b
SET reaction_count = (
    SELECT COUNT(*) FROM broadcast_reactions br WHERE br.broadcast_id = b.id
);
