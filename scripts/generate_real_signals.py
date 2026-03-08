#!/usr/bin/env python3
"""
Generate real trade signals for the past 7 days using exact pipeline logic.
Fetches live Binance data, runs golden pocket strategy, resolves outcomes,
and outputs a SQL migration file for Supabase.
"""

import json
import uuid
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Optional

# ─── Configuration (EXACT mirror of fibonacci-pipeline/index.ts) ─────────────

ASSETS = [
    {"symbol": "BTCUSDT", "ticker": "BTC"},
    {"symbol": "ETHUSDT", "ticker": "ETH"},
    {"symbol": "SOLUSDT", "ticker": "SOL"},
    {"symbol": "SUIUSDT", "ticker": "SUI"},
    {"symbol": "LINKUSDT", "ticker": "LINK"},
    {"symbol": "ADAUSDT", "ticker": "ADA"},
]

TIMEFRAME_CONFIGS = [
    {"tf": "4h", "interval": "4h", "limit": 500},
    {"tf": "1d", "interval": "1d", "limit": 120},
]

SWING_PARAMS = {
    "4h": {"lookback": 8, "min_reversal": 5.0},
    "1d": {"lookback": 5, "min_reversal": 8.0},
}

FIB_RATIOS = [0.618, 0.786]
CONFLUENCE_TOLERANCE_PCT = 1.5
SIGNAL_PROXIMITY_PCT = 2.0
MIN_RR_RATIO = 1.0
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
SIGNAL_EXPIRY_HOURS = 72
WICK_REJECTION_RATIO = 1.5
VOLUME_SPIKE_RATIO = 1.3

EMA_FAST_PERIOD = 20
EMA_SLOW_PERIOD = 50
EMA_SLOPE_LOOKBACK = 6
EMA_PULLBACK_TOLERANCE = 0.008

# Only generate signals from this many days ago
LOOKBACK_DAYS = 7

# ─── Data Classes ─────────────────────────────────────────────────────────────

@dataclass
class Candle:
    open_time: str
    open: float
    high: float
    low: float
    close: float
    volume: float

@dataclass
class SwingPoint:
    type: str  # "high" or "low"
    price: float
    candle_time: str
    reversal_pct: float

@dataclass
class FibLevel:
    timeframe: str
    ratio: float
    price: float
    direction: str  # "from_high" or "from_low"

@dataclass
class ConfluenceZone:
    low: float
    high: float
    mid: float
    strength: int
    zone_type: str  # "support" or "resistance"
    tf_count: int
    levels: list

@dataclass
class Signal:
    id: str
    asset: str
    signal_type: str
    status: str
    entry_zone_low: float
    entry_zone_high: float
    entry_price_mid: float
    target_1: float
    target_2: float
    stop_loss: float
    risk_reward_ratio: float
    risk_1r: float
    bounce_confirmed: bool
    confirmation_details: dict
    ema_trend_aligned: bool
    generated_at: str
    triggered_at: str
    expires_at: str
    # Resolution fields
    best_price: Optional[float] = None
    runner_stop: Optional[float] = None
    runner_exit_price: Optional[float] = None
    t1_hit_at: Optional[str] = None
    t1_pnl_pct: Optional[float] = None
    runner_pnl_pct: Optional[float] = None
    outcome: Optional[str] = None
    outcome_pct: Optional[float] = None
    closed_at: Optional[str] = None
    duration_hours: Optional[int] = None

# ─── Binance Data Fetching ────────────────────────────────────────────────────

def fetch_candles(symbol: str) -> dict:
    result = {}
    for config in TIMEFRAME_CONFIGS:
        url = f"https://api.binance.com/api/v3/klines?symbol={symbol}&interval={config['interval']}&limit={config['limit']}"
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req) as resp:
            raw = json.loads(resp.read())

        candles = []
        for k in raw:
            candles.append(Candle(
                open_time=datetime.fromtimestamp(k[0] / 1000, tz=timezone.utc).isoformat(),
                open=float(k[1]),
                high=float(k[2]),
                low=float(k[3]),
                close=float(k[4]),
                volume=float(k[5]),
            ))
        result[config["tf"]] = candles
    return result

# ─── Swing Detection ─────────────────────────────────────────────────────────

