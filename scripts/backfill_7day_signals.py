#!/usr/bin/env python3
"""
Backfill 7 days of trade signals using 24/7 (all 4H candle closes).
Outputs SQL statements to run in Supabase Dashboard SQL Editor.

This replaces existing signals from the past 7 days with signals
generated from all six 4H candle closes (not just US session).
"""

import json
import time
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Optional

# ─── Configuration (matches live pipeline) ────────────────────────────────

ASSETS = {
    "BTCUSDT": "BTC",
    "ETHUSDT": "ETH",
    "SOLUSDT": "SOL",
    "SUIUSDT": "SUI",
    "LINKUSDT": "LINK",
    "ADAUSDT": "ADA",
}

SWING_PARAMS = {
    "4h": {"lookback": 8, "min_reversal": 5.0},
    "1d": {"lookback": 5, "min_reversal": 8.0},
}

FIB_RATIOS = [0.618, 0.786]  # Golden pocket only (matches live pipeline)

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

BMSB_SMA_PERIOD = 140  # 20 weeks * 7
BMSB_EMA_PERIOD = 147  # 21 weeks * 7

BACKFILL_DAYS = 7
ALL_SESSION_HOURS = {0, 4, 8, 12, 16, 20}


# ─── Data Structures ──────────────────────────────────────────────────────

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
    direction: str

@dataclass
class Signal:
    asset: str
    signal_type: str
    entry_time: datetime
    entry_mid: float
    entry_low: float
    entry_high: float
    target1: float
    target2: float
    stop_loss: float
    rr_ratio: float
    risk_1r: float
    confluence_strength: int
    expires_at: datetime
    counter_trend: bool = False
    ema_trend_aligned: bool = True
    bounce_details: dict = field(default_factory=dict)
    # Resolution fields
    status: str = "triggered"
    outcome: Optional[str] = None
    outcome_pct: float = 0.0
    best_price: float = 0.0
    runner_stop: float = 0.0
    t1_hit_at: Optional[datetime] = None
    t1_pnl_pct: float = 0.0
    runner_exit_price: float = 0.0
    runner_pnl_pct: float = 0.0
    closed_at: Optional[datetime] = None
    duration_hours: int = 0


# ─── Fetch Data ───────────────────────────────────────────────────────────

def fetch_binance_klines(symbol: str, interval: str, limit: int) -> list[Candle]:
    url = f"https://api.binance.us/api/v3/klines?symbol={symbol}&interval={interval}&limit={limit}"
    try:
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        print(f"  Error fetching {symbol} {interval}: {e}")
        return []

    return [Candle(
        open_time=datetime.fromtimestamp(k[0] / 1000, tz=timezone.utc),
        open=float(k[1]), high=float(k[2]), low=float(k[3]),
        close=float(k[4]), volume=float(k[5]),
    ) for k in data]


def fetch_all_data() -> dict[str, dict[str, list[Candle]]]:
    all_data = {}
    for symbol, ticker in ASSETS.items():
        all_data[ticker] = {}
        print(f"  Fetching {ticker}...", end="", flush=True)
        # 4h: 250 candles (~42 days)
        all_data[ticker]["4h"] = fetch_binance_klines(symbol, "4h", 250)
        time.sleep(0.3)
        # 1d: 200 candles (~200 days, need 147+ for BMSB)
        all_data[ticker]["1d"] = fetch_binance_klines(symbol, "1d", 200)
        time.sleep(0.3)
        print(f" {len(all_data[ticker]['4h'])} 4h, {len(all_data[ticker]['1d'])} 1d candles")
    return all_data


# ─── Swing Detection (matches pipeline exactly) ──────────────────────────

