-- Reclassify closed signals where best_price reached the consider-profit zone
-- (60% of entry→T1) but were marked as "loss". These should be "partial".

-- Long signals: best_price >= entry + (t1 - entry) * 0.6
UPDATE trade_signals
SET outcome = 'partial'
WHERE outcome = 'loss'
  AND best_price IS NOT NULL
  AND target_1 IS NOT NULL
  AND signal_type IN ('buy', 'strong_buy')
  AND best_price >= entry_price_mid + (target_1 - entry_price_mid) * 0.6;

-- Short signals: best_price <= entry - (entry - t1) * 0.6
UPDATE trade_signals
SET outcome = 'partial'
WHERE outcome = 'loss'
  AND best_price IS NOT NULL
  AND target_1 IS NOT NULL
  AND signal_type IN ('sell', 'strong_sell')
  AND best_price <= entry_price_mid - (entry_price_mid - target_1) * 0.6;
