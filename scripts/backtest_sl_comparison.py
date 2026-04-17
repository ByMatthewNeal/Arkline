#!/usr/bin/env python3
"""
Backtest: Stop Loss Comparison — Current (Fib-based) vs ATR-Capped

Runs the same signal generation but resolves each signal TWICE:
  1. Current SL: next fib level beyond entry (no cap)
  2. ATR-capped SL: min(fib SL, entry ± 1.5 × ATR14)

Outputs side-by-side comparison so we can see the real impact.

Usage:
    python3 scripts/backtest_sl_comparison.py
"""

import copy
import json
import time
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

# ─── Assets (current pipeline assets) ────────────────────────────────────────

ASSETS = [
    {"pair": "BTC-USD",    "ticker": "BTC"},
    {"pair": "ETH-USD",    "ticker": "ETH"},
    {"pair": "SOL-USD",    "ticker": "SOL"},
    {"pair": "SUI-USD",    "ticker": "SUI"},
    {"pair": "LINK-USD",   "ticker": "LINK"},
    {"pair": "ADA-USD",    "ticker": "ADA"},
    {"pair": "AVAX-USD",   "ticker": "AVAX"},
    {"pair": "RENDER-USD", "ticker": "RENDER"},
    {"pair": "APT-USD",    "ticker": "APT"},
    {"pair": "HYPE-USD",   "ticker": "HYPE"},
]

# ─── Configuration (matches live pipeline) ────────────────────────────────────

TIMEFRAME_CONFIGS = [
    {"tf": "4h", "granularity": "FOUR_HOUR", "seconds": 14400, "limit": 2400},
    {"tf": "1d", "granularity": "ONE_DAY",   "seconds": 86400, "limit": 500},
]

SWING_PARAMS = {
    "4h": {"lookback": 8, "min_reversal": 5.0},
    "1d": {"lookback": 5, "min_reversal": 8.0},
}

FIB_RATIOS = [0.618, 0.786]
MIN_RR_RATIO = 0.75
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
WICK_REJECTION_RATIO = 1.2
VOLUME_SPIKE_RATIO = 1.15

EMA_FAST_PERIOD = 20
EMA_SLOW_PERIOD = 50
EMA_SLOPE_LOOKBACK = 6
EMA_PULLBACK_TOLERANCE = 0.015

BACKTEST_DAYS = 90
WARMUP_CANDLES_4H = 60

# ATR cap multipliers to test
ATR_MULTIPLIERS = [1.5, 2.0, 2.5]

EXPIRY_HOURS = 72


# ─── Data Structures ─────────────────────────────────────────────────────────

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
    sl_pct: float = 0.0       # SL distance as % from entry
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


@dataclass
class Results:
    label: str
    total: int = 0
    wins: int = 0
    losses: int = 0
    win_rate: float = 0.0
    avg_win: float = 0.0
    avg_loss: float = 0.0
    total_pnl: float = 0.0
    profit_factor: float = 0.0
    avg_sl_pct: float = 0.0
    max_sl_pct: float = 0.0
    signals_rejected: int = 0


# ─── Coinbase API ─────────────────────────────────────────────────────────────

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


# ─── ATR Calculation ──────────────────────────────────────────────────────────

def compute_atr(candles_4h: list[Candle], period_candles: int = 84) -> float:
    """Compute ATR as a percentage of current price.
    Uses last `period_candles` 4H candles (84 = 14 days).
    Returns ATR as absolute price value."""
    if len(candles_4h) < period_candles + 1:
        return 0.0

    recent = candles_4h[-(period_candles + 1):]
    tr_sum = 0.0
    for i in range(1, len(recent)):
        c = recent[i]
        c_prev = recent[i - 1]
        tr = max(
            c.high - c.low,
            abs(c.high - c_prev.close),
            abs(c.low - c_prev.close)
        )
        tr_sum += tr

    atr_per_4h = tr_sum / (len(recent) - 1)
    # Scale to daily: 6 × 4H candles = 1 day
    atr_daily = atr_per_4h * 6
    return atr_daily


# ─── Swing Detection ─────────────────────────────────────────────────────────

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


# ─── Fibonacci Levels ─────────────────────────────────────────────────────────

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


# ─── Confluence Clustering ────────────────────────────────────────────────────

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


# ─── EMA Helpers ──────────────────────────────────────────────────────────────

def calc_ema(candles: list[Candle], period: int) -> float | None:
    if len(candles) < period:
        return None
    multiplier = 2 / (period + 1)
    ema = sum(c.close for c in candles[:period]) / period
    for i in range(period, len(candles)):
        ema = (candles[i].close - ema) * multiplier + ema
    return ema


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


# ─── Bounce Confirmation ─────────────────────────────────────────────────────

def check_bounce(candles: list[Candle], zone_low: float, zone_high: float, is_buy: bool) -> bool:
    if len(candles) < 3:
        return False

    latest = candles[-1]
    prev = candles[-2]

    wick_ok = False
    consec_ok = False

    if is_buy:
        body = abs(latest.close - latest.open)
        lower_wick = min(latest.open, latest.close) - latest.low
        if lower_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close > zone_low:
            wick_ok = True
        if latest.close > zone_high and prev.close > zone_high and prev.low <= zone_high:
            consec_ok = True
    else:
        body = abs(latest.close - latest.open)
        upper_wick = latest.high - max(latest.open, latest.close)
        if upper_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close < zone_high:
            wick_ok = True
        if latest.close < zone_low and prev.close < zone_low and prev.high >= zone_low:
            consec_ok = True

    vol_ok = False
    vol_candles = candles[-21:-1]
    if len(vol_candles) >= 10 and latest.volume > 0:
        avg_vol = sum(c.volume for c in vol_candles) / len(vol_candles)
        if avg_vol > 0 and latest.volume >= VOLUME_SPIKE_RATIO * avg_vol:
            vol_ok = True

    return wick_ok or vol_ok or consec_ok


# ─── Targets & Stop Loss ─────────────────────────────────────────────────────

def compute_targets_and_stop(zone, all_fib_prices, is_buy):
    """Current fib-based SL (no cap)."""
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


def apply_atr_cap(entry_mid: float, fib_sl: float, is_buy: bool, atr: float, multiplier: float) -> float:
    """Cap the SL at entry ± multiplier × ATR. Return the tighter of fib vs ATR."""
    if is_buy:
        atr_sl = entry_mid - (atr * multiplier)
        return max(fib_sl, atr_sl)  # tighter = higher for buys
    else:
        atr_sl = entry_mid + (atr * multiplier)
        return min(fib_sl, atr_sl)  # tighter = lower for sells


# ─── Signal Resolution ───────────────────────────────────────────────────────

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
            signal.outcome = "loss"
            signal.outcome_pct = round(pnl, 2)
        signal.status = "closed"
        signal.closed_at = candle_time
        signal.duration_hours = duration
        return

    if is_buy:
        if not t1_already_hit:
            if candle.low <= sl:
                pnl = ((sl - entry_mid) / entry_mid) * 100
                signal.outcome = "loss"
                signal.outcome_pct = round(pnl, 2)
                signal.status = "closed"
                signal.closed_at = candle_time
                signal.duration_hours = duration
                return
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
                pnl = ((entry_mid - sl) / entry_mid) * 100
                signal.outcome = "loss"
                signal.outcome_pct = round(pnl, 2)
                signal.status = "closed"
                signal.closed_at = candle_time
                signal.duration_hours = duration
                return
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


# ─── Compute Results ──────────────────────────────────────────────────────────

def compute_results(label: str, signals: list[Signal], rejected: int = 0) -> Results:
    r = Results(label=label)
    closed = [s for s in signals if s.status == "closed"]
    wins = [s for s in closed if s.outcome == "win"]
    losses = [s for s in closed if s.outcome == "loss"]

    r.total = len(closed)
    r.wins = len(wins)
    r.losses = len(losses)
    r.win_rate = len(wins) / len(closed) * 100 if closed else 0
    r.avg_win = sum(s.outcome_pct for s in wins) / len(wins) if wins else 0
    r.avg_loss = sum(s.outcome_pct for s in losses) / len(losses) if losses else 0
    r.total_pnl = sum(s.outcome_pct for s in closed)
    r.signals_rejected = rejected

    gross_profit = sum(s.outcome_pct for s in closed if s.outcome_pct > 0)
    gross_loss = abs(sum(s.outcome_pct for s in closed if s.outcome_pct < 0))
    r.profit_factor = gross_profit / gross_loss if gross_loss > 0 else float("inf")

    sl_pcts = [s.sl_pct for s in closed if s.sl_pct > 0]
    r.avg_sl_pct = sum(sl_pcts) / len(sl_pcts) if sl_pcts else 0
    r.max_sl_pct = max(sl_pcts) if sl_pcts else 0

    return r


# ─── Main Backtest ────────────────────────────────────────────────────────────

def run_backtest(candles: dict, atr_multiplier: float = None):
    """Run the 4H swing tier. If atr_multiplier is set, cap SL using ATR.
    Returns (signals, rejected_count)."""
    iter_candles = candles["4h"]
    warmup = WARMUP_CANDLES_4H

    if len(iter_candles) < warmup:
        return [], 0

    signals: list[Signal] = []
    rejected = 0

    for i in range(warmup, len(iter_candles)):
        candle = iter_candles[i]
        eval_time = candle.open_time
        current_price = candle.close

        for sig in signals:
            if sig.status == "triggered":
                resolve_signal(sig, candle, eval_time)

        if i % 3 != 0:
            continue

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

        zones = cluster_levels(all_fibs, current_price, 1.5)
        all_fib_prices = [f.price for f in all_fibs]

        trend_candles = [c for c in iter_candles if c.open_time <= eval_time]
        bounce_history = trend_candles

        # Compute ATR if needed
        atr = None
        if atr_multiplier is not None:
            atr = compute_atr(trend_candles)

        for zone in zones:
            dist_pct = abs((current_price - zone.mid) / current_price) * 100
            if dist_pct > 3.0:
                continue

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

            if not check_bounce(bounce_history[-25:], zone.low, zone.high, is_buy):
                continue

            result = compute_targets_and_stop(zone, all_fib_prices, is_buy)
            if result is None:
                continue
            t1, t2, fib_sl = result

            entry_mid = zone.mid

            # Apply ATR cap if configured
            if atr_multiplier is not None and atr and atr > 0:
                sl = apply_atr_cap(entry_mid, fib_sl, is_buy, atr, atr_multiplier)
            else:
                sl = fib_sl

            risk_dist = abs(entry_mid - sl)
            reward_dist = abs(t1 - entry_mid)
            rr = reward_dist / risk_dist if risk_dist > 0 else 0

            # With tighter SL, some signals may no longer meet R:R minimum
            if rr < MIN_RR_RATIO:
                rejected += 1
                continue

            sl_pct = (risk_dist / entry_mid) * 100

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
                expires_at=eval_time + timedelta(hours=EXPIRY_HOURS),
                sl_pct=round(sl_pct, 2),
                best_price=entry_mid,
                runner_stop=sl,
            )
            signals.append(signal)

    return signals, rejected