def detect_swings(candles: list, lookback: int, min_reversal: float) -> list:
    swings = []
    for i in range(lookback, len(candles) - lookback):
        c = candles[i]
        # Swing high
        is_high = all(candles[j].high < c.high for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_high:
            surrounding_lows = [candles[j].low for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_lows:
                min_low = min(surrounding_lows)
                rev_pct = ((c.high - min_low) / min_low) * 100
                if rev_pct >= min_reversal:
                    swings.append(SwingPoint("high", c.high, c.open_time, rev_pct))

        # Swing low
        is_low = all(candles[j].low > c.low for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_low:
            surrounding_highs = [candles[j].high for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_highs:
                max_high = max(surrounding_highs)
                rev_pct = ((max_high - c.low) / c.low) * 100
                if rev_pct >= min_reversal:
                    swings.append(SwingPoint("low", c.low, c.open_time, rev_pct))
    return swings

def detect_all_swings(candles: dict) -> dict:
    result = {}
    for tf, tf_candles in candles.items():
        params = SWING_PARAMS.get(tf)
        if not params or len(tf_candles) < params["lookback"] * 2 + 1:
            result[tf] = []
            continue
        result[tf] = detect_swings(tf_candles, params["lookback"], params["min_reversal"])
    return result

# ─── Fibonacci Levels ────────────────────────────────────────────────────────

def compute_all_fibs(swings: dict) -> list:
    all_levels = []
    for tf, tf_swings in swings.items():
        highs = sorted([s for s in tf_swings if s.type == "high"], key=lambda s: s.candle_time, reverse=True)[:3]
        lows = sorted([s for s in tf_swings if s.type == "low"], key=lambda s: s.candle_time, reverse=True)[:3]

        for sh in highs:
            for sl in lows:
                if sh.price <= sl.price:
                    continue
                diff = sh.price - sl.price
                for ratio in FIB_RATIOS:
                    all_levels.append(FibLevel(tf, ratio, sh.price - diff * ratio, "from_high"))
                    all_levels.append(FibLevel(tf, ratio, sl.price + diff * ratio, "from_low"))
    return all_levels

# ─── Confluence Clustering ───────────────────────────────────────────────────

def cluster_levels(fibs: list, current_price: float) -> list:
    if not fibs:
        return []

    nearby = sorted([l for l in fibs if abs((l.price - current_price) / current_price) * 100 <= 15], key=lambda l: l.price)
    if not nearby:
        return []

    clusters = []
    current_cluster = [nearby[0]]
    cluster_low = nearby[0].price
    cluster_high = nearby[0].price

    for i in range(1, len(nearby)):
        level = nearby[i]
        cluster_mid = (cluster_low + cluster_high) / 2
        dist_pct = abs((level.price - cluster_mid) / cluster_mid) * 100

        if dist_pct <= CONFLUENCE_TOLERANCE_PCT:
            current_cluster.append(level)
            cluster_high = max(cluster_high, level.price)
            cluster_low = min(cluster_low, level.price)
        else:
            if len(current_cluster) >= 2:
                mid = (cluster_low + cluster_high) / 2
                tfs = set(l.timeframe for l in current_cluster)
                clusters.append(ConfluenceZone(
                    cluster_low, cluster_high, mid, len(current_cluster),
                    "support" if mid < current_price else "resistance",
                    len(tfs), current_cluster
                ))
            current_cluster = [level]
            cluster_low = level.price
            cluster_high = level.price

    if len(current_cluster) >= 2:
        mid = (cluster_low + cluster_high) / 2
        tfs = set(l.timeframe for l in current_cluster)
        clusters.append(ConfluenceZone(
            cluster_low, cluster_high, mid, len(current_cluster),
            "support" if mid < current_price else "resistance",
            len(tfs), current_cluster
        ))

    return clusters

# ─── EMA Trend Filter ────────────────────────────────────────────────────────

def calc_ema(candles: list, period: int) -> float:
    if len(candles) < period:
        return None
    multiplier = 2 / (period + 1)
    ema = sum(c.close for c in candles[:period]) / period
    for i in range(period, len(candles)):
        ema = (candles[i].close - ema) * multiplier + ema
    return ema

def check_trend_alignment(candles_4h: list, is_buy: bool) -> bool:
    if len(candles_4h) < EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK:
        return True
    ema_fast = calc_ema(candles_4h, EMA_FAST_PERIOD)
    ema_slow = calc_ema(candles_4h, EMA_SLOW_PERIOD)
    ema_slow_prev = calc_ema(candles_4h[:-EMA_SLOPE_LOOKBACK], EMA_SLOW_PERIOD)
    if ema_fast is None or ema_slow is None or ema_slow_prev is None:
        return True

    price = candles_4h[-1].close
    if is_buy:
        trend_ok = ema_fast > ema_slow
        pullback_ok = (ema_slow > ema_slow_prev) and (abs(price - ema_slow) / ema_slow < EMA_PULLBACK_TOLERANCE)
        return trend_ok or pullback_ok
    else:
        trend_ok = ema_fast < ema_slow
        pullback_ok = (ema_slow < ema_slow_prev) and (abs(price - ema_slow) / ema_slow < EMA_PULLBACK_TOLERANCE)
        return trend_ok or pullback_ok

# ─── Bounce Confirmation ─────────────────────────────────────────────────────

def check_bounce(candles: list, zone_low: float, zone_high: float, is_buy: bool) -> dict:
    details = {"wick_rejection": False, "volume_spike": False, "consecutive_closes": False}
    if len(candles) < 3:
        return {"confirmed": False, "details": details}

    latest = candles[-1]
    prev = candles[-2]

    if is_buy:
        body = abs(latest.close - latest.open)
        lower_wick = min(latest.open, latest.close) - latest.low
        if lower_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close > zone_low:
            details["wick_rejection"] = True
        if latest.close > zone_high and prev.close > zone_high and prev.low <= zone_high:
            details["consecutive_closes"] = True
    else:
        body = abs(latest.close - latest.open)
        upper_wick = latest.high - max(latest.open, latest.close)
        if upper_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close < zone_high:
            details["wick_rejection"] = True
        if latest.close < zone_low and prev.close < zone_low and prev.high >= zone_low:
            details["consecutive_closes"] = True

    vol_candles = candles[-21:-1]
    if len(vol_candles) >= 10 and latest.volume > 0:
        avg_vol = sum(c.volume for c in vol_candles) / len(vol_candles)
        if avg_vol > 0 and latest.volume >= VOLUME_SPIKE_RATIO * avg_vol:
            details["volume_spike"] = True

    confirmed = details["wick_rejection"] or details["volume_spike"] or details["consecutive_closes"]
    return {"confirmed": confirmed, "details": details}

# ─── Targets & Stop Loss ─────────────────────────────────────────────────────

def compute_targets_and_stop(zone, all_fib_prices: list, is_buy: bool):
    sorted_prices = sorted(all_fib_prices)
    zone_mid = zone.mid

    if is_buy:
        levels_below = [p for p in sorted_prices if p < zone.low]
        next_down = levels_below[-1] if levels_below else None
        stop_loss = next_down * 0.997 if next_down else zone_mid * 0.985

        levels_above = [p for p in sorted_prices if p > zone.high]
        target1 = levels_above[0] if levels_above else zone_mid * 1.03
        target2 = levels_above[1] if len(levels_above) > 1 else target1 * 1.015
        return {"target1": target1, "target2": target2, "stop_loss": stop_loss}
    else:
        levels_above = [p for p in sorted_prices if p > zone.high]
        next_up = levels_above[0] if levels_above else None
        stop_loss = next_up * 1.003 if next_up else zone_mid * 1.015

        levels_below = [p for p in sorted_prices if p < zone.low]
        target1 = levels_below[-1] if levels_below else zone_mid * 0.97
        target2 = levels_below[-2] if len(levels_below) > 1 else target1 * 0.985
        return {"target1": target1, "target2": target2, "stop_loss": stop_loss}

# ─── Signal Resolution ───────────────────────────────────────────────────────

def resolve_signal(signal: Signal, candles_4h: list, trigger_idx: int) -> Signal:
    """Walk forward through candles to resolve the signal outcome."""
    is_buy = signal.signal_type in ("buy", "strong_buy")
    entry_mid = signal.entry_price_mid
    t1 = signal.target_1
    sl = signal.stop_loss
    risk_1r = signal.risk_1r
    expires_at = datetime.fromisoformat(signal.expires_at)

    best_price = entry_mid
    runner_stop = sl
    t1_hit = False
    t1_pnl = 0.0

    for i in range(trigger_idx + 1, len(candles_4h)):
        candle = candles_4h[i]
        candle_time = datetime.fromisoformat(candle.open_time)

        # Expiry check
        if candle_time >= expires_at:
            exit_price = candle.close
            if t1_hit:
                runner_pnl = ((exit_price - entry_mid) / entry_mid * 100) if is_buy else ((entry_mid - exit_price) / entry_mid * 100)
                total_pnl = (t1_pnl + runner_pnl) / 2
                signal.status = "target_hit" if total_pnl > 0 else "expired"
                signal.outcome = "win" if total_pnl > 0 else "loss"
                signal.outcome_pct = round(total_pnl, 2)
                signal.runner_exit_price = exit_price
                signal.runner_pnl_pct = round(runner_pnl, 2)
            else:
                pnl = ((exit_price - entry_mid) / entry_mid * 100) if is_buy else ((entry_mid - exit_price) / entry_mid * 100)
                signal.status = "expired"
                signal.outcome = "loss"
                signal.outcome_pct = round(pnl, 2)
            signal.closed_at = candle_time.isoformat()
            signal.duration_hours = int((candle_time - datetime.fromisoformat(signal.triggered_at)).total_seconds() / 3600)
            signal.best_price = best_price
            signal.runner_stop = runner_stop
            return signal

        if is_buy:
            if not t1_hit:
                if candle.low <= sl:
                    pnl = ((sl - entry_mid) / entry_mid) * 100
                    signal.status = "invalidated"
                    signal.outcome = "loss"
                    signal.outcome_pct = round(pnl, 2)
                    signal.closed_at = candle_time.isoformat()
                    signal.duration_hours = int((candle_time - datetime.fromisoformat(signal.triggered_at)).total_seconds() / 3600)
                    signal.best_price = best_price
                    signal.runner_stop = runner_stop
                    return signal
                if candle.high >= t1:
                    t1_hit = True
                    t1_pnl = ((t1 - entry_mid) / entry_mid) * 100
                    signal.t1_hit_at = candle_time.isoformat()
                    signal.t1_pnl_pct = round(t1_pnl, 2)
                    best_price = max(best_price, candle.high)
                    runner_stop = entry_mid  # Move to breakeven
            else:
                best_price = max(best_price, candle.high)
                runner_stop = max(runner_stop, best_price - risk_1r)
                if candle.low <= runner_stop:
                    runner_pnl = ((runner_stop - entry_mid) / entry_mid) * 100
                    total_pnl = (t1_pnl + runner_pnl) / 2
                    signal.status = "target_hit" if total_pnl > 0 else "invalidated"
                    signal.outcome = "win" if total_pnl > 0 else "loss"
                    signal.outcome_pct = round(total_pnl, 2)
                    signal.runner_exit_price = runner_stop
                    signal.runner_pnl_pct = round(runner_pnl, 2)
                    signal.closed_at = candle_time.isoformat()
                    signal.duration_hours = int((candle_time - datetime.fromisoformat(signal.triggered_at)).total_seconds() / 3600)
                    signal.best_price = best_price
                    signal.runner_stop = runner_stop
                    return signal
        else:
            if not t1_hit:
                if candle.high >= sl:
                    pnl = ((entry_mid - sl) / entry_mid) * 100
                    signal.status = "invalidated"
                    signal.outcome = "loss"
                    signal.outcome_pct = round(pnl, 2)
                    signal.closed_at = candle_time.isoformat()
                    signal.duration_hours = int((candle_time - datetime.fromisoformat(signal.triggered_at)).total_seconds() / 3600)
                    signal.best_price = best_price
                    signal.runner_stop = runner_stop
                    return signal
                if candle.low <= t1:
                    t1_hit = True
                    t1_pnl = ((entry_mid - t1) / entry_mid) * 100
                    signal.t1_hit_at = candle_time.isoformat()
                    signal.t1_pnl_pct = round(t1_pnl, 2)
                    best_price = min(best_price, candle.low)
                    runner_stop = entry_mid  # Move to breakeven
            else:
                best_price = min(best_price, candle.low)
                runner_stop = min(runner_stop, best_price + risk_1r)
                if candle.high >= runner_stop:
                    runner_pnl = ((entry_mid - runner_stop) / entry_mid) * 100
                    total_pnl = (t1_pnl + runner_pnl) / 2
                    signal.status = "target_hit" if total_pnl > 0 else "invalidated"
                    signal.outcome = "win" if total_pnl > 0 else "loss"
                    signal.outcome_pct = round(total_pnl, 2)
                    signal.runner_exit_price = runner_stop
                    signal.runner_pnl_pct = round(runner_pnl, 2)
                    signal.closed_at = candle_time.isoformat()
                    signal.duration_hours = int((candle_time - datetime.fromisoformat(signal.triggered_at)).total_seconds() / 3600)
                    signal.best_price = best_price
                    signal.runner_stop = runner_stop
                    return signal

    # Signal is still open (not resolved yet)
    signal.best_price = best_price
    signal.runner_stop = runner_stop
    return signal

# ─── Main Pipeline ───────────────────────────────────────────────────────────

def run_pipeline_for_asset(asset: dict) -> list:
    symbol = asset["symbol"]
    ticker = asset["ticker"]
    print(f"\n  Processing {ticker}...")

    candles = fetch_candles(symbol)
    candles_4h = candles["4h"]
    candles_1d = candles["1d"]

    if len(candles_4h) < EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK:
        print(f"    Not enough 4h candles for {ticker}")
        return []

    # Determine the 7-day cutoff
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=LOOKBACK_DAYS)

    # Find the index where we start evaluating (every 3rd candle = ~12h intervals, matching pipeline schedule)
    signals = []
    existing_zones = set()  # Track entry_price_mid to avoid duplicates

    # Walk through 4h candles, evaluating at each one in the 7-day window
    for eval_idx in range(EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK, len(candles_4h)):
        eval_candle = candles_4h[eval_idx]
        eval_time = datetime.fromisoformat(eval_candle.open_time)

        if eval_time < cutoff:
            continue

        # Only evaluate every 3rd candle (~12h intervals like the pipeline)
        if eval_idx % 3 != 0:
            continue

        # Use candles up to this point for analysis
        candles_up_to = candles_4h[:eval_idx + 1]
        current_price = candles_up_to[-1].close

        # Run full pipeline on data available at this time
        swings = detect_all_swings({"4h": candles_up_to, "1d": candles_1d})
        fibs = compute_all_fibs(swings)
        zones = cluster_levels(fibs, current_price)
        all_fib_prices = [f.price for f in fibs]

        for zone in zones:
            dist_pct = abs((current_price - zone.mid) / current_price) * 100
            if dist_pct > SIGNAL_PROXIMITY_PCT:
                continue

            # Skip if we already have a signal near this zone
            zone_key = round(zone.mid, 2)
            if any(abs(z - zone_key) / max(zone_key, 1) < 0.005 for z in existing_zones):
                continue

            is_buy = zone.zone_type == "support"

            if not check_trend_alignment(candles_up_to, is_buy):
                continue

            bounce = check_bounce(candles_up_to[-25:], zone.low, zone.high, is_buy)
            if not bounce["confirmed"]:
                continue

            targets = compute_targets_and_stop(zone, all_fib_prices, is_buy)
            if not targets:
                continue

            entry_mid = zone.mid
            risk_dist = abs(entry_mid - targets["stop_loss"])
            reward_dist = abs(targets["target1"] - entry_mid)
            rr_ratio = reward_dist / risk_dist if risk_dist > 0 else 0

            if rr_ratio < MIN_RR_RATIO:
                continue

            is_strong = rr_ratio >= STRONG_MIN_RR_RATIO and zone.strength >= STRONG_MIN_CONFLUENCE
            if is_buy:
                signal_type = "strong_buy" if is_strong else "buy"
            else:
                signal_type = "strong_sell" if is_strong else "sell"

            expires_at = (eval_time + timedelta(hours=SIGNAL_EXPIRY_HOURS)).isoformat()

            signal = Signal(
                id=str(uuid.uuid4()),
                asset=ticker,
                signal_type=signal_type,
                status="triggered",
                entry_zone_low=zone.low,
                entry_zone_high=zone.high,
                entry_price_mid=entry_mid,
                target_1=targets["target1"],
                target_2=targets["target2"],
                stop_loss=targets["stop_loss"],
                risk_reward_ratio=round(rr_ratio, 2),
                risk_1r=risk_dist,
                bounce_confirmed=True,
                confirmation_details=bounce["details"],
                ema_trend_aligned=True,
                generated_at=eval_time.isoformat(),
                triggered_at=eval_time.isoformat(),
                expires_at=expires_at,
                best_price=entry_mid,
                runner_stop=targets["stop_loss"],
            )

            # Resolve against future candles
            signal = resolve_signal(signal, candles_4h, eval_idx)
            signals.append(signal)
            existing_zones.add(zone_key)

    print(f"    {ticker}: {len(signals)} signals found")
    return signals

# ─── SQL Generation ──────────────────────────────────────────────────────────

def sql_val(v):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "TRUE" if v else "FALSE"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, dict):
        return f"'{json.dumps(v)}'::jsonb"
    # String — escape single quotes
    return f"'{str(v).replace(chr(39), chr(39)+chr(39))}'"

def signal_to_sql(s: Signal) -> str:
    return f"""INSERT INTO trade_signals (
  id, asset, signal_type, status,
  entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss,
  risk_reward_ratio, risk_1r,
  bounce_confirmed, confirmation_details, ema_trend_aligned,
  best_price, runner_stop, runner_exit_price,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct, duration_hours,
  generated_at, triggered_at, expires_at, closed_at
) VALUES (
  {sql_val(s.id)}, {sql_val(s.asset)}, {sql_val(s.signal_type)}, {sql_val(s.status)},
  {sql_val(s.entry_zone_low)}, {sql_val(s.entry_zone_high)}, {sql_val(s.entry_price_mid)},
  {sql_val(s.target_1)}, {sql_val(s.target_2)}, {sql_val(s.stop_loss)},
  {sql_val(s.risk_reward_ratio)}, {sql_val(s.risk_1r)},
  {sql_val(s.bounce_confirmed)}, {sql_val(s.confirmation_details)}, {sql_val(s.ema_trend_aligned)},
  {sql_val(s.best_price)}, {sql_val(s.runner_stop)}, {sql_val(s.runner_exit_price)},
  {sql_val(s.t1_hit_at)}, {sql_val(s.t1_pnl_pct)}, {sql_val(s.runner_pnl_pct)},
  {sql_val(s.outcome)}, {sql_val(s.outcome_pct)}, {sql_val(s.duration_hours)},
  {sql_val(s.generated_at)}, {sql_val(s.triggered_at)}, {sql_val(s.expires_at)}, {sql_val(s.closed_at)}
) ON CONFLICT (id) DO NOTHING;"""

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    now = datetime.now(timezone.utc)
    cutoff = now - timedelta(days=LOOKBACK_DAYS)
    print(f"Generating real signals from {cutoff.strftime('%Y-%m-%d')} to {now.strftime('%Y-%m-%d')}")
    print(f"Assets: {', '.join(a['ticker'] for a in ASSETS)}")

    all_signals = []
    for asset in ASSETS:
        signals = run_pipeline_for_asset(asset)
        all_signals.extend(signals)

    print(f"\n{'='*70}")
    print(f"TOTAL: {len(all_signals)} real signals generated")
    print(f"{'='*70}")

    # Print summary
    active = [s for s in all_signals if s.status == "triggered"]
    wins = [s for s in all_signals if s.outcome == "win"]
    losses = [s for s in all_signals if s.outcome == "loss"]
    print(f"  Active/Open: {len(active)}")
    print(f"  Wins: {len(wins)}")
    print(f"  Losses: {len(losses)}")
    print()

    for s in all_signals:
        is_buy = s.signal_type in ("buy", "strong_buy")
        direction = "LONG" if is_buy else "SHORT"
        status_str = s.status.upper()
        pnl_str = f"{s.outcome_pct:+.2f}%" if s.outcome_pct is not None else "open"
        dur_str = f"{s.duration_hours}h" if s.duration_hours else "..."

        if s.entry_price_mid > 1000:
            price_str = f"${s.entry_price_mid:,.0f}"
        elif s.entry_price_mid > 1:
            price_str = f"${s.entry_price_mid:.2f}"
        else:
            price_str = f"${s.entry_price_mid:.4f}"

        gen = datetime.fromisoformat(s.generated_at).strftime("%m/%d %H:%M")
        print(f"  {gen}  {s.asset:5s} {direction:5s} {s.signal_type:12s} {price_str:>12s}  R:R {s.risk_reward_ratio:.1f}  {status_str:12s} {pnl_str:>8s}  {dur_str}")

    # Write SQL migration
    output_path = "supabase/migrations/20260307000001_seed_real_signals.sql"
    with open(output_path, "w") as f:
        f.write(f"-- Real trade signals generated from Binance data ({cutoff.strftime('%Y-%m-%d')} to {now.strftime('%Y-%m-%d')})\n")
        f.write(f"-- Generated by scripts/generate_real_signals.py using exact pipeline logic\n")
        f.write(f"-- {len(all_signals)} signals across {len(ASSETS)} assets\n\n")

        for s in all_signals:
            f.write(signal_to_sql(s))
            f.write("\n\n")

    print(f"\nSQL migration written to: {output_path}")
    print(f"Apply with: supabase db push  OR  paste into Supabase SQL Editor")

if __name__ == "__main__":
    main()
