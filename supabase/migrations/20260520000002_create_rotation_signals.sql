-- Crypto vs Equities rotation signal + sector performance tables

-- Daily rotation score: -100 (favor crypto) to +100 (favor equities)
CREATE TABLE IF NOT EXISTS rotation_signals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    signal_date DATE NOT NULL,
    rotation_score INTEGER NOT NULL,
    regime TEXT NOT NULL,                      -- crypto_favored, equity_favored, neutral, risk_off
    narrative TEXT,
    btc_30d_return DOUBLE PRECISION,
    spy_30d_return DOUBLE PRECISION,
    btc_risk_level TEXT,
    spy_risk_level TEXT,
    fear_greed_value INTEGER,
    fear_greed_trend TEXT,
    dxy_trend TEXT,
    dxy_value DOUBLE PRECISION,
    vix_level DOUBLE PRECISION,
    btc_dominance DOUBLE PRECISION,
    btc_dominance_trend TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(signal_date)
);

CREATE INDEX idx_rotation_signals_date ON rotation_signals(signal_date DESC);

-- Per-sector daily performance with relative strength vs SPY
CREATE TABLE IF NOT EXISTS sector_performance (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    signal_date DATE NOT NULL,
    sector_id TEXT NOT NULL,
    sector_name TEXT NOT NULL,
    return_7d DOUBLE PRECISION,
    return_30d DOUBLE PRECISION,
    relative_strength_vs_spy DOUBLE PRECISION,
    top_performer TEXT,
    top_performer_return DOUBLE PRECISION,
    stock_returns JSONB DEFAULT '{}',          -- {ticker: return_30d} for all stocks in sector
    is_defensive BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(signal_date, sector_id)
);

CREATE INDEX idx_sector_performance_date ON sector_performance(signal_date DESC);

-- RLS
ALTER TABLE rotation_signals ENABLE ROW LEVEL SECURITY;
ALTER TABLE sector_performance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read rotation signals"
    ON rotation_signals FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Authenticated users can read sector performance"
    ON sector_performance FOR SELECT
    TO authenticated
    USING (true);

-- Prevent client writes
CREATE POLICY "No client writes to rotation signals"
    ON rotation_signals FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "No client updates to rotation signals"
    ON rotation_signals FOR UPDATE TO authenticated USING (false);
CREATE POLICY "No client deletes from rotation signals"
    ON rotation_signals FOR DELETE TO authenticated USING (false);

CREATE POLICY "No client writes to sector performance"
    ON sector_performance FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "No client updates to sector performance"
    ON sector_performance FOR UPDATE TO authenticated USING (false);
CREATE POLICY "No client deletes from sector performance"
    ON sector_performance FOR DELETE TO authenticated USING (false);
