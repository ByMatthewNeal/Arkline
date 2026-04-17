-- Add followed_model_portfolio column to profiles
-- Stores the strategy key ('core', 'edge', 'alpha') the user follows
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS followed_model_portfolio TEXT DEFAULT NULL;
