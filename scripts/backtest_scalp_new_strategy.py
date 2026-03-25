#!/usr/bin/env python3
"""
Backtest: Would the new strategy filters make 1H scalps viable?
Tests 1H entry / 4H bias with all new filters:
  - Choppiness detector (raises R:R in choppy markets)
  - Momentum filter (blocks signals against 5%+ 5-day moves)
  - Daily trend guard (blocks shorts in strong daily uptrends)
  - 24-hour per-asset cooldown
  - Min R:R 1.0 (raised to 2.0 in choppy markets)

Compares against current 4H swing setup over same period.

Usage:
    python3 scripts/backtest_scalp_new_strategy.py
"""

import json
import time
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from collections import Counter

# ─── Assets (current 10) ────────────────────────────────────────────────────

ASSETS = [
    {"symbol": "BTC-USD",  "ticker": "BTC"},
    {"symbol": "ETH-USD",  "ticker": "ETH"},
    {"symbol": "SOL-USD",  "ticker": "SOL"},
    {"symbol": "SUI-USD",  "ticker": "SUI"},
    {"symbol": "LINK-USD", "ticker": "LINK"},
    {"symbol": "ADA-USD",  "ticker": "ADA"},
    {"symbol": "AVAX-USD", "ticker": "AVAX"},
    {"symbol": "APT-USD",  "ticker": "APT"},
    {"symbol": "XRP-USD",  "ticker": "XRP"},
    {"symbol": "ATOM-USD", "ticker": "ATOM"},
]

# ─── Configuration ───────────────────────────────────────────────────────────

FIB_RATIOS = [0.618, 0.786]
CONFLUENCE_TOLERANCE_PCT = 1.5
SIGNAL_PROXIMITY_PCT = 2.0
MIN_RR_RATIO = 1.0
CHOPPY_MIN_RR_RATIO = 2.0
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
WICK_REJECTION_RATIO = 1.5
VOLUME_SPIKE_RATIO = 1.3

EMA_FAST_PERIOD = 20
EMA_SLOW_PERIOD = 50
EMA_PULLBACK_TOLERANCE = 0.008

BACKTEST_DAYS = 90
WARMUP_CANDLES = 60
COOLDOWN_HOURS = 24

# Momentum filter
MOMENTUM_LOOKBACK_DAYS = 5
MOMENTUM_THRESHOLD_PCT = 5.0

# Choppiness detector
CHOPPY_EMA_SPREAD_PCT = 1.5
CHOPPY_CROSSOVER_THRESHOLD = 2
CHOPPY_WHIPSAW_THRESHOLD = 6

# Tier configs
TIERS = {
    "1h": {
        "entry_interval": "1h",
        "bias_interval": "4h",
        "entry_limit": 2400,
        "bias_limit": 1200,
        "swing_params": {
            "entry": {"lookback": 10, "min_reversal": 2.5},
            "bias":  {"lookback": 8,  "min_reversal": 5.0},
        },
        "slope_lookback": 12,
        "expiry_hours": 48,
        "eval_interval": 2,
        "label": "1H Scalp",
    },
    "4h": {
        "entry_interval": "4h",
        "bias_interval": "1d",
        "entry_limit": 2400,
        "bias_limit": 500,
        "swing_params": {
            "entry": {"lookback": 8,  "min_reversal": 5.0},
            "bias":  {"lookback": 5,  "min_reversal": 8.0},
        },
        "slope_lookback": 6,
        "expiry_hours": 72,
        "eval_interval": 3,
        "label": "4H Swing",
    },
}


# ─── Data Structures ────────────────────────────────────────────────────────

@dataclass
class Candle:
    open_time: datetime
    open: float
    high: float
    low: float
    close: float
    volume: float

@dataclass
class SwingPoint:
    type: str
    price: float
    candle_time: datetime

@dataclass
class FibLevel:
    timeframe: str
    ratio: float
    price: float

@dataclass
class ConfluenceZone:
    low: float
    high: float
    mid: float
    strength: int
    zone_type: str
    tf_count: int

@dataclass
class Signal:
    entry_time: datetime
    signal_type: str
    entry_mid: float
    entry_low: float
    entry_high: float
    target1: float
    target2: float
    stop_loss: float
    risk_1r: float
    rr_ratio: float
    confluence_strength: int
    expires_at: datetime
    status: str = "triggered"
    t1_hit_at: datetime = None
    t1_pnl_pct: float = 0.0
    best_price: float = 0.0
    runner_stop: float = 0.0
    runner_pnl_pct: float = 0.0
    outcome: str = None
    outcome_pct: float = 0.0
    closed_at: datetime = None
    duration_hours: int = 0
    choppy: bool = False
    counter_trend: bool = False
    blocked_by: str = None  # For tracking filter effectiveness

    @property
    def is_buy(self) -> bool:
        return "buy" in self.signal_type


