-- Market Breadth: tracks % of top tokens in uptrend + EMA trend analysis
-- Inspired by Alpha Extract's Market Strength indicator

CREATE TABLE IF NOT EXISTS market_breadth (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    signal_date DATE NOT NULL,
    total_tokens INTEGER NOT NULL,           -- total tokens scanned
    trending_tokens INTEGER NOT NULL,        -- tokens currently in uptrend (price > 20D SMA)
    breadth_pct DOUBLE PRECISION NOT NULL,   -- trending_tokens / total_tokens * 100
    ema_12 DOUBLE PRECISION,                 -- EMA 12 of breadth_pct
    ema_21 DOUBLE PRECISION,                 -- EMA 21 of breadth_pct
    trend TEXT NOT NULL DEFAULT 'neutral',   -- bullish (ema12 > ema21), bearish, neutral
    prev_trend TEXT,                         -- previous day's trend (for crossover detection)
    crossover TEXT,                          -- bullish_crossover, bearish_crossover, or null
    btc_price DOUBLE PRECISION,              -- BTC price for context overlay
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(signal_date)
);

CREATE INDEX idx_market_breadth_date ON market_breadth(signal_date DESC);

-- RLS: read-only for authenticated users
ALTER TABLE market_breadth ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read market breadth"
    ON market_breadth FOR SELECT
    TO authenticated
    USING (true);

-- Prevent client writes
CREATE POLICY "No client writes to market breadth"
    ON market_breadth FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "No client updates to market breadth"
    ON market_breadth FOR UPDATE TO authenticated USING (false);
CREATE POLICY "No client deletes from market breadth"
    ON market_breadth FOR DELETE TO authenticated USING (false);
