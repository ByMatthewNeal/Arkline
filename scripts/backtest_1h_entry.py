#!/usr/bin/env python3
"""
Backtest: 1H Entry / 4H Bias — Fibonacci Golden Pocket Strategy
Compares against the current 4H Entry / 1D Bias setup.

Key differences from current pipeline:
- Swing detection on 1H + 4H (instead of 4H + 1D)
- Bounce confirmation on 1H candles
- Signal evaluation walks 1H candles
- Trend alignment still on 4H EMAs

Usage:
    python3 scripts/backtest_1h_entry.py
"""

import json
import time
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

# ─── Assets (same as live pipeline) ─────────────────────────────────────────

ASSETS = [
    {"symbol": "BTC-USD",    "ticker": "BTC"},
    {"symbol": "ETH-USD",    "ticker": "ETH"},
    {"symbol": "SOL-USD",    "ticker": "SOL"},
    {"symbol": "SUI-USD",    "ticker": "SUI"},
    {"symbol": "LINK-USD",   "ticker": "LINK"},
    {"symbol": "ADA-USD",    "ticker": "ADA"},
    {"symbol": "AVAX-USD",   "ticker": "AVAX"},
    {"symbol": "RENDER-USD", "ticker": "RENDER"},
    {"symbol": "APT-USD",    "ticker": "APT"},
]

# ─── Configuration ───────────────────────────────────────────────────────────

# 1H Entry / 4H Bias setup
TIMEFRAME_CONFIGS_1H = [
    {"tf": "1h", "interval": "1h", "limit": 2400},   # ~100 days
    {"tf": "4h", "interval": "4h", "limit": 1200},   # ~200 days
]

# Current 4H Entry / 1D Bias setup (for comparison)
TIMEFRAME_CONFIGS_4H = [
    {"tf": "4h", "interval": "4h", "limit": 2400},
    {"tf": "1d", "interval": "1d", "limit": 500},
]

SWING_PARAMS_1H = {
    "1h": {"lookback": 10, "min_reversal": 2.5},  # Tighter for 1H
    "4h": {"lookback": 8,  "min_reversal": 5.0},
}

SWING_PARAMS_4H = {
    "4h": {"lookback": 8,  "min_reversal": 5.0},
    "1d": {"lookback": 5,  "min_reversal": 8.0},
}

FIB_RATIOS = [0.618, 0.786]
CONFLUENCE_TOLERANCE_PCT = 1.5
SIGNAL_PROXIMITY_PCT = 2.0
MIN_RR_RATIO = 1.0
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
SIGNAL_EXPIRY_HOURS_1H = 48   # Shorter expiry for 1H setup
SIGNAL_EXPIRY_HOURS_4H = 72
WICK_REJECTION_RATIO = 1.5
VOLUME_SPIKE_RATIO = 1.3

EMA_FAST_PERIOD = 20
EMA_SLOW_PERIOD = 50
EMA_SLOPE_LOOKBACK_1H = 12   # 12 x 1h = 12h for 1H setup
EMA_SLOPE_LOOKBACK_4H = 6    # 6 x 4h = 24h for 4H setup
EMA_PULLBACK_TOLERANCE = 0.008

WARMUP_CANDLES = 60
BACKTEST_DAYS = 90  # ~3 months of comparable data for both setups


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
class AssetResults:
    ticker: str
    setup: str  # "1H/4H" or "4H/1D"
    total: int = 0
    wins: int = 0
    losses: int = 0
    win_rate: float = 0.0
    avg_win: float = 0.0
    avg_loss: float = 0.0
    total_pnl: float = 0.0
    profit_factor: float = 0.0
    long_count: int = 0
    long_wins: int = 0
    long_pnl: float = 0.0
    long_win_rate: float = 0.0
    short_count: int = 0
    short_wins: int = 0
    short_pnl: float = 0.0
    short_win_rate: float = 0.0
    avg_rr: float = 0.0
    avg_duration_hours: float = 0.0
    signals_per_month: float = 0.0


# ─── Fetch Historical Data ───────────────────────────────────────────────────

COINBASE_GRANULARITY = {
    "1h": "ONE_HOUR",
    "4h": "FOUR_HOUR",
    "1d": "ONE_DAY",
}

COINBASE_SECONDS = {
    "1h": 3600,
    "4h": 14400,
    "1d": 86400,
}

def fetch_candles(symbol: str, interval: str, limit: int) -> list[Candle]:
    """Fetch candles from Coinbase Advanced Trade API (max 350 per request)."""
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

        candles = []
        for k in candles_data:
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

        if len(candles_data) < batch:
            break
        time.sleep(0.2)

    # Deduplicate and sort
    seen = set()
    unique = []
    for c in all_candles:
        key = c.open_time
        if key not in seen:
            seen.add(key)
            unique.append(c)
    unique.sort(key=lambda c: c.open_time)
    return unique[-limit:]


