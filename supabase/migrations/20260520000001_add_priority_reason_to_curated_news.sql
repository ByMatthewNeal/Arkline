-- Add priority_reason field for high-impact news articles (relevance_score >= 7)
ALTER TABLE curated_news ADD COLUMN IF NOT EXISTS priority_reason TEXT DEFAULT '';
