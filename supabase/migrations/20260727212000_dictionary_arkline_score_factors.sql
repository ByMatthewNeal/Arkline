-- The three "held" factor terms from the DefineTerm spec, plus aliases so every
-- ArkLine Score component label resolves.
--
-- Component names come from APISentimentService and render via
-- HomeRiskComponents `Text(component.name)`. House style for `arkline` entries:
-- describe the framework and how to read it, never the component weights.

INSERT INTO dictionary (term, definition, category, example, related_terms, slug, aliases)
VALUES
  (
    'BTC Cycle Risk',
    'Where Bitcoin is trading relative to its long-term logarithmic growth trend — a primary input to its Risk Level. Well below the trend has historically been the cheap end of a cycle; well above it, the stretched end. It describes cycle position, not timing: price can stay stretched for months before anything changes.',
    'arkline',
    'BTC pushing well above its long-term trend is what pulls the risk level toward the high end, even while price is still climbing.',
    ARRAY['Risk Levels', 'All-Time High', 'Bull Market'],
    'btc-cycle-risk',
    ARRAY['Log Regression', 'Logarithmic Regression', 'Cycle Risk']
  ),
  (
    'Capital Flow',
    'Arkline''s read on where money is moving inside crypto — out toward risk, or back toward safety. It blends stablecoin dominance, the direction of Bitcoin dominance, and altcoins'' share of total market cap. Rising stablecoin dominance means capital is sitting on the sidelines; falling Bitcoin dominance with a rising alt share means it is rotating further out the risk curve. It shows where money is going, not what to buy.',
    'arkline',
    'Capital flow turned defensive as stablecoin dominance climbed — money moving to the sidelines rather than into alts.',
    ARRAY['Bitcoin Dominance', 'Stablecoin', 'Altcoin Season', 'Rotation Signal'],
    'capital-flow',
    ARRAY['Capital Rotation', 'Capital Flows']
  ),
  (
    'App Store FOMO',
    'Coinbase''s position on the US App Store free-apps chart, used as a proxy for how much attention retail is paying to crypto. A fast climb toward the top usually means new money is arriving late in a move — historically a marker of froth rather than opportunity. It measures crowd attention, not price.',
    'arkline',
    'Coinbase climbing into the top 20 free apps has historically lined up with local tops rather than good entries.',
    ARRAY['FOMO', 'Fear & Greed Index', 'Risk Levels'],
    'app-store-fomo',
    ARRAY['App Store Ranking', 'App Store Sentiment']
  )
ON CONFLICT DO NOTHING;

-- Aliases for the remaining ArkLine Score component labels, which carry
-- parenthetical or plural forms that do not match the term string.
UPDATE dictionary SET aliases = aliases || ARRAY['DXY (Dollar)']      WHERE slug = 'dxy';
UPDATE dictionary SET aliases = aliases || ARRAY['VIX (Volatility)']  WHERE slug = 'vix';
UPDATE dictionary SET aliases = aliases || ARRAY['Funding Rates']     WHERE slug = 'funding-rate';
