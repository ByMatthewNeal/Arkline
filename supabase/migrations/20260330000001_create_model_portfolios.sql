-- Model Portfolios: Arkline Core (Conservative) & Arkline Edge (Aggressive)
-- Systematic crypto portfolios driven by QPS signals + risk levels, benchmarked against SPY

-- Portfolio metadata
CREATE TABLE IF NOT EXISTS model_portfolios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  strategy TEXT NOT NULL,  -- 'core' or 'edge'
  description TEXT,
  universe TEXT[] NOT NULL,
  starting_nav NUMERIC NOT NULL DEFAULT 50000,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Daily NAV snapshots
CREATE TABLE IF NOT EXISTS model_portfolio_nav (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_id UUID NOT NULL REFERENCES model_portfolios(id),
  nav_date DATE NOT NULL,
  nav NUMERIC NOT NULL,
  allocations JSONB NOT NULL DEFAULT '{}',  -- {"BTC": {"pct": 0.60, "value": 30000, "qty": 0.35}, ...}
  btc_signal TEXT,        -- bullish/neutral/bearish
  btc_risk_level NUMERIC, -- 0.0-1.0
  btc_risk_category TEXT,  -- Very Low Risk, Low Risk, etc.
  gold_signal TEXT,        -- bullish/neutral/bearish
  macro_regime TEXT,       -- Risk-On Disinflation, Risk-Off Inflation, etc.
  dominant_alt TEXT,       -- ticker of dominant altcoin (Edge only)
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(portfolio_id, nav_date)
);
CREATE INDEX IF NOT EXISTS idx_model_portfolio_nav_date ON model_portfolio_nav(portfolio_id, nav_date DESC);

-- Trade log (every allocation change)
CREATE TABLE IF NOT EXISTS model_portfolio_trades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  portfolio_id UUID NOT NULL REFERENCES model_portfolios(id),
  trade_date DATE NOT NULL,
  trigger TEXT NOT NULL,            -- "BTC Bearish → Neutral", "Macro Risk-Off", etc.
  from_allocation JSONB NOT NULL,   -- previous allocation percentages
  to_allocation JSONB NOT NULL,     -- new allocation percentages
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_model_portfolio_trades_date ON model_portfolio_trades(portfolio_id, trade_date DESC);

-- SPY benchmark NAV
CREATE TABLE IF NOT EXISTS benchmark_nav (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nav_date DATE UNIQUE NOT NULL,
  spy_price NUMERIC NOT NULL,
  nav NUMERIC NOT NULL,             -- $50k starting, tracks buy-and-hold
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_benchmark_nav_date ON benchmark_nav(nav_date DESC);

-- Daily BTC risk level (log regression, computed server-side)
CREATE TABLE IF NOT EXISTS model_portfolio_risk_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  asset TEXT NOT NULL DEFAULT 'BTC',
  risk_date DATE NOT NULL,
  risk_level NUMERIC NOT NULL,      -- 0.0-1.0
  price NUMERIC NOT NULL,
  fair_value NUMERIC NOT NULL,
  deviation NUMERIC NOT NULL,       -- log deviation
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(asset, risk_date)
);

-- Seed the two portfolios
INSERT INTO model_portfolios (name, strategy, description, universe, starting_nav) VALUES
  ('Arkline Core', 'core', 'Conservative systematic crypto portfolio. BTC + ETH core with risk-level accumulation and gold hedging.', ARRAY['BTC', 'ETH', 'PAXG', 'USDC'], 50000),
  ('Arkline Edge', 'edge', 'Aggressive systematic crypto portfolio. Rotates into dominant altcoins via QPS signals with risk-level accumulation.', ARRAY['BTC', 'ETH', 'SOL', 'ALT', 'PAXG', 'USDC'], 50000)
ON CONFLICT (name) DO NOTHING;

-- RLS: Read-only for authenticated users, no writes
ALTER TABLE model_portfolios ENABLE ROW LEVEL SECURITY;
ALTER TABLE model_portfolio_nav ENABLE ROW LEVEL SECURITY;
ALTER TABLE model_portfolio_trades ENABLE ROW LEVEL SECURITY;
ALTER TABLE benchmark_nav ENABLE ROW LEVEL SECURITY;
ALTER TABLE model_portfolio_risk_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "model_portfolios_read" ON model_portfolios FOR SELECT TO authenticated USING (true);
CREATE POLICY "model_portfolios_no_insert" ON model_portfolios FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "model_portfolios_no_update" ON model_portfolios FOR UPDATE TO authenticated USING (false);
CREATE POLICY "model_portfolios_no_delete" ON model_portfolios FOR DELETE TO authenticated USING (false);

CREATE POLICY "model_portfolio_nav_read" ON model_portfolio_nav FOR SELECT TO authenticated USING (true);
CREATE POLICY "model_portfolio_nav_no_insert" ON model_portfolio_nav FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "model_portfolio_nav_no_update" ON model_portfolio_nav FOR UPDATE TO authenticated USING (false);
CREATE POLICY "model_portfolio_nav_no_delete" ON model_portfolio_nav FOR DELETE TO authenticated USING (false);

CREATE POLICY "model_portfolio_trades_read" ON model_portfolio_trades FOR SELECT TO authenticated USING (true);
CREATE POLICY "model_portfolio_trades_no_insert" ON model_portfolio_trades FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "model_portfolio_trades_no_update" ON model_portfolio_trades FOR UPDATE TO authenticated USING (false);
CREATE POLICY "model_portfolio_trades_no_delete" ON model_portfolio_trades FOR DELETE TO authenticated USING (false);

CREATE POLICY "benchmark_nav_read" ON benchmark_nav FOR SELECT TO authenticated USING (true);
CREATE POLICY "benchmark_nav_no_insert" ON benchmark_nav FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "benchmark_nav_no_update" ON benchmark_nav FOR UPDATE TO authenticated USING (false);
CREATE POLICY "benchmark_nav_no_delete" ON benchmark_nav FOR DELETE TO authenticated USING (false);

CREATE POLICY "model_portfolio_risk_history_read" ON model_portfolio_risk_history FOR SELECT TO authenticated USING (true);
CREATE POLICY "model_portfolio_risk_history_no_insert" ON model_portfolio_risk_history FOR INSERT TO authenticated WITH CHECK (false);
CREATE POLICY "model_portfolio_risk_history_no_update" ON model_portfolio_risk_history FOR UPDATE TO authenticated USING (false);
CREATE POLICY "model_portfolio_risk_history_no_delete" ON model_portfolio_risk_history FOR DELETE TO authenticated USING (false);
