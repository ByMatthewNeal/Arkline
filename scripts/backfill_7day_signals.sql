-- ═══════════════════════════════════════════════════════════════════
-- BACKFILL: 7-day signals with 24/7 coverage (all 4H candle closes)
-- Generated: 2026-03-08 16:49:07 UTC
-- Signals: 19
-- ═══════════════════════════════════════════════════════════════════

-- Step 1: Remove existing signals from the past 7 days
DELETE FROM trade_signals WHERE triggered_at >= '2026-03-01T16:49:07+00:00';

-- Step 2: Insert backfilled signals
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'BTC', 'buy', 'target_hit', 69601.92, 70113.68, 69857.80,
  71632.47, 72144.23, 68959.70, 1.98, 898.0990,
  74038.22, 73140.12, 73140.12,
  true, true, '{"wick_rejection": false, "volume_spike": true, "consecutive_closes": false}'::jsonb, true,
  '2026-03-04T12:00:00+00:00', '2026-03-07T12:00:00+00:00', '2026-03-04T20:00:00+00:00', 8,
  '2026-03-04T16:00:00+00:00', 2.54, 4.7,
  'win', 3.62
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'BTC', 'buy', 'invalidated', 69601.92, 70636.88, 70119.40,
  71579.91, 71632.47, 68959.70, 1.26, 1159.70,
  70119.40, 68959.70, NULL,
  true, true, '{"wick_rejection": true, "volume_spike": false, "consecutive_closes": false}'::jsonb, true,
  '2026-03-06T04:00:00+00:00', '2026-03-09T04:00:00+00:00', '2026-03-06T16:00:00+00:00', 12,
  NULL, 0.0, 0.0,
  'loss', -1.65
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'ETH', 'buy', 'target_hit', 1987.48, 2026.74, 2007.11,
  2050.64, 2053.78, 1964.51, 1.02, 42.6035,
  2058.06, 2015.46, 2015.46,
  true, true, '{"wick_rejection": true, "volume_spike": false, "consecutive_closes": true}'::jsonb, true,
  '2026-03-02T20:00:00+00:00', '2026-03-05T20:00:00+00:00', '2026-03-03T04:00:00+00:00', 8,
  '2026-03-03T00:00:00+00:00', 2.17, 0.42,
  'win', 1.29
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'ETH', 'buy', 'invalidated', 2142.90, 2143.96, 2143.43,
  2220.06, 2244.01, 2096.22, 1.62, 47.2121,
  2143.43, 2096.22, NULL,
  true, true, '{"wick_rejection": false, "volume_spike": true, "consecutive_closes": false}'::jsonb, true,
  '2026-03-04T16:00:00+00:00', '2026-03-07T16:00:00+00:00', '2026-03-05T08:00:00+00:00', 16,
  NULL, 0.0, 0.0,
  'loss', -2.2
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'SOL', 'strong_buy', 'invalidated', 91.2028, 91.9888, 91.5958,
  98.3741, 103.4047, 89.0933, 2.71, 2.5025,
  91.5958, 89.0933, NULL,
  true, true, '{"wick_rejection": false, "volume_spike": true, "consecutive_closes": false}'::jsonb, true,
  '2026-03-04T16:00:00+00:00', '2026-03-07T16:00:00+00:00', '2026-03-05T16:00:00+00:00', 24,
  NULL, 0.0, 0.0,
  'loss', -2.73
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'SOL', 'buy', 'target_hit', 87.8744, 89.3614, 88.6179,
  91.2028, 91.9888, 87.2163, 1.84, 1.4016,
  92.8800, 91.4784, 91.4784,
  true, true, '{"wick_rejection": true, "volume_spike": false, "consecutive_closes": false}'::jsonb, true,
  '2026-03-05T08:00:00+00:00', '2026-03-08T08:00:00+00:00', '2026-03-05T16:00:00+00:00', 8,
  '2026-03-05T12:00:00+00:00', 2.92, 3.23,
  'win', 3.07
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'SOL', 'buy', 'invalidated', 87.8744, 89.3614, 88.6179,
  91.2028, 91.9888, 87.2163, 1.84, 1.4016,
  88.6179, 87.2163, NULL,
  true, true, '{"wick_rejection": true, "volume_spike": false, "consecutive_closes": false}'::jsonb, true,
  '2026-03-06T00:00:00+00:00', '2026-03-09T00:00:00+00:00', '2026-03-06T12:00:00+00:00', 12,
  NULL, 0.0, 0.0,
  'loss', -1.58
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'SUI', 'sell', 'target_hit', 0.893203, 0.914892, 0.904047,
  0.885171, 0.883871, 0.921887, 1.06, 0.017839,
  0.880900, 0.898739, 0.898739,
  true, true, '{"wick_rejection": false, "volume_spike": true, "consecutive_closes": true}'::jsonb, false,
  '2026-03-02T00:00:00+00:00', '2026-03-05T00:00:00+00:00', '2026-03-02T16:00:00+00:00', 16,
  '2026-03-02T08:00:00+00:00', 2.09, 0.59,
  'win', 1.34
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'SUI', 'sell', 'invalidated', 0.893203, 0.916842, 0.905022,
  0.885339, 0.883871, 0.921887, 1.17, 0.016864,
  0.905022, 0.921887, NULL,
  true, true, '{"wick_rejection": true, "volume_spike": false, "consecutive_closes": false}'::jsonb, false,
  '2026-03-03T16:00:00+00:00', '2026-03-06T16:00:00+00:00', '2026-03-03T20:00:00+00:00', 4,
  NULL, 0.0, 0.0,
  'loss', -1.86
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'SUI', 'strong_buy', 'invalidated', 0.975574, 0.996607, 0.986090,
  1.0608, 1.2656, 0.951205, 2.14, 0.034886,
  0.986090, 0.951205, NULL,
  true, true, '{"wick_rejection": true, "volume_spike": true, "consecutive_closes": false}'::jsonb, true,
  '2026-03-04T20:00:00+00:00', '2026-03-07T20:00:00+00:00', '2026-03-05T04:00:00+00:00', 8,
  NULL, 0.0, 0.0,
  'loss', -3.54
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'SUI', 'buy', 'invalidated', 0.954067, 0.961091, 0.957579,
  0.975574, 0.975592, 0.948009, 1.88, 0.009570,
  0.957579, 0.948009, NULL,
  true, true, '{"wick_rejection": true, "volume_spike": false, "consecutive_closes": false}'::jsonb, true,
  '2026-03-05T20:00:00+00:00', '2026-03-08T20:00:00+00:00', '2026-03-06T12:00:00+00:00', 16,
  NULL, 0.0, 0.0,
  'loss', -1.0
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'LINK', 'buy', 'target_hit', 8.5217, 8.7308, 8.6262,
  8.7855, 8.7856, 8.4690, 1.01, 0.157253,
  8.8900, 8.7327, 8.7327,
  true, true, '{"wick_rejection": true, "volume_spike": false, "consecutive_closes": false}'::jsonb, true,
  '2026-03-02T00:00:00+00:00', '2026-03-05T00:00:00+00:00', '2026-03-02T08:00:00+00:00', 8,
  '2026-03-02T04:00:00+00:00', 1.85, 1.23,
  'win', 1.54
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'LINK', 'strong_buy', 'invalidated', 8.9546, 9.0188, 8.9867,
  9.2580, 9.2580, 8.8875, 2.73, 0.099223,
  8.9867, 8.8875, NULL,
  true, true, '{"wick_rejection": false, "volume_spike": true, "consecutive_closes": false}'::jsonb, true,
  '2026-03-02T16:00:00+00:00', '2026-03-05T16:00:00+00:00', '2026-03-03T04:00:00+00:00', 12,
  NULL, 0.0, 0.0,
  'loss', -1.1
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'LINK', 'strong_buy', 'target_hit', 8.9546, 9.0502, 9.0024,
  9.2580, 9.2580, 8.8875, 2.22, 0.114943,
  9.6200, 9.5051, 9.5051,
  true, true, '{"wick_rejection": false, "volume_spike": true, "consecutive_closes": false}'::jsonb, true,
  '2026-03-04T12:00:00+00:00', '2026-03-07T12:00:00+00:00', '2026-03-04T20:00:00+00:00', 8,
  '2026-03-04T16:00:00+00:00', 2.84, 5.58,
  'win', 4.21
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'LINK', 'buy', 'invalidated', 8.9546, 9.1210, 9.0378,
  9.2580, 9.2580, 8.8875, 1.47, 0.150313,
  9.0378, 8.8875, NULL,
  true, true, '{"wick_rejection": true, "volume_spike": false, "consecutive_closes": false}'::jsonb, true,
  '2026-03-05T20:00:00+00:00', '2026-03-08T20:00:00+00:00', '2026-03-06T00:00:00+00:00', 4,
  NULL, 0.0, 0.0,
  'loss', -1.66
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'LINK', 'buy', 'target_hit', 8.9546, 9.1210, 9.0378,
  9.2580, 9.2580, 8.8875, 1.47, 0.150313,
  9.2800, 9.1297, 9.1297,
  true, true, '{"wick_rejection": true, "volume_spike": true, "consecutive_closes": true}'::jsonb, true,
  '2026-03-06T00:00:00+00:00', '2026-03-09T00:00:00+00:00', '2026-03-06T12:00:00+00:00', 12,
  '2026-03-06T04:00:00+00:00', 2.44, 1.02,
  'win', 1.73
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'ADA', 'sell', 'target_hit', 0.276582, 0.283647, 0.280114,
  0.273071, 0.272857, 0.285286, 1.36, 0.005172,
  0.268000, 0.273172, 0.273172,
  true, true, '{"wick_rejection": false, "volume_spike": true, "consecutive_closes": false}'::jsonb, false,
  '2026-03-03T00:00:00+00:00', '2026-03-06T00:00:00+00:00', '2026-03-03T08:00:00+00:00', 8,
  '2026-03-03T04:00:00+00:00', 2.51, 2.48,
  'win', 2.49
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'ADA', 'sell', 'target_hit', 0.258227, 0.261853, 0.260040,
  0.253643, 0.243174, 0.264742, 1.36, 0.004702,
  0.251900, 0.256602, 0.256602,
  true, true, '{"wick_rejection": false, "volume_spike": true, "consecutive_closes": false}'::jsonb, false,
  '2026-03-06T16:00:00+00:00', '2026-03-09T16:00:00+00:00', '2026-03-07T20:00:00+00:00', 28,
  '2026-03-07T16:00:00+00:00', 2.46, 1.32,
  'win', 1.89
);
INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  'ADA', 'sell', 'target_hit', 0.258227, 0.261853, 0.260040,
  0.253643, 0.243174, 0.264742, 1.36, 0.004702,
  0.250000, 0.254702, 0.254702,
  true, true, '{"wick_rejection": true, "volume_spike": false, "consecutive_closes": true}'::jsonb, false,
  '2026-03-07T20:00:00+00:00', '2026-03-10T20:00:00+00:00', '2026-03-08T12:00:00+00:00', 16,
  '2026-03-08T04:00:00+00:00', 2.46, 2.05,
  'win', 2.26
);