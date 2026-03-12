-- Economic Events table
-- Stores economic calendar data from FMP with Claude-generated analysis

CREATE TABLE IF NOT EXISTS economic_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    country TEXT,
    currency TEXT,
    event_date DATE NOT NULL,
    event_time TIMESTAMPTZ,
    impact TEXT NOT NULL DEFAULT 'low',
    forecast TEXT,
    previous TEXT,
    actual TEXT,
    beat_miss TEXT,
    claude_analysis TEXT,
    analyzed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(title, event_date),
    CONSTRAINT impact_check CHECK (impact IN ('high', 'medium', 'low')),
    CONSTRAINT beat_miss_check CHECK (beat_miss IS NULL OR beat_miss IN ('beat', 'miss', 'inline'))
);

-- Indexes
CREATE INDEX idx_economic_events_event_date ON economic_events (event_date);
CREATE INDEX idx_economic_events_impact ON economic_events (impact);

-- RLS
ALTER TABLE economic_events ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read
CREATE POLICY "economic_events_select" ON economic_events
    FOR SELECT TO authenticated USING (true);

-- Deny insert/update/delete for authenticated (service role bypasses RLS)
CREATE POLICY "economic_events_deny_insert" ON economic_events
    FOR INSERT TO authenticated WITH CHECK (false);

CREATE POLICY "economic_events_deny_update" ON economic_events
    FOR UPDATE TO authenticated USING (false) WITH CHECK (false);

CREATE POLICY "economic_events_deny_delete" ON economic_events
    FOR DELETE TO authenticated USING (false);
