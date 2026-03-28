-- Add resolution_source column to track how signals were resolved (automated vs manual)
ALTER TABLE public.trade_signals
ADD COLUMN IF NOT EXISTS resolution_source TEXT DEFAULT 'automated'
CHECK (resolution_source IN ('automated', 'manual'));

-- Backfill existing resolved signals as automated
UPDATE public.trade_signals
SET resolution_source = 'automated'
WHERE resolution_source IS NULL AND status IN ('target_hit', 'invalidated', 'expired');
