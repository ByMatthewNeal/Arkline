#!/usr/bin/env python3
"""
Backtest: Time-Filtered Win Rate Analysis
Compare signal performance during 8:00 AM – 12:30 PM ET (Mon–Fri)
versus all hours, using the same pipeline parameters.

Usage:
    python3 scripts/backtest_time_filter.py
"""

import json
import time
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

# ─── All 26 Pipeline Assets ─────────────────────────────────────────────────

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
    {"pair": "ONDO-USD",   "ticker": "ONDO"},
    {"pair": "POL-USD",    "ticker": "POL"},
    {"pair": "BNB-USD",    "ticker": "BNB"},
    {"pair": "ATOM-USD",   "ticker": "ATOM"},
    {"pair": "TIA-USD",    "ticker": "TIA"},
    {"pair": "XRP-USD",    "ticker": "XRP"},
    {"pair": "INJ-USD",    "ticker": "INJ"},
    {"pair": "DOGE-USD",   "ticker": "DOGE"},
    {"pair": "AAVE-USD",   "ticker": "AAVE"},
    {"pair": "PEPE-USD",   "ticker": "PEPE"},
    {"pair": "ENA-USD",    "ticker": "ENA"},
    {"pair": "FET-USD",    "ticker": "FET"},
    {"pair": "ARB-USD",    "ticker": "ARB"},
    {"pair": "DOT-USD",    "ticker": "DOT"},
    {"pair": "UNI-USD",    "ticker": "UNI"},
    {"pair": "NEAR-USD",   "ticker": "NEAR"},
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
MIN_RR_RATIO = 0.75
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
WICK_REJECTION_RATIO = 1.2
VOLUME_SPIKE_RATIO = 1.15

EMA_FAST_PERIOD = 20
EMA_SLOW_PERIOD = 50
EMA_SLOPE_LOOKBACK = 6
EMA_PULLBACK_TOLERANCE = 0.015

BACKTEST_DAYS = 365
WARMUP_CANDLES_4H = 60

# ─── Time Filter: 8:00 AM – 12:30 PM ET, Mon–Fri ───────────────────────────

ET_OFFSET_HOURS = -4  # EDT (summer). For EST use -5. Most of the year is EDT.

def is_in_trading_window(utc_time: datetime) -> bool:
    """Check if a UTC datetime falls within 8:00 AM – 12:30 PM ET, Mon–Fri."""
    et_time = utc_time + timedelta(hours=ET_OFFSET_HOURS)
    # Monday=0 ... Sunday=6
    if et_time.weekday() >= 5:
        return False
    hour = et_time.hour
    minute = et_time.minute
    time_minutes = hour * 60 + minute
    # 8:00 AM = 480 min, 12:30 PM = 750 min
    return 480 <= time_minutes < 750


# ─── Tier Configuration (matches live pipeline) ─────────────────────────────

@dataclass
class TierConfig:
    tier_name: str
    swing_timeframes: list
    trend_timeframe: str
    bounce_timeframe: str
    signal_proximity_pct: float
    confluence_tolerance_pct: float
    expiry_hours: int

TIER_SWING = TierConfig(
    tier_name="4h",
    swing_timeframes=["4h", "1d"],
    trend_timeframe="4h",
    bounce_timeframe="4h",
    signal_proximity_pct=3.0,
    confluence_tolerance_pct=1.5,
    expiry_hours=72,
)

TIER_SCALP = TierConfig(
    tier_name="1h",
    swing_timeframes=["1h", "4h"],
    trend_timeframe="4h",
    bounce_timeframe="1h",
    signal_proximity_pct=2.0,
    confluence_tolerance_pct=1.0,
    expiry_hours=48,
)


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


# ─── Fetch Historical Data (Coinbase Advanced Trade API) ─────────────────────

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


# ─── Bounce Confirmation ────────────────────────────────────────────────────

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


# ─── Targets & Stop Loss ────────────────────────────────────────────────────

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


# ─── Compute Results ─────────────────────────────────────────────────────────

@dataclass
class Results:
    ticker: str
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
    long_win_rate: float = 0.0
    short_count: int = 0
    short_wins: int = 0
    short_win_rate: float = 0.0
    avg_rr: float = 0.0
    signals_per_month: float = 0.0

