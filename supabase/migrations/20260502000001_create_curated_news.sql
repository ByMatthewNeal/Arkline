-- Curated News table
-- Stores AI-filtered and enriched news articles from Bloomberg + Google News RSS.
-- Written by curate-news edge function (30-min cron), read by iOS/web clients.

CREATE TABLE IF NOT EXISTS curated_news (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_title TEXT NOT NULL,
    curated_title TEXT NOT NULL,
    source TEXT NOT NULL,
    source_url TEXT NOT NULL,
    published_at TIMESTAMPTZ NOT NULL,
    takeaway_1 TEXT NOT NULL,
    takeaway_2 TEXT NOT NULL,
    takeaway_3 TEXT NOT NULL,
    relevance_score INTEGER DEFAULT 0,
    category TEXT,
    url_hash TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_curated_news_published ON curated_news (published_at DESC);

-- RLS: authenticated read-only
ALTER TABLE curated_news ENABLE ROW LEVEL SECURITY;

CREATE POLICY "curated_news_select" ON curated_news
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "curated_news_deny_insert" ON curated_news
    FOR INSERT TO authenticated WITH CHECK (false);

CREATE POLICY "curated_news_deny_update" ON curated_news
    FOR UPDATE TO authenticated USING (false) WITH CHECK (false);

CREATE POLICY "curated_news_deny_delete" ON curated_news
    FOR DELETE TO authenticated USING (false);

-- Daily cleanup: keep 3 days of articles
SELECT cron.schedule(
    'cleanup-curated-news-daily',
    '0 4 * * *',
    $$DELETE FROM curated_news WHERE published_at < now() - interval '3 days'$$
);
