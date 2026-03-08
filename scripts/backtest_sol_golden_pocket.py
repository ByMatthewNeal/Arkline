#!/usr/bin/env python3
"""
Backtest: SOL Golden Pocket Strategy
Uses the EXACT same parameters as the live BTC fibonacci-pipeline.
4H entry / 1D bias, 0.618-0.786 golden pocket only, EMA 20/50 trend filter,
bounce confirmation, split exit (50% at T1, 50% runner trailing 1R).
"""

import json
import time
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

# ─── Configuration (EXACT mirror of fibonacci-pipeline/index.ts) ─────────────

ASSET_SYMBOL = "SOLUSDT"
ASSET_TICKER = "SOL"

TIMEFRAME_CONFIGS = [
    {"tf": "4h", "interval": "4h", "limit": 2400},   # ~400 days of 4H candles (paginated)
    {"tf": "1d", "interval": "1d", "limit": 500},
]

SWING_PARAMS = {
    "4h": {"lookback": 8, "min_reversal": 5.0},
    "1d": {"lookback": 5, "min_reversal": 8.0},
}

# Only the golden pocket — same as pipeline
FIB_RATIOS = [0.618, 0.786]

CONFLUENCE_TOLERANCE_PCT = 1.5
SIGNAL_PROXIMITY_PCT = 2.0
MIN_RR_RATIO = 1.0
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
SIGNAL_EXPIRY_HOURS = 72
WICK_REJECTION_RATIO = 1.5
VOLUME_SPIKE_RATIO = 1.3

# EMA parameters — same as pipeline
EMA_FAST_PERIOD = 20
EMA_SLOW_PERIOD = 50
EMA_SLOPE_LOOKBACK = 6
EMA_PULLBACK_TOLERANCE = 0.008

# Backtest window
BACKTEST_DAYS = 365
WARMUP_CANDLES_4H = 60  # Need enough for EMA 50 + slope lookback


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
    type: str  # "high" or "low"
    price: float
    candle_time: datetime
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
    # Resolution state
    status: str = "triggered"
    t1_hit_at: datetime = None
    t1_pnl_pct: float = 0.0
    best_price: float = 0.0
    runner_stop: float = 0.0
    runner_exit_price: float = 0.0
    runner_pnl_pct: float = 0.0
    outcome: str = None  # "win", "loss", "partial"
    outcome_pct: float = 0.0
    closed_at: datetime = None
    duration_hours: int = 0

    @property
    def is_buy(self) -> bool:
        return "buy" in self.signal_type


# ─── Fetch Historical Data ───────────────────────────────────────────────────

def fetch_candles(symbol: str, interval: str, limit: int) -> list[Candle]:
    """Fetch from Binance, paginating if needed for >1000 candles."""
    all_candles = []
    end_time = None

    while len(all_candles) < limit:
        batch = min(1000, limit - len(all_candles))
        url = f"https://api.binance.com/api/v3/klines?symbol={symbol}&interval={interval}&limit={batch}"
        if end_time:
            url += f"&endTime={end_time}"

        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
        except Exception as e:
            print(f"  Error fetching {symbol} {interval}: {e}")
            break

        if not data:
            break

        candles = []
        for k in data:
            candles.append(Candle(
                open_time=datetime.fromtimestamp(k[0] / 1000, tz=timezone.utc),
                open=float(k[1]),
                high=float(k[2]),
                low=float(k[3]),
                close=float(k[4]),
                volume=float(k[5]),
            ))

        all_candles = candles + all_candles  # prepend older candles
        end_time = int(candles[0].open_time.timestamp() * 1000) - 1

        if len(data) < batch:
            break
        time.sleep(0.3)

    return all_candles