# ─── Fetch Data ──────────────────────────────────────────────────────────────

COINBASE_GRANULARITY = {"1h": "ONE_HOUR", "4h": "FOUR_HOUR", "1d": "ONE_DAY"}
COINBASE_SECONDS = {"1h": 3600, "4h": 14400, "1d": 86400}

def fetch_candles(symbol: str, interval: str, limit: int) -> list[Candle]:
    granularity = COINBASE_GRANULARITY[interval]
    interval_seconds = COINBASE_SECONDS[interval]
    all_candles = []
    end_ts = int(datetime.now(timezone.utc).timestamp())

    while len(all_candles) < limit:
        batch = min(300, limit - len(all_candles))
        start_ts = end_ts - (batch * interval_seconds)
        url = (f"https://api.coinbase.com/api/v3/brokerage/market/products/{symbol}/candles"
               f"?start={start_ts}&end={end_ts}&granularity={granularity}&limit={batch}")
        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
        except Exception as e:
            print(f"  Error fetching {symbol} {interval}: {e}")
            break

        candles_data = data.get("candles", [])
        if not candles_data:
            break

        candles = [Candle(
            open_time=datetime.fromtimestamp(int(k["start"]), tz=timezone.utc),
            open=float(k["open"]), high=float(k["high"]),
            low=float(k["low"]), close=float(k["close"]),
            volume=float(k["volume"]),
        ) for k in candles_data]
        candles.sort(key=lambda c: c.open_time)
        all_candles = candles + all_candles
        end_ts = start_ts - 1
        if len(candles_data) < batch:
            break
        time.sleep(0.2)

    seen = set()
    unique = []
    for c in all_candles:
        if c.open_time not in seen:
            seen.add(c.open_time)
            unique.append(c)
    unique.sort(key=lambda c: c.open_time)
    return unique[-limit:]


# ─── Analysis Functions ──────────────────────────────────────────────────────

