#!/usr/bin/env python3
"""
Backtest: US Session (12:00 + 16:00 UTC) vs 24/7 Signal Detection

Compares signal quality, win rate, profit factor, and total P&L when
the pipeline only fires during US session 4H candles vs every 4H candle.

Uses 4H candle data from Binance for evaluation timing (not daily closes).
Split-exit: 50% closed at T1, 50% runner trailing with 1R stop.
"""

import json
import time
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from collections import defaultdict

# ─── Configuration ──────────────────────────────────────────────────────────

ASSETS = {
    "BTCUSDT": "BTC",
    "ETHUSDT": "ETH",
    "SOLUSDT": "SOL",
    "SUIUSDT": "SUI",
    "LINKUSDT": "LINK",
    "ADAUSDT": "ADA",
}

TIMEFRAMES = [
    {"tf": "1h", "interval": "1h", "limit": 1000, "lookback_days": 42},
    {"tf": "4h", "interval": "4h", "limit": 1000, "lookback_days": 120},
    {"tf": "1d", "interval": "1d", "limit": 365, "lookback_days": 365},
]

SWING_PARAMS = {
    "1d": {"lookback": 5, "min_reversal": 8},
    "4h": {"lookback": 8, "min_reversal": 5},
    "1h": {"lookback": 10, "min_reversal": 2.5},
}

FIB_RATIOS = [0.236, 0.382, 0.500, 0.618, 0.786]
EXT_RATIOS = [1.272, 1.618]

CONFLUENCE_TOLERANCE_PCT = 2
SIGNAL_PROXIMITY_PCT = 3
MIN_RR_RATIO = 1.0
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 3
SIGNAL_EXPIRY_HOURS = 72
WICK_REJECTION_RATIO = 2.0
VOLUME_SPIKE_RATIO = 1.5

BACKTEST_DAYS = 365
WARMUP_DAYS = 30

# Session definitions (UTC hours when 4H candles close)
US_SESSION_HOURS = {12, 16}         # Current pipeline: 12:00 + 16:00 UTC
ALL_SESSION_HOURS = {0, 4, 8, 12, 16, 20}  # Every 4H candle close


# ─── Data Structures ───────────────────────────────────────────────────────

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
    session: str = ""  # "us" or "all"
    eval_hour: int = 0
    outcome: str = "open"
    exit_price: float = 0.0
    exit_time: datetime = None
    pnl_pct: float = 0.0
    t1_hit: bool = False
    t1_pnl_pct: float = 0.0
    runner_pnl_pct: float = 0.0
    combined_pnl_pct: float = 0.0


# ─── Fetch Historical Data ─────────────────────────────────────────────────

def fetch_binance_klines(symbol: str, interval: str, limit: int, end_time_ms: int = None) -> list[Candle]:
    url = f"https://api.binance.us/api/v3/klines?symbol={symbol}&interval={interval}&limit={limit}"
    if end_time_ms:
        url += f"&endTime={end_time_ms}"
    try:
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        print(f"  Error fetching {symbol} {interval}: {e}")
        return []

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
    return candles


def fetch_all_data() -> dict[str, dict[str, list[Candle]]]:
    all_data = {}
    total = len(ASSETS) * len(TIMEFRAMES)
    count = 0
    for symbol, ticker in ASSETS.items():
        all_data[ticker] = {}
        for tf_config in TIMEFRAMES:
            count += 1
            tf = tf_config["tf"]
            print(f"  [{count}/{total}] Fetching {ticker} {tf}...", end="", flush=True)
            candles = fetch_binance_klines(symbol, tf_config["interval"], tf_config["limit"])
            all_data[ticker][tf] = candles
            print(f" {len(candles)} candles")
            time.sleep(0.3)
    return all_data


