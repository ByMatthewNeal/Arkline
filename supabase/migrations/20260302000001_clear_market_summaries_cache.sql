-- Clear stale market summary cache for 2026-03-02 to force regeneration with correct DXY data
DELETE FROM market_summaries WHERE summary_date = '2026-03-02';

-- Drop this migration's effect after running (it's a one-time data fix)
