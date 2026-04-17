#!/usr/bin/env python3
"""
Backtest: Fair Value Gap Impact Analysis
Compares the current pipeline (no FVG) vs pipeline with FVG confluence scoring.
FVG is a score enhancer, not a filter — so signal count stays the same,
but we can measure how signals WITH FVG confluence perform vs WITHOUT.

Usage:
    python3 scripts/backtest_fvg_impact.py
"""

import json
import time
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

# ─── Assets (current live pipeline) ─────────────────────────────────────────

ASSETS = [
    {"pair": "BTC-USD",  "ticker": "BTC"},
    {"pair": "ETH-USD",  "ticker": "ETH"},
    {"pair": "SOL-USD",  "ticker": "SOL"},
    {"pair": "SUI-USD",  "ticker": "SUI"},
    {"pair": "LINK-USD", "ticker": "LINK"},
    {"pair": "ADA-USD",  "ticker": "ADA"},
    {"pair": "AVAX-USD", "ticker": "AVAX"},
    {"pair": "APT-USD",  "ticker": "APT"},
    {"pair": "XRP-USD",  "ticker": "XRP"},
    {"pair": "ATOM-USD", "ticker": "ATOM"},
]

# ─── Configuration (same as live pipeline) ───────────────────────────────────

TIMEFRAME_CONFIGS = [
    {"tf": "1h", "granularity": "ONE_HOUR",  "seconds": 3600,  "limit": 2400},
    {"tf": "4h", "granularity": "FOUR_HOUR", "seconds": 14400, "limit": 2400},
    {"tf": "1d", "granularity": "ONE_DAY",   "seconds": 86400, "limit": 500},
]

SWING_PARAMS = {
    "1h": {"lookback": 10, "min_reversal": 2.5},
    "4h": {"lookback": 8, "min_reversal": 5.0},
    "1d": {"lookback": 5, "min_reversal": 8.0},
}

FIB_RATIOS = [0.618, 0.786]
MIN_RR_RATIO = 1.0
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
WICK_REJECTION_RATIO = 1.2
VOLUME_SPIKE_RATIO = 1.15
SIGNAL_PROXIMITY_PCT = 3.0
CONFLUENCE_TOLERANCE_PCT = 1.5
SIGNAL_EXPIRY_HOURS = 72
MIN_SCORE = 60

EMA_FAST_PERIOD = 20
EMA_SLOW_PERIOD = 50
EMA_SLOPE_LOOKBACK = 6
EMA_PULLBACK_TOLERANCE = 0.015

BACKTEST_DAYS = 365
WARMUP_CANDLES_4H = 60

# FVG thresholds (match pipeline)
FVG_MIN_SIZE_PCT = 0.1
FVG_TF_SCORES = {"4h": 8, "1d": 4, "1h": 3}
FVG_WIDE_BONUS = 2
FVG_WIDE_THRESHOLD = 1.5  # % of price


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
    reversal_pct: float


@dataclass
class FibLevel:
    timeframe: str
    ratio: float
    price: float
    direction: str


@dataclass
class ConfluenceZone:
    low: float
    high: float
    mid: float
    strength: int
    zone_type: str
    tf_count: int


@dataclass
class FairValueGap:
    type: str       # "bullish" or "bearish"
    timeframe: str
    high: float
    low: float
    size_pct: float
    candle_time: datetime


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
    composite_score: int
    has_fvg: bool
    ticker: str = ""
    fvg_timeframe: str = None
    fvg_bonus: int = 0
    expires_at: datetime = None
    status: str = "triggered"
    t1_hit_at: datetime = None
    t1_pnl_pct: float = 0.0
    best_price: float = 0.0
    runner_stop: float = 0.0
    runner_exit_price: float = 0.0
    runner_pnl_pct: float = 0.0
    outcome: str = None
    outcome_pct: float = 0.0
    closed_at: datetime = None
    duration_hours: int = 0

    @property
    def is_buy(self) -> bool:
        return "buy" in self.signal_type


# ─── Fetch Historical Data ──────────────────────────────────────────────────

CB_BASE = "https://api.coinbase.com/api/v3/brokerage/market/products"
CB_MAX_CANDLES = 350

def fetch_candles(pair: str, granularity: str, candle_seconds: int, limit: int) -> list[Candle]:
    all_candles: list[Candle] = []
    end_ts = int(datetime.now(timezone.utc).timestamp())

    while len(all_candles) < limit:
        batch = min(CB_MAX_CANDLES, limit - len(all_candles))
        start_ts = end_ts - (batch * candle_seconds)

        url = (f"{CB_BASE}/{pair}/candles"
               f"?granularity={granularity}&start={start_ts}&end={end_ts}&limit={batch}")

        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
        except Exception as e:
            print(f"    Error fetching {pair} {granularity}: {e}")
            break

        raw = data.get("candles", [])
        if not raw:
            break

        candles = []
        for k in raw:
            candles.append(Candle(
                open_time=datetime.fromtimestamp(int(k["start"]), tz=timezone.utc),
                open=float(k["open"]),
                high=float(k["high"]),
                low=float(k["low"]),
                close=float(k["close"]),
                volume=float(k["volume"]),
            ))

        candles.sort(key=lambda c: c.open_time)
        all_candles = candles + all_candles
        end_ts = start_ts - 1

        if len(raw) < batch:
            break
        time.sleep(0.3)

    seen = set()
    unique = []
    for c in all_candles:
        ts = c.open_time.timestamp()
        if ts not in seen:
            seen.add(ts)
            unique.append(c)
    unique.sort(key=lambda c: c.open_time)
    return unique