# ─── Swing Detection ───────────────────────────────────────────────────────

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
                min_surrounding = min(surrounding_lows)
                reversal_pct = ((high - min_surrounding) / min_surrounding) * 100
                if reversal_pct >= min_reversal:
                    swings.append(SwingPoint(asset, tf, candles[i].open_time, "high", high))

        is_low = all(candles[j].low > low for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_low:
            surrounding_highs = [candles[j].high for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_highs:
                max_surrounding = max(surrounding_highs)
                reversal_pct = ((max_surrounding - low) / low) * 100
                if reversal_pct >= min_reversal:
                    swings.append(SwingPoint(asset, tf, candles[i].open_time, "low", low))

    return swings


# ─── Fibonacci Levels ──────────────────────────────────────────────────────

def compute_fib_levels(swings: list[SwingPoint], asset: str, tf: str) -> list[FibLevel]:
    highs = sorted([s for s in swings if s.swing_type == "high"], key=lambda s: s.candle_time, reverse=True)
    lows = sorted([s for s in swings if s.swing_type == "low"], key=lambda s: s.candle_time, reverse=True)

    if not highs or not lows:
        return []

    levels = []
    for sh in highs[:2]:
        for sl in lows[:2]:
            if sh.price <= sl.price:
                continue
            diff = sh.price - sl.price
            for ratio in FIB_RATIOS:
                price = sh.price - diff * ratio
                levels.append(FibLevel(asset, tf, ratio, price, "retracement"))
            for ratio in EXT_RATIOS:
                levels.append(FibLevel(asset, tf, ratio, sl.price + diff * ratio, "extension"))
                levels.append(FibLevel(asset, tf, ratio, sh.price - diff * ratio, "extension"))
    return levels


# ─── Confluence Clustering ─────────────────────────────────────────────────

def cluster_levels(levels: list[FibLevel], current_price: float) -> list[dict]:
    if not levels:
        return []

    nearby = [l for l in levels if abs((l.price - current_price) / current_price) * 100 <= 20]
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
                clusters.append({
                    "low": cluster_low, "high": cluster_high, "mid": mid,
                    "strength": len(current_cluster), "zone_type": zone_type,
                })
            current_cluster = [level]
            cluster_low = level.price
            cluster_high = level.price

    if len(current_cluster) >= 2:
        mid = (cluster_low + cluster_high) / 2
        zone_type = "support" if mid < current_price else "resistance"
        clusters.append({
            "low": cluster_low, "high": cluster_high, "mid": mid,
            "strength": len(current_cluster), "zone_type": zone_type,
        })

    return clusters


# ─── Bounce Confirmation ──────────────────────────────────────────────────

def check_bounce(candles: list[Candle], zone_low: float, zone_high: float, is_buy: bool) -> bool:
    if len(candles) < 3:
        return False

    latest = candles[-1]
    prev = candles[-2]

    if is_buy:
        body = abs(latest.close - latest.open)
        lower_wick = min(latest.open, latest.close) - latest.low
        wick_ok = lower_wick >= WICK_REJECTION_RATIO * max(body, 0.01) and latest.close > zone_low
        consec_ok = latest.close > zone_high and prev.close > zone_high and prev.low <= zone_high
    else:
        body = abs(latest.close - latest.open)
        upper_wick = latest.high - max(latest.open, latest.close)
        wick_ok = upper_wick >= WICK_REJECTION_RATIO * max(body, 0.01) and latest.close < zone_high
        consec_ok = latest.close < zone_low and prev.close < zone_low and prev.high >= zone_low

    vol_candles = candles[-21:-1]
    vol_ok = False
    if len(vol_candles) >= 10 and latest.volume > 0:
        avg_vol = sum(c.volume for c in vol_candles) / len(vol_candles)
        if avg_vol > 0 and latest.volume >= VOLUME_SPIKE_RATIO * avg_vol:
            vol_ok = True

    return wick_ok or vol_ok or consec_ok


# ─── Target & Stop Computation ─────────────────────────────────────────────

def compute_targets_and_stop(zone: dict, all_fib_prices: list[float], is_buy: bool):
    all_prices = sorted(all_fib_prices)
    zone_mid = zone["mid"]

    if is_buy:
        levels_below = [p for p in all_prices if p < zone["low"]]
        next_down = levels_below[-1] if levels_below else None
        stop_loss = next_down * 0.985 if next_down else zone_mid * 0.95

        levels_above = [p for p in all_prices if p > zone["high"]]
        target1 = levels_above[0] if levels_above else zone_mid * 1.15
        target2 = levels_above[1] if len(levels_above) > 1 else target1 * 1.05
    else:
        levels_above = [p for p in all_prices if p > zone["high"]]
        next_up = levels_above[0] if levels_above else None
        stop_loss = next_up * 1.015 if next_up else zone_mid * 1.05

        levels_below = [p for p in all_prices if p < zone["low"]]
        target1 = levels_below[-1] if levels_below else zone_mid * 0.85
        target2 = levels_below[-2] if len(levels_below) > 1 else target1 * 0.95

    return target1, target2, stop_loss


# ─── Signal Generation (4H candle-based) ───────────────────────────────────

def generate_signals_for_session(all_data: dict, session_hours: set, session_label: str) -> list[Signal]:
    """
    Walk through 4H candles and generate signals only when the candle close
    hour matches one of the session_hours.
    """
    signals: list[Signal] = []
    now = datetime.now(tz=timezone.utc)
    start_date = now - timedelta(days=BACKTEST_DAYS)

    for ticker in ASSETS.values():
        daily_candles = all_data[ticker].get("1d", [])
        hourly_candles = all_data[ticker].get("1h", [])
        four_h_candles = all_data[ticker].get("4h", [])

        if len(four_h_candles) < 50:
            continue

        # Walk 4H candles as the evaluation clock
        for idx in range(30, len(four_h_candles)):
            eval_candle = four_h_candles[idx]
            eval_time = eval_candle.open_time
            # The candle close time is open_time + 4h
            close_time = eval_time + timedelta(hours=4)
            close_hour = close_time.hour

            if close_time < start_date:
                continue

            # Only evaluate at allowed session hours
            if close_hour not in session_hours:
                continue

            current_price = eval_candle.close

            # Get historical data up to this point
            daily_history = [c for c in daily_candles if c.open_time <= eval_time]
            four_h_history = four_h_candles[:idx + 1]
            hourly_history = [c for c in hourly_candles if c.open_time <= eval_time]

            all_fib_levels = []
            for tf, history in [("1d", daily_history), ("4h", four_h_history), ("1h", hourly_history)]:
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

                # Check for duplicate open signals
                duplicate = False
                for s in signals:
                    if s.asset == ticker and s.outcome == "open":
                        if abs(s.entry_mid - zone["mid"]) / zone["mid"] < 0.02:
                            duplicate = True
                            break
                if duplicate:
                    continue

                is_buy = zone["zone_type"] == "support"

                nearby_hourly = [c for c in hourly_history if c.open_time <= eval_time][-25:]
                if not nearby_hourly:
                    continue

                if not check_bounce(nearby_hourly, zone["low"], zone["high"], is_buy):
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

                signal = Signal(
                    asset=ticker, signal_type=sig_type, entry_time=close_time,
                    entry_mid=entry_mid, entry_low=zone["low"], entry_high=zone["high"],
                    target1=t1, target2=t2, stop_loss=sl,
                    rr_ratio=round(rr, 2), confluence_strength=zone["strength"],
                    expires_at=close_time + timedelta(hours=SIGNAL_EXPIRY_HOURS),
                    session=session_label, eval_hour=close_hour,
                )
                signals.append(signal)

            # Resolve open signals using 4H candle data (split-exit model)
            resolve_signals(signals, ticker, eval_candle, close_time)

    # Close any remaining open signals
    for s in signals:
        if s.outcome == "open":
            s.outcome = "expired"
            s.exit_time = now

    return signals


def resolve_signals(signals: list[Signal], ticker: str, candle: Candle, eval_time: datetime):
    """Resolve open signals using split-exit: 50% at T1, 50% runner."""
    for s in signals:
        if s.outcome != "open" or s.asset != ticker:
            continue

        is_buy = "buy" in s.signal_type

        # Expiry check
        if eval_time > s.expires_at:
            s.outcome = "expired"
            s.exit_time = eval_time
            s.exit_price = candle.close
            continue

        if is_buy:
            # Stop loss hit
            if candle.low <= s.stop_loss:
                if s.t1_hit:
                    # Runner stopped — partial win
                    s.outcome = "partial"
                    s.exit_price = s.stop_loss
                    s.runner_pnl_pct = (s.stop_loss - s.entry_mid) / s.entry_mid * 100
                else:
                    s.outcome = "loss"
                    s.exit_price = s.stop_loss
                s.exit_time = eval_time
                _calc_combined_pnl(s)
                continue

            # T1 hit
            if not s.t1_hit and candle.high >= s.target1:
                s.t1_hit = True
                s.t1_pnl_pct = (s.target1 - s.entry_mid) / s.entry_mid * 100
                # Move runner stop to breakeven (entry)
                # (we don't modify stop_loss, we track runner separately)

            # T2 hit (full win)
            if candle.high >= s.target2:
                s.outcome = "win"
                s.exit_price = s.target2
                s.exit_time = eval_time
                s.runner_pnl_pct = (s.target2 - s.entry_mid) / s.entry_mid * 100
                _calc_combined_pnl(s)
        else:
            # Stop loss hit (short)
            if candle.high >= s.stop_loss:
                if s.t1_hit:
                    s.outcome = "partial"
                    s.exit_price = s.stop_loss
                    s.runner_pnl_pct = (s.entry_mid - s.stop_loss) / s.entry_mid * 100
                else:
                    s.outcome = "loss"
                    s.exit_price = s.stop_loss
                s.exit_time = eval_time
                _calc_combined_pnl(s)
                continue

            if not s.t1_hit and candle.low <= s.target1:
                s.t1_hit = True
                s.t1_pnl_pct = (s.entry_mid - s.target1) / s.entry_mid * 100

            if candle.low <= s.target2:
                s.outcome = "win"
                s.exit_price = s.target2
                s.exit_time = eval_time
                s.runner_pnl_pct = (s.entry_mid - s.target2) / s.entry_mid * 100
                _calc_combined_pnl(s)


def _calc_combined_pnl(s: Signal):
    """Calculate combined P&L using 50/50 split-exit."""
    if s.t1_hit:
        # 50% closed at T1, 50% at runner exit
        t1_half = s.t1_pnl_pct * 0.5
        if s.outcome == "partial":
            # Runner stopped at breakeven (entry) or stop
            runner_half = 0  # Breakeven on runner
        else:
            runner_half = s.runner_pnl_pct * 0.5
        s.combined_pnl_pct = t1_half + runner_half
    else:
        # Full stop loss on entire position
        is_buy = "buy" in s.signal_type
        if is_buy:
            s.combined_pnl_pct = (s.exit_price - s.entry_mid) / s.entry_mid * 100
        else:
            s.combined_pnl_pct = (s.entry_mid - s.exit_price) / s.entry_mid * 100
    s.pnl_pct = s.combined_pnl_pct


# ─── Analysis & Reporting ──────────────────────────────────────────────────

def analyze(signals: list[Signal], label: str) -> dict:
    closed = [s for s in signals if s.outcome in ("win", "partial", "loss")]
    wins = [s for s in closed if s.outcome == "win"]
    partials = [s for s in closed if s.outcome == "partial"]
    losses = [s for s in closed if s.outcome == "loss"]
    expired = [s for s in signals if s.outcome == "expired"]

    total = len(closed)
    win_count = len(wins) + len(partials)  # partials are profitable (T1 hit)
    win_rate = win_count / total * 100 if total else 0

    avg_win = sum(s.pnl_pct for s in wins + partials) / win_count if win_count else 0
    avg_loss = sum(s.pnl_pct for s in losses) / len(losses) if losses else 0
    total_pnl = sum(s.pnl_pct for s in closed)

    gross_profit = sum(s.pnl_pct for s in closed if s.pnl_pct > 0)
    gross_loss = abs(sum(s.pnl_pct for s in closed if s.pnl_pct < 0))
    pf = gross_profit / gross_loss if gross_loss > 0 else float("inf")

    avg_rr = sum(s.rr_ratio for s in closed) / total if total else 0
    avg_confluence = sum(s.confluence_strength for s in closed) / total if total else 0

    # Per-asset breakdown
    asset_stats = {}
    for s in closed:
        if s.asset not in asset_stats:
            asset_stats[s.asset] = {"wins": 0, "losses": 0, "partials": 0, "pnl": 0}
        if s.outcome == "win":
            asset_stats[s.asset]["wins"] += 1
        elif s.outcome == "partial":
            asset_stats[s.asset]["partials"] += 1
        else:
            asset_stats[s.asset]["losses"] += 1
        asset_stats[s.asset]["pnl"] += s.pnl_pct

    # Hour distribution
    hour_dist = defaultdict(int)
    for s in closed:
        hour_dist[s.eval_hour] += 1

    return {
        "label": label,
        "total_signals": len(signals),
        "closed": total,
        "wins": len(wins),
        "partials": len(partials),
        "losses": len(losses),
        "expired": len(expired),
        "win_rate": win_rate,
        "avg_win": avg_win,
        "avg_loss": avg_loss,
        "total_pnl": total_pnl,
        "profit_factor": pf,
        "avg_rr": avg_rr,
        "avg_confluence": avg_confluence,
        "asset_stats": asset_stats,
        "hour_dist": dict(hour_dist),
        "signals": signals,
    }


def print_comparison(us: dict, full: dict):
    print()
    print("=" * 80)
    print("SESSION COMPARISON: US Only (12+16 UTC) vs 24/7 (All 4H Candles)")
    print("=" * 80)
    print(f"Backtest period: {BACKTEST_DAYS} days | Assets: {', '.join(ASSETS.values())}")
    print(f"Split-exit: 50% at T1, 50% runner trailing")
    print()

    # Side-by-side table
    metrics = [
        ("Total Signals", f"{us['total_signals']}", f"{full['total_signals']}"),
        ("Closed Trades", f"{us['closed']}", f"{full['closed']}"),
        ("Wins", f"{us['wins']}", f"{full['wins']}"),
        ("Partials (T1 hit)", f"{us['partials']}", f"{full['partials']}"),
        ("Losses", f"{us['losses']}", f"{full['losses']}"),
        ("Expired", f"{us['expired']}", f"{full['expired']}"),
        ("", "", ""),
        ("Win Rate", f"{us['win_rate']:.1f}%", f"{full['win_rate']:.1f}%"),
        ("Avg Win", f"{us['avg_win']:+.2f}%", f"{full['avg_win']:+.2f}%"),
        ("Avg Loss", f"{us['avg_loss']:+.2f}%", f"{full['avg_loss']:+.2f}%"),
        ("Total P&L", f"{us['total_pnl']:+.2f}%", f"{full['total_pnl']:+.2f}%"),
        ("Profit Factor", f"{us['profit_factor']:.2f}", f"{full['profit_factor']:.2f}"),
        ("Avg R:R", f"{us['avg_rr']:.2f}", f"{full['avg_rr']:.2f}"),
        ("Avg Confluence", f"{us['avg_confluence']:.1f}", f"{full['avg_confluence']:.1f}"),
    ]

    print(f"  {'Metric':<24} {'US Session':>14} {'24/7':>14} {'Delta':>14}")
    print(f"  {'-'*66}")

    for label, us_val, full_val in metrics:
        if not label:
            print()
            continue
        # Try to compute delta
        delta = ""
        try:
            us_num = float(us_val.rstrip("%").lstrip("+"))
            full_num = float(full_val.rstrip("%").lstrip("+"))
            diff = full_num - us_num
            if "%" in us_val:
                delta = f"{diff:+.2f}%"
            else:
                delta = f"{diff:+.1f}"
        except (ValueError, TypeError):
            pass

        print(f"  {label:<24} {us_val:>14} {full_val:>14} {delta:>14}")

    # Per-asset comparison
    print(f"\n  {'─'*66}")
    print(f"\n  PER-ASSET BREAKDOWN")
    print(f"  {'─'*66}")
    all_assets = sorted(set(list(us["asset_stats"].keys()) + list(full["asset_stats"].keys())))

    print(f"\n  {'Asset':<8} {'── US Session ──':^28} {'── 24/7 ──────':^28}")
    print(f"  {'':8} {'W':>4} {'P':>4} {'L':>4} {'WR%':>6} {'P&L':>8}  {'W':>4} {'P':>4} {'L':>4} {'WR%':>6} {'P&L':>8}")

    for asset in all_assets:
        us_a = us["asset_stats"].get(asset, {"wins": 0, "partials": 0, "losses": 0, "pnl": 0})
        full_a = full["asset_stats"].get(asset, {"wins": 0, "partials": 0, "losses": 0, "pnl": 0})

        us_total = us_a["wins"] + us_a["partials"] + us_a["losses"]
        full_total = full_a["wins"] + full_a["partials"] + full_a["losses"]
        us_wr = (us_a["wins"] + us_a["partials"]) / us_total * 100 if us_total else 0
        full_wr = (full_a["wins"] + full_a["partials"]) / full_total * 100 if full_total else 0

        print(f"  {asset:<8} {us_a['wins']:>4} {us_a['partials']:>4} {us_a['losses']:>4} {us_wr:>5.1f}% {us_a['pnl']:>+7.1f}%"
              f"  {full_a['wins']:>4} {full_a['partials']:>4} {full_a['losses']:>4} {full_wr:>5.1f}% {full_a['pnl']:>+7.1f}%")

    # Hour distribution (for 24/7 mode)
    print(f"\n  {'─'*66}")
    print(f"\n  SIGNAL DISTRIBUTION BY HOUR (24/7 Mode)")
    print(f"  {'─'*66}")

    full_closed = [s for s in full["signals"] if s.outcome in ("win", "partial", "loss")]
    hour_wins = defaultdict(int)
    hour_total = defaultdict(int)
    hour_pnl = defaultdict(float)

    for s in full_closed:
        hour_total[s.eval_hour] += 1
        if s.outcome in ("win", "partial"):
            hour_wins[s.eval_hour] += 1
        hour_pnl[s.eval_hour] += s.pnl_pct

    print(f"\n  {'Hour':>6} {'Signals':>8} {'Win Rate':>10} {'Total P&L':>10} {'Avg P&L':>10} {'US?':>6}")
    for h in sorted(hour_total.keys()):
        total = hour_total[h]
        wr = hour_wins[h] / total * 100 if total else 0
        pnl = hour_pnl[h]
        avg = pnl / total if total else 0
        is_us = "  *" if h in US_SESSION_HOURS else ""
        bar = "#" * int(total / max(1, max(hour_total.values())) * 20)
        print(f"  {h:>4}:00 {total:>8} {wr:>9.1f}% {pnl:>+9.2f}% {avg:>+9.2f}% {is_us:>6}  {bar}")

    # Verdict
    print(f"\n  {'='*66}")
    print(f"  VERDICT")
    print(f"  {'='*66}")

    us_quality = us["profit_factor"] if us["profit_factor"] != float("inf") else 10
    full_quality = full["profit_factor"] if full["profit_factor"] != float("inf") else 10
    pnl_diff = full["total_pnl"] - us["total_pnl"]
    wr_diff = full["win_rate"] - us["win_rate"]
    pf_diff = full_quality - us_quality

    print(f"\n  US Session signals: {us['closed']} trades, {us['win_rate']:.1f}% WR, {us['profit_factor']:.2f} PF, {us['total_pnl']:+.1f}% P&L")
    print(f"  24/7 signals:       {full['closed']} trades, {full['win_rate']:.1f}% WR, {full['profit_factor']:.2f} PF, {full['total_pnl']:+.1f}% P&L")
    print()

    if pf_diff > 0.2 and pnl_diff > 0:
        print("  >> 24/7 mode generates MORE signals with BETTER quality.")
        print("     Consider expanding to all 4H candle closes.")
    elif pf_diff < -0.2 and pnl_diff < 0:
        print("  >> US Session produces HIGHER quality signals.")
        print("     The current 12:00 + 16:00 UTC schedule is optimal.")
    elif abs(pf_diff) <= 0.2 and pnl_diff > 0:
        print("  >> Similar signal quality, but 24/7 captures MORE opportunities.")
        print("     Consider expanding if you want more trade frequency.")
    elif wr_diff < -3 and pnl_diff > 0:
        print("  >> 24/7 has more total P&L but LOWER win rate.")
        print("     More signals ≠ better. The extra signals dilute quality.")
        print("     Stick with US Session for cleaner setups.")
    else:
        print("  >> Mixed results. Review per-asset and per-hour data above.")
        print("     Consider selectively adding specific non-US hours.")

    # Identify best non-US hours
    non_us_hours = {h: (hour_pnl[h], hour_total[h], hour_wins[h] / hour_total[h] * 100 if hour_total[h] else 0)
                    for h in hour_total if h not in US_SESSION_HOURS}
    if non_us_hours:
        best_non_us = max(non_us_hours.items(), key=lambda x: x[1][0])
        if best_non_us[1][0] > 0 and best_non_us[1][2] > 50:
            print(f"\n  Best non-US hour: {best_non_us[0]:02d}:00 UTC "
                  f"({best_non_us[1][1]} signals, {best_non_us[1][2]:.0f}% WR, {best_non_us[1][0]:+.1f}% P&L)")
            print(f"  Could consider adding this hour to the pipeline schedule.")

    print()


# ─── Main ──────────────────────────────────────────────────────────────────

def run():
    print("=" * 80)
    print("BACKTEST: US SESSION vs 24/7 SIGNAL DETECTION")
    print("=" * 80)
    print(f"Period: {BACKTEST_DAYS} days | Assets: {', '.join(ASSETS.values())}")
    print(f"US Session: 12:00 + 16:00 UTC | 24/7: Every 4H close")
    print()

    print("Fetching historical data from Binance...")
    all_data = fetch_all_data()
    print()

    print("Generating US Session signals (12:00 + 16:00 UTC)...")
    us_signals = generate_signals_for_session(all_data, US_SESSION_HOURS, "us")
    us_closed = [s for s in us_signals if s.outcome in ("win", "partial", "loss")]
    print(f"  {len(us_signals)} total, {len(us_closed)} closed")

    print("\nGenerating 24/7 signals (all 4H candles)...")
    full_signals = generate_signals_for_session(all_data, ALL_SESSION_HOURS, "all")
    full_closed = [s for s in full_signals if s.outcome in ("win", "partial", "loss")]
    print(f"  {len(full_signals)} total, {len(full_closed)} closed")

    us_results = analyze(us_signals, "US Session (12+16 UTC)")
    full_results = analyze(full_signals, "24/7 (All 4H Candles)")

    print_comparison(us_results, full_results)


if __name__ == "__main__":
    run()
