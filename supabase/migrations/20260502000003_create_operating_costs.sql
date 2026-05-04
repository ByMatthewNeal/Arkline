-- Operating Costs table
-- Admin-managed list of all recurring business costs (APIs, infrastructure, subscriptions).
-- Displayed in the admin dashboard Operating Costs view.

CREATE TABLE IF NOT EXISTS operating_costs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    plan TEXT NOT NULL DEFAULT 'Free',
    monthly_cost DOUBLE PRECISION,
    annual_cost DOUBLE PRECISION,
    note TEXT,
    is_estimate BOOLEAN DEFAULT false,
    payment_date TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: admin-only read/write
ALTER TABLE operating_costs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "operating_costs_admin_select" ON operating_costs
    FOR SELECT TO authenticated USING (public.is_admin());
CREATE POLICY "operating_costs_admin_insert" ON operating_costs
    FOR INSERT TO authenticated WITH CHECK (public.is_admin());
CREATE POLICY "operating_costs_admin_update" ON operating_costs
    FOR UPDATE TO authenticated USING (public.is_admin());
CREATE POLICY "operating_costs_admin_delete" ON operating_costs
    FOR DELETE TO authenticated USING (public.is_admin());

-- Seed current costs
INSERT INTO operating_costs (name, category, plan, monthly_cost, annual_cost, note, is_estimate, payment_date) VALUES
    -- Market Data APIs
    ('CoinGecko', 'Market Data APIs', 'Basic', 35, NULL, 'Crypto prices, global data, trending', false, NULL),
    ('FMP', 'Market Data APIs', 'Starter', 29, NULL, 'Economic calendar, historical prices', false, NULL),
    ('Taapi.io', 'Market Data APIs', 'Free', 0, NULL, 'Technical analysis indicators', false, NULL),
    ('Finnhub', 'Market Data APIs', 'Free', 0, NULL, 'Stock market data', false, NULL),
    ('Metals API', 'Market Data APIs', 'Free', 0, NULL, 'Precious metals pricing', false, NULL),
    ('Coinglass', 'Market Data APIs', 'Hobbyist', 35, NULL, 'Derivatives & long/short data', false, NULL),
    -- AI & Intelligence
    ('Claude API', 'AI & Intelligence', 'Pay-per-use', 15, NULL, 'News curation, briefings, analysis, summaries', true, NULL),
    ('OpenAI TTS', 'AI & Intelligence', 'Pay-per-use', 3, NULL, 'Briefing audio generation', true, NULL),
    ('Tavily Search', 'AI & Intelligence', 'Pay-per-use', 2, NULL, 'Market deck research', true, NULL),
    -- Infrastructure
    ('Supabase', 'Infrastructure', 'Free', 0, NULL, 'Database, auth, edge functions, storage', false, NULL),
    ('Vercel', 'Infrastructure', 'Pro', 20, NULL, 'arkline.io web hosting', false, NULL),
    ('Resend', 'Infrastructure', 'Free', 0, NULL, 'Transactional emails (invites)', false, NULL),
    ('ImprovMX', 'Infrastructure', 'Premium', 9, NULL, 'Email forwarding (support@arkline.io)', false, '30th'),
    -- Design & Branding
    ('Design.com', 'Design & Branding', 'Starter', 15, NULL, 'Logo & design tools', false, '8th'),
    ('Design.com', 'Design & Branding', 'Exclusive License', NULL, 36, 'Logo exclusive rights', false, 'Feb 10'),
    -- Payments & Distribution
    ('Stripe', 'Payments & Distribution', 'Standard', 0, NULL, '2.9% + $0.30 per transaction', false, NULL),
    ('Apple Developer', 'Payments & Distribution', 'Annual', NULL, 99, 'App Store distribution', false, NULL),
    ('GoDaddy', 'Payments & Distribution', 'Domain', NULL, 90, 'arkline.io — renews Jul 14', false, 'Jul 14'),
    -- Free APIs
    ('Coinbase', 'Free APIs', 'Public', 0, NULL, 'OHLC candles, signal pipeline', false, NULL),
    ('Binance', 'Free APIs', 'Public', 0, NULL, 'OHLC verification, futures data', false, NULL),
    ('Yahoo Finance', 'Free APIs', 'Public', 0, NULL, 'SPY, VIX, traditional markets', false, NULL),
    ('FRED', 'Free APIs', 'Free key', 0, NULL, 'M2 supply, treasury yields, FX rates', false, NULL),
    ('Bloomberg RSS', 'Free APIs', 'Public', 0, NULL, 'News feeds', false, NULL),
    ('Google News RSS', 'Free APIs', 'Public', 0, NULL, 'News feeds', false, NULL);
