-- Reel Scripts table
-- Auto-generated Instagram Reel scripts for the founder.
-- Generated Mon/Wed/Fri at 8 AM ET by generate-reel-script edge function.

CREATE TABLE IF NOT EXISTS reel_scripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hook TEXT NOT NULL,
    body TEXT NOT NULL,
    cta TEXT NOT NULL,
    topic TEXT,
    source_headlines TEXT[],
    word_count INTEGER,
    script_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'fresh',
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(script_date)
);

CREATE INDEX idx_reel_scripts_date ON reel_scripts (script_date DESC);

-- RLS: admin-only
ALTER TABLE reel_scripts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reel_scripts_admin_select" ON reel_scripts
    FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY "reel_scripts_admin_insert" ON reel_scripts
    FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY "reel_scripts_admin_update" ON reel_scripts
    FOR UPDATE TO authenticated USING (public.is_admin());
CREATE POLICY "reel_scripts_admin_delete" ON reel_scripts
    FOR DELETE TO authenticated USING (public.is_admin());

-- Cleanup: keep 30 days
SELECT cron.schedule(
    'cleanup-reel-scripts-monthly',
    '0 5 1 * *',
    $$DELETE FROM reel_scripts WHERE script_date < CURRENT_DATE - interval '30 days'$$
);
