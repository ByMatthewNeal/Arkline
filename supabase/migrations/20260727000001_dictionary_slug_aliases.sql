-- Add stable slug + aliases to dictionary for inline DefineTerm lookups.
-- Slugs are the canonical keys screens reference; aliases cover UI labels
-- that differ from the display term (e.g. "R:R" -> risk-reward-ratio).

ALTER TABLE dictionary ADD COLUMN IF NOT EXISTS slug text;
ALTER TABLE dictionary ADD COLUMN IF NOT EXISTS aliases text[] NOT NULL DEFAULT '{}';

-- Kebab-case of term: strip parens, non-alphanumerics -> '-', trim '-'
UPDATE dictionary
SET slug = trim(both '-' from lower(
  regexp_replace(regexp_replace(term, '[()]', '', 'g'), '[^a-z0-9]+', '-', 'gi')
))
WHERE slug IS NULL;

-- Manual overrides so slugs match the wiring map
UPDATE dictionary SET slug = 'target-1' WHERE term = 'Target 1 (T1)';
UPDATE dictionary SET slug = 'target-2' WHERE term = 'Target 2 (T2)';

-- Aliases for UI labels that differ from the term string
UPDATE dictionary SET aliases = ARRAY['R:R', 'RR', 'Risk/Reward', 'Risk / Reward'] WHERE slug = 'risk-reward-ratio';
UPDATE dictionary SET aliases = ARRAY['Fear & Greed'] WHERE slug = 'fear-greed-index';
UPDATE dictionary SET aliases = ARRAY['T1', 'Target 1'] WHERE slug = 'target-1';
UPDATE dictionary SET aliases = ARRAY['T2', 'Target 2'] WHERE slug = 'target-2';
UPDATE dictionary SET aliases = ARRAY['WTI', 'WTI Crude', 'Crude Oil'] WHERE slug = 'wti-crude-oil';
UPDATE dictionary SET aliases = ARRAY['US Net Liquidity'] WHERE slug = 'net-liquidity';
UPDATE dictionary SET aliases = ARRAY['Alt Season'] WHERE slug = 'altcoin-season';
UPDATE dictionary SET aliases = ARRAY['Stop Loss Level'] WHERE slug = 'invalidation';
UPDATE dictionary SET aliases = ARRAY['Dollar Index'] WHERE slug = 'dxy';

ALTER TABLE dictionary ALTER COLUMN slug SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS dictionary_slug_key ON dictionary(slug);
