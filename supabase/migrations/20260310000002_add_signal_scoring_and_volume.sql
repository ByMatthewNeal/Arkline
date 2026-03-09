-- Add composite scoring, volume confluence, and proximity alert tracking

ALTER TABLE public.trade_signals
  ADD COLUMN IF NOT EXISTS composite_score INTEGER,
  ADD COLUMN IF NOT EXISTS volume_confluence JSONB,
  ADD COLUMN IF NOT EXISTS proximity_notified_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_signals_composite_score
  ON public.trade_signals(composite_score DESC)
  WHERE status IN ('active', 'triggered');

COMMENT ON COLUMN public.trade_signals.composite_score IS
  'Weighted signal quality score 0-100 combining confluence depth, EMA alignment, volume, macro conditions';

COMMENT ON COLUMN public.trade_signals.volume_confluence IS
  'Volume profile data: {has_volume_confluence, volume_node_count, max_relative_volume}';

COMMENT ON COLUMN public.trade_signals.proximity_notified_at IS
  'Last time a proximity alert was sent for this signal';
