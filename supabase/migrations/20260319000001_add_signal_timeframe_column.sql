-- Add timeframe column to trade_signals for dual-tier signal generation
-- '4h' = Swing (4H entry / 1D bias, 72h expiry) — existing signals
-- '1h' = Scalp (1H entry / 4H bias, 48h expiry) — new tier

ALTER TABLE public.trade_signals
ADD COLUMN timeframe TEXT NOT NULL DEFAULT '4h';

ALTER TABLE public.trade_signals
ADD CONSTRAINT trade_signals_timeframe_check CHECK (timeframe IN ('1h', '4h'));

-- Update indexes for efficient querying by timeframe
DROP INDEX IF EXISTS idx_signals_active;
CREATE INDEX idx_signals_active ON public.trade_signals(asset, timeframe, status, generated_at DESC);

CREATE INDEX idx_signals_timeframe_status ON public.trade_signals(timeframe, status);
