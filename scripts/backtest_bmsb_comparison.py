#!/usr/bin/env python3
"""
Backtest: Bull Market Support Band Filter Comparison
Runs all 6 assets WITH and WITHOUT the 20W SMA / 21W EMA filter,
then compares results side-by-side.

Bull Market Support Band = 20-week SMA + 21-week EMA (calculated from daily candles).
- Price ABOVE both → bullish regime → longs allowed, shorts suppressed
- Price BELOW both → bearish regime → shorts allowed, longs suppressed
- Price BETWEEN them → neutral → both directions allowed
"""

import json
import time
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

# ─── Assets ──────────────────────────────────────────────────────────────────

ASSETS = [
    {"symbol": "BTCUSDT", "ticker": "BTC"},
    {"symbol": "ETHUSDT", "ticker": "ETH"},
    {"symbol": "SOLUSDT", "ticker": "SOL"},
    {"symbol": "SUIUSDT", "ticker": "SUI"},
    {"symbol": "LINKUSDT", "ticker": "LINK"},
    {"symbol": "ADAUSDT", "ticker": "ADA"},
]

# ─── Configuration (same as pipeline) ────────────────────────────────────────

TIMEFRAME_CONFIGS = [
    {"tf": "4h", "interval": "4h", "limit": 2400},
    {"tf": "1d", "interval": "1d", "limit": 500},
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

# Bull Market Support Band periods (in daily candles)
BMSB_SMA_PERIOD = 140   # 20 weeks × 7 days
BMSB_EMA_PERIOD = 147   # 21 weeks × 7 days

BACKTEST_DAYS = 365
WARMUP_CANDLES_4H = 60


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
    bmsb_filtered: bool = False  # True if this signal would be filtered by BMSB
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
class BacktestResults:
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
    long_pnl: float = 0.0
    short_count: int = 0
    short_wins: int = 0
    short_pnl: float = 0.0
    filtered_count: int = 0  # How many signals the BMSB filter would have removed


# ─── Fetch Historical Data ───────────────────────────────────────────────────

def fetch_candles(symbol: str, interval: str, limit: int) -> list[Candle]:
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

        all_candles = candles + all_candles
        end_time = int(candles[0].open_time.timestamp() * 1000) - 1

        if len(data) < batch:
            break
        time.sleep(0.3)

    return all_candles


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


# ─── EMA & Moving Average Helpers ─────────────────────────────────────────────

def calc_ema(candles: list[Candle], period: int) -> float | None:
    if len(candles) < period:
        return None
    multiplier = 2 / (period + 1)
    ema = sum(c.close for c in candles[:period]) / period
    for i in range(period, len(candles)):
        ema = (candles[i].close - ema) * multiplier + ema
    return ema


def calc_sma(candles: list[Candle], period: int) -> float | None:
    if len(candles) < period:
        return None
    return sum(c.close for c in candles[-period:]) / period


# ─── Bull Market Support Band Check ──────────────────────────────────────────

def check_bmsb(daily_candles: list[Candle], current_price: float, is_buy: bool) -> bool:
    """
    Bull Market Support Band: 20W SMA (140d) + 21W EMA (147d)

    Returns True if the signal direction is ALLOWED by the BMSB regime:
    - Price ABOVE both bands → bullish regime → longs OK, shorts suppressed
    - Price BELOW both bands → bearish regime → shorts OK, longs suppressed
    - Price BETWEEN bands → neutral → both directions OK
    """
    if len(daily_candles) < BMSB_EMA_PERIOD:
        return True  # Not enough data, allow all

    sma_20w = calc_sma(daily_candles, BMSB_SMA_PERIOD)
    ema_21w = calc_ema(daily_candles, BMSB_EMA_PERIOD)

    if sma_20w is None or ema_21w is None:
        return True

    band_top = max(sma_20w, ema_21w)
    band_bottom = min(sma_20w, ema_21w)

    if current_price > band_top:
        # Bullish regime — longs OK, suppress shorts
        return is_buy
    elif current_price < band_bottom:
        # Bearish regime — shorts OK, suppress longs
        return not is_buy
    else:
        # In the band — neutral, allow both
        return True


# ─── Trend Alignment ─────────────────────────────────────────────────────────

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

def compute_results(ticker: str, signals: list[Signal], filtered_only: bool = False) -> BacktestResults:
    """Compute results. If filtered_only=True, exclude BMSB-filtered signals."""
    if filtered_only:
        active_signals = [s for s in signals if not s.bmsb_filtered]
    else:
        active_signals = signals

    closed = [s for s in active_signals if s.status == "closed"]
    wins = [s for s in closed if s.outcome == "win"]
    losses = [s for s in closed if s.outcome == "loss"]

    buys = [s for s in closed if s.is_buy]
    sells = [s for s in closed if not s.is_buy]
    buy_wins = [s for s in buys if s.outcome == "win"]
    sell_wins = [s for s in sells if s.outcome == "win"]

    r = BacktestResults(ticker=ticker)
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
    r.short_count = len(sells)
    r.short_wins = len(sell_wins)
    r.short_pnl = sum(s.outcome_pct for s in sells)
    r.filtered_count = len([s for s in signals if s.bmsb_filtered and s.status == "closed"])

    return r


# ─── Main Backtest ────────────────────────────────────────────────────────────

def run_asset_backtest(asset_symbol: str, asset_ticker: str) -> list[Signal]:
    """Run backtest for a single asset. Returns all signals with bmsb_filtered flag."""
    print(f"\n  Fetching {asset_ticker} data...")

    candles = {}
    for config in TIMEFRAME_CONFIGS:
        tf = config["tf"]
        candles[tf] = fetch_candles(asset_symbol, config["interval"], config["limit"])
        print(f"    {tf}: {len(candles[tf])} candles")
        time.sleep(0.3)

    candles_4h = candles["4h"]
    candles_1d = candles["1d"]

    if len(candles_4h) < WARMUP_CANDLES_4H:
        print(f"    Not enough 4H data for {asset_ticker}")
        return []

    signals: list[Signal] = []

    for i in range(WARMUP_CANDLES_4H, len(candles_4h)):
        candle = candles_4h[i]
        eval_time = candle.open_time
        current_price = candle.close

        # Resolve open signals
        for sig in signals:
            if sig.status == "triggered":
                resolve_signal(sig, candle, eval_time)

        if i % 3 != 0:
            continue

        history_4h = candles_4h[:i + 1]
        history_1d = [c for c in candles_1d if c.open_time <= eval_time]

        swings_4h = detect_swings(history_4h[-250:], "4h")
        swings_1d = detect_swings(history_1d[-120:], "1d")

        fibs_4h = compute_fibs(swings_4h, "4h")
        fibs_1d = compute_fibs(swings_1d, "1d")
        all_fibs = fibs_4h + fibs_1d

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

            if not check_trend_alignment(history_4h, is_buy):
                continue

            if not check_bounce(history_4h[-25:], zone.low, zone.high, is_buy):
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

            # Check BMSB — flag the signal but still generate it for comparison
            bmsb_pass = check_bmsb(history_1d, current_price, is_buy)

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
                bmsb_filtered=not bmsb_pass,
                best_price=entry_mid,
                runner_stop=sl,
            )
            signals.append(signal)

    return signals