def compute_results(ticker: str, signals: list[Signal]) -> Results:
    closed = [s for s in signals if s.status == "closed"]
    wins = [s for s in closed if s.outcome == "win"]
    losses = [s for s in closed if s.outcome == "loss"]

    buys = [s for s in closed if s.is_buy]
    sells = [s for s in closed if not s.is_buy]
    buy_wins = [s for s in buys if s.outcome == "win"]
    sell_wins = [s for s in sells if s.outcome == "win"]

    r = Results(ticker=ticker)
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
    r.long_win_rate = len(buy_wins) / len(buys) * 100 if buys else 0

    r.short_count = len(sells)
    r.short_wins = len(sell_wins)
    r.short_win_rate = len(sell_wins) / len(sells) * 100 if sells else 0

    r.avg_rr = sum(s.rr_ratio for s in closed) / len(closed) if closed else 0

    if closed:
        first = min(s.entry_time for s in closed)
        last = max(s.entry_time for s in closed)
        months = max(1, (last - first).days / 30)
        r.signals_per_month = len(closed) / months
    else:
        r.signals_per_month = 0

    return r


# ─── Main Backtest ───────────────────────────────────────────────────────────

def run_tier(tier: TierConfig, candles: dict, all_candles_4h: list[Candle]) -> list[Signal]:
    if tier.tier_name == "4h":
        iter_candles = candles["4h"]
        warmup = WARMUP_CANDLES_4H
        eval_interval = 3
    else:
        iter_candles = candles.get("1h", [])
        warmup = 60
        eval_interval = 3

    if len(iter_candles) < warmup:
        return []

    signals: list[Signal] = []

    for i in range(warmup, len(iter_candles)):
        candle = iter_candles[i]
        eval_time = candle.open_time
        current_price = candle.close

        for sig in signals:
            if sig.status == "triggered":
                resolve_signal(sig, candle, eval_time)

        if i % eval_interval != 0:
            continue

        all_fibs = []
        for tf in tier.swing_timeframes:
            tf_candles = candles.get(tf, [])
            history = [c for c in tf_candles if c.open_time <= eval_time]
            limit = 250 if tf in ("4h", "1h") else 120
            swings = detect_swings(history[-limit:], tf)
            fibs = compute_fibs(swings, tf)
            all_fibs.extend(fibs)

        if not all_fibs:
            continue

        zones = cluster_levels(all_fibs, current_price, tier.confluence_tolerance_pct)
        all_fib_prices = [f.price for f in all_fibs]

        trend_candles = [c for c in all_candles_4h if c.open_time <= eval_time]
        bounce_tf_candles = candles.get(tier.bounce_timeframe, [])
        bounce_history = [c for c in bounce_tf_candles if c.open_time <= eval_time]

        for zone in zones:
            dist_pct = abs((current_price - zone.mid) / current_price) * 100
            if dist_pct > tier.signal_proximity_pct:
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
                expires_at=eval_time + timedelta(hours=tier.expiry_hours),
                best_price=entry_mid,
                runner_stop=sl,
            )
            signals.append(signal)

    return signals