def detect_swings(candles: list[Candle], tf: str) -> list[SwingPoint]:
    params = SWING_PARAMS[tf]
    lookback = params["lookback"]
    min_reversal = params["min_reversal"]
    swings = []

    if len(candles) < lookback * 2 + 1:
        return swings

    for i in range(lookback, len(candles) - lookback):
        c = candles[i]

        # Swing high
        is_high = all(candles[j].high < c.high for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_high:
            surrounding_lows = [candles[j].low for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_lows:
                min_low = min(surrounding_lows)
                reversal_pct = ((c.high - min_low) / min_low) * 100
                if reversal_pct >= min_reversal:
                    swings.append(SwingPoint("high", c.high, c.open_time))

        # Swing low
        is_low = all(candles[j].low > c.low for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_low:
            surrounding_highs = [candles[j].high for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_highs:
                max_high = max(surrounding_highs)
                reversal_pct = ((max_high - c.low) / c.low) * 100
                if reversal_pct >= min_reversal:
                    swings.append(SwingPoint("low", c.low, c.open_time))

    return swings


# ─── Fibonacci Levels ─────────────────────────────────────────────────────

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


# ─── Confluence Clustering ────────────────────────────────────────────────

def cluster_levels(fibs: list[FibLevel], current_price: float) -> list[dict]:
    if not fibs:
        return []

    nearby = sorted(
        [f for f in fibs if abs((f.price - current_price) / current_price) * 100 <= 15],
        key=lambda f: f.price
    )
    if not nearby:
        return []

    clusters = []
    current_cluster = [nearby[0]]
    cl_low = nearby[0].price
    cl_high = nearby[0].price

    for i in range(1, len(nearby)):
        level = nearby[i]
        cl_mid = (cl_low + cl_high) / 2
        dist_pct = abs((level.price - cl_mid) / cl_mid) * 100

        if dist_pct <= CONFLUENCE_TOLERANCE_PCT:
            current_cluster.append(level)
            cl_high = max(cl_high, level.price)
            cl_low = min(cl_low, level.price)
        else:
            if len(current_cluster) >= 2:
                mid = (cl_low + cl_high) / 2
                tfs = set(l.timeframe for l in current_cluster)
                clusters.append({
                    "low": cl_low, "high": cl_high, "mid": mid,
                    "strength": len(current_cluster),
                    "zone_type": "support" if mid < current_price else "resistance",
                    "tf_count": len(tfs),
                })
            current_cluster = [level]
            cl_low = level.price
            cl_high = level.price

    if len(current_cluster) >= 2:
        mid = (cl_low + cl_high) / 2
        tfs = set(l.timeframe for l in current_cluster)
        clusters.append({
            "low": cl_low, "high": cl_high, "mid": mid,
            "strength": len(current_cluster),
            "zone_type": "support" if mid < current_price else "resistance",
            "tf_count": len(tfs),
        })

    return clusters


# ─── EMA / BMSB ──────────────────────────────────────────────────────────

def calc_ema(candles: list[Candle], period: int) -> Optional[float]:
    if len(candles) < period:
        return None
    multiplier = 2 / (period + 1)
    ema = sum(c.close for c in candles[:period]) / period
    for c in candles[period:]:
        ema = (c.close - ema) * multiplier + ema
    return ema


def calc_sma(candles: list[Candle], period: int) -> Optional[float]:
    if len(candles) < period:
        return None
    return sum(c.close for c in candles[-period:]) / period


def check_trend(candles_4h: list[Candle], is_buy: bool) -> bool:
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
        pullback_ok = ema_slow > ema_slow_prev and abs(price - ema_slow) / ema_slow < EMA_PULLBACK_TOLERANCE
        return trend_ok or pullback_ok
    else:
        trend_ok = ema_fast < ema_slow
        pullback_ok = ema_slow < ema_slow_prev and abs(price - ema_slow) / ema_slow < EMA_PULLBACK_TOLERANCE
        return trend_ok or pullback_ok


def check_bmsb(daily_candles: list[Candle], current_price: float, is_buy: bool) -> bool:
    if len(daily_candles) < BMSB_EMA_PERIOD:
        return False
    sma = calc_sma(daily_candles, BMSB_SMA_PERIOD)
    ema = calc_ema(daily_candles, BMSB_EMA_PERIOD)
    if sma is None or ema is None:
        return False

    band_top = max(sma, ema)
    band_bottom = min(sma, ema)

    if current_price > band_top:
        return not is_buy  # Shorts are counter-trend
    elif current_price < band_bottom:
        return is_buy  # Longs are counter-trend
    return False


# ─── Bounce Confirmation ─────────────────────────────────────────────────

def check_bounce(candles: list[Candle], zone_low: float, zone_high: float, is_buy: bool) -> tuple[bool, dict]:
    details = {"wick_rejection": False, "volume_spike": False, "consecutive_closes": False}
    if len(candles) < 3:
        return False, details

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
    return confirmed, details


# ─── Targets & Stop ──────────────────────────────────────────────────────

def compute_targets_and_stop(zone: dict, all_fib_prices: list[float], is_buy: bool):
    sorted_prices = sorted(all_fib_prices)
    zone_mid = zone["mid"]

    if is_buy:
        levels_below = [p for p in sorted_prices if p < zone["low"]]
        next_down = levels_below[-1] if levels_below else None
        stop_loss = next_down * 0.997 if next_down else zone_mid * 0.985

        levels_above = [p for p in sorted_prices if p > zone["high"]]
        target1 = levels_above[0] if levels_above else zone_mid * 1.03
        target2 = levels_above[1] if len(levels_above) > 1 else target1 * 1.015
    else:
        levels_above = [p for p in sorted_prices if p > zone["high"]]
        next_up = levels_above[0] if levels_above else None
        stop_loss = next_up * 1.003 if next_up else zone_mid * 1.015

        levels_below = [p for p in sorted_prices if p < zone["low"]]
        target1 = levels_below[-1] if levels_below else zone_mid * 0.97
        target2 = levels_below[-2] if len(levels_below) > 1 else target1 * 0.985

    return target1, target2, stop_loss


# ─── Signal Generation & Resolution ──────────────────────────────────────

def generate_and_resolve_signals(all_data: dict) -> list[Signal]:
    signals: list[Signal] = []
    now = datetime.now(tz=timezone.utc)
    start_date = now - timedelta(days=BACKFILL_DAYS)

    for ticker in ASSETS.values():
        candles_4h = all_data[ticker].get("4h", [])
        candles_1d = all_data[ticker].get("1d", [])

        if len(candles_4h) < EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK:
            continue

        # Walk through 4H candles
        for idx in range(EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK, len(candles_4h)):
            eval_candle = candles_4h[idx]
            close_time = eval_candle.open_time + timedelta(hours=4)
            close_hour = close_time.hour

            if close_time < start_date:
                continue
            if close_time > now:
                break
            if close_hour not in ALL_SESSION_HOURS:
                continue

            current_price = eval_candle.close
            history_4h = candles_4h[:idx + 1]
            history_1d = [c for c in candles_1d if c.open_time <= eval_candle.open_time]

            # First resolve existing open signals
            resolve_signals(signals, ticker, eval_candle, close_time)

            # Detect swings and compute fibs for both timeframes
            all_fibs = []
            for tf, history in [("4h", history_4h), ("1d", history_1d)]:
                if len(history) < SWING_PARAMS[tf]["lookback"] * 2 + 1:
                    continue
                swings = detect_swings(history, tf)
                fibs = compute_fibs(swings, tf)
                all_fibs.extend(fibs)

            if not all_fibs:
                continue

            zones = cluster_levels(all_fibs, current_price)
            all_fib_prices = [f.price for f in all_fibs]

            for zone in zones:
                dist_pct = abs((current_price - zone["mid"]) / current_price) * 100
                if dist_pct > SIGNAL_PROXIMITY_PCT:
                    continue

                # Check for duplicate
                duplicate = False
                for s in signals:
                    if s.asset == ticker and s.status == "triggered":
                        if abs(s.entry_mid - zone["mid"]) / zone["mid"] < 0.005:
                            duplicate = True
                            break
                if duplicate:
                    continue

                is_buy = zone["zone_type"] == "support"

                if not check_trend(history_4h, is_buy):
                    continue

                bounce_ok, bounce_details = check_bounce(history_4h[-25:], zone["low"], zone["high"], is_buy)
                if not bounce_ok:
                    continue

                t1, t2, sl = compute_targets_and_stop(zone, all_fib_prices, is_buy)
                entry_mid = zone["mid"]
                risk_dist = abs(entry_mid - sl)
                reward_dist = abs(t1 - entry_mid)
                rr = reward_dist / risk_dist if risk_dist > 0 else 0

                if rr < MIN_RR_RATIO:
                    continue

                is_strong = rr >= STRONG_MIN_RR_RATIO and zone["strength"] >= STRONG_MIN_CONFLUENCE
                if is_buy:
                    sig_type = "strong_buy" if is_strong else "buy"
                else:
                    sig_type = "strong_sell" if is_strong else "sell"

                counter_trend = check_bmsb(history_1d, current_price, is_buy)

                signal = Signal(
                    asset=ticker, signal_type=sig_type, entry_time=close_time,
                    entry_mid=entry_mid, entry_low=zone["low"], entry_high=zone["high"],
                    target1=t1, target2=t2, stop_loss=sl,
                    rr_ratio=round(rr, 2), risk_1r=risk_dist,
                    confluence_strength=zone["strength"],
                    expires_at=close_time + timedelta(hours=SIGNAL_EXPIRY_HOURS),
                    counter_trend=counter_trend,
                    ema_trend_aligned=True,
                    bounce_details=bounce_details,
                    best_price=entry_mid,
                    runner_stop=sl,
                )
                signals.append(signal)

    # Final resolve pass
    now = datetime.now(tz=timezone.utc)
    for s in signals:
        if s.status == "triggered":
            s.status = "expired"
            s.outcome = "loss"
            s.outcome_pct = 0
            s.closed_at = s.expires_at
            s.duration_hours = int((s.expires_at - s.entry_time).total_seconds() / 3600)

    return signals


def resolve_signals(signals: list[Signal], ticker: str, candle: Candle, eval_time: datetime):
    for s in signals:
        if s.status != "triggered" or s.asset != ticker:
            continue

        is_buy = s.signal_type in ("buy", "strong_buy")
        entry_mid = s.entry_mid
        risk_1r = s.risk_1r

        # Expiry
        if eval_time >= s.expires_at:
            exit_price = candle.close
            if s.t1_hit_at:
                runner_pnl = ((exit_price - entry_mid) / entry_mid * 100) if is_buy else ((entry_mid - exit_price) / entry_mid * 100)
                total_pnl = (s.t1_pnl_pct + runner_pnl) / 2
                s.status = "target_hit" if total_pnl > 0 else "expired"
                s.outcome = "win" if total_pnl > 0 else "loss"
                s.outcome_pct = round(total_pnl, 2)
                s.runner_exit_price = exit_price
                s.runner_pnl_pct = round(runner_pnl, 2)
            else:
                pnl = ((exit_price - entry_mid) / entry_mid * 100) if is_buy else ((entry_mid - exit_price) / entry_mid * 100)
                s.status = "expired"
                s.outcome = "loss"
                s.outcome_pct = round(pnl, 2)
            s.closed_at = eval_time
            s.duration_hours = int((eval_time - s.entry_time).total_seconds() / 3600)
            continue

        if is_buy:
            if not s.t1_hit_at:
                # Check SL
                if candle.low <= s.stop_loss:
                    pnl = ((s.stop_loss - entry_mid) / entry_mid) * 100
                    s.status = "invalidated"
                    s.outcome = "loss"
                    s.outcome_pct = round(pnl, 2)
                    s.closed_at = eval_time
                    s.duration_hours = int((eval_time - s.entry_time).total_seconds() / 3600)
                    continue
                # Check T1
                if candle.high >= s.target1:
                    s.t1_hit_at = eval_time
                    s.t1_pnl_pct = round(((s.target1 - entry_mid) / entry_mid) * 100, 2)
                    s.best_price = candle.high
                    s.runner_stop = entry_mid  # Breakeven
            else:
                # Runner phase
                s.best_price = max(s.best_price, candle.high)
                s.runner_stop = max(s.runner_stop, s.best_price - risk_1r)

                if candle.low <= s.runner_stop:
                    runner_pnl = ((s.runner_stop - entry_mid) / entry_mid) * 100
                    total_pnl = (s.t1_pnl_pct + runner_pnl) / 2
                    s.status = "target_hit" if total_pnl > 0 else "invalidated"
                    s.outcome = "win" if total_pnl > 0 else "loss"
                    s.outcome_pct = round(total_pnl, 2)
                    s.runner_exit_price = s.runner_stop
                    s.runner_pnl_pct = round(runner_pnl, 2)
                    s.closed_at = eval_time
                    s.duration_hours = int((eval_time - s.entry_time).total_seconds() / 3600)
                else:
                    s.best_price = max(s.best_price, candle.high)
                    s.runner_stop = max(s.runner_stop, s.best_price - risk_1r)
        else:
            # SHORT
            if not s.t1_hit_at:
                if candle.high >= s.stop_loss:
                    pnl = ((entry_mid - s.stop_loss) / entry_mid) * 100
                    s.status = "invalidated"
                    s.outcome = "loss"
                    s.outcome_pct = round(pnl, 2)
                    s.closed_at = eval_time
                    s.duration_hours = int((eval_time - s.entry_time).total_seconds() / 3600)
                    continue
                if candle.low <= s.target1:
                    s.t1_hit_at = eval_time
                    s.t1_pnl_pct = round(((entry_mid - s.target1) / entry_mid) * 100, 2)
                    s.best_price = candle.low
                    s.runner_stop = entry_mid
            else:
                s.best_price = min(s.best_price, candle.low)
                s.runner_stop = min(s.runner_stop, s.best_price + risk_1r)

                if candle.high >= s.runner_stop:
                    runner_pnl = ((entry_mid - s.runner_stop) / entry_mid) * 100
                    total_pnl = (s.t1_pnl_pct + runner_pnl) / 2
                    s.status = "target_hit" if total_pnl > 0 else "invalidated"
                    s.outcome = "win" if total_pnl > 0 else "loss"
                    s.outcome_pct = round(total_pnl, 2)
                    s.runner_exit_price = s.runner_stop
                    s.runner_pnl_pct = round(runner_pnl, 2)
                    s.closed_at = eval_time
                    s.duration_hours = int((eval_time - s.entry_time).total_seconds() / 3600)
                else:
                    s.best_price = min(s.best_price, candle.low)
                    s.runner_stop = min(s.runner_stop, s.best_price + risk_1r)


# ─── SQL Output ───────────────────────────────────────────────────────────

def escape_sql(s: str) -> str:
    return s.replace("'", "''")


def format_price(p: float) -> str:
    if p > 1000:
        return f"{p:.2f}"
    elif p > 1:
        return f"{p:.4f}"
    else:
        return f"{p:.6f}"


def generate_sql(signals: list[Signal]) -> str:
    now = datetime.now(tz=timezone.utc)
    cutoff = now - timedelta(days=BACKFILL_DAYS)

    lines = []
    lines.append("-- ═══════════════════════════════════════════════════════════════════")
    lines.append("-- BACKFILL: 7-day signals with 24/7 coverage (all 4H candle closes)")
    lines.append(f"-- Generated: {now.strftime('%Y-%m-%d %H:%M:%S UTC')}")
    lines.append(f"-- Signals: {len(signals)}")
    lines.append("-- ═══════════════════════════════════════════════════════════════════")
    lines.append("")
    lines.append("-- Step 1: Remove existing signals from the past 7 days")
    lines.append(f"DELETE FROM trade_signals WHERE triggered_at >= '{cutoff.strftime('%Y-%m-%dT%H:%M:%S+00:00')}';")
    lines.append("")
    lines.append("-- Step 2: Insert backfilled signals")

    for s in signals:
        t1_hit_at = f"'{s.t1_hit_at.strftime('%Y-%m-%dT%H:%M:%S+00:00')}'" if s.t1_hit_at else "NULL"
        closed_at = f"'{s.closed_at.strftime('%Y-%m-%dT%H:%M:%S+00:00')}'" if s.closed_at else "NULL"
        outcome = f"'{s.outcome}'" if s.outcome else "NULL"
        runner_exit = s.runner_exit_price if s.runner_exit_price else "NULL"
        bounce_json = json.dumps(s.bounce_details).replace("'", "''")

        lines.append(f"""INSERT INTO trade_signals (
  asset, signal_type, status, entry_zone_low, entry_zone_high, entry_price_mid,
  target_1, target_2, stop_loss, risk_reward_ratio, risk_1r,
  best_price, runner_stop, runner_exit_price,
  ema_trend_aligned, bounce_confirmed, confirmation_details, counter_trend,
  triggered_at, expires_at, closed_at, duration_hours,
  t1_hit_at, t1_pnl_pct, runner_pnl_pct,
  outcome, outcome_pct
) VALUES (
  '{s.asset}', '{s.signal_type}', '{s.status}', {format_price(s.entry_low)}, {format_price(s.entry_high)}, {format_price(s.entry_mid)},
  {format_price(s.target1)}, {format_price(s.target2)}, {format_price(s.stop_loss)}, {s.rr_ratio}, {format_price(s.risk_1r)},
  {format_price(s.best_price)}, {format_price(s.runner_stop)}, {runner_exit if isinstance(runner_exit, str) else format_price(runner_exit)},
  {str(s.ema_trend_aligned).lower()}, true, '{bounce_json}'::jsonb, {str(s.counter_trend).lower()},
  '{s.entry_time.strftime('%Y-%m-%dT%H:%M:%S+00:00')}', '{s.expires_at.strftime('%Y-%m-%dT%H:%M:%S+00:00')}', {closed_at}, {s.duration_hours},
  {t1_hit_at}, {s.t1_pnl_pct}, {s.runner_pnl_pct},
  {outcome}, {s.outcome_pct}
);""")

    return "\n".join(lines)


# ─── Main ─────────────────────────────────────────────────────────────────

def run():
    print("=" * 70)
    print("BACKFILL: 7-Day Signals with 24/7 Coverage")
    print("=" * 70)
    print(f"Assets: {', '.join(ASSETS.values())}")
    print(f"Period: Last {BACKFILL_DAYS} days | All 4H candle closes")
    print()

    print("Fetching data from Binance...")
    all_data = fetch_all_data()
    print()

    print("Generating signals...")
    signals = generate_and_resolve_signals(all_data)

    # Print summary
    wins = [s for s in signals if s.outcome == "win"]
    losses = [s for s in signals if s.outcome == "loss"]
    total_closed = len(wins) + len(losses)
    win_rate = len(wins) / total_closed * 100 if total_closed else 0
    total_pnl = sum(s.outcome_pct for s in signals)

    print(f"\n  Total signals: {len(signals)}")
    print(f"  Wins: {len(wins)} | Losses: {len(losses)}")
    print(f"  Win rate: {win_rate:.1f}%")
    print(f"  Total P&L: {total_pnl:+.2f}%")
    print()

    for s in signals:
        direction = "Long" if "buy" in s.signal_type else "Short"
        strength = "Strong " if "strong" in s.signal_type else ""
        status_icon = "✅" if s.outcome == "win" else "❌" if s.outcome == "loss" else "⏳"
        print(f"  {status_icon} {s.asset:<5} {strength}{direction:<12} Entry: ${format_price(s.entry_mid):>10} "
              f"R:R {s.rr_ratio:.1f}x  {s.outcome_pct:+.2f}%  [{s.status}]  "
              f"{s.entry_time.strftime('%m/%d %H:%M')} UTC")

    print()

    # Generate SQL
    sql = generate_sql(signals)
    sql_file = "/Users/matt/Arkline/scripts/backfill_7day_signals.sql"
    with open(sql_file, "w") as f:
        f.write(sql)
    print(f"SQL written to: {sql_file}")
    print("Run this in the Supabase Dashboard SQL Editor to backfill signals.")
    print()


if __name__ == "__main__":
    run()