# ─── Swing Detection (same as pipeline) ─────────────────────────────────────

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
                    swings.append(SwingPoint("high", c.high, c.open_time, reversal_pct))

        # Swing low
        is_low = all(candles[j].low > c.low for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_low:
            surrounding_highs = [candles[j].high for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_highs:
                max_high = max(surrounding_highs)
                reversal_pct = ((max_high - c.low) / c.low) * 100
                if reversal_pct >= min_reversal:
                    swings.append(SwingPoint("low", c.low, c.open_time, reversal_pct))

    return swings


# ─── Fibonacci Levels (same as pipeline) ────────────────────────────────────

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


# ─── Confluence Clustering (same as pipeline) ───────────────────────────────

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


# ─── EMA Trend Filter (same as pipeline) ────────────────────────────────────

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


# ─── Bounce Confirmation (same as pipeline) ─────────────────────────────────

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

    # Volume spike
    vol_ok = False
    vol_candles = candles[-21:-1]
    if len(vol_candles) >= 10 and latest.volume > 0:
        avg_vol = sum(c.volume for c in vol_candles) / len(vol_candles)
        if avg_vol > 0 and latest.volume >= VOLUME_SPIKE_RATIO * avg_vol:
            vol_ok = True

    return wick_ok or vol_ok or consec_ok


# ─── Targets & Stop Loss (same as pipeline) ─────────────────────────────────

def compute_targets_and_stop(zone: ConfluenceZone, all_fib_prices: list[float], is_buy: bool):
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


# ─── Signal Resolution (50% at T1, trail runner — same as pipeline) ─────────

def resolve_signal(signal: Signal, candle: Candle, candle_time: datetime):
    """Resolve one candle against an open signal. Mutates signal in place."""
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

    # Expiry
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
            # Phase 1: Full position
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
                signal.runner_stop = entry_mid  # Move to breakeven
        else:
            # Phase 2: Runner
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
        # SHORT
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


# ─── Main Backtest Loop ─────────────────────────────────────────────────────

def run_backtest():
    print("=" * 70)
    print(f"FIBONACCI GOLDEN POCKET BACKTEST — {ASSET_TICKER}")
    print("Same strategy as live BTC pipeline")
    print("=" * 70)
    print(f"Period: ~{BACKTEST_DAYS} days | Golden Pocket: {FIB_RATIOS}")
    print(f"Split Exit: 50% at T1, 50% runner (trailing 1R stop)")
    print(f"EMA Filter: {EMA_FAST_PERIOD}/{EMA_SLOW_PERIOD} on 4H")
    print()

    # Fetch data
    print("Fetching historical data from Binance...")
    candles = {}
    for config in TIMEFRAME_CONFIGS:
        tf = config["tf"]
        print(f"  {tf}...", end="", flush=True)
        candles[tf] = fetch_candles(ASSET_SYMBOL, config["interval"], config["limit"])
        print(f" {len(candles[tf])} candles")
        time.sleep(0.3)

    candles_4h = candles["4h"]
    candles_1d = candles["1d"]

    if len(candles_4h) < WARMUP_CANDLES_4H:
        print("Not enough 4H data for backtest")
        return

    # Determine backtest start
    start_time = candles_4h[WARMUP_CANDLES_4H].open_time
    print(f"\nBacktest range: {start_time.strftime('%Y-%m-%d')} to {candles_4h[-1].open_time.strftime('%Y-%m-%d')}")

    signals: list[Signal] = []

    # Walk forward through 4H candles (simulating pipeline runs at each candle)
    for i in range(WARMUP_CANDLES_4H, len(candles_4h)):
        candle = candles_4h[i]
        eval_time = candle.open_time
        current_price = candle.close

        # Resolve open signals against this candle
        for sig in signals:
            if sig.status == "triggered":
                resolve_signal(sig, candle, eval_time)

        # Only evaluate new signals every 6th candle (~24h, simulating 12:00 and 16:00 UTC)
        # The pipeline runs at specific times; we approximate by running every few candles
        if i % 3 != 0:  # Every 3rd 4H candle = every 12 hours
            continue

        # Get history up to this point
        history_4h = candles_4h[:i + 1]
        history_1d = [c for c in candles_1d if c.open_time <= eval_time]

        # Detect swings on both timeframes
        swings_4h = detect_swings(history_4h[-250:], "4h")  # Last 250 candles like pipeline
        swings_1d = detect_swings(history_1d[-120:], "1d")

        # Compute fibs
        fibs_4h = compute_fibs(swings_4h, "4h")
        fibs_1d = compute_fibs(swings_1d, "1d")
        all_fibs = fibs_4h + fibs_1d

        if not all_fibs:
            continue

        # Cluster
        zones = cluster_levels(all_fibs, current_price)
        all_fib_prices = [f.price for f in all_fibs]

        for zone in zones:
            dist_pct = abs((current_price - zone.mid) / current_price) * 100
            if dist_pct > SIGNAL_PROXIMITY_PCT:
                continue

            # Check for existing signal near this zone
            duplicate = False
            for s in signals:
                if s.status == "triggered" and abs(s.entry_mid - zone.mid) / zone.mid < 0.005:
                    duplicate = True
                    break
            if duplicate:
                continue

            is_buy = zone.zone_type == "support"

            # EMA trend filter on 4H
            if not check_trend_alignment(history_4h, is_buy):
                continue

            # Bounce confirmation on recent 4H candles
            if not check_bounce(history_4h[-25:], zone.low, zone.high, is_buy):
                continue

            # Targets and stop
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
                expires_at=eval_time + timedelta(hours=SIGNAL_EXPIRY_HOURS),
                best_price=entry_mid,
                runner_stop=sl,
            )
            signals.append(signal)

    # ─── Results ─────────────────────────────────────────────────────────────

    closed = [s for s in signals if s.status == "closed"]
    still_open = [s for s in signals if s.status == "triggered"]
    wins = [s for s in closed if s.outcome == "win"]
    losses = [s for s in closed if s.outcome == "loss"]

    print(f"\n{'=' * 70}")
    print(f"RESULTS — {ASSET_TICKER} GOLDEN POCKET STRATEGY")
    print(f"{'=' * 70}")
    print(f"\nTotal Signals: {len(signals)}")
    print(f"Closed: {len(closed)} | Still Open: {len(still_open)}")
    print(f"Wins: {len(wins)} | Losses: {len(losses)}")

    if closed:
        win_rate = len(wins) / len(closed) * 100
        avg_win = sum(s.outcome_pct for s in wins) / len(wins) if wins else 0
        avg_loss = sum(s.outcome_pct for s in losses) / len(losses) if losses else 0
        total_pnl = sum(s.outcome_pct for s in closed)
        gross_profit = sum(s.outcome_pct for s in closed if s.outcome_pct > 0)
        gross_loss = abs(sum(s.outcome_pct for s in closed if s.outcome_pct < 0))
        pf = gross_profit / gross_loss if gross_loss > 0 else float("inf")

        # T1 hit rate (among all closed)
        t1_hits = [s for s in closed if s.t1_hit_at is not None]

        # Average duration
        durations = [s.duration_hours for s in closed if s.duration_hours > 0]
        avg_duration = sum(durations) / len(durations) if durations else 0

        # Streak
        streak = 0
        for s in sorted(closed, key=lambda x: x.closed_at or x.entry_time, reverse=True):
            if s.outcome == "win":
                if streak >= 0:
                    streak += 1
                else:
                    break
            elif s.outcome == "loss":
                if streak <= 0:
                    streak -= 1
                else:
                    break

        print(f"\nWin Rate: {win_rate:.1f}%")
        print(f"T1 Hit Rate: {len(t1_hits)}/{len(closed)} ({len(t1_hits)/len(closed)*100:.1f}%)")
        print(f"Avg Win: {avg_win:+.2f}%")
        print(f"Avg Loss: {avg_loss:+.2f}%")
        print(f"Total P&L: {total_pnl:+.2f}%")
        print(f"Profit Factor: {pf:.2f}")
        print(f"Avg Duration: {avg_duration:.0f}h ({avg_duration/24:.1f}d)")
        print(f"Current Streak: {streak:+d}")

    # Signal-by-signal log
    print(f"\n{'=' * 70}")
    print("SIGNAL LOG")
    print(f"{'=' * 70}")
    print(f"{'Date':<12} {'Type':<12} {'Entry':>9} {'T1':>9} {'SL':>9} {'R:R':>5} "
          f"{'T1 Hit':>6} {'Outcome':<7} {'P&L':>7} {'Dur':>5}")
    print(f"{'-' * 90}")

    for s in sorted(signals, key=lambda x: x.entry_time):
        date_str = s.entry_time.strftime("%Y-%m-%d")
        t1_str = "Yes" if s.t1_hit_at else "No"
        outcome_str = s.outcome or "open"
        pnl_str = f"{s.outcome_pct:+.1f}%" if s.outcome else "..."
        dur_str = f"{s.duration_hours}h" if s.duration_hours else "..."
        print(f"{date_str:<12} {s.signal_type:<12} ${s.entry_mid:>8.2f} ${s.target1:>8.2f} "
              f"${s.stop_loss:>8.2f} {s.rr_ratio:>5.1f} {t1_str:>6} {outcome_str:<7} {pnl_str:>7} {dur_str:>5}")

    # Buy vs Sell breakdown
    if closed:
        buys = [s for s in closed if s.is_buy]
        sells = [s for s in closed if not s.is_buy]
        buy_wins = [s for s in buys if s.outcome == "win"]
        sell_wins = [s for s in sells if s.outcome == "win"]

        print(f"\n{'=' * 70}")
        print("DIRECTION BREAKDOWN")
        print(f"{'=' * 70}")
        if buys:
            print(f"LONG:  {len(buys)} trades | {len(buy_wins)} wins | {len(buy_wins)/len(buys)*100:.1f}% win rate | "
                  f"P&L: {sum(s.outcome_pct for s in buys):+.2f}%")
        if sells:
            print(f"SHORT: {len(sells)} trades | {len(sell_wins)} wins | {len(sell_wins)/len(sells)*100:.1f}% win rate | "
                  f"P&L: {sum(s.outcome_pct for s in sells):+.2f}%")

    # Monthly breakdown
    if closed:
        print(f"\n{'=' * 70}")
        print("MONTHLY BREAKDOWN")
        print(f"{'=' * 70}")
        print(f"{'Month':<10} {'Signals':>8} {'Wins':>6} {'Losses':>7} {'Win%':>6} {'P&L':>8}")
        print(f"{'-' * 50}")

        monthly = {}
        for s in closed:
            key = s.entry_time.strftime("%Y-%m")
            if key not in monthly:
                monthly[key] = {"signals": 0, "wins": 0, "losses": 0, "pnl": 0.0}
            monthly[key]["signals"] += 1
            if s.outcome == "win":
                monthly[key]["wins"] += 1
            else:
                monthly[key]["losses"] += 1
            monthly[key]["pnl"] += s.outcome_pct

        for month in sorted(monthly.keys()):
            m = monthly[month]
            wr = m["wins"] / m["signals"] * 100 if m["signals"] > 0 else 0
            print(f"{month:<10} {m['signals']:>8} {m['wins']:>6} {m['losses']:>7} {wr:>5.1f}% {m['pnl']:>+7.2f}%")

    print()


if __name__ == "__main__":
    run_backtest()
