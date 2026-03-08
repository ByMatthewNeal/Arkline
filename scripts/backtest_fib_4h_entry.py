#!/usr/bin/env python3
"""
Backtest: Fibonacci 0.618/0.786 — 4h Entry / 1D Bias (Multi-Day Holds)
Simplified: Only 0.618 and 0.786 Fib retracements.
EMA trend filter on both assets. 50% at T1, trail runner.
"""

import json
import math
import time
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

# ─── Configuration ────────────────────────────────────────────────────────────

ASSETS = {
    "BTCUSDT": "BTC",
    # "SOLUSDT": "SOL",  # Disabled — BTC only performs better on 4h/1D
}

# Timeframes: 4h for entry, 1d for higher-TF confluence
TIMEFRAME_CONFIGS = [
    {"tf": "4h", "interval": "4h", "candles_needed": 2700},    # ~450 days (365 + warmup)
    {"tf": "1d", "interval": "1d", "candles_needed": 500},     # ~500 days
]

# Swing detection params (wider for higher TFs)
SWING_PARAMS = {
    "4h":  {"lookback": 8, "min_reversal": 5.0},
    "1d":  {"lookback": 5, "min_reversal": 8.0},
}

# Only the golden pocket — 0.618 and 0.786
FIB_RATIOS = [0.618, 0.786]
EXT_RATIOS = []  # No extensions

CONFLUENCE_TOLERANCE_PCT = 1.5   # Wider clustering for 4h
SIGNAL_PROXIMITY_PCT = 2.0      # Price within 2% of zone (wider for 4h)
MIN_RR_RATIO = 1.0
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
SIGNAL_EXPIRY_BARS = 18          # 18 x 4h = 72 hours = 3 days
WICK_REJECTION_RATIO = 1.5
VOLUME_SPIKE_RATIO = 1.3

BACKTEST_DAYS = 365
WARMUP_BARS = 50  # 50 x 4h = ~8 days warmup

# Only enter on US session 4h candles (7am + 11am EST)
US_SESSION_CANDLE_HOURS = [12, 16]  # 12:00 UTC = 7am EST, 16:00 UTC = 11am EST

# Leverage / portfolio
STARTING_BALANCE = 1_000
POSITION_SIZE_PCT = 10
LEVERAGE_LEVELS = [15]
TAKER_FEE = 0.0004
FUNDING_RATE_8H = 0.0001
MAINTENANCE_MARGIN_RATE = 0.004


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
    asset: str
    timeframe: str
    candle_time: datetime
    swing_type: str
    price: float

@dataclass
class FibLevel:
    asset: str
    timeframe: str
    ratio: float
    price: float
    level_type: str

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
    confluence_strength: int
    expires_at: datetime
    outcome: str = "open"
    exit_price: float = 0.0
    exit_time: datetime = None
    pnl_pct: float = 0.0
    t1_hit: bool = False
    # Runner tracking (50% at T1, 50% trails)
    best_price: float = 0.0       # best price reached after T1
    runner_stop: float = 0.0      # trailing stop for runner
    runner_exit: float = 0.0      # where runner closed
    runner_pnl_pct: float = 0.0   # runner half P&L
    t1_pnl_pct: float = 0.0      # first half P&L (at T1)
    risk_1r: float = 0.0         # 1R distance in price


# ─── Fetch Data ───────────────────────────────────────────────────────────────

def fetch_klines_paginated(symbol: str, interval: str, total_needed: int) -> list[Candle]:
    all_candles = []
    end_time = None
    remaining = total_needed

    while remaining > 0:
        batch = min(remaining, 1000)
        url = f"https://api.binance.com/api/v3/klines?symbol={symbol}&interval={interval}&limit={batch}"
        if end_time:
            url += f"&endTime={end_time}"

        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
        except Exception as e:
            print(f"  Error: {e}")
            break

        if not data:
            break

        candles = []
        for k in data:
            candles.append(Candle(
                open_time=datetime.fromtimestamp(k[0] / 1000, tz=timezone.utc),
                open=float(k[1]), high=float(k[2]),
                low=float(k[3]), close=float(k[4]),
                volume=float(k[5]),
            ))

        all_candles = candles + all_candles
        remaining -= len(candles)

        if len(candles) < batch:
            break

        end_time = int(candles[0].open_time.timestamp() * 1000) - 1
        time.sleep(0.2)

    return all_candles