def main():
    print("=" * 100)
    print("STOP LOSS COMPARISON — Current (Fib) vs ATR-Capped")
    print("=" * 100)
    print(f"Period: ~{BACKTEST_DAYS} days | ATR multipliers tested: {ATR_MULTIPLIERS}")
    print(f"Assets: {', '.join(a['ticker'] for a in ASSETS)}")
    print()

    # Aggregate results across all assets
    all_current_signals = []
    all_atr_signals = {m: [] for m in ATR_MULTIPLIERS}
    all_atr_rejected = {m: 0 for m in ATR_MULTIPLIERS}

    for asset in ASSETS:
        ticker = asset["ticker"]
        pair = asset["pair"]
        print(f"  {ticker}...", end=" ", flush=True)

        candles = {}
        for config in TIMEFRAME_CONFIGS:
            tf = config["tf"]
            candles[tf] = fetch_candles(pair, config["granularity"], config["seconds"], config["limit"])
            time.sleep(0.3)

        if len(candles.get("4h", [])) < WARMUP_CANDLES_4H:
            print(f"not enough data")
            continue

        print(f"{len(candles['4h'])} 4H candles", end="", flush=True)

        # Run current (no cap)
        current_signals, _ = run_backtest(candles, atr_multiplier=None)
        all_current_signals.extend(current_signals)
        current_closed = len([s for s in current_signals if s.status == "closed"])

        # Run each ATR multiplier
        for mult in ATR_MULTIPLIERS:
            atr_signals, atr_rejected = run_backtest(candles, atr_multiplier=mult)
            all_atr_signals[mult].extend(atr_signals)
            all_atr_rejected[mult] += atr_rejected

        print(f" → {current_closed} signals")
        time.sleep(1)

    # ─── Results ──────────────────────────────────────────────────────────────

    current_results = compute_results("Current (Fib SL)", all_current_signals)
    atr_results = {}
    for mult in ATR_MULTIPLIERS:
        atr_results[mult] = compute_results(f"ATR × {mult}", all_atr_signals[mult], all_atr_rejected[mult])

    print(f"\n\n{'=' * 100}")
    print("RESULTS COMPARISON")
    print(f"{'=' * 100}")

    header = f"{'Strategy':<20} │ {'Sigs':>4} {'Win%':>6} {'PF':>5} {'P&L':>8} │ {'Avg Win':>8} {'Avg Loss':>9} │ {'Avg SL%':>7} {'Max SL%':>7} │ {'Rejected':>8}"
    print(header)
    print("─" * 100)

    for r in [current_results] + [atr_results[m] for m in ATR_MULTIPLIERS]:
        rej_str = f"{r.signals_rejected}" if r.signals_rejected > 0 else "-"
        print(f"{r.label:<20} │ {r.total:>4} {r.win_rate:>5.1f}% {r.profit_factor:>5.2f} {r.total_pnl:>+7.2f}% │ "
              f"{r.avg_win:>+7.2f}% {r.avg_loss:>+8.2f}% │ {r.avg_sl_pct:>6.2f}% {r.max_sl_pct:>6.2f}% │ {rej_str:>8}")

    # ─── Key Takeaways ───────────────────────────────────────────────────────

    print(f"\n\n{'=' * 100}")
    print("KEY TAKEAWAYS")
    print(f"{'=' * 100}")

    best_mult = None
    best_pf = current_results.profit_factor

    for mult in ATR_MULTIPLIERS:
        r = atr_results[mult]
        pf_change = r.profit_factor - current_results.profit_factor
        pnl_change = r.total_pnl - current_results.total_pnl
        loss_change = r.avg_loss - current_results.avg_loss
        sl_change = r.avg_sl_pct - current_results.avg_sl_pct

        print(f"\nATR × {mult} vs Current:")
        print(f"  Profit Factor: {current_results.profit_factor:.2f} → {r.profit_factor:.2f} ({pf_change:+.2f})")
        print(f"  Total P&L:     {current_results.total_pnl:+.2f}% → {r.total_pnl:+.2f}% ({pnl_change:+.2f}%)")
        print(f"  Avg Loss:      {current_results.avg_loss:+.2f}% → {r.avg_loss:+.2f}% ({loss_change:+.2f}%)")
        print(f"  Avg SL Dist:   {current_results.avg_sl_pct:.2f}% → {r.avg_sl_pct:.2f}% ({sl_change:+.2f}%)")
        print(f"  Signals:       {current_results.total} → {r.total} (rejected {r.signals_rejected} for R:R)")

        if r.profit_factor > best_pf:
            best_pf = r.profit_factor
            best_mult = mult

    if best_mult:
        print(f"\n✓ RECOMMENDATION: ATR × {best_mult} improves profit factor from {current_results.profit_factor:.2f} to {best_pf:.2f}")
    else:
        print(f"\n→ Current fib-based SL has the best profit factor ({best_pf:.2f}). ATR cap may not be needed.")

    print()


if __name__ == "__main__":
    main()