# ─── Swing Detection ────────────────────────────────────────────────────────

def detect_swings(candles: list[Candle], tf: str) -> list[SwingPoint]:
    params = SWING_PARAMS[tf]
    lookback = params["lookback"]
    min_reversal = params["min_reversal"]
    swings = []

    if len(candles) < lookback * 2 + 1:
        return swings

    for i in range(lookback, len(candles) - lookback):
        c = candles[i]

        is_high = all(candles[j].high < c.high for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_high:
            surrounding_lows = [candles[j].low for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_lows:
                min_low = min(surrounding_lows)
                reversal_pct = ((c.high - min_low) / min_low) * 100
                if reversal_pct >= min_reversal:
                    swings.append(SwingPoint("high", c.high, c.open_time, reversal_pct))

        is_low = all(candles[j].low > c.low for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_low:
            surrounding_highs = [candles[j].high for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_highs:
                max_high = max(surrounding_highs)
                reversal_pct = ((max_high - c.low) / c.low) * 100
                if reversal_pct >= min_reversal:
                    swings.append(SwingPoint("low", c.low, c.open_time, reversal_pct))

    return swings


# ─── Fibonacci Levels ────────────────────────────────────────────────────────

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
                levels.append(FibLevel(tf, ratio, sh.price - diff * ratio, "from_high"))
                levels.append(FibLevel(tf, ratio, sl.price + diff * ratio, "from_low"))
    return levels


# ─── Confluence Clustering ───────────────────────────────────────────────────

def cluster_levels(fibs: list[FibLevel], current_price: float, tolerance_pct: float = 1.5) -> list[ConfluenceZone]:
    if not fibs:
        return []

    nearby = [l for l in fibs if abs((l.price - current_price) / current_price) * 100 <= 15]
    if not nearby:
        return []

    nearby.sort(key=lambda l: l.price)

    clusters = []
    current_cluster = [nearby[0]]
    cl_low = nearby[0].price
    cl_high = nearby[0].price

    for i in range(1, len(nearby)):
        level = nearby[i]
        cl_mid = (cl_low + cl_high) / 2
        dist_pct = abs((level.price - cl_mid) / cl_mid) * 100

        if dist_pct <= tolerance_pct:
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
            cl_low = level.price
            cl_high = level.price

    if len(current_cluster) >= 2:
        mid = (cl_low + cl_high) / 2
        tfs = set(l.timeframe for l in current_cluster)
        clusters.append(ConfluenceZone(cl_low, cl_high, mid, len(current_cluster),
                                       "support" if mid < current_price else "resistance", len(tfs)))

    return clusters


# ─── EMA Helpers ─────────────────────────────────────────────────────────────

def calc_ema(candles: list[Candle], period: int) -> float | None:
    if len(candles) < period:
        return None
    multiplier = 2 / (period + 1)
    ema = sum(c.close for c in candles[:period]) / period
    for i in range(period, len(candles)):
        ema = (candles[i].close - ema) * multiplier + ema
    return ema


# ─── Trend Alignment ────────────────────────────────────────────────────────

def check_trend_alignment(candles_4h: list[Candle], is_buy: bool) -> bool:
    if len(candles_4h) < EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK:
        return True

    ema_fast = calc_ema(candles_4h, EMA_FAST_PERIOD)
    ema_slow = calc_ema(candles_4h, EMA_SLOW_PERIOD)
    ema_slow_prev = calc_ema(candles_4h[:-EMA_SLOPE_LOOKBACK], EMA_SLOW_PERIOD)

    if ema_fast is None or ema_slow is None or ema_slow_prev is None:
        return True

    price = candles_4h[-1].close
    ema_slope_up = ema_slow > ema_slow_prev
    ema_slope_down = ema_slow < ema_slow_prev

    if is_buy:
        trend_ok = ema_fast > ema_slow
        pullback_ok = ema_slope_up and abs(price - ema_slow) / ema_slow < EMA_PULLBACK_TOLERANCE
        return trend_ok or pullback_ok
    else:
        trend_ok = ema_fast < ema_slow
        pullback_ok = ema_slope_down and abs(price - ema_slow) / ema_slow < EMA_PULLBACK_TOLERANCE
        return trend_ok or pullback_ok


# ─── Daily Trend Guard ──────────────────────────────────────────────────────

def check_daily_trend_guard(daily_candles: list[Candle], is_buy: bool) -> bool:
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
        return False
    return True


# ─── Momentum Filter ────────────────────────────────────────────────────────

def check_momentum_filter(daily_candles: list[Candle], is_buy: bool) -> bool:
    lookback = 5
    threshold = 5.0
    if len(daily_candles) < lookback + 1:
        return True
    current = daily_candles[-1].close
    past = daily_candles[-1 - lookback].close
    change_pct = ((current - past) / past) * 100
    if not is_buy and change_pct >= threshold:
        return False
    if is_buy and change_pct <= -threshold:
        return False
    return True


# ─── Bounce Confirmation ────────────────────────────────────────────────────

def check_bounce(candles: list[Candle], zone_low: float, zone_high: float, is_buy: bool) -> dict:
    details = {"wick_rejection": False, "volume_spike": False, "consecutive_closes": False}

    if len(candles) < 3:
        return {"confirmed": False, "details": details}

    # Zone touch check
    recent = candles[-6:]
    zone_margin = (zone_high - zone_low) * 0.5
    zone_touched = False
    if is_buy:
        zone_touched = any(c.low <= zone_high + zone_margin for c in recent)
    else:
        zone_touched = any(c.high >= zone_low - zone_margin for c in recent)
    if not zone_touched:
        return {"confirmed": False, "details": details}

    latest = candles[-1]
    prev = candles[-2]

    if is_buy:
        body = abs(latest.close - latest.open)
        lower_wick = min(latest.open, latest.close) - latest.low
        if lower_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.low <= zone_high + zone_margin and latest.close > zone_low:
            details["wick_rejection"] = True
        if latest.close > zone_high and prev.close > zone_high and prev.low <= zone_high:
            details["consecutive_closes"] = True
    else:
        body = abs(latest.close - latest.open)
        upper_wick = latest.high - max(latest.open, latest.close)
        if upper_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.high >= zone_low - zone_margin and latest.close < zone_high:
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


# ─── Fair Value Gap Detection ────────────────────────────────────────────────

def detect_fvgs(candles: dict, eval_time: datetime) -> list[FairValueGap]:
    """Detect unfilled FVGs across 1H, 4H, 1D up to eval_time."""
    fvgs = []
    tf_configs = [
        ("1h", 50),
        ("4h", 50),
        ("1d", 30),
    ]

    for tf, lookback in tf_configs:
        tf_candles = candles.get(tf, [])
        # Only use candles up to eval_time
        history = [c for c in tf_candles if c.open_time <= eval_time]
        if len(history) < 5:
            continue

        start_idx = max(2, len(history) - lookback)

        for i in range(start_idx, len(history)):
            prev2 = history[i - 2]
            mid = history[i - 1]
            curr = history[i]

            # Bullish FVG: current low > candle-two-ago high
            if curr.low > prev2.high:
                gap_low = prev2.high
                gap_high = curr.low
                size_pct = (gap_high - gap_low) / mid.close * 100

                # Check if filled by subsequent candles
                filled = False
                for j in range(i + 1, len(history)):
                    if history[j].close <= gap_low:
                        filled = True
                        break

                if not filled and size_pct >= FVG_MIN_SIZE_PCT:
                    fvgs.append(FairValueGap("bullish", tf, gap_high, gap_low, round(size_pct, 2), mid.open_time))

            # Bearish FVG: current high < candle-two-ago low
            if curr.high < prev2.low:
                gap_high = prev2.low
                gap_low = curr.high
                size_pct = (gap_high - gap_low) / mid.close * 100

                filled = False
                for j in range(i + 1, len(history)):
                    if history[j].close >= gap_high:
                        filled = True
                        break

                if not filled and size_pct >= FVG_MIN_SIZE_PCT:
                    fvgs.append(FairValueGap("bearish", tf, gap_high, gap_low, round(size_pct, 2), mid.open_time))

    return fvgs


def check_fvg_confluence(zone: ConfluenceZone, fvgs: list[FairValueGap], is_buy: bool) -> dict:
    """Check if any FVG overlaps with a confluence zone in the right direction."""
    result = {"has_fvg": False, "best_tf": None, "bonus": 0, "gap_size_pct": 0}
    margin = (zone.high - zone.low) * 0.5

    for fvg in fvgs:
        if is_buy and fvg.type != "bullish":
            continue
        if not is_buy and fvg.type != "bearish":
            continue

        overlaps = fvg.high >= (zone.low - margin) and fvg.low <= (zone.high + margin)
        if not overlaps:
            continue

        bonus = FVG_TF_SCORES.get(fvg.timeframe, 4)
        if fvg.size_pct >= FVG_WIDE_THRESHOLD:
            bonus += FVG_WIDE_BONUS

        if bonus > result["bonus"]:
            result["has_fvg"] = True
            result["best_tf"] = fvg.timeframe
            result["bonus"] = bonus
            result["gap_size_pct"] = fvg.size_pct

    return result


# ─── Composite Score ─────────────────────────────────────────────────────────

def compute_composite_score(zone, candles_4h, bounce, vol_confluence, fvg_result, is_buy, rr_ratio) -> int:
    score = 0

    # 1. Confluence Depth (0-35 pts)
    strength = zone.strength
    if strength >= 4:
        score += 30
    elif strength >= 3:
        score += 20
    else:
        score += 10
    if zone.tf_count >= 2:
        score += 5
    score = min(score, 35)

    # 2. EMA Alignment (0-20 pts)
    if len(candles_4h) >= EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK:
        ema_fast = calc_ema(candles_4h, EMA_FAST_PERIOD)
        ema_slow = calc_ema(candles_4h, EMA_SLOW_PERIOD)
        ema_slow_prev = calc_ema(candles_4h[:-EMA_SLOPE_LOOKBACK], EMA_SLOW_PERIOD)
        if ema_fast and ema_slow and ema_slow_prev:
            price = candles_4h[-1].close
            spread = abs(ema_fast - ema_slow) / ema_slow * 100
            slope_strength = abs(ema_slow - ema_slow_prev) / ema_slow_prev * 100
            aligned = (ema_fast > ema_slow) if is_buy else (ema_fast < ema_slow)
            if aligned:
                score += 10
                if spread > 1.0:
                    score += 5
                if slope_strength > 0.3:
                    score += 5
            else:
                if abs(price - ema_slow) / ema_slow < EMA_PULLBACK_TOLERANCE:
                    score += 8

    # 3. Volume Confirmation Quality (0-20 pts)
    vol_score = 0
    if bounce["details"]["wick_rejection"]:
        vol_score += 8
    if bounce["details"]["volume_spike"]:
        vol_score += 8
    if bounce["details"]["consecutive_closes"]:
        vol_score += 8
    if vol_confluence:
        vol_score += 4
    score += min(vol_score, 20)

    # 4. Risk/Reward (0-15 pts)
    if rr_ratio >= 3.0:
        score += 15
    elif rr_ratio >= 2.0:
        score += 10
    else:
        score += 5

    # 5. Macro/Context (0-15 pts) — simplified for backtest (no F&G/BTC risk)
    score += 10

    # 6. FVG Confluence (0-10 pts)
    if fvg_result["has_fvg"]:
        score += fvg_result["bonus"]

    return min(max(score, 0), 100)


# ─── Volume Profile (simplified) ────────────────────────────────────────────

def compute_volume_confluence(zone, candles_4h):
    """Simplified volume node check."""
    if len(candles_4h) < 20:
        return False
    highs = [c.high for c in candles_4h]
    lows = [c.low for c in candles_4h]
    price_max = max(highs)
    price_min = min(lows)
    rng = price_max - price_min
    if rng <= 0:
        return False

    num_bins = 50
    bin_size = rng / num_bins
    bins = [0.0] * num_bins
    for c in candles_4h:
        typical = (c.high + c.low + c.close) / 3
        idx = min(int((typical - price_min) / bin_size), num_bins - 1)
        bins[idx] += c.volume

    avg_vol = sum(bins) / num_bins
    if avg_vol <= 0:
        return False

    for i in range(num_bins):
        if bins[i] / avg_vol >= 1.5:
            node_low = price_min + i * bin_size
            node_high = price_min + (i + 1) * bin_size
            if node_high >= zone.low and node_low <= zone.high:
                return True
    return False


# ─── Targets & Stop Loss ────────────────────────────────────────────────────

def compute_targets_and_stop(zone, all_fib_prices, is_buy):
    sorted_prices = sorted(all_fib_prices)
    zone_mid = zone.mid
    min_target_gap = zone_mid * 0.015

    if is_buy:
        levels_below = [p for p in sorted_prices if p < zone.low]
        next_down = levels_below[-1] if levels_below else None
        stop_loss = next_down * 0.997 if next_down else zone_mid * 0.985

        levels_above = [p for p in sorted_prices if p > zone.high]
        target1 = levels_above[0] if levels_above else zone_mid * 1.03
        t2_candidate = next((p for p in levels_above if p > target1 + min_target_gap), None)
        target2 = t2_candidate if t2_candidate else target1 * 1.03
    else:
        levels_above = [p for p in sorted_prices if p > zone.high]
        next_up = levels_above[0] if levels_above else None
        stop_loss = next_up * 1.003 if next_up else zone_mid * 1.015

        levels_below = list(reversed([p for p in sorted_prices if p < zone.low]))
        target1 = levels_below[0] if levels_below else zone_mid * 0.97
        t2_candidate = next((p for p in levels_below if p < target1 - min_target_gap), None)
        target2 = t2_candidate if t2_candidate else target1 * 0.97

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
            signal.runner_exit_price = exit_price
            signal.runner_pnl_pct = round(runner_pnl, 2)
            signal.outcome = "win" if total_pnl > 0 else "loss"
            signal.outcome_pct = round(total_pnl, 2)
        else:
            pnl = ((exit_price - entry_mid) / entry_mid * 100) if is_buy else ((entry_mid - exit_price) / entry_mid * 100)
            # Consider-profit zone: if price is 60%+ towards T1, count as partial win
            progress = (exit_price - entry_mid) / (t1 - entry_mid) if is_buy and t1 != entry_mid else (entry_mid - exit_price) / (entry_mid - t1) if not is_buy and t1 != entry_mid else 0
            if progress >= 0.6:
                signal.outcome = "win"
            else:
                signal.outcome = "loss"
            signal.outcome_pct = round(pnl, 2)
        signal.status = "closed"
        signal.closed_at = candle_time
        signal.duration_hours = duration
        return

    if is_buy:
        if not t1_already_hit:
            if candle.low <= sl:
                # Consider-profit zone check
                progress = (candle.high - entry_mid) / (t1 - entry_mid) if t1 != entry_mid else 0
                if signal.best_price > entry_mid:
                    progress = max(progress, (signal.best_price - entry_mid) / (t1 - entry_mid) if t1 != entry_mid else 0)
                if progress >= 0.6:
                    exit_price = entry_mid + (t1 - entry_mid) * 0.6
                    pnl = ((exit_price - entry_mid) / entry_mid) * 100
                    signal.outcome = "win"
                else:
                    pnl = ((sl - entry_mid) / entry_mid) * 100
                    signal.outcome = "loss"
                signal.outcome_pct = round(pnl, 2)
                signal.status = "closed"
                signal.closed_at = candle_time
                signal.duration_hours = duration
                return
            signal.best_price = max(signal.best_price, candle.high)
            if candle.high >= t1:
                t1_pnl = ((t1 - entry_mid) / entry_mid) * 100
                signal.t1_hit_at = candle_time
                signal.t1_pnl_pct = round(t1_pnl, 2)
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
                signal.runner_exit_price = runner_stop
                signal.runner_pnl_pct = round(runner_pnl, 2)
                signal.outcome = "win" if total_pnl > 0 else "loss"
                signal.outcome_pct = round(total_pnl, 2)
                signal.status = "closed"
                signal.closed_at = candle_time
                signal.duration_hours = duration
    else:
        if not t1_already_hit:
            if candle.high >= sl:
                progress = (entry_mid - candle.low) / (entry_mid - t1) if t1 != entry_mid else 0
                if signal.best_price < entry_mid and signal.best_price > 0:
                    progress = max(progress, (entry_mid - signal.best_price) / (entry_mid - t1) if t1 != entry_mid else 0)
                if progress >= 0.6:
                    exit_price = entry_mid - (entry_mid - t1) * 0.6
                    pnl = ((entry_mid - exit_price) / entry_mid) * 100
                    signal.outcome = "win"
                else:
                    pnl = ((entry_mid - sl) / entry_mid) * 100
                    signal.outcome = "loss"
                signal.outcome_pct = round(pnl, 2)
                signal.status = "closed"
                signal.closed_at = candle_time
                signal.duration_hours = duration
                return
            signal.best_price = min(signal.best_price, candle.low) if signal.best_price > 0 else candle.low
            if candle.low <= t1:
                t1_pnl = ((entry_mid - t1) / entry_mid) * 100
                signal.t1_hit_at = candle_time
                signal.t1_pnl_pct = round(t1_pnl, 2)
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
                signal.runner_exit_price = runner_stop
                signal.runner_pnl_pct = round(runner_pnl, 2)
                signal.outcome = "win" if total_pnl > 0 else "loss"
                signal.outcome_pct = round(total_pnl, 2)
                signal.status = "closed"
                signal.closed_at = candle_time
                signal.duration_hours = duration


# ─── Main Backtest ───────────────────────────────────────────────────────────

def run_backtest(candles: dict, all_candles_4h: list[Candle]) -> list[Signal]:
    """Run swing tier backtest with FVG tracking."""
    iter_candles = candles["4h"]
    warmup = WARMUP_CANDLES_4H
    eval_interval = 3

    if len(iter_candles) < warmup:
        return []

    signals: list[Signal] = []

    for i in range(warmup, len(iter_candles)):
        candle = iter_candles[i]
        eval_time = candle.open_time
        current_price = candle.close

        # Resolve open signals on every candle
        for sig in signals:
            if sig.status == "triggered":
                resolve_signal(sig, candle, eval_time)

        if i % eval_interval != 0:
            continue

        # Build swing histories
        all_fibs = []
        for tf in ["4h", "1d"]:
            tf_candles = candles.get(tf, [])
            history = [c for c in tf_candles if c.open_time <= eval_time]
            limit = 250 if tf == "4h" else 120
            swings = detect_swings(history[-limit:], tf)
            fibs = compute_fibs(swings, tf)
            all_fibs.extend(fibs)

        if not all_fibs:
            continue

        zones = cluster_levels(all_fibs, current_price, CONFLUENCE_TOLERANCE_PCT)
        all_fib_prices = [f.price for f in all_fibs]

        trend_candles = [c for c in all_candles_4h if c.open_time <= eval_time]
        daily_candles = [c for c in candles.get("1d", []) if c.open_time <= eval_time]

        # Detect FVGs once per evaluation point
        fvgs = detect_fvgs(candles, eval_time)

        # Get bounce candles (try 1H first, fall back to 4H — matches live pipeline)
        bounce_candles_1h = [c for c in candles.get("1h", []) if c.open_time <= eval_time]
        bounce_candles_4h = [c for c in candles.get("4h", []) if c.open_time <= eval_time]

        for zone in zones:
            dist_pct = abs((current_price - zone.mid) / current_price) * 100
            if dist_pct > SIGNAL_PROXIMITY_PCT:
                continue

            # Dedup
            duplicate = False
            for s in signals:
                if s.status == "triggered" and abs(s.entry_mid - zone.mid) / zone.mid < 0.005:
                    duplicate = True
                    break
            if duplicate:
                continue

            is_buy = zone.zone_type == "support"

            if not check_trend_alignment(trend_candles, is_buy):
                continue

            if not check_daily_trend_guard(daily_candles, is_buy):
                continue

            if not check_momentum_filter(daily_candles, is_buy):
                continue

            # Bounce confirmation (try 1H first, then 4H)
            bounce = check_bounce(bounce_candles_1h[-25:], zone.low, zone.high, is_buy)
            if not bounce["confirmed"]:
                bounce = check_bounce(bounce_candles_4h[-25:], zone.low, zone.high, is_buy)
            if not bounce["confirmed"]:
                continue

            result = compute_targets_and_stop(zone, all_fib_prices, is_buy)
            if result is None:
                continue
            t1, t2, sl = result

            entry_mid = current_price
            risk_dist = abs(entry_mid - sl)
            reward_dist = abs(t1 - entry_mid)
            rr = reward_dist / risk_dist if risk_dist > 0 else 0

            if rr < MIN_RR_RATIO:
                continue

            # FVG confluence
            fvg_result = check_fvg_confluence(zone, fvgs, is_buy)

            # Volume confluence
            vol_confluence = compute_volume_confluence(zone, trend_candles[-250:])

            # Composite score
            score = compute_composite_score(zone, trend_candles, bounce, vol_confluence, fvg_result, is_buy, rr)

            if score < MIN_SCORE:
                continue

            is_strong = rr >= STRONG_MIN_RR_RATIO and zone.strength >= STRONG_MIN_CONFLUENCE
            if is_buy:
                sig_type = "strong_buy" if is_strong else "buy"
            else:
                sig_type = "strong_sell" if is_strong else "sell"

            signal = Signal(
                entry_time=eval_time,
                signal_type=sig_type,
                entry_mid=entry_mid,
                entry_low=zone.low,
                entry_high=zone.high,
                target1=t1,
                target2=t2,
                stop_loss=sl,
                risk_1r=risk_dist,
                rr_ratio=round(rr, 2),
                confluence_strength=zone.strength,
                composite_score=score,
                has_fvg=fvg_result["has_fvg"],
                fvg_timeframe=fvg_result["best_tf"],
                fvg_bonus=fvg_result["bonus"],
                expires_at=eval_time + timedelta(hours=SIGNAL_EXPIRY_HOURS),
                best_price=entry_mid,
                runner_stop=sl,
            )
            signal.ticker = ""  # Set by caller
            signals.append(signal)

    return signals


# ─── Analysis ────────────────────────────────────────────────────────────────

def analyze_group(label: str, signals: list[Signal]) -> dict:
    closed = [s for s in signals if s.status == "closed"]
    if not closed:
        return {"label": label, "count": 0}

    wins = [s for s in closed if s.outcome == "win"]
    losses = [s for s in closed if s.outcome == "loss"]
    gross_profit = sum(s.outcome_pct for s in closed if s.outcome_pct > 0)
    gross_loss = abs(sum(s.outcome_pct for s in closed if s.outcome_pct < 0))

    return {
        "label": label,
        "count": len(closed),
        "wins": len(wins),
        "losses": len(losses),
        "win_rate": len(wins) / len(closed) * 100,
        "total_pnl": sum(s.outcome_pct for s in closed),
        "avg_pnl": sum(s.outcome_pct for s in closed) / len(closed),
        "profit_factor": gross_profit / gross_loss if gross_loss > 0 else float("inf"),
        "avg_win": sum(s.outcome_pct for s in wins) / len(wins) if wins else 0,
        "avg_loss": sum(s.outcome_pct for s in losses) / len(losses) if losses else 0,
        "avg_score": sum(s.composite_score for s in closed) / len(closed),
    }


def print_group(g: dict):
    if g["count"] == 0:
        print(f"  {g['label']}: No signals")
        return
    print(f"  {g['label']:.<40} {g['count']:>4} sigs │ {g['win_rate']:>5.1f}% WR │ {g['profit_factor']:>5.2f} PF │ "
          f"{g['total_pnl']:>+7.2f}% P&L │ avg {g['avg_pnl']:>+5.2f}% │ W:{g['avg_win']:>+5.2f}% L:{g['avg_loss']:>+5.2f}% │ score {g['avg_score']:>4.1f}")


def main():
    print("=" * 120)
    print("FAIR VALUE GAP IMPACT ANALYSIS — Fibonacci Golden Pocket Strategy")
    print("=" * 120)
    print(f"Period: ~{BACKTEST_DAYS} days | Assets: {len(ASSETS)} | FVG scoring: 1D +8, 4H +6, 1H +4, wide gap +2")
    print(f"FVG is a score ENHANCER — all signals generate regardless, we compare FVG vs non-FVG performance\n")

    all_signals: list[Signal] = []

    for asset in ASSETS:
        ticker = asset["ticker"]
        pair = asset["pair"]
        print(f"  Fetching {ticker}...")

        candles = {}
        for config in TIMEFRAME_CONFIGS:
            tf = config["tf"]
            candles[tf] = fetch_candles(pair, config["granularity"], config["seconds"], config["limit"])
            print(f"    {tf}: {len(candles[tf])} candles")
            time.sleep(0.3)

        if len(candles.get("4h", [])) < WARMUP_CANDLES_4H:
            print(f"    Not enough data for {ticker}")
            continue

        signals = run_backtest(candles, candles["4h"])
        for s in signals:
            s.ticker = ticker
        closed = [s for s in signals if s.status == "closed"]
        fvg_count = sum(1 for s in closed if s.has_fvg)
        print(f"    → {len(closed)} closed signals ({fvg_count} with FVG confluence)")
        all_signals.extend(signals)
        time.sleep(1)

    # ─── Results ─────────────────────────────────────────────────────────────

    closed = [s for s in all_signals if s.status == "closed"]
    with_fvg = [s for s in closed if s.has_fvg]
    without_fvg = [s for s in closed if not s.has_fvg]

    print(f"\n\n{'=' * 120}")
    print("OVERALL RESULTS")
    print(f"{'=' * 120}")

    all_group = analyze_group("All Signals", closed)
    fvg_group = analyze_group("WITH FVG Confluence", with_fvg)
    no_fvg_group = analyze_group("WITHOUT FVG Confluence", without_fvg)

    print_group(all_group)
    print_group(fvg_group)
    print_group(no_fvg_group)

    if fvg_group["count"] > 0 and no_fvg_group["count"] > 0:
        print(f"\n  FVG Edge:")
        wr_delta = fvg_group["win_rate"] - no_fvg_group["win_rate"]
        pf_delta = fvg_group["profit_factor"] - no_fvg_group["profit_factor"]
        pnl_delta = fvg_group["avg_pnl"] - no_fvg_group["avg_pnl"]
        print(f"    Win Rate:      {wr_delta:>+5.1f}%  ({'FVG better' if wr_delta > 0 else 'no FVG better'})")
        print(f"    Profit Factor: {pf_delta:>+5.2f}   ({'FVG better' if pf_delta > 0 else 'no FVG better'})")
        print(f"    Avg P&L/trade: {pnl_delta:>+5.2f}%  ({'FVG better' if pnl_delta > 0 else 'no FVG better'})")

    # ─── By Direction ────────────────────────────────────────────────────────

    print(f"\n{'=' * 120}")
    print("BY DIRECTION")
    print(f"{'=' * 120}")

    longs_fvg = [s for s in with_fvg if s.is_buy]
    longs_no = [s for s in without_fvg if s.is_buy]
    shorts_fvg = [s for s in with_fvg if not s.is_buy]
    shorts_no = [s for s in without_fvg if not s.is_buy]

    print_group(analyze_group("Longs WITH FVG", longs_fvg))
    print_group(analyze_group("Longs WITHOUT FVG", longs_no))
    print_group(analyze_group("Shorts WITH FVG", shorts_fvg))
    print_group(analyze_group("Shorts WITHOUT FVG", shorts_no))

    # ─── By FVG Timeframe ────────────────────────────────────────────────────

    print(f"\n{'=' * 120}")
    print("BY FVG TIMEFRAME")
    print(f"{'=' * 120}")

    for tf in ["1d", "4h", "1h"]:
        tf_signals = [s for s in with_fvg if s.fvg_timeframe == tf]
        print_group(analyze_group(f"FVG on {tf}", tf_signals))

    # ─── Per Asset Breakdown ─────────────────────────────────────────────────

    print(f"\n{'=' * 120}")
    print("PER ASSET — FVG vs NO FVG")
    print(f"{'=' * 120}")

    header = f"{'Asset':<7} │ {'All':>4} {'FVG':>4} {'noFVG':>5} │ {'FVG WR':>7} {'noFVG WR':>9} {'Δ WR':>6} │ {'FVG PF':>7} {'noFVG PF':>9} │ {'FVG P&L':>8} {'noFVG P&L':>10}"
    print(header)
    print("─" * 110)

    for asset in ASSETS:
        ticker = asset["ticker"]
        asset_closed = [s for s in closed if s.ticker == ticker]
        asset_fvg = [s for s in asset_closed if s.has_fvg]
        asset_no_fvg = [s for s in asset_closed if not s.has_fvg]

        fvg_wr = (sum(1 for s in asset_fvg if s.outcome == "win") / len(asset_fvg) * 100) if asset_fvg else 0
        no_fvg_wr = (sum(1 for s in asset_no_fvg if s.outcome == "win") / len(asset_no_fvg) * 100) if asset_no_fvg else 0
        delta_wr = fvg_wr - no_fvg_wr if asset_fvg and asset_no_fvg else 0

        fvg_gp = sum(s.outcome_pct for s in asset_fvg if s.outcome_pct > 0)
        fvg_gl = abs(sum(s.outcome_pct for s in asset_fvg if s.outcome_pct < 0))
        fvg_pf = fvg_gp / fvg_gl if fvg_gl > 0 else (float("inf") if fvg_gp > 0 else 0)

        no_fvg_gp = sum(s.outcome_pct for s in asset_no_fvg if s.outcome_pct > 0)
        no_fvg_gl = abs(sum(s.outcome_pct for s in asset_no_fvg if s.outcome_pct < 0))
        no_fvg_pf = no_fvg_gp / no_fvg_gl if no_fvg_gl > 0 else (float("inf") if no_fvg_gp > 0 else 0)

        fvg_pnl = sum(s.outcome_pct for s in asset_fvg)
        no_fvg_pnl = sum(s.outcome_pct for s in asset_no_fvg)

        print(f"{ticker:<7} │ {len(asset_closed):>4} {len(asset_fvg):>4} {len(asset_no_fvg):>5} │ "
              f"{fvg_wr:>6.1f}% {no_fvg_wr:>8.1f}% {delta_wr:>+5.1f}% │ "
              f"{fvg_pf:>6.2f} {no_fvg_pf:>8.2f} │ "
              f"{fvg_pnl:>+7.2f}% {no_fvg_pnl:>+9.2f}%")

    # ─── Score Distribution ──────────────────────────────────────────────────

    print(f"\n{'=' * 120}")
    print("SCORE DISTRIBUTION — FVG IMPACT")
    print(f"{'=' * 120}")

    # Show how many signals got bumped above score threshold by FVG
    fvg_signals_near_threshold = [s for s in with_fvg if s.composite_score - s.fvg_bonus < MIN_SCORE]
    print(f"  Signals that ONLY passed threshold because of FVG bonus: {len(fvg_signals_near_threshold)}")
    if fvg_signals_near_threshold:
        fvg_near_group = analyze_group("FVG-enabled (would have been filtered)", fvg_signals_near_threshold)
        print_group(fvg_near_group)

    # Score buckets
    print(f"\n  Score Buckets (FVG signals):")
    for lo, hi, label in [(90, 101, "A+ (90-100)"), (80, 90, "A  (80-89)"), (70, 80, "B+ (70-79)"), (60, 70, "B  (60-69)")]:
        bucket = [s for s in with_fvg if lo <= s.composite_score < hi]
        if bucket:
            g = analyze_group(f"  {label}", bucket)
            print_group(g)

    print(f"\n  Score Buckets (non-FVG signals):")
    for lo, hi, label in [(90, 101, "A+ (90-100)"), (80, 90, "A  (80-89)"), (70, 80, "B+ (70-79)"), (60, 70, "B  (60-69)")]:
        bucket = [s for s in without_fvg if lo <= s.composite_score < hi]
        if bucket:
            g = analyze_group(f"  {label}", bucket)
            print_group(g)

    print(f"\n{'=' * 120}")
    print("CONCLUSION")
    print(f"{'=' * 120}")
    fvg_pct = len(with_fvg) / len(closed) * 100 if closed else 0
    print(f"  {len(with_fvg)}/{len(closed)} signals ({fvg_pct:.1f}%) had FVG confluence")
    if fvg_group["count"] > 0 and no_fvg_group["count"] > 0:
        if fvg_group["profit_factor"] > no_fvg_group["profit_factor"] and fvg_group["win_rate"] > no_fvg_group["win_rate"]:
            print(f"  ✓ FVG confluence signals outperform on both WR and PF — validates the enhancer")
        elif fvg_group["profit_factor"] > no_fvg_group["profit_factor"]:
            print(f"  ~ FVG signals have better PF but lower WR — bigger wins when they hit")
        elif fvg_group["win_rate"] > no_fvg_group["win_rate"]:
            print(f"  ~ FVG signals have better WR but lower PF — more consistent but smaller edge")
        else:
            print(f"  ✗ FVG confluence did not improve performance — consider removing or adjusting thresholds")
    print()


if __name__ == "__main__":
    main()