def fetch_all_data() -> dict[str, dict[str, list[Candle]]]:
    all_data = {}
    total_fetches = len(ASSETS) * len(TIMEFRAME_CONFIGS)
    count = 0

    for symbol, ticker in ASSETS.items():
        all_data[ticker] = {}
        for tf_config in TIMEFRAME_CONFIGS:
            count += 1
            tf = tf_config["tf"]
            needed = tf_config["candles_needed"]
            pages = math.ceil(needed / 1000)
            print(f"  [{count}/{total_fetches}] Fetching {ticker} {tf} (~{needed} candles, {pages} pages)...", end="", flush=True)
            candles = fetch_klines_paginated(symbol, tf_config["interval"], needed)
            all_data[ticker][tf] = candles
            print(f" {len(candles)} candles")

    return all_data


# ─── Swing Detection ─────────────────────────────────────────────────────────

def detect_swings(candles: list[Candle], asset: str, tf: str) -> list[SwingPoint]:
    params = SWING_PARAMS[tf]
    lookback = params["lookback"]
    min_reversal = params["min_reversal"]
    swings = []

    if len(candles) < lookback * 2 + 1:
        return swings

    for i in range(lookback, len(candles) - lookback):
        high = candles[i].high
        low = candles[i].low

        is_high = all(candles[j].high < high for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_high:
            surrounding_lows = [candles[j].low for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_lows:
                reversal_pct = ((high - min(surrounding_lows)) / min(surrounding_lows)) * 100
                if reversal_pct >= min_reversal:
                    swings.append(SwingPoint(asset, tf, candles[i].open_time, "high", high))

        is_low = all(candles[j].low > low for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_low:
            surrounding_highs = [candles[j].high for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_highs:
                reversal_pct = ((max(surrounding_highs) - low) / low) * 100
                if reversal_pct >= min_reversal:
                    swings.append(SwingPoint(asset, tf, candles[i].open_time, "low", low))

    return swings


# ─── Fibonacci Levels ─────────────────────────────────────────────────────────

def compute_fib_levels(swings: list[SwingPoint], asset: str, tf: str) -> list[FibLevel]:
    highs = sorted([s for s in swings if s.swing_type == "high"], key=lambda s: s.candle_time, reverse=True)
    lows = sorted([s for s in swings if s.swing_type == "low"], key=lambda s: s.candle_time, reverse=True)

    if not highs or not lows:
        return []

    levels = []
    for sh in highs[:3]:
        for sl in lows[:3]:
            if sh.price <= sl.price:
                continue
            diff = sh.price - sl.price
            for ratio in FIB_RATIOS:
                # Retracement from high (support for longs)
                levels.append(FibLevel(asset, tf, ratio, sh.price - diff * ratio, "retracement"))
                # Retracement from low (resistance for shorts)
                levels.append(FibLevel(asset, tf, ratio, sl.price + diff * ratio, "retracement"))
    return levels


# ─── Confluence Clustering ────────────────────────────────────────────────────

def cluster_levels(levels: list[FibLevel], current_price: float) -> list[dict]:
    if not levels:
        return []

    nearby = [l for l in levels if abs((l.price - current_price) / current_price) * 100 <= 15]
    if not nearby:
        return []

    nearby.sort(key=lambda l: l.price)
    clusters = []
    current_cluster = [nearby[0]]
    cluster_low = nearby[0].price
    cluster_high = nearby[0].price

    for i in range(1, len(nearby)):
        level = nearby[i]
        cluster_mid = (cluster_low + cluster_high) / 2
        distance_pct = abs((level.price - cluster_mid) / cluster_mid) * 100

        if distance_pct <= CONFLUENCE_TOLERANCE_PCT:
            current_cluster.append(level)
            cluster_high = max(cluster_high, level.price)
            cluster_low = min(cluster_low, level.price)
        else:
            if len(current_cluster) >= 2:
                mid = (cluster_low + cluster_high) / 2
                zone_type = "support" if mid < current_price else "resistance"
                tfs = set(l.timeframe for l in current_cluster)
                clusters.append({
                    "low": cluster_low, "high": cluster_high, "mid": mid,
                    "strength": len(current_cluster), "zone_type": zone_type,
                    "tf_count": len(tfs),
                })
            current_cluster = [level]
            cluster_low = level.price
            cluster_high = level.price

    if len(current_cluster) >= 2:
        mid = (cluster_low + cluster_high) / 2
        zone_type = "support" if mid < current_price else "resistance"
        tfs = set(l.timeframe for l in current_cluster)
        clusters.append({
            "low": cluster_low, "high": cluster_high, "mid": mid,
            "strength": len(current_cluster), "zone_type": zone_type,
            "tf_count": len(tfs),
        })

    return clusters


# ─── EMA Trend Filter (on 4h candles) ────────────────────────────────────────

def calc_ema(candles: list[Candle], period: int) -> float | None:
    if len(candles) < period:
        return None
    multiplier = 2 / (period + 1)
    ema = sum(c.close for c in candles[:period]) / period
    for c in candles[period:]:
        ema = (c.close - ema) * multiplier + ema
    return ema


def check_trend_alignment(candles_4h: list[Candle], is_buy: bool) -> bool:
    """
    EMA 20/50 on 4h chart for trend direction.
    Slope check over last 6 candles (24h) for momentum.
    """
    if len(candles_4h) < 55:
        return True

    ema_fast = calc_ema(candles_4h, 20)
    ema_slow = calc_ema(candles_4h, 50)
    ema_slow_prev = calc_ema(candles_4h[:-6], 50)

    if ema_fast is None or ema_slow is None or ema_slow_prev is None:
        return True

    price = candles_4h[-1].close
    ema_slope_up = ema_slow > ema_slow_prev
    ema_slope_down = ema_slow < ema_slow_prev

    if is_buy:
        trend_ok = ema_fast > ema_slow
        pullback_ok = ema_slope_up and abs(price - ema_slow) / ema_slow < 0.008
        return trend_ok or pullback_ok
    else:
        trend_ok = ema_fast < ema_slow
        pullback_ok = ema_slope_down and abs(price - ema_slow) / ema_slow < 0.008
        return trend_ok or pullback_ok


# ─── Bounce Confirmation (on 4h candles) ─────────────────────────────────────

def check_bounce(candles: list[Candle], zone_low: float, zone_high: float, is_buy: bool) -> bool:
    if len(candles) < 3:
        return False

    latest = candles[-1]
    prev = candles[-2]

    if is_buy:
        body = abs(latest.close - latest.open)
        lower_wick = min(latest.open, latest.close) - latest.low
        wick_ok = lower_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close > zone_low
        consec_ok = latest.close > zone_high and prev.close > zone_high and prev.low <= zone_high
    else:
        body = abs(latest.close - latest.open)
        upper_wick = latest.high - max(latest.open, latest.close)
        wick_ok = upper_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close < zone_high
        consec_ok = latest.close < zone_low and prev.close < zone_low and prev.high >= zone_low

    vol_candles = candles[-21:-1]
    vol_ok = False
    if len(vol_candles) >= 10 and latest.volume > 0:
        avg_vol = sum(c.volume for c in vol_candles) / len(vol_candles)
        if avg_vol > 0 and latest.volume >= VOLUME_SPIKE_RATIO * avg_vol:
            vol_ok = True

    return wick_ok or vol_ok or consec_ok


# ─── Target & Stop ───────────────────────────────────────────────────────────

def compute_targets_and_stop(zone: dict, all_fib_prices: list[float], is_buy: bool):
    all_prices = sorted(all_fib_prices)
    zone_mid = zone["mid"]

    if is_buy:
        levels_below = [p for p in all_prices if p < zone["low"]]
        next_down = levels_below[-1] if levels_below else None
        stop_loss = next_down * 0.997 if next_down else zone_mid * 0.985  # Slightly wider for 4h

        levels_above = [p for p in all_prices if p > zone["high"]]
        target1 = levels_above[0] if levels_above else zone_mid * 1.03
        target2 = levels_above[1] if len(levels_above) > 1 else target1 * 1.015
    else:
        levels_above = [p for p in all_prices if p > zone["high"]]
        next_up = levels_above[0] if levels_above else None
        stop_loss = next_up * 1.003 if next_up else zone_mid * 1.015

        levels_below = [p for p in all_prices if p < zone["low"]]
        target1 = levels_below[-1] if levels_below else zone_mid * 0.97
        target2 = levels_below[-2] if len(levels_below) > 1 else target1 * 0.985

    return target1, target2, stop_loss


# ─── Leverage Helpers ─────────────────────────────────────────────────────────

def calc_liquidation_price(entry: float, leverage: int, is_long: bool) -> float:
    if is_long:
        return entry * (1 - 1 / leverage + MAINTENANCE_MARGIN_RATE)
    else:
        return entry * (1 + 1 / leverage - MAINTENANCE_MARGIN_RATE)


def calc_leveraged_pnl(entry: float, exit_price: float, leverage: int, is_long: bool,
                        position_usd: float, hours_held: float):
    if is_long:
        raw_pnl_pct = (exit_price - entry) / entry
    else:
        raw_pnl_pct = (entry - exit_price) / entry

    leveraged_pnl_pct = raw_pnl_pct * leverage
    fees = position_usd * TAKER_FEE * 2
    funding_periods = hours_held / 8
    funding = position_usd * FUNDING_RATE_8H * funding_periods
    margin = position_usd / leverage
    pnl_usd = margin * leveraged_pnl_pct - fees - funding
    pnl_pct_on_margin = (pnl_usd / margin) * 100 if margin > 0 else 0

    return pnl_usd, pnl_pct_on_margin, fees, funding


# ─── Signal Resolution (50% at T1, trail runner with 1R stop) ────────────────

def _resolve_signal(s: Signal, candle: Candle, eval_time: datetime):
    is_buy = "buy" in s.signal_type

    # --- Expiry ---
    if eval_time > s.expires_at:
        s.exit_time = eval_time
        s.exit_price = candle.close
        if s.t1_hit:
            runner_pnl = ((candle.close - s.entry_mid) / s.entry_mid * 100) if is_buy else ((s.entry_mid - candle.close) / s.entry_mid * 100)
            s.runner_exit = candle.close
            s.runner_pnl_pct = runner_pnl
            s.pnl_pct = (s.t1_pnl_pct + runner_pnl) / 2
            s.outcome = "win" if s.pnl_pct > 0 else "expired"
        else:
            s.pnl_pct = ((candle.close - s.entry_mid) / s.entry_mid * 100) if is_buy else ((s.entry_mid - candle.close) / s.entry_mid * 100)
            s.outcome = "expired"
        return

    if is_buy:
        if not s.t1_hit:
            if candle.low <= s.stop_loss:
                s.outcome = "loss"
                s.exit_price = s.stop_loss
                s.exit_time = eval_time
                s.pnl_pct = (s.stop_loss - s.entry_mid) / s.entry_mid * 100
                return
            if candle.high >= s.target1:
                s.t1_hit = True
                s.t1_pnl_pct = (s.target1 - s.entry_mid) / s.entry_mid * 100
                s.best_price = candle.high
                s.runner_stop = s.entry_mid
        else:
            s.best_price = max(s.best_price, candle.high)
            s.runner_stop = max(s.runner_stop, s.best_price - s.risk_1r)

            if candle.low <= s.runner_stop:
                s.runner_exit = s.runner_stop
                s.runner_pnl_pct = (s.runner_stop - s.entry_mid) / s.entry_mid * 100
                s.pnl_pct = (s.t1_pnl_pct + s.runner_pnl_pct) / 2
                s.exit_price = s.runner_stop
                s.exit_time = eval_time
                s.outcome = "win" if s.pnl_pct > 0 else "loss"
    else:
        if not s.t1_hit:
            if candle.high >= s.stop_loss:
                s.outcome = "loss"
                s.exit_price = s.stop_loss
                s.exit_time = eval_time
                s.pnl_pct = (s.entry_mid - s.stop_loss) / s.entry_mid * 100
                return
            if candle.low <= s.target1:
                s.t1_hit = True
                s.t1_pnl_pct = (s.entry_mid - s.target1) / s.entry_mid * 100
                s.best_price = candle.low
                s.runner_stop = s.entry_mid
        else:
            s.best_price = min(s.best_price, candle.low)
            s.runner_stop = min(s.runner_stop, s.best_price + s.risk_1r)

            if candle.high >= s.runner_stop:
                s.runner_exit = s.runner_stop
                s.runner_pnl_pct = (s.entry_mid - s.runner_stop) / s.entry_mid * 100
                s.pnl_pct = (s.t1_pnl_pct + s.runner_pnl_pct) / 2
                s.exit_price = s.runner_stop
                s.exit_time = eval_time
                s.outcome = "win" if s.pnl_pct > 0 else "loss"


# ─── Walk-Forward on 4h Candles ──────────────────────────────────────────────

def generate_signals(all_data: dict) -> list[Signal]:
    signals: list[Signal] = []
    now = datetime.now(tz=timezone.utc)
    start_date = now - timedelta(days=BACKTEST_DAYS)

    for ticker in ASSETS.values():
        candles_4h = all_data[ticker].get("4h", [])
        candles_1d = all_data[ticker].get("1d", [])

        if len(candles_4h) < WARMUP_BARS + 100:
            print(f"  Skipping {ticker}: only {len(candles_4h)} 4h candles")
            continue

        print(f"  Processing {ticker}: {len(candles_4h)} bars...", end="", flush=True)
        ticker_signals = 0

        # Walk forward on 4h bars
        for bar_idx in range(WARMUP_BARS, len(candles_4h)):
            eval_candle = candles_4h[bar_idx]
            eval_time = eval_candle.open_time

            if eval_time < start_date:
                continue

            # Only enter on US session 4h candles (12:00 and 16:00 UTC)
            hour_utc = eval_time.hour
            is_entry_candle = hour_utc in US_SESSION_CANDLE_HOURS

            # Always resolve open signals
            for s in signals:
                if s.outcome != "open" or s.asset != ticker:
                    continue
                _resolve_signal(s, eval_candle, eval_time)

            if not is_entry_candle:
                continue

            current_price = eval_candle.close

            # Get history up to this point
            history_4h = candles_4h[:bar_idx + 1]
            history_1d = [c for c in candles_1d if c.open_time <= eval_time]

            # Detect swings and compute fibs on 4h and 1d
            all_fib_levels = []
            for tf, history in [("4h", history_4h[-200:]), ("1d", history_1d[-100:])]:
                if len(history) < 20:
                    continue
                swings = detect_swings(history, ticker, tf)
                fibs = compute_fib_levels(swings, ticker, tf)
                all_fib_levels.extend(fibs)

            if not all_fib_levels:
                continue

            zones = cluster_levels(all_fib_levels, current_price)
            all_fib_prices = [l.price for l in all_fib_levels]

            for zone in zones:
                distance_pct = abs((current_price - zone["mid"]) / current_price) * 100
                if distance_pct > SIGNAL_PROXIMITY_PCT:
                    continue

                # Duplicate check
                duplicate = False
                for s in signals:
                    if s.asset == ticker and s.outcome == "open":
                        if abs(s.entry_mid - zone["mid"]) / zone["mid"] < 0.008:
                            duplicate = True
                            break
                if duplicate:
                    continue

                is_buy = zone["zone_type"] == "support"

                # EMA trend direction filter on 4h
                if not check_trend_alignment(history_4h, is_buy):
                    continue

                # Bounce confirmation on 4h candles
                recent_4h = history_4h[-25:]
                if not check_bounce(recent_4h, zone["low"], zone["high"], is_buy):
                    continue

                t1, t2, sl = compute_targets_and_stop(zone, all_fib_prices, is_buy)
                if t1 is None or sl is None:
                    continue

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

                expires = eval_time + timedelta(hours=4 * SIGNAL_EXPIRY_BARS)

                signal = Signal(
                    asset=ticker, signal_type=sig_type, entry_time=eval_time,
                    entry_mid=entry_mid, entry_low=zone["low"], entry_high=zone["high"],
                    target1=t1, target2=t2, stop_loss=sl,
                    rr_ratio=round(rr, 2), confluence_strength=zone["strength"],
                    expires_at=expires,
                    best_price=entry_mid,
                    runner_stop=sl,
                    risk_1r=risk_dist,
                )
                signals.append(signal)
                ticker_signals += 1

        print(f" {ticker_signals} signals")

    # Mark remaining open
    for s in signals:
        if s.outcome == "open":
            for tn in ASSETS.values():
                candles = all_data[tn].get("4h", [])
                if candles and tn == s.asset:
                    price = candles[-1].close
                    is_buy = "buy" in s.signal_type
                    s.pnl_pct = ((price - s.entry_mid) / s.entry_mid * 100) if is_buy else ((s.entry_mid - price) / s.entry_mid * 100)

    return signals


# ─── Simulate Leverage ────────────────────────────────────────────────────────

def simulate_leverage(signals: list[Signal], leverage: int, margin_mode: str) -> dict:
    balance = STARTING_BALANCE
    peak_balance = balance
    max_drawdown = 0.0
    total_fees = 0.0
    total_funding = 0.0
    liquidations = 0
    trades_data = []

    for signal in sorted(signals, key=lambda s: s.entry_time):
        if signal.outcome == "open":
            continue

        is_long = "buy" in signal.signal_type
        entry = signal.entry_mid
        margin_for_trade = balance * (POSITION_SIZE_PCT / 100)
        if margin_for_trade < 1:
            continue

        position_usd = margin_for_trade * leverage
        liq_price = calc_liquidation_price(entry, leverage, is_long)

        # Check liquidation
        was_liquidated = False
        if is_long and signal.outcome in ("loss", "expired") and signal.exit_price <= liq_price:
            was_liquidated = True
        elif not is_long and signal.outcome in ("loss", "expired") and signal.exit_price >= liq_price:
            was_liquidated = True

        if signal.exit_time and signal.entry_time:
            hours_held = max(0.25, (signal.exit_time - signal.entry_time).total_seconds() / 3600)
        else:
            hours_held = (SIGNAL_EXPIRY_BARS * 4)

        if was_liquidated:
            pnl_usd = -margin_for_trade
            fees = position_usd * TAKER_FEE
            funding = position_usd * FUNDING_RATE_8H * (hours_held / 8)
            pnl_pct_on_margin = -100.0
            liquidations += 1
        else:
            exit_price = signal.exit_price if signal.exit_price > 0 else entry
            pnl_usd, pnl_pct_on_margin, fees, funding = calc_leveraged_pnl(
                entry, exit_price, leverage, is_long, position_usd, hours_held
            )

        trades_data.append({
            "signal": signal, "leverage": leverage, "margin_mode": margin_mode,
            "margin": margin_for_trade, "position_usd": position_usd,
            "liq_price": liq_price, "is_long": is_long,
            "pnl_usd": pnl_usd, "roi_pct": pnl_pct_on_margin,
            "fees": fees, "funding": funding, "liquidated": was_liquidated,
        })

        balance += pnl_usd
        total_fees += fees
        total_funding += funding
        if balance > peak_balance:
            peak_balance = balance
        dd = (peak_balance - balance) / peak_balance * 100
        if dd > max_drawdown:
            max_drawdown = dd
        if balance <= 0:
            balance = 0
            break

    winning = [t for t in trades_data if t["pnl_usd"] > 0]

    return {
        "leverage": leverage, "margin_mode": margin_mode,
        "trades": len(trades_data), "wins": len(winning),
        "losses": len(trades_data) - len(winning), "liquidations": liquidations,
        "win_rate": len(winning) / len(trades_data) * 100 if trades_data else 0,
        "ending_balance": round(balance, 2),
        "total_return_pct": round((balance - STARTING_BALANCE) / STARTING_BALANCE * 100, 2),
        "max_drawdown_pct": round(max_drawdown, 2),
        "total_fees": round(total_fees, 2), "total_funding": round(total_funding, 2),
        "avg_roi": round(sum(t["roi_pct"] for t in trades_data) / len(trades_data), 2) if trades_data else 0,
        "best_trade": round(max(t["roi_pct"] for t in trades_data), 2) if trades_data else 0,
        "worst_trade": round(min(t["roi_pct"] for t in trades_data), 2) if trades_data else 0,
        "trades_list": trades_data,
    }


# ─── Print Results ────────────────────────────────────────────────────────────

def print_results(signals: list[Signal], leverage_results: list[dict]):
    closed = [s for s in signals if s.outcome in ("win", "partial", "loss")]
    wins = [s for s in signals if s.outcome == "win"]
    partials = [s for s in signals if s.outcome == "partial"]
    losses = [s for s in signals if s.outcome == "loss"]
    expired = [s for s in signals if s.outcome == "expired"]
    still_open = [s for s in signals if s.outcome == "open"]

    print(f"\n{'='*70}")
    print("SPOT BASELINE")
    print(f"{'='*70}")
    print(f"Total: {len(signals)} | W: {len(wins)} | P: {len(partials)} | L: {len(losses)} | Exp: {len(expired)} | Open: {len(still_open)}")

    if closed:
        wr = (len(wins) + len(partials)) / len(closed) * 100
        avg_win = sum(s.pnl_pct for s in wins) / len(wins) if wins else 0
        avg_loss = sum(s.pnl_pct for s in losses) / len(losses) if losses else 0
        total_pnl = sum(s.pnl_pct for s in closed)
        gp = sum(s.pnl_pct for s in closed if s.pnl_pct > 0)
        gl = abs(sum(s.pnl_pct for s in closed if s.pnl_pct < 0))
        pf = gp / gl if gl > 0 else float("inf")

        print(f"Win Rate: {wr:.1f}% | Avg Win: {avg_win:+.2f}% | Avg Loss: {avg_loss:+.2f}%")
        print(f"Total P&L: {total_pnl:+.2f}% | Profit Factor: {pf:.2f}")
        print(f"Avg P&L/trade: {total_pnl/len(closed):+.3f}%")

    # Per-asset
    print(f"\nPer-Asset:")
    print(f"  {'Asset':<6} {'Total':>5} {'W':>3} {'P':>3} {'L':>3} {'Exp':>4} {'Win%':>6} {'Total P&L':>9}")
    for asset in sorted(set(s.asset for s in signals)):
        a_all = [s for s in signals if s.asset == asset]
        a_closed = [s for s in a_all if s.outcome in ("win", "partial", "loss")]
        aw = len([s for s in a_all if s.outcome == "win"])
        ap = len([s for s in a_all if s.outcome == "partial"])
        al = len([s for s in a_all if s.outcome == "loss"])
        ae = len([s for s in a_all if s.outcome == "expired"])
        awr = (aw + ap) / len(a_closed) * 100 if a_closed else 0
        apnl = sum(s.pnl_pct for s in a_closed)
        print(f"  {asset:<6} {len(a_all):>5} {aw:>3} {ap:>3} {al:>3} {ae:>4} {awr:>5.1f}% {apnl:>+8.2f}%")

    # Leverage table
    print(f"\n{'='*70}")
    print("LEVERAGE COMPARISON")
    print(f"{'='*70}")
    print(f"\n{'':>6} {'Mode':<6} {'Trades':>6} {'Win%':>6} {'Liq':>4} {'End Bal':>10} "
          f"{'Return':>8} {'MaxDD':>7} {'Fees':>7} {'Fund':>7} {'AvgROI':>8} {'Best':>8} {'Worst':>8}")
    print(f"  {'-'*100}")

    for r in leverage_results:
        m = r["margin_mode"][:4].title()
        print(f"  {r['leverage']:>2}x  {m:<6} {r['trades']:>6} {r['win_rate']:>5.1f}% {r['liquidations']:>4} "
              f"${r['ending_balance']:>9,.2f} {r['total_return_pct']:>+7.1f}% {r['max_drawdown_pct']:>6.1f}% "
              f"${r['total_fees']:>6.2f} ${r['total_funding']:>6.2f} {r['avg_roi']:>+7.1f}% "
              f"{r['best_trade']:>+7.1f}% {r['worst_trade']:>+7.1f}%")

    # Signal log
    print(f"\n{'='*70}")
    print("SIGNAL LOG (times in EST) — 4h Entry / 1D Bias — 50% at T1 + Trail Runner")
    print(f"{'='*70}")
    print(f"{'#':<4} {'DateTime EST':<18} {'Asset':<6} {'Type':<12} {'Entry':>10} {'T1':>10} {'SL':>10} {'R:R':>5} {'Out':<8} {'T1 P&L':>7} {'Runner':>7} {'Total':>7} {'R-Mult':>6} {'Duration'}")
    print(f"{'-'*130}")

    for idx, s in enumerate(sorted(signals, key=lambda x: x.entry_time), 1):
        est_time = s.entry_time - timedelta(hours=5)
        dt_str = est_time.strftime("%m/%d %I:%M%p").replace("AM","am").replace("PM","pm")
        if s.exit_time and s.entry_time:
            dur_hrs = (s.exit_time - s.entry_time).total_seconds() / 3600
            if dur_hrs < 1:
                dur_str = f"{int(dur_hrs * 60)}m"
            elif dur_hrs < 24:
                dur_str = f"{dur_hrs:.1f}h"
            else:
                days = dur_hrs / 24
                dur_str = f"{days:.1f}d"
        else:
            dur_str = "-"

        if s.outcome == "open":
            print(f"{idx:<4} {dt_str:<18} {s.asset:<6} {s.signal_type:<12} {s.entry_mid:>10,.2f} {s.target1:>10,.2f} {s.stop_loss:>10,.2f} {s.rr_ratio:>5.1f} {'open':<8} {'...':>7} {'...':>7} {'...':>7} {'...':>6} {dur_str}")
        elif s.t1_hit:
            t1_str = f"{s.t1_pnl_pct:+.2f}%"
            run_str = f"{s.runner_pnl_pct:+.2f}%"
            tot_str = f"{s.pnl_pct:+.2f}%"
            r_mult = s.pnl_pct / (s.risk_1r / s.entry_mid * 100) if s.risk_1r > 0 else 0
            r_str = f"{r_mult:+.1f}R"
            print(f"{idx:<4} {dt_str:<18} {s.asset:<6} {s.signal_type:<12} {s.entry_mid:>10,.2f} {s.target1:>10,.2f} {s.stop_loss:>10,.2f} {s.rr_ratio:>5.1f} {s.outcome:<8} {t1_str:>7} {run_str:>7} {tot_str:>7} {r_str:>6} {dur_str}")
        else:
            tot_str = f"{s.pnl_pct:+.2f}%"
            r_mult = s.pnl_pct / (s.risk_1r / s.entry_mid * 100) if s.risk_1r > 0 else 0
            r_str = f"{r_mult:+.1f}R"
            print(f"{idx:<4} {dt_str:<18} {s.asset:<6} {s.signal_type:<12} {s.entry_mid:>10,.2f} {s.target1:>10,.2f} {s.stop_loss:>10,.2f} {s.rr_ratio:>5.1f} {s.outcome:<8} {'—':>7} {'—':>7} {tot_str:>7} {r_str:>6} {dur_str}")

    print()


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    print("=" * 70)
    print("FIBONACCI 0.618/0.786 BACKTEST — 4h ENTRY / 1D BIAS (MULTI-DAY)")
    print("=" * 70)
    print(f"Period: {BACKTEST_DAYS} days | Assets: {', '.join(ASSETS.values())}")
    print(f"Fibs: 0.618 + 0.786 only | Entry: 4h | Bias: 1D")
    print(f"EMA trend filter: 20/50 on 4h | Entry candles: {US_SESSION_CANDLE_HOURS} UTC")
    print(f"Expiry: {SIGNAL_EXPIRY_BARS} bars ({SIGNAL_EXPIRY_BARS * 4}h = {SIGNAL_EXPIRY_BARS * 4 / 24:.1f} days)")
    print(f"Proximity: {SIGNAL_PROXIMITY_PCT}% | Confluence tol: {CONFLUENCE_TOLERANCE_PCT}%")
    print(f"Strategy: 50% at T1, trail runner with 1R stop")
    print(f"Balance: ${STARTING_BALANCE:,} | Position: {POSITION_SIZE_PCT}% | Leverage: {LEVERAGE_LEVELS[0]}x")
    print()

    print("Fetching data...")
    all_data = fetch_all_data()
    print()

    print("Generating signals...")
    signals = generate_signals(all_data)
    closed = [s for s in signals if s.outcome in ("win", "partial", "loss")]
    print(f"\nTotal: {len(signals)} signals ({len(closed)} closed)")

    # Leverage sims
    all_results = []
    for mode in ["isolated"]:
        for lev in LEVERAGE_LEVELS:
            result = simulate_leverage(signals, lev, mode)
            all_results.append(result)

    print_results(signals, all_results)


if __name__ == "__main__":
    main()
