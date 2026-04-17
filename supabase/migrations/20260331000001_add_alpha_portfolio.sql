-- Add Arkline Alpha portfolio (alt-heavy, aggressive alt rotation)
INSERT INTO model_portfolios (name, strategy, description, universe, starting_nav) VALUES
  ('Arkline Alpha', 'alpha', 'Alt-heavy systematic crypto portfolio. 40-50% deployed into top-performing altcoins with BTC/ETH/SOL base.', ARRAY['BTC', 'ETH', 'SOL', 'ALT', 'PAXG', 'USDC'], 50000)
ON CONFLICT (name) DO NOTHING;