def detect_swings(candles: list[Candle], lookback: int, min_reversal: float) -> list[SwingPoint]:
    swings = []
    if len(candles) < lookback * 2 + 1:
        return swings
    for i in range(lookback, len(candles) - lookback):
        c = candles[i]
        is_high = all(candles[j].high < c.high for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_high:
            lows = [candles[j].low for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if lows and ((c.high - min(lows)) / min(lows)) * 100 >= min_reversal:
                swings.append(SwingPoint("high", c.high, c.open_time))
        is_low = all(candles[j].low > c.low for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_low:
            highs = [candles[j].high for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if highs and ((max(highs) - c.low) / c.low) * 100 >= min_reversal:
                swings.append(SwingPoint("low", c.low, c.open_time))
    return swings

def compute_fibs(swings: list[SwingPoint], tf: str) -> list[FibLevel]:
    highs = sorted([s for s in swings if s.type == "high"], key=lambda s: s.candle_time, reverse=True)[:3]
    lows = sorted([s for s in swings if s.type == "low"], key=lambda s: s.candle_time, reverse=True)[:3]
    levels = []
    for sh in highs:
        for sl in lows:
            if sh.price <= sl.price:
                continue
            diff = sh.price - sl.price
            for ratio in FIB_RATIOS:
                levels.append(FibLevel(tf, ratio, sh.price - diff * ratio))
                levels.append(FibLevel(tf, ratio, sl.price + diff * ratio))
    return levels

def cluster_levels(fibs: list[FibLevel], current_price: float) -> list[ConfluenceZone]:
    if not fibs:
        return []
    nearby = sorted([l for l in fibs if abs((l.price - current_price) / current_price) * 100 <= 15],
                    key=lambda l: l.price)
    if not nearby:
        return []
    clusters = []
    current_cluster = [nearby[0]]
    cl_low = cl_high = nearby[0].price
    for i in range(1, len(nearby)):
        level = nearby[i]
        cl_mid = (cl_low + cl_high) / 2
        if abs((level.price - cl_mid) / cl_mid) * 100 <= CONFLUENCE_TOLERANCE_PCT:
            current_cluster.append(level)
            cl_high = max(cl_high, level.price)
            cl_low = min(cl_low, level.price)
        else:
            if len(current_cluster) >= 2:
                mid = (cl_low + cl_high) / 2
                tfs = set(l.timeframe for l in current_cluster)
                clusters.append(ConfluenceZone(cl_low, cl_high, mid, len(current_cluster),
                                               "support" if mid < current_price else "resistance", len(tfs)))
            current_cluster = [level]
            cl_low = cl_high = level.price
    if len(current_cluster) >= 2:
        mid = (cl_low + cl_high) / 2
        tfs = set(l.timeframe for l in current_cluster)
        clusters.append(ConfluenceZone(cl_low, cl_high, mid, len(current_cluster),
                                       "support" if mid < current_price else "resistance", len(tfs)))
    return clusters

def calc_ema(candles: list[Candle], period: int) -> float | None:
    if len(candles) < period:
        return None
    multiplier = 2 / (period + 1)
    ema = sum(c.close for c in candles[:period]) / period
    for i in range(period, len(candles)):
        ema = (candles[i].close - ema) * multiplier + ema
    return ema


# ─── New Filters ─────────────────────────────────────────────────────────────

def detect_choppy_market(candles_4h: list[Candle]) -> bool:
    """Choppiness detector: tight EMA spread + frequent crossovers or whipsaws."""
    if len(candles_4h) < EMA_SLOW_PERIOD + 10:
        return False
    recent = candles_4h[-60:]  # Last ~10 days of 4H
    ema_fast = calc_ema(recent, EMA_FAST_PERIOD)
    ema_slow = calc_ema(recent, EMA_SLOW_PERIOD)
    if ema_fast is None or ema_slow is None:
        return False
    spread = abs(ema_fast - ema_slow) / ema_slow * 100
    tight_spread = spread < CHOPPY_EMA_SPREAD_PCT

    # Count crossovers in last 30 candles
    crossovers = 0
    for i in range(max(1, len(recent) - 30), len(recent)):
        ef_now = calc_ema(recent[:i+1], EMA_FAST_PERIOD)
        es_now = calc_ema(recent[:i+1], EMA_SLOW_PERIOD)
        ef_prev = calc_ema(recent[:i], EMA_FAST_PERIOD)
        es_prev = calc_ema(recent[:i], EMA_SLOW_PERIOD)
        if ef_now and es_now and ef_prev and es_prev:
            if (ef_now > es_now) != (ef_prev > es_prev):
                crossovers += 1

    # Count price whipsaws (direction changes)
    whipsaws = 0
    for i in range(2, min(30, len(recent))):
        prev_dir = recent[-i].close - recent[-i-1].close
        curr_dir = recent[-i+1].close - recent[-i].close
        if (prev_dir > 0) != (curr_dir > 0):
            whipsaws += 1

    return tight_spread and (crossovers >= CHOPPY_CROSSOVER_THRESHOLD or whipsaws >= CHOPPY_WHIPSAW_THRESHOLD)

def check_momentum_filter(daily_candles: list[Candle], is_buy: bool) -> bool:
    """Block signals against strong recent momentum."""
    if len(daily_candles) < MOMENTUM_LOOKBACK_DAYS + 1:
        return True
    current = daily_candles[-1].close
    past = daily_candles[-(MOMENTUM_LOOKBACK_DAYS + 1)].close
    if past == 0:
        return True
    change_pct = ((current - past) / past) * 100
    if not is_buy and change_pct >= MOMENTUM_THRESHOLD_PCT:
        return False  # Block shorts during strong rally
    if is_buy and change_pct <= -MOMENTUM_THRESHOLD_PCT:
        return False  # Block longs during strong selloff
    return True

def check_daily_trend_guard(daily_candles: list[Candle], is_buy: bool) -> bool:
    """Block shorts in strong daily uptrends. Never blocks longs."""
    if is_buy:
        return True
    if len(daily_candles) < EMA_SLOW_PERIOD + 5:
        return True
    ema_fast = calc_ema(daily_candles, EMA_FAST_PERIOD)
    ema_slow = calc_ema(daily_candles, EMA_SLOW_PERIOD)
    ema_slow_prev = calc_ema(daily_candles[:-5], EMA_SLOW_PERIOD)
    if ema_fast is None or ema_slow is None or ema_slow_prev is None:
        return True
    spread = abs(ema_fast - ema_slow) / ema_slow * 100
    slope_up = ema_slow > ema_slow_prev
    if ema_fast > ema_slow and slope_up and spread > 1.0:
        return False  # Block shorts in clear daily uptrend
    return True


# ─── Bounce & Targets ────────────────────────────────────────────────────────

def check_bounce(candles: list[Candle], zone_low: float, zone_high: float, is_buy: bool, require_extra: bool = False) -> bool:
    if len(candles) < 3:
        return False
    latest = candles[-1]
    prev = candles[-2]
    signals = 0

    if is_buy:
        body = abs(latest.close - latest.open)
        lower_wick = min(latest.open, latest.close) - latest.low
        if lower_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close > zone_low:
            signals += 1
        if latest.close > zone_high and prev.close > zone_high and prev.low <= zone_high:
            signals += 1
    else:
        body = abs(latest.close - latest.open)
        upper_wick = latest.high - max(latest.open, latest.close)
        if upper_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close < zone_high:
            signals += 1
        if latest.close < zone_low and prev.close < zone_low and prev.high >= zone_low:
            signals += 1

    vol_candles = candles[-21:-1]
    if len(vol_candles) >= 10 and latest.volume > 0:
        avg_vol = sum(c.volume for c in vol_candles) / len(vol_candles)
        if avg_vol > 0 and latest.volume >= VOLUME_SPIKE_RATIO * avg_vol:
            signals += 1

    required = 2 if require_extra else 1
    return signals >= required

def check_trend_alignment(trend_candles: list[Candle], is_buy: bool, slope_lookback: int) -> bool:
    if len(trend_candles) < EMA_SLOW_PERIOD + slope_lookback:
        return True
    ema_fast = calc_ema(trend_candles, EMA_FAST_PERIOD)
    ema_slow = calc_ema(trend_candles, EMA_SLOW_PERIOD)
    ema_slow_prev = calc_ema(trend_candles[:-slope_lookback], EMA_SLOW_PERIOD)
    if ema_fast is None or ema_slow is None or ema_slow_prev is None:
        return True
    price = trend_candles[-1].close
    if is_buy:
        trend_ok = ema_fast > ema_slow
        pullback_ok = (ema_slow > ema_slow_prev) and abs(price - ema_slow) / ema_slow < EMA_PULLBACK_TOLERANCE
        return trend_ok or pullback_ok
    else:
        trend_ok = ema_fast < ema_slow
        pullback_ok = (ema_slow < ema_slow_prev) and abs(price - ema_slow) / ema_slow < EMA_PULLBACK_TOLERANCE
        return trend_ok or pullback_ok

def compute_targets_and_stop(zone, all_fib_prices, is_buy):
    sorted_prices = sorted(all_fib_prices)
    zone_mid = zone.mid
    if is_buy:
        levels_below = [p for p in sorted_prices if p < zone.low]
        next_down = levels_below[-1] if levels_below else None
        stop_loss = next_down * 0.997 if next_down else zone_mid * 0.985
        levels_above = [p for p in sorted_prices if p > zone.high]
        target1 = levels_above[0] if levels_above else zone_mid * 1.03
        target2 = levels_above[1] if len(levels_above) > 1 else target1 * 1.015
    else:
        levels_above = [p for p in sorted_prices if p > zone.high]
        next_up = levels_above[0] if levels_above else None
        stop_loss = next_up * 1.003 if next_up else zone_mid * 1.015
        levels_below = [p for p in sorted_prices if p < zone.low]
        target1 = levels_below[-1] if levels_below else zone_mid * 0.97
        target2 = levels_below[-2] if len(levels_below) > 1 else target1 * 0.985
    return target1, target2, stop_loss


# ─── Signal Resolution ──────────────────────────────────────────────────────

def resolve_signal(signal: Signal, candle: Candle, candle_time: datetime):
    if signal.status != "triggered":
        return
    is_buy = signal.is_buy
    entry_mid = signal.entry_mid
    t1 = signal.target1
    sl = signal.stop_loss
    risk_1r = signal.risk_1r
    t1_already_hit = signal.t1_hit_at is not None
    best_price = signal.best_price if signal.best_price else entry_mid
    runner_stop = signal.runner_stop if signal.runner_stop else sl
    duration = int((candle_time - signal.entry_time).total_seconds() / 3600)

    if candle_time >= signal.expires_at:
        exit_price = candle.close
        if t1_already_hit:
            runner_pnl = ((exit_price - entry_mid) / entry_mid * 100) if is_buy else ((entry_mid - exit_price) / entry_mid * 100)
            total_pnl = (signal.t1_pnl_pct + runner_pnl) / 2
            signal.runner_pnl_pct = round(runner_pnl, 2)
            signal.outcome = "win" if total_pnl > 0 else "loss"
            signal.outcome_pct = round(total_pnl, 2)
        else:
            pnl = ((exit_price - entry_mid) / entry_mid * 100) if is_buy else ((entry_mid - exit_price) / entry_mid * 100)
            signal.outcome = "loss"
            signal.outcome_pct = round(pnl, 2)
        signal.status = "closed"
        signal.closed_at = candle_time
        signal.duration_hours = duration
        return

    if is_buy:
        if not t1_already_hit:
            if candle.low <= sl:
                signal.outcome = "loss"
                signal.outcome_pct = round(((sl - entry_mid) / entry_mid) * 100, 2)
                signal.status = "closed"
                signal.closed_at = candle_time
                signal.duration_hours = duration
                return
            if candle.high >= t1:
                signal.t1_hit_at = candle_time
                signal.t1_pnl_pct = round(((t1 - entry_mid) / entry_mid) * 100, 2)
                signal.best_price = candle.high
                signal.runner_stop = entry_mid
        else:
            best_price = max(best_price, candle.high)
            runner_stop = max(runner_stop, best_price - risk_1r)
            signal.best_price = best_price
            signal.runner_stop = runner_stop
            if candle.low <= runner_stop:
                runner_pnl = ((runner_stop - entry_mid) / entry_mid) * 100
                total_pnl = (signal.t1_pnl_pct + runner_pnl) / 2
                signal.runner_pnl_pct = round(runner_pnl, 2)
                signal.outcome = "win" if total_pnl > 0 else "loss"
                signal.outcome_pct = round(total_pnl, 2)
                signal.status = "closed"
                signal.closed_at = candle_time
                signal.duration_hours = duration
    else:
        if not t1_already_hit:
            if candle.high >= sl:
                signal.outcome = "loss"
                signal.outcome_pct = round(((entry_mid - sl) / entry_mid) * 100, 2)
                signal.status = "closed"
                signal.closed_at = candle_time
                signal.duration_hours = duration
                return
            if candle.low <= t1:
                signal.t1_hit_at = candle_time
                signal.t1_pnl_pct = round(((entry_mid - t1) / entry_mid) * 100, 2)
                signal.best_price = candle.low
                signal.runner_stop = entry_mid
        else:
            best_price = min(best_price, candle.low)
            runner_stop = min(runner_stop, best_price + risk_1r)
            signal.best_price = best_price
            signal.runner_stop = runner_stop
            if candle.high >= runner_stop:
                runner_pnl = ((entry_mid - runner_stop) / entry_mid) * 100
                total_pnl = (signal.t1_pnl_pct + runner_pnl) / 2
                signal.runner_pnl_pct = round(runner_pnl, 2)
                signal.outcome = "win" if total_pnl > 0 else "loss"
                signal.outcome_pct = round(total_pnl, 2)
                signal.status = "closed"
                signal.closed_at = candle_time
                signal.duration_hours = duration


# ─── Backtest Runner ─────────────────────────────────────────────────────────

def run_backtest(asset_symbol: str, asset_ticker: str, tier_key: str,
                 daily_candles: list[Candle] = None,
                 candles_4h_for_choppy: list[Candle] = None) -> tuple[list[Signal], dict]:
    tier = TIERS[tier_key]
    stats = {"total_evaluated": 0, "blocked_trend": 0, "blocked_bounce": 0,
             "blocked_rr": 0, "blocked_cooldown": 0, "blocked_momentum": 0,
             "blocked_daily_guard": 0, "choppy_periods": 0}

    entry_candles = fetch_candles(asset_symbol, tier["entry_interval"], tier["entry_limit"])
    bias_candles = fetch_candles(asset_symbol, tier["bias_interval"], tier["bias_limit"])
    time.sleep(0.3)

    if len(entry_candles) < WARMUP_CANDLES:
        return [], stats

    cutoff = datetime.now(timezone.utc) - timedelta(days=BACKTEST_DAYS)
    signals: list[Signal] = []
    last_signal_time = {}  # per-asset cooldown

    for i in range(WARMUP_CANDLES, len(entry_candles)):
        candle = entry_candles[i]
        eval_time = candle.open_time
        current_price = candle.close

        if eval_time < cutoff:
            continue

        for sig in signals:
            if sig.status == "triggered":
                resolve_signal(sig, candle, eval_time)

        if i % tier["eval_interval"] != 0:
            continue

        stats["total_evaluated"] += 1

        # 24h cooldown
        if asset_ticker in last_signal_time:
            hours_since = (eval_time - last_signal_time[asset_ticker]).total_seconds() / 3600
            if hours_since < COOLDOWN_HOURS:
                stats["blocked_cooldown"] += 1
                continue

        history_entry = entry_candles[:i + 1]
        history_bias = [c for c in bias_candles if c.open_time <= eval_time]

        # Get daily candles up to eval time (for momentum + daily guard)
        daily_history = [c for c in (daily_candles or []) if c.open_time <= eval_time]

        # Detect choppiness on 4H candles
        choppy_candles = candles_4h_for_choppy or (history_entry if tier_key == "4h" else history_bias)
        choppy_history = [c for c in choppy_candles if c.open_time <= eval_time]
        is_choppy = detect_choppy_market(choppy_history)
        if is_choppy:
            stats["choppy_periods"] += 1

        sp_entry = tier["swing_params"]["entry"]
        sp_bias = tier["swing_params"]["bias"]
        swings_entry = detect_swings(history_entry[-500:], sp_entry["lookback"], sp_entry["min_reversal"])
        swings_bias = detect_swings(history_bias[-250:] if history_bias else [], sp_bias["lookback"], sp_bias["min_reversal"])

        fibs_entry = compute_fibs(swings_entry, "entry")
        fibs_bias = compute_fibs(swings_bias, "bias")
        all_fibs = fibs_entry + fibs_bias
        if not all_fibs:
            continue

        zones = cluster_levels(all_fibs, current_price)
        all_fib_prices = [f.price for f in all_fibs]

        for zone in zones:
            dist_pct = abs((current_price - zone.mid) / current_price) * 100
            if dist_pct > SIGNAL_PROXIMITY_PCT:
                continue

            duplicate = any(s.status == "triggered" and abs(s.entry_mid - zone.mid) / zone.mid < 0.005 for s in signals)
            if duplicate:
                continue

            is_buy = zone.zone_type == "support"

            # Trend alignment
            if not check_trend_alignment(history_bias if tier_key == "1h" else history_entry,
                                         is_buy, tier["slope_lookback"]):
                stats["blocked_trend"] += 1
                continue

            # Daily trend guard
            if not check_daily_trend_guard(daily_history, is_buy):
                stats["blocked_daily_guard"] += 1
                continue

            # Momentum filter
            if not check_momentum_filter(daily_history, is_buy):
                stats["blocked_momentum"] += 1
                continue

            # Bounce (require 2/3 in choppy)
            if not check_bounce(history_entry[-25:], zone.low, zone.high, is_buy, require_extra=is_choppy):
                stats["blocked_bounce"] += 1
                continue

            t1, t2, sl = compute_targets_and_stop(zone, all_fib_prices, is_buy)
            entry_mid = zone.mid
            risk_dist = abs(entry_mid - sl)
            reward_dist = abs(t1 - entry_mid)
            rr = reward_dist / risk_dist if risk_dist > 0 else 0

            effective_min_rr = CHOPPY_MIN_RR_RATIO if is_choppy else MIN_RR_RATIO
            if rr < effective_min_rr:
                stats["blocked_rr"] += 1
                continue

            is_strong = rr >= STRONG_MIN_RR_RATIO and zone.strength >= STRONG_MIN_CONFLUENCE
            if is_buy:
                sig_type = "strong_buy" if is_strong else "buy"
            else:
                sig_type = "strong_sell" if is_strong else "sell"

            signal = Signal(
                entry_time=eval_time, signal_type=sig_type,
                entry_mid=entry_mid, entry_low=zone.low, entry_high=zone.high,
                target1=t1, target2=t2, stop_loss=sl,
                risk_1r=risk_dist, rr_ratio=round(rr, 2),
                confluence_strength=zone.strength,
                expires_at=eval_time + timedelta(hours=tier["expiry_hours"]),
                best_price=entry_mid, runner_stop=sl,
                choppy=is_choppy,
            )
            signals.append(signal)
            last_signal_time[asset_ticker] = eval_time
            break  # One signal per eval per asset

    return signals, stats


# ─── Results ─────────────────────────────────────────────────────────────────

def compute_results(ticker: str, signals: list[Signal], label: str) -> dict:
    closed = [s for s in signals if s.status == "closed"]
    wins = [s for s in closed if s.outcome == "win"]
    losses = [s for s in closed if s.outcome == "loss"]
    buys = [s for s in closed if s.is_buy]
    sells = [s for s in closed if not s.is_buy]
    buy_wins = [s for s in buys if s.outcome == "win"]
    sell_wins = [s for s in sells if s.outcome == "win"]

    gross_profit = sum(s.outcome_pct for s in closed if s.outcome_pct > 0)
    gross_loss = abs(sum(s.outcome_pct for s in closed if s.outcome_pct < 0))
    total_pnl = sum(s.outcome_pct for s in closed)

    durations = [s.duration_hours for s in closed if s.duration_hours > 0]

    return {
        "ticker": ticker, "label": label,
        "total": len(closed), "wins": len(wins), "losses": len(losses),
        "win_rate": len(wins) / len(closed) * 100 if closed else 0,
        "avg_win": sum(s.outcome_pct for s in wins) / len(wins) if wins else 0,
        "avg_loss": sum(s.outcome_pct for s in losses) / len(losses) if losses else 0,
        "total_pnl": total_pnl,
        "profit_factor": gross_profit / gross_loss if gross_loss > 0 else float("inf"),
        "long_count": len(buys), "long_wins": len(buy_wins),
        "long_wr": len(buy_wins) / len(buys) * 100 if buys else 0,
        "long_pnl": sum(s.outcome_pct for s in buys),
        "short_count": len(sells), "short_wins": len(sell_wins),
        "short_wr": len(sell_wins) / len(sells) * 100 if sells else 0,
        "short_pnl": sum(s.outcome_pct for s in sells),
        "avg_duration_h": sum(durations) / len(durations) if durations else 0,
        "choppy_signals": len([s for s in closed if s.choppy]),
    }


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    print("=" * 130)
    print("SCALP vs SWING COMPARISON — New Strategy Filters Applied to Both")
    print("=" * 130)
    print(f"Period: ~{BACKTEST_DAYS} days | Assets: {', '.join(a['ticker'] for a in ASSETS)}")
    print(f"Filters: Choppiness detector, Momentum (5d/5%), Daily trend guard, 24h cooldown")
    print(f"Min R:R: {MIN_RR_RATIO} (normal) / {CHOPPY_MIN_RR_RATIO} (choppy)")
    print()

    all_results_1h = {}
    all_results_4h = {}
    all_stats_1h = {}
    all_stats_4h = {}

    for asset in ASSETS:
        ticker = asset["ticker"]
        symbol = asset["symbol"]
        print(f"\n  {ticker}...")

        # Fetch daily candles once for both tiers (for momentum + daily guard)
        print(f"    Fetching daily candles...")
        daily_candles = fetch_candles(symbol, "1d", 500)
        time.sleep(0.3)

        # Fetch 4H candles for choppiness detector (used by both tiers)
        print(f"    Fetching 4H candles for choppiness...")
        candles_4h = fetch_candles(symbol, "4h", 1200)
        time.sleep(0.3)

        print(f"    Running 1H scalp backtest...")
        signals_1h, stats_1h = run_backtest(symbol, ticker, "1h", daily_candles, candles_4h)
        r1h = compute_results(ticker, signals_1h, "1H Scalp")
        all_results_1h[ticker] = r1h
        all_stats_1h[ticker] = stats_1h
        print(f"    1H: {r1h['total']} signals, {r1h['win_rate']:.1f}% WR, {r1h['profit_factor']:.2f} PF, {r1h['total_pnl']:+.1f}%")

        print(f"    Running 4H swing backtest...")
        signals_4h, stats_4h = run_backtest(symbol, ticker, "4h", daily_candles, candles_4h)
        r4h = compute_results(ticker, signals_4h, "4H Swing")
        all_results_4h[ticker] = r4h
        all_stats_4h[ticker] = stats_4h
        print(f"    4H: {r4h['total']} signals, {r4h['win_rate']:.1f}% WR, {r4h['profit_factor']:.2f} PF, {r4h['total_pnl']:+.1f}%")

        time.sleep(1)

    # ─── Comparison Table ────────────────────────────────────────────────────

    print(f"\n\n{'=' * 140}")
    print("SIDE-BY-SIDE COMPARISON")
    print(f"{'=' * 140}")

    header = f"{'Asset':<7} | {'--- 1H Scalp (new filters) ---':^48} | {'--- 4H Swing (new filters) ---':^48} | {'Winner':<8}"
    print(header)
    sub = f"{'':7} | {'Sigs':>4} {'Win%':>6} {'PF':>6} {'P&L':>8} {'L-WR':>5} {'S-WR':>5} {'AvgH':>5} | {'Sigs':>4} {'Win%':>6} {'PF':>6} {'P&L':>8} {'L-WR':>5} {'S-WR':>5} {'AvgH':>5} | {'':8}"
    print(sub)
    print("-" * 140)

    total_1h_pnl = total_4h_pnl = 0
    total_1h_sigs = total_4h_sigs = 0

    for asset in ASSETS:
        ticker = asset["ticker"]
        r1 = all_results_1h[ticker]
        r4 = all_results_4h[ticker]
        total_1h_pnl += r1["total_pnl"]
        total_4h_pnl += r4["total_pnl"]
        total_1h_sigs += r1["total"]
        total_4h_sigs += r4["total"]

        if r1["total"] < 3 and r4["total"] < 3:
            winner = "---"
        elif r1["total"] < 3:
            winner = "4H"
        elif r4["total"] < 3:
            winner = "1H"
        elif r1["profit_factor"] > r4["profit_factor"]:
            winner = "1H"
        else:
            winner = "4H"

        dur_1h = f"{r1['avg_duration_h']:.0f}" if r1['avg_duration_h'] else "-"
        dur_4h = f"{r4['avg_duration_h']:.0f}" if r4['avg_duration_h'] else "-"

        print(f"{ticker:<7} | {r1['total']:>4} {r1['win_rate']:>5.1f}% {r1['profit_factor']:>5.2f} {r1['total_pnl']:>+7.1f}% {r1['long_wr']:>4.0f}% {r1['short_wr']:>4.0f}% {dur_1h:>5} | "
              f"{r4['total']:>4} {r4['win_rate']:>5.1f}% {r4['profit_factor']:>5.2f} {r4['total_pnl']:>+7.1f}% {r4['long_wr']:>4.0f}% {r4['short_wr']:>4.0f}% {dur_4h:>5} | {winner:<8}")

    print("-" * 140)
    print(f"{'TOTAL':<7} | {total_1h_sigs:>4} {'':6} {'':6} {total_1h_pnl:>+7.1f}% {'':5} {'':5} {'':5} | "
          f"{total_4h_sigs:>4} {'':6} {'':6} {total_4h_pnl:>+7.1f}% {'':5} {'':5} {'':5} |")

    # ─── Filter Effectiveness ────────────────────────────────────────────────

    print(f"\n\n{'=' * 100}")
    print("FILTER EFFECTIVENESS (1H Scalp)")
    print(f"{'=' * 100}")
    print(f"{'Asset':<7} | {'Evaluated':>9} {'Trend':>7} {'DGuard':>7} {'Moment':>7} {'Bounce':>7} {'R:R':>7} {'Cool':>7} {'Choppy':>7}")
    print("-" * 100)
    for asset in ASSETS:
        t = asset["ticker"]
        s = all_stats_1h[t]
        print(f"{t:<7} | {s['total_evaluated']:>9} {s['blocked_trend']:>7} {s['blocked_daily_guard']:>7} "
              f"{s['blocked_momentum']:>7} {s['blocked_bounce']:>7} {s['blocked_rr']:>7} {s['blocked_cooldown']:>7} {s['choppy_periods']:>7}")

    # ─── Combined Summary ────────────────────────────────────────────────────

    print(f"\n\n{'=' * 80}")
    print("COMBINED: What if both tiers ran together?")
    print(f"{'=' * 80}")

    combined_sigs = total_1h_sigs + total_4h_sigs
    combined_pnl = total_1h_pnl + total_4h_pnl
    sigs_per_day = combined_sigs / BACKTEST_DAYS if BACKTEST_DAYS > 0 else 0
    sigs_per_week = sigs_per_day * 7

    print(f"  Total signals: {combined_sigs} ({total_1h_sigs} scalp + {total_4h_sigs} swing)")
    print(f"  Signals/day:   {sigs_per_day:.1f}")
    print(f"  Signals/week:  {sigs_per_week:.1f}")
    print(f"  Combined P&L:  {combined_pnl:+.1f}%")
    print(f"  1H-only P&L:   {total_1h_pnl:+.1f}%")
    print(f"  4H-only P&L:   {total_4h_pnl:+.1f}%")
    print()


if __name__ == "__main__":
    main()