# ─── Swing Detection ─────────────────────────────────────────────────────────

def detect_swings(candles: list[Candle], tf: str, swing_params: dict) -> list[SwingPoint]:
    params = swing_params[tf]
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


# ─── Confluence Clustering ────────────────────────────────────────────────────

def cluster_levels(fibs: list[FibLevel], current_price: float) -> list[ConfluenceZone]:
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

        if dist_pct <= CONFLUENCE_TOLERANCE_PCT:
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


# ─── Trend Alignment ─────────────────────────────────────────────────────────

def check_trend_alignment(trend_candles: list[Candle], is_buy: bool, slope_lookback: int) -> bool:
    if len(trend_candles) < EMA_SLOW_PERIOD + slope_lookback:
        return True

    ema_fast = calc_ema(trend_candles, EMA_FAST_PERIOD)
    ema_slow = calc_ema(trend_candles, EMA_SLOW_PERIOD)
    ema_slow_prev = calc_ema(trend_candles[:-slope_lookback], EMA_SLOW_PERIOD)

    if ema_fast is None or ema_slow is None or ema_slow_prev is None:
        return True

    price = trend_candles[-1].close
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

def compute_results(ticker: str, signals: list[Signal], setup: str) -> AssetResults:
    closed = [s for s in signals if s.status == "closed"]
    wins = [s for s in closed if s.outcome == "win"]
    losses = [s for s in closed if s.outcome == "loss"]

    buys = [s for s in closed if s.is_buy]
    sells = [s for s in closed if not s.is_buy]
    buy_wins = [s for s in buys if s.outcome == "win"]
    sell_wins = [s for s in sells if s.outcome == "win"]

    r = AssetResults(ticker=ticker, setup=setup)
    r.total = len(closed)
    r.wins = len(wins)
    r.losses = len(losses)
    r.win_rate = len(wins) / len(closed) * 100 if closed else 0
    r.avg_win = sum(s.outcome_pct for s in wins) / len(wins) if wins else 0
    r.avg_loss = sum(s.outcome_pct for s in losses) / len(losses) if losses else 0
    r.total_pnl = sum(s.outcome_pct for s in closed)

    gross_profit = sum(s.outcome_pct for s in closed if s.outcome_pct > 0)
    gross_loss = abs(sum(s.outcome_pct for s in closed if s.outcome_pct < 0))
    r.profit_factor = gross_profit / gross_loss if gross_loss > 0 else float("inf")

    r.long_count = len(buys)
    r.long_wins = len(buy_wins)
    r.long_pnl = sum(s.outcome_pct for s in buys)
    r.long_win_rate = len(buy_wins) / len(buys) * 100 if buys else 0

    r.short_count = len(sells)
    r.short_wins = len(sell_wins)
    r.short_pnl = sum(s.outcome_pct for s in sells)
    r.short_win_rate = len(sell_wins) / len(sells) * 100 if sells else 0

    r.avg_rr = sum(s.rr_ratio for s in closed) / len(closed) if closed else 0

    durations = [s.duration_hours for s in closed if s.duration_hours > 0]
    r.avg_duration_hours = sum(durations) / len(durations) if durations else 0

    if closed:
        first = min(s.entry_time for s in closed)
        last = max(s.entry_time for s in closed)
        months = max(1, (last - first).days / 30)
        r.signals_per_month = len(closed) / months
    else:
        r.signals_per_month = 0

    return r


# ─── Backtest Runner ─────────────────────────────────────────────────────────

