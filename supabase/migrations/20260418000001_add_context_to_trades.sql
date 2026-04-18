-- Add market context column to model_portfolio_trades
-- Stores headlines and economic events from the rebalance day
-- Format: { "headlines": ["...", "..."], "events": ["...", "..."] }

ALTER TABLE model_portfolio_trades
ADD COLUMN IF NOT EXISTS market_context JSONB DEFAULT NULL;
