-- Remove the newer duplicate ETH short signal (B+ grade, 5h ago)
-- Keep the older A-grade signal which was created first
-- Identify by entry zone: the duplicate has entry_zone_low ~2083
DELETE FROM trade_signals
WHERE asset = 'ETH'
  AND status = 'triggered'
  AND signal_type IN ('sell', 'strong_sell')
  AND entry_zone_low > 2080
  AND triggered_at > now() - interval '1 day';
