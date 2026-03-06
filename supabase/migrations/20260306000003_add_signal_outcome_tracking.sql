-- Phase 5: Enhanced outcome tracking for trade signals

-- Track when T1 is hit (enables partial win detection)
ALTER TABLE public.trade_signals
  ADD COLUMN IF NOT EXISTS t1_hit_at TIMESTAMPTZ;

-- Index for performance queries on closed signals
CREATE INDEX IF NOT EXISTS idx_signals_closed
  ON public.trade_signals(outcome, closed_at DESC)
  WHERE closed_at IS NOT NULL;

-- Index for per-asset outcome queries
CREATE INDEX IF NOT EXISTS idx_signals_asset_outcome
  ON public.trade_signals(asset, outcome)
  WHERE closed_at IS NOT NULL;

-- Index for confluence zone lookups from signals
CREATE INDEX IF NOT EXISTS idx_signals_confluence_zone
  ON public.trade_signals(confluence_zone_id)
  WHERE confluence_zone_id IS NOT NULL;

-- Fix FK to SET NULL when confluence zone is replaced
ALTER TABLE public.trade_signals
  DROP CONSTRAINT IF EXISTS trade_signals_confluence_zone_id_fkey;
ALTER TABLE public.trade_signals
  ADD CONSTRAINT trade_signals_confluence_zone_id_fkey
  FOREIGN KEY (confluence_zone_id) REFERENCES public.fib_confluence_zones(id)
  ON DELETE SET NULL;

-- RLS: Deny direct writes from authenticated users (service role bypasses RLS)
DO $$ BEGIN
  -- ohlc_candles
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny writes on ohlc_candles' AND tablename = 'ohlc_candles') THEN
    CREATE POLICY "Deny writes on ohlc_candles" ON public.ohlc_candles FOR INSERT TO authenticated USING (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny updates on ohlc_candles' AND tablename = 'ohlc_candles') THEN
    CREATE POLICY "Deny updates on ohlc_candles" ON public.ohlc_candles FOR UPDATE TO authenticated USING (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny deletes on ohlc_candles' AND tablename = 'ohlc_candles') THEN
    CREATE POLICY "Deny deletes on ohlc_candles" ON public.ohlc_candles FOR DELETE TO authenticated USING (false);
  END IF;

  -- swing_points
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny writes on swing_points' AND tablename = 'swing_points') THEN
    CREATE POLICY "Deny writes on swing_points" ON public.swing_points FOR INSERT TO authenticated USING (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny updates on swing_points' AND tablename = 'swing_points') THEN
    CREATE POLICY "Deny updates on swing_points" ON public.swing_points FOR UPDATE TO authenticated USING (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny deletes on swing_points' AND tablename = 'swing_points') THEN
    CREATE POLICY "Deny deletes on swing_points" ON public.swing_points FOR DELETE TO authenticated USING (false);
  END IF;

  -- fib_levels
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny writes on fib_levels' AND tablename = 'fib_levels') THEN
    CREATE POLICY "Deny writes on fib_levels" ON public.fib_levels FOR INSERT TO authenticated USING (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny updates on fib_levels' AND tablename = 'fib_levels') THEN
    CREATE POLICY "Deny updates on fib_levels" ON public.fib_levels FOR UPDATE TO authenticated USING (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny deletes on fib_levels' AND tablename = 'fib_levels') THEN
    CREATE POLICY "Deny deletes on fib_levels" ON public.fib_levels FOR DELETE TO authenticated USING (false);
  END IF;

  -- fib_confluence_zones
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny writes on fib_confluence_zones' AND tablename = 'fib_confluence_zones') THEN
    CREATE POLICY "Deny writes on fib_confluence_zones" ON public.fib_confluence_zones FOR INSERT TO authenticated USING (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny updates on fib_confluence_zones' AND tablename = 'fib_confluence_zones') THEN
    CREATE POLICY "Deny updates on fib_confluence_zones" ON public.fib_confluence_zones FOR UPDATE TO authenticated USING (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny deletes on fib_confluence_zones' AND tablename = 'fib_confluence_zones') THEN
    CREATE POLICY "Deny deletes on fib_confluence_zones" ON public.fib_confluence_zones FOR DELETE TO authenticated USING (false);
  END IF;

  -- trade_signals
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny writes on trade_signals' AND tablename = 'trade_signals') THEN
    CREATE POLICY "Deny writes on trade_signals" ON public.trade_signals FOR INSERT TO authenticated USING (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny updates on trade_signals' AND tablename = 'trade_signals') THEN
    CREATE POLICY "Deny updates on trade_signals" ON public.trade_signals FOR UPDATE TO authenticated USING (false);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny deletes on trade_signals' AND tablename = 'trade_signals') THEN
    CREATE POLICY "Deny deletes on trade_signals" ON public.trade_signals FOR DELETE TO authenticated USING (false);
  END IF;
END $$;