def run_backtest(asset_symbol: str, asset_ticker: str, mode: str) -> list[Signal]:
    """
    mode: "1h_4h" or "4h_1d"
    """
    if mode == "1h_4h":
        configs = TIMEFRAME_CONFIGS_1H
        swing_params = SWING_PARAMS_1H
        entry_tf = "1h"
        bias_tf = "4h"
        slope_lookback = EMA_SLOPE_LOOKBACK_1H
        expiry_hours = SIGNAL_EXPIRY_HOURS_1H
    else:
        configs = TIMEFRAME_CONFIGS_4H
        swing_params = SWING_PARAMS_4H
        entry_tf = "4h"
        bias_tf = "1d"
        slope_lookback = EMA_SLOPE_LOOKBACK_4H
        expiry_hours = SIGNAL_EXPIRY_HOURS_4H

    candles = {}
    for config in configs:
        tf = config["tf"]
        candles[tf] = fetch_candles(asset_symbol, config["interval"], config["limit"])
        time.sleep(0.3)

    entry_candles = candles[entry_tf]
    bias_candles = candles[bias_tf]

    if len(entry_candles) < WARMUP_CANDLES:
        return []

    # Limit to backtest window
    cutoff = datetime.now(timezone.utc) - timedelta(days=BACKTEST_DAYS)

    signals: list[Signal] = []

    for i in range(WARMUP_CANDLES, len(entry_candles)):
        candle = entry_candles[i]
        eval_time = candle.open_time
        current_price = candle.close

        if eval_time < cutoff:
            continue

        # Resolve open signals
        for sig in signals:
            if sig.status == "triggered":
                resolve_signal(sig, candle, eval_time)

        # Only evaluate every N candles to avoid over-signaling
        eval_interval = 2 if mode == "1h_4h" else 3
        if i % eval_interval != 0:
            continue

        history_entry = entry_candles[:i + 1]
        history_bias = [c for c in bias_candles if c.open_time <= eval_time]

        swings_entry = detect_swings(history_entry[-500:], entry_tf, swing_params)
        swings_bias = detect_swings(history_bias[-250:], bias_tf, swing_params)

        fibs_entry = compute_fibs(swings_entry, entry_tf)
        fibs_bias = compute_fibs(swings_bias, bias_tf)
        all_fibs = fibs_entry + fibs_bias

        if not all_fibs:
            continue

        zones = cluster_levels(all_fibs, current_price)
        all_fib_prices = [f.price for f in all_fibs]

        for zone in zones:
            dist_pct = abs((current_price - zone.mid) / current_price) * 100
            if dist_pct > SIGNAL_PROXIMITY_PCT:
                continue

            duplicate = False
            for s in signals:
                if s.status == "triggered" and abs(s.entry_mid - zone.mid) / zone.mid < 0.005:
                    duplicate = True
                    break
            if duplicate:
                continue

            is_buy = zone.zone_type == "support"

            # Trend alignment on bias timeframe
            if mode == "1h_4h":
                trend_candles = history_bias
            else:
                # For 4H/1D, trend on 4H (same as current pipeline)
                trend_candles = history_entry

            if not check_trend_alignment(trend_candles, is_buy, slope_lookback):
                continue

            # Bounce on entry timeframe
            if not check_bounce(history_entry[-25:], zone.low, zone.high, is_buy):
                continue

            result = compute_targets_and_stop(zone, all_fib_prices, is_buy)
            if result is None:
                continue
            t1, t2, sl = result

            entry_mid = zone.mid
            risk_dist = abs(entry_mid - sl)
            reward_dist = abs(t1 - entry_mid)
            rr = reward_dist / risk_dist if risk_dist > 0 else 0

            if rr < MIN_RR_RATIO:
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
                expires_at=eval_time + timedelta(hours=expiry_hours),
                best_price=entry_mid,
                runner_stop=sl,
            )
            signals.append(signal)

    return signals


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    print("=" * 120)
    print("TIMEFRAME COMPARISON: 1H Entry / 4H Bias  vs  4H Entry / 1D Bias")
    print("=" * 120)
    print(f"Backtest period: ~{BACKTEST_DAYS} days | Ratios: {FIB_RATIOS}")
    print(f"1H/4H: entry on 1H candles, trend on 4H EMAs, {SIGNAL_EXPIRY_HOURS_1H}h expiry")
    print(f"4H/1D: entry on 4H candles, trend on 4H EMAs, {SIGNAL_EXPIRY_HOURS_4H}h expiry (current pipeline)")
    print(f"Assets: {', '.join(a['ticker'] for a in ASSETS)}")

    results_1h = {}
    results_4h = {}

    for asset in ASSETS:
        ticker = asset["ticker"]
        symbol = asset["symbol"]
        print(f"\n  {ticker}...")

        # Fetch data once, run both backtests
        print(f"    Running 1H/4H backtest...")
        signals_1h = run_backtest(symbol, ticker, "1h_4h")
        r1h = compute_results(ticker, signals_1h, "1H/4H")
        results_1h[ticker] = r1h
        print(f"    1H/4H: {r1h.total} signals, {r1h.win_rate:.1f}% WR, {r1h.profit_factor:.2f} PF, {r1h.total_pnl:+.1f}%")

        print(f"    Running 4H/1D backtest...")
        signals_4h = run_backtest(symbol, ticker, "4h_1d")
        r4h = compute_results(ticker, signals_4h, "4H/1D")
        results_4h[ticker] = r4h
        print(f"    4H/1D: {r4h.total} signals, {r4h.win_rate:.1f}% WR, {r4h.profit_factor:.2f} PF, {r4h.total_pnl:+.1f}%")

        time.sleep(1)

    # ─── Comparison Table ────────────────────────────────────────────────────

    print(f"\n\n{'=' * 140}")
    print("SIDE-BY-SIDE COMPARISON")
    print(f"{'=' * 140}")

    header = (f"{'Asset':<7} │ {'--- 1H Entry / 4H Bias ---':^48} │ {'--- 4H Entry / 1D Bias (current) ---':^48} │ {'Winner':<8}")
    print(header)
    sub = (f"{'':7} │ {'Sigs':>4} {'Win%':>6} {'PF':>5} {'P&L':>8} {'Sig/Mo':>6} {'AvgDur':>6} │ "
           f"{'Sigs':>4} {'Win%':>6} {'PF':>5} {'P&L':>8} {'Sig/Mo':>6} {'AvgDur':>6} │ {'':8}")
    print(sub)
    print("─" * 140)

    total_1h_pnl = 0
    total_4h_pnl = 0
    total_1h_sigs = 0
    total_4h_sigs = 0
    wins_1h = 0
    wins_4h = 0

    for asset in ASSETS:
        ticker = asset["ticker"]
        r1 = results_1h[ticker]
        r4 = results_4h[ticker]

        total_1h_pnl += r1.total_pnl
        total_4h_pnl += r4.total_pnl
        total_1h_sigs += r1.total
        total_4h_sigs += r4.total

        # Determine winner by profit factor (with min signals requirement)
        if r1.total < 3 and r4.total < 3:
            winner = "---"
        elif r1.total < 3:
            winner = "4H/1D"
            wins_4h += 1
        elif r4.total < 3:
            winner = "1H/4H"
            wins_1h += 1
        elif r1.profit_factor > r4.profit_factor:
            winner = "1H/4H"
            wins_1h += 1
        elif r4.profit_factor > r1.profit_factor:
            winner = "4H/1D"
            wins_4h += 1
        else:
            winner = "TIE"

        dur_1h = f"{r1.avg_duration_hours:.0f}h" if r1.avg_duration_hours else "---"
        dur_4h = f"{r4.avg_duration_hours:.0f}h" if r4.avg_duration_hours else "---"

        print(f"{ticker:<7} │ {r1.total:>4} {r1.win_rate:>5.1f}% {r1.profit_factor:>5.2f} {r1.total_pnl:>+7.1f}% {r1.signals_per_month:>5.1f} {dur_1h:>6} │ "
              f"{r4.total:>4} {r4.win_rate:>5.1f}% {r4.profit_factor:>5.2f} {r4.total_pnl:>+7.1f}% {r4.signals_per_month:>5.1f} {dur_4h:>6} │ {winner:<8}")

    print("─" * 140)
    print(f"{'TOTAL':<7} │ {total_1h_sigs:>4} {'':6} {'':5} {total_1h_pnl:>+7.1f}% {'':6} {'':6} │ "
          f"{total_4h_sigs:>4} {'':6} {'':5} {total_4h_pnl:>+7.1f}% {'':6} {'':6} │")

    print(f"\n  1H/4H wins: {wins_1h} assets | 4H/1D wins: {wins_4h} assets")
    print(f"  1H/4H total signals: {total_1h_sigs} | 4H/1D total signals: {total_4h_sigs}")
    print(f"  1H/4H total P&L: {total_1h_pnl:+.1f}% | 4H/1D total P&L: {total_4h_pnl:+.1f}%")

    # ─── Long vs Short Breakdown ─────────────────────────────────────────────

    print(f"\n\n{'=' * 120}")
    print("LONG vs SHORT BREAKDOWN")
    print(f"{'=' * 120}")

    header2 = (f"{'Asset':<7} │ {'--- 1H/4H Long ---':^22} {'--- 1H/4H Short ---':^22} │ "
               f"{'--- 4H/1D Long ---':^22} {'--- 4H/1D Short ---':^22}")
    print(header2)
    sub2 = (f"{'':7} │ {'#':>3} {'Win%':>6} {'P&L':>8}   {'#':>3} {'Win%':>6} {'P&L':>8} │ "
            f"{'#':>3} {'Win%':>6} {'P&L':>8}   {'#':>3} {'Win%':>6} {'P&L':>8}")
    print(sub2)
    print("─" * 120)

    for asset in ASSETS:
        ticker = asset["ticker"]
        r1 = results_1h[ticker]
        r4 = results_4h[ticker]
        print(f"{ticker:<7} │ {r1.long_count:>3} {r1.long_win_rate:>5.1f}% {r1.long_pnl:>+7.1f}%   "
              f"{r1.short_count:>3} {r1.short_win_rate:>5.1f}% {r1.short_pnl:>+7.1f}% │ "
              f"{r4.long_count:>3} {r4.long_win_rate:>5.1f}% {r4.long_pnl:>+7.1f}%   "
              f"{r4.short_count:>3} {r4.short_win_rate:>5.1f}% {r4.short_pnl:>+7.1f}%")

    print()


if __name__ == "__main__":
    main()
