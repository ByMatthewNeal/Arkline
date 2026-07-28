-- Adds the two risk-factor terms that DefineTerm tap targets already reference
-- but that had no dictionary row (so they rendered no "?" in the app).
--   macro-risk         -> RiskFactorType.macroRisk
--   bull-market-bands  -> RiskFactorType.bullMarketBands
-- Per house style, the `arkline` entry describes the framework without exposing
-- component weights; the `technical` entry names standard public TA periods.

INSERT INTO dictionary (term, definition, category, example, related_terms, slug, aliases)
VALUES
  (
    'Macro Risk',
    'Arkline''s single read on the macro backdrop, blending equity-market volatility and dollar strength into one input to an asset''s Risk Level. When volatility is climbing and the dollar is strengthening, macro risk reads high — historically a tougher backdrop for risk assets like crypto. Treat it as context for how much risk to carry, not as a buy or sell trigger.',
    'arkline',
    'Macro risk climbed as the VIX pushed higher and the dollar rallied — a headwind for crypto even while price was still holding up.',
    ARRAY['VIX', 'DXY', 'Risk Levels', 'Risk-Off'],
    'macro-risk',
    ARRAY['Macro Risk Factor']
  ),
  (
    'Bull Market Bands',
    'The 20-week simple moving average and 21-week exponential moving average plotted together — commonly called the bull market support band. In healthy uptrends price tends to hold above the band and bounce from it, while sustained trading below it is a common sign the trend has weakened. It describes the regime a setup is forming in; it is not a signal on its own.',
    'technical',
    'BTC pulled back into the bull market bands and bounced, keeping the broader uptrend intact.',
    ARRAY['SMA', 'Support', 'Bull Market', 'Risk Levels'],
    'bull-market-bands',
    ARRAY['Bull Mkt Bands', 'Bull Market Support Band', 'BMSB']
  )
ON CONFLICT DO NOTHING;