def main():
    print("=" * 80)
    print("BULL MARKET SUPPORT BAND FILTER — BACKTEST COMPARISON")
    print("20-week SMA + 21-week EMA regime filter")
    print("=" * 80)
    print(f"Period: ~{BACKTEST_DAYS} days | Golden Pocket: {FIB_RATIOS}")
    print(f"BMSB: Above both → longs only | Below both → shorts only | Between → both")

    all_results = {}

    for asset in ASSETS:
        ticker = asset["ticker"]
        signals = run_asset_backtest(asset["symbol"], ticker)

        # Compute results: without filter (baseline) and with filter
        baseline = compute_results(ticker, signals, filtered_only=False)
        filtered = compute_results(ticker, signals, filtered_only=True)
        all_results[ticker] = {"baseline": baseline, "filtered": filtered, "signals": signals}

        print(f"    {ticker}: {baseline.total} signals total, {filtered.filtered_count} would be filtered by BMSB")
        time.sleep(1)  # Rate limit between assets

    # ─── Comparison Table ─────────────────────────────────────────────────────

    print(f"\n\n{'=' * 100}")
    print("SIDE-BY-SIDE COMPARISON: WITHOUT vs WITH BMSB FILTER")
    print(f"{'=' * 100}")

    header = f"{'Asset':<6} │ {'Signals':>7} {'Win%':>6} {'PF':>5} {'P&L':>8} │ {'Signals':>7} {'Win%':>6} {'PF':>5} {'P&L':>8} │ {'Removed':>7} {'Win% Δ':>7} {'PF Δ':>6} {'P&L Δ':>8}"
    print(f"{'':>6} │ {'─── BASELINE (no filter) ───':^30} │ {'─── WITH BMSB FILTER ───':^30} │ {'─── DELTA ───':^24}")
    print(header)
    print("─" * 100)

    totals_base = {"signals": 0, "wins": 0, "pnl": 0.0, "gp": 0.0, "gl": 0.0}
    totals_filt = {"signals": 0, "wins": 0, "pnl": 0.0, "gp": 0.0, "gl": 0.0, "removed": 0}

    for ticker in [a["ticker"] for a in ASSETS]:
        b = all_results[ticker]["baseline"]
        f = all_results[ticker]["filtered"]

        wr_delta = f.win_rate - b.win_rate
        pf_delta = f.profit_factor - b.profit_factor
        pnl_delta = f.total_pnl - b.total_pnl

        print(f"{ticker:<6} │ {b.total:>7} {b.win_rate:>5.1f}% {b.profit_factor:>5.2f} {b.total_pnl:>+7.2f}% │ "
              f"{f.total:>7} {f.win_rate:>5.1f}% {f.profit_factor:>5.2f} {f.total_pnl:>+7.2f}% │ "
              f"{f.filtered_count:>7} {wr_delta:>+6.1f}% {pf_delta:>+5.2f} {pnl_delta:>+7.2f}%")

        totals_base["signals"] += b.total
        totals_base["wins"] += b.wins
        totals_base["pnl"] += b.total_pnl
        totals_filt["signals"] += f.total
        totals_filt["wins"] += f.wins
        totals_filt["pnl"] += f.total_pnl
        totals_filt["removed"] += f.filtered_count

    print("─" * 100)

    # Totals
    base_wr = totals_base["wins"] / totals_base["signals"] * 100 if totals_base["signals"] > 0 else 0
    filt_wr = totals_filt["wins"] / totals_filt["signals"] * 100 if totals_filt["signals"] > 0 else 0
    print(f"{'TOTAL':<6} │ {totals_base['signals']:>7} {base_wr:>5.1f}%       {totals_base['pnl']:>+7.2f}% │ "
          f"{totals_filt['signals']:>7} {filt_wr:>5.1f}%       {totals_filt['pnl']:>+7.2f}% │ "
          f"{totals_filt['removed']:>7} {filt_wr - base_wr:>+6.1f}%       {totals_filt['pnl'] - totals_base['pnl']:>+7.2f}%")

    # ─── Detailed: What got filtered ──────────────────────────────────────────

    print(f"\n\n{'=' * 100}")
    print("FILTERED SIGNALS DETAIL — Signals that BMSB would have removed")
    print(f"{'=' * 100}")
    print(f"{'Date':<12} {'Asset':<6} {'Type':<12} {'Entry':>10} {'BMSB Regime':<14} {'Outcome':<7} {'P&L':>7}")
    print("─" * 75)

    for ticker in [a["ticker"] for a in ASSETS]:
        signals = all_results[ticker]["signals"]
        filtered_sigs = sorted(
            [s for s in signals if s.bmsb_filtered and s.status == "closed"],
            key=lambda s: s.entry_time
        )
        for s in filtered_sigs:
            regime = "BEARISH (long)" if s.is_buy else "BULLISH (short)"
            outcome_str = s.outcome or "open"
            pnl_str = f"{s.outcome_pct:+.1f}%" if s.outcome else "..."
            print(f"{s.entry_time.strftime('%Y-%m-%d'):<12} {ticker:<6} {s.signal_type:<12} "
                  f"${s.entry_mid:>9.2f} {regime:<14} {outcome_str:<7} {pnl_str:>7}")

    # ─── Direction breakdown with BMSB ────────────────────────────────────────

    print(f"\n\n{'=' * 100}")
    print("DIRECTION BREAKDOWN — WITH BMSB FILTER")
    print(f"{'=' * 100}")
    print(f"{'Asset':<6} │ {'Long Trades':>11} {'Long Win%':>10} {'Long P&L':>10} │ {'Short Trades':>12} {'Short Win%':>11} {'Short P&L':>11}")
    print("─" * 80)

    for ticker in [a["ticker"] for a in ASSETS]:
        f = all_results[ticker]["filtered"]
        long_wr = f.long_wins / f.long_count * 100 if f.long_count > 0 else 0
        short_wr = f.short_wins / f.short_count * 100 if f.short_count > 0 else 0
        print(f"{ticker:<6} │ {f.long_count:>11} {long_wr:>9.1f}% {f.long_pnl:>+9.2f}% │ "
              f"{f.short_count:>12} {short_wr:>10.1f}% {f.short_pnl:>+10.2f}%")

    print()


if __name__ == "__main__":
    main()
