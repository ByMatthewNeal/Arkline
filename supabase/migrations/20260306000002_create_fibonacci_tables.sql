-- Fibonacci Swing Trade Signal System — Phase 1 Tables
-- Creates tables for OHLC candle storage, swing point detection,
-- Fibonacci level computation, confluence zones, and trade signals.

-- 1. OHLC Candle Storage
CREATE TABLE IF NOT EXISTS public.ohlc_candles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  asset TEXT NOT NULL,
  timeframe TEXT NOT NULL,
  open_time TIMESTAMPTZ NOT NULL,
  open NUMERIC NOT NULL,
  high NUMERIC NOT NULL,
  low NUMERIC NOT NULL,
  close NUMERIC NOT NULL,
  volume NUMERIC,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(asset, timeframe, open_time)
);

CREATE INDEX IF NOT EXISTS idx_ohlc_asset_tf_time
  ON public.ohlc_candles(asset, timeframe, open_time DESC);

-- 2. Swing Points (detected swing highs/lows)
CREATE TABLE IF NOT EXISTS public.swing_points (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  asset TEXT NOT NULL,
  timeframe TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('high', 'low')),
  price NUMERIC NOT NULL,
  candle_time TIMESTAMPTZ NOT NULL,
  reversal_pct NUMERIC NOT NULL,
  is_active BOOLEAN DEFAULT true,
  detected_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(asset, timeframe, type, candle_time)
);

CREATE INDEX IF NOT EXISTS idx_swing_active
  ON public.swing_points(asset, timeframe, is_active, detected_at DESC);

-- 3. Fibonacci Levels
CREATE TABLE IF NOT EXISTS public.fib_levels (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  asset TEXT NOT NULL,
  timeframe TEXT NOT NULL,
  direction TEXT NOT NULL CHECK (direction IN ('retracement', 'extension')),
  swing_high_price NUMERIC NOT NULL,
  swing_low_price NUMERIC NOT NULL,
  swing_high_time TIMESTAMPTZ NOT NULL,
  swing_low_time TIMESTAMPTZ NOT NULL,
  level_236 NUMERIC NOT NULL,
  level_382 NUMERIC NOT NULL,
  level_500 NUMERIC NOT NULL,
  level_618 NUMERIC NOT NULL,
  level_786 NUMERIC NOT NULL,
  ext_1272 NUMERIC,
  ext_1618 NUMERIC,
  computed_at TIMESTAMPTZ DEFAULT now(),
  is_current BOOLEAN DEFAULT true,
  UNIQUE(asset, timeframe, direction, swing_high_time, swing_low_time)
);

CREATE INDEX IF NOT EXISTS idx_fib_current
  ON public.fib_levels(asset, is_current, timeframe);

-- 4. Fibonacci Confluence Zones
CREATE TABLE IF NOT EXISTS public.fib_confluence_zones (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  asset TEXT NOT NULL,
  zone_type TEXT NOT NULL CHECK (zone_type IN ('support', 'resistance')),
  zone_low NUMERIC NOT NULL,
  zone_high NUMERIC NOT NULL,
  zone_mid NUMERIC NOT NULL,
  strength INTEGER NOT NULL,
  contributing_levels JSONB NOT NULL,
  distance_pct NUMERIC NOT NULL,
  is_active BOOLEAN DEFAULT true,
  computed_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_confluence_active
  ON public.fib_confluence_zones(asset, is_active, distance_pct);

-- 5. Trade Signals
CREATE TABLE IF NOT EXISTS public.trade_signals (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  asset TEXT NOT NULL,
  signal_type TEXT NOT NULL CHECK (signal_type IN ('strong_buy', 'buy', 'strong_sell', 'sell')),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'triggered', 'invalidated', 'target_hit', 'expired')),

  -- Entry
  entry_zone_low NUMERIC NOT NULL,
  entry_zone_high NUMERIC NOT NULL,
  entry_price_mid NUMERIC NOT NULL,
  confluence_zone_id UUID REFERENCES public.fib_confluence_zones(id),

  -- Targets
  target_1 NUMERIC,
  target_2 NUMERIC,

  -- Risk management
  stop_loss NUMERIC NOT NULL,
  risk_reward_ratio NUMERIC NOT NULL,
  invalidation_note TEXT,

  -- Supporting signals (snapshot at time of signal)
  btc_risk_score NUMERIC,
  fear_greed_index INTEGER,
  macro_regime TEXT,
  coinbase_ranking INTEGER,
  arkline_score INTEGER,

  -- Confirmation
  bounce_confirmed BOOLEAN DEFAULT false,
  confirmation_details JSONB,

  -- Outcomes
  outcome TEXT CHECK (outcome IS NULL OR outcome IN ('win', 'loss', 'partial')),
  outcome_pct NUMERIC,
  duration_hours INTEGER,

  -- Metadata
  generated_at TIMESTAMPTZ DEFAULT now(),
  triggered_at TIMESTAMPTZ,
  closed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  briefing_text TEXT,

  CONSTRAINT valid_rr CHECK (risk_reward_ratio >= 1.5)
);

CREATE INDEX IF NOT EXISTS idx_signals_active
  ON public.trade_signals(asset, status, generated_at DESC);

-- RLS: These tables are system-managed (edge function writes with service role).
-- Read access for authenticated users (premium gating handled in app layer).
ALTER TABLE public.ohlc_candles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.swing_points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fib_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fib_confluence_zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trade_signals ENABLE ROW LEVEL SECURITY;

-- Read policies for authenticated users
DROP POLICY IF EXISTS "Authenticated users can read ohlc_candles" ON public.ohlc_candles;
CREATE POLICY "Authenticated users can read ohlc_candles"
  ON public.ohlc_candles FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can read swing_points" ON public.swing_points;
CREATE POLICY "Authenticated users can read swing_points"
  ON public.swing_points FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can read fib_levels" ON public.fib_levels;
CREATE POLICY "Authenticated users can read fib_levels"
  ON public.fib_levels FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can read fib_confluence_zones" ON public.fib_confluence_zones;
CREATE POLICY "Authenticated users can read fib_confluence_zones"
  ON public.fib_confluence_zones FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can read trade_signals" ON public.trade_signals;
CREATE POLICY "Authenticated users can read trade_signals"
  ON public.trade_signals FOR SELECT
  USING (auth.role() = 'authenticated');

-- Schedule the fibonacci pipeline to run every hour via pg_cron
DO $$
BEGIN
    PERFORM cron.unschedule('fibonacci-pipeline-hourly');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

DO $outer$
BEGIN
    PERFORM cron.schedule(
        'fibonacci-pipeline-hourly',
        '5 * * * *', -- 5 minutes past every hour
        $$
        SELECT net.http_post(
            url := current_setting('app.supabase_url') || '/functions/v1/fibonacci-pipeline',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-cron-secret', current_setting('app.cron_secret')
            ),
            body := '{}'::jsonb
        );
        $$
    );
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron scheduling failed — use an external scheduler to POST to fibonacci-pipeline hourly';
END $outer$;
