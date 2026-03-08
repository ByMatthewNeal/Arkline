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
-- INSERT requires WITH CHECK, UPDATE requires both USING + WITH CHECK, DELETE requires USING

-- Helper to create deny policies for each table
DO $$
DECLARE
  tbl TEXT;
  tbls TEXT[] := ARRAY['ohlc_candles', 'swing_points', 'fib_levels', 'fib_confluence_zones', 'trade_signals'];
BEGIN
  FOREACH tbl IN ARRAY tbls LOOP
    -- INSERT deny
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny inserts on ' || tbl AND tablename = tbl) THEN
      EXECUTE format('CREATE POLICY "Deny inserts on %I" ON public.%I FOR INSERT TO authenticated WITH CHECK (false)', tbl, tbl);
    END IF;

    -- UPDATE deny
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny updates on ' || tbl AND tablename = tbl) THEN
      EXECUTE format('CREATE POLICY "Deny updates on %I" ON public.%I FOR UPDATE TO authenticated USING (false) WITH CHECK (false)', tbl, tbl);
    END IF;

    -- DELETE deny
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Deny deletes on ' || tbl AND tablename = tbl) THEN
      EXECUTE format('CREATE POLICY "Deny deletes on %I" ON public.%I FOR DELETE TO authenticated USING (false)', tbl, tbl);
    END IF;
  END LOOP;
END $$;