def main():
    print("=" * 130)
    print("TIME-FILTERED BACKTEST — 8:00 AM – 12:30 PM ET (Mon–Fri) vs All Hours")
    print("=" * 130)
    print(f"Period: ~{BACKTEST_DAYS} days | {len(ASSETS)} assets | Swing + Scalp tiers")
    print(f"Time filter: 8:00 AM – 12:30 PM ET (UTC{ET_OFFSET_HOURS:+d}), weekdays only")
    print()

    all_signals_by_asset: dict[str, list[Signal]] = {}

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
            print(f"    Not enough 4H data for {ticker}")
            continue

        swing_signals = run_tier(TIER_SWING, candles, candles["4h"])
        scalp_signals = run_tier(TIER_SCALP, candles, candles["4h"])
        all_sigs = swing_signals + scalp_signals
        all_signals_by_asset[ticker] = all_sigs
        print(f"    Swing: {len(swing_signals)}, Scalp: {len(scalp_signals)}, Total: {len(all_sigs)}")
        time.sleep(1)

    # ─── Split signals into filtered vs all ──────────────────────────────────

    print(f"\n\n{'=' * 130}")
    print("RESULTS — ALL HOURS vs 8 AM – 12:30 PM ET (Mon–Fri)")
    print(f"{'=' * 130}")

    header = (f"{'Asset':<7} │ {'ALL HOURS':^42} │ {'8AM–12:30PM ET Mon-Fri':^42} │ {'Delta':^12}")
    sub    = (f"{'':7} │ {'Sigs':>4} {'Win%':>6} {'PF':>5} {'P&L':>8} {'L.WR':>6} {'S.WR':>6} │ "
              f"{'Sigs':>4} {'Win%':>6} {'PF':>5} {'P&L':>8} {'L.WR':>6} {'S.WR':>6} │ {'WR Δ':>6} {'PF Δ':>5}")
    print(header)
    print(sub)
    print("─" * 130)

    # Aggregate totals
    all_total_sigs = 0
    all_total_wins = 0
    filt_total_sigs = 0
    filt_total_wins = 0
    all_total_pnl = 0.0
    filt_total_pnl = 0.0

    rows = []

    for ticker, signals in sorted(all_signals_by_asset.items()):
        # All hours
        r_all = compute_results(ticker, signals)

        # Filtered: only signals whose entry_time is in the trading window
        filtered_signals = [s for s in signals if is_in_trading_window(s.entry_time)]
        r_filt = compute_results(ticker, filtered_signals)

        wr_delta = r_filt.win_rate - r_all.win_rate if r_filt.total >= 3 else 0
        pf_delta = r_filt.profit_factor - r_all.profit_factor if r_filt.total >= 3 else 0

        rows.append((ticker, r_all, r_filt, wr_delta, pf_delta))

        all_total_sigs += r_all.total
        all_total_wins += r_all.wins
        filt_total_sigs += r_filt.total
        filt_total_wins += r_filt.wins
        all_total_pnl += r_all.total_pnl
        filt_total_pnl += r_filt.total_pnl

    # Sort by filtered PF descending
    rows.sort(key=lambda x: x[2].profit_factor, reverse=True)

    for ticker, r_all, r_filt, wr_delta, pf_delta in rows:
        wr_d_str = f"{wr_delta:>+5.1f}%" if r_filt.total >= 3 else "  n/a"
        pf_d_str = f"{pf_delta:>+5.2f}" if r_filt.total >= 3 else "  n/a"

        print(f"{ticker:<7} │ {r_all.total:>4} {r_all.win_rate:>5.1f}% {r_all.profit_factor:>5.2f} {r_all.total_pnl:>+7.2f}% {r_all.long_win_rate:>5.1f}% {r_all.short_win_rate:>5.1f}% │ "
              f"{r_filt.total:>4} {r_filt.win_rate:>5.1f}% {r_filt.profit_factor:>5.2f} {r_filt.total_pnl:>+7.2f}% {r_filt.long_win_rate:>5.1f}% {r_filt.short_win_rate:>5.1f}% │ "
              f"{wr_d_str} {pf_d_str}")

    # Totals
    all_wr = all_total_wins / all_total_sigs * 100 if all_total_sigs else 0
    filt_wr = filt_total_wins / filt_total_sigs * 100 if filt_total_sigs else 0

    print("─" * 130)
    print(f"{'TOTAL':<7} │ {all_total_sigs:>4} {all_wr:>5.1f}% {'':5} {all_total_pnl:>+7.2f}% {'':6} {'':6} │ "
          f"{filt_total_sigs:>4} {filt_wr:>5.1f}% {'':5} {filt_total_pnl:>+7.2f}% {'':6} {'':6} │ "
          f"{filt_wr - all_wr:>+5.1f}%")

    # Summary
    print(f"\n\n{'=' * 80}")
    print("SUMMARY")
    print(f"{'=' * 80}")
    print(f"  All hours:          {all_total_sigs:>4} signals, {all_wr:.1f}% WR, {all_total_pnl:+.2f}% total P&L")
    print(f"  8AM–12:30PM ET M-F: {filt_total_sigs:>4} signals, {filt_wr:.1f}% WR, {filt_total_pnl:+.2f}% total P&L")
    pct_of_total = filt_total_sigs / all_total_sigs * 100 if all_total_sigs else 0
    print(f"  Window captures:    {pct_of_total:.1f}% of all signals")
    print(f"  Win rate delta:     {filt_wr - all_wr:+.1f}%")

    # Best / worst performers in the window
    valid_rows = [(t, ra, rf, wd, pd) for t, ra, rf, wd, pd in rows if rf.total >= 5]
    if valid_rows:
        best = max(valid_rows, key=lambda x: x[3])
        worst = min(valid_rows, key=lambda x: x[3])
        print(f"\n  Best improvement:   {best[0]} ({best[3]:+.1f}% WR, {best[2].profit_factor:.2f} PF in window)")
        print(f"  Worst in window:    {worst[0]} ({worst[3]:+.1f}% WR, {worst[2].profit_factor:.2f} PF in window)")


if __name__ == "__main__":
    main()
