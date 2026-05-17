-- Add market price columns to risk_snapshots for historical correlation.
-- Captured alongside each daily Arkline Score so scrubbing the chart
-- shows BTC, S&P 500, and Nasdaq prices at the time of each reading.
ALTER TABLE public.risk_snapshots
ADD COLUMN IF NOT EXISTS btc_price NUMERIC,
ADD COLUMN IF NOT EXISTS sp500_price NUMERIC,
ADD COLUMN IF NOT EXISTS nasdaq_price NUMERIC;
