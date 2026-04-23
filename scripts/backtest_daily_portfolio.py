#!/usr/bin/env python3
"""
Daily (1D) Timeframe Portfolio Backtest: MIN_RR = 1.0 vs MIN_RR = 1.5
Focus 5 assets: BTC, ETH, SOL, SUI, ADA
Single tier: daily candles only
Simulated $1,000 portfolio with 2% risk per trade

Hypothesis: Daily timeframe signals may be more reliable
(fewer false signals, cleaner swing points).

Usage:
    python3 scripts/backtest_daily_portfolio.py
"""

import json
import time
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from collections import defaultdict

# ─── Assets (Focus 5 only) ──────────────────────────────────────────────────

ASSETS = [
    {"symbol": "BTC-USD",  "ticker": "BTC"},
    {"symbol": "ETH-USD",  "ticker": "ETH"},
    {"symbol": "SOL-USD",  "ticker": "SOL"},
    {"symbol": "SUI-USD",  "ticker": "SUI"},
    {"symbol": "ADA-USD",  "ticker": "ADA"},
]

# ─── Configuration ───────────────────────────────────────────────────────────

SWING_PARAMS = {
    "1d": {"lookback": 5,  "min_reversal": 8.0},
}

FIB_RATIOS = [0.618, 0.786]
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
WICK_REJECTION_RATIO = 1.2
VOLUME_SPIKE_RATIO = 1.15
EMA_FAST_PERIOD = 20
EMA_SLOW_PERIOD = 50
EMA_PULLBACK_TOLERANCE = 0.015
EMA_SLOPE_LOOKBACK = 5  # 5 daily candles
WARMUP_CANDLES = 60
MIN_SCORE = 60

# Portfolio config
STARTING_CAPITAL = 1000.0
RISK_PER_TRADE_PCT = 2.0  # Risk 2% of portfolio per trade

# Daily tier config
DAILY_TIER = {
    "tier_name": "daily",
    "swing_timeframes": ["1d"],
    "trend_timeframe": "1d",
    "bounce_timeframes": ["1d"],
    "signal_proximity_pct": 3.0,
    "confluence_tolerance_pct": 1.5,
    "expiry_hours": 168,  # 7 days
    "slope_lookback": EMA_SLOPE_LOOKBACK,
    "eval_interval": 1,  # every daily candle
    "history_slice": 500,
}

# Candle fetch limit — 365 days + warmup
CANDLE_LIMITS = {
    "1d": 500,
}

COINBASE_GRANULARITY = {"1d": "ONE_DAY"}
COINBASE_SECONDS = {"1d": 86400}


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
    tier: str
    ticker: str
    entry_mid: float
    entry_low: float
    entry_high: float
    target1: float
    target2: float
    stop_loss: float
    risk_1r: float
    rr_ratio: float
    confluence_strength: int
    score: int
    expires_at: datetime
    position_size: float = 0.0
    risk_amount: float = 0.0
    status: str = "triggered"
    t1_hit_at: datetime = None
    t1_pnl_pct: float = 0.0
    best_price: float = 0.0
    runner_stop: float = 0.0
    runner_exit_price: float = 0.0
    runner_pnl_pct: float = 0.0
    outcome: str = None
    outcome_pct: float = 0.0
    dollar_pnl: float = 0.0
    closed_at: datetime = None
    duration_hours: int = 0

    @property
    def is_buy(self) -> bool:
        return "buy" in self.signal_type


# ─── Fetch Historical Data ──────────────────────────────────────────────────

def fetch_candles(symbol: str, interval: str, limit: int) -> list:
    granularity = COINBASE_GRANULARITY[interval]
    interval_seconds = COINBASE_SECONDS[interval]
    all_candles = []
    end_ts = int(datetime.now(timezone.utc).timestamp())
    retries = 0
    max_retries = 3

    while len(all_candles) < limit:
        batch = min(300, limit - len(all_candles))
        start_ts = end_ts - (batch * interval_seconds)
        url = (f"https://api.coinbase.com/api/v3/brokerage/market/products/{symbol}/candles"
               f"?start={start_ts}&end={end_ts}&granularity={granularity}&limit={batch}")
        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                data = json.loads(resp.read())
            retries = 0
        except Exception as e:
            retries += 1
            if retries >= max_retries:
                print(f"  Error fetching {symbol} {interval} after {max_retries} retries: {e}")
                break
            time.sleep(1)
            continue

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
        time.sleep(0.25)

    seen = set()
    unique = []
    for c in all_candles:
        if c.open_time not in seen:
            seen.add(c.open_time)
            unique.append(c)
    unique.sort(key=lambda c: c.open_time)
    return unique[-limit:]


# ─── Technical Functions ─────────────────────────────────────────────────────

def detect_swings(candles, tf):
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
                rev = ((c.high - min_low) / min_low) * 100
                if rev >= min_reversal:
                    swings.append(SwingPoint("high", c.high, c.open_time, rev))
        is_low = all(candles[j].low > c.low for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_low:
            surrounding_highs = [candles[j].high for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_highs:
                max_high = max(surrounding_highs)
                rev = ((max_high - c.low) / c.low) * 100
                if rev >= min_reversal:
                    swings.append(SwingPoint("low", c.low, c.open_time, rev))
    return swings


def compute_fibs(swings, tf):
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


def cluster_levels(fibs, current_price, confluence_tolerance_pct):
    if not fibs:
        return []
    nearby = sorted([l for l in fibs if abs((l.price - current_price) / current_price) * 100 <= 15], key=lambda l: l.price)
    if not nearby:
        return []
    clusters = []
    current_cluster = [nearby[0]]
    cl_low = cl_high = nearby[0].price
    for i in range(1, len(nearby)):
        level = nearby[i]
        cl_mid = (cl_low + cl_high) / 2
        if abs((level.price - cl_mid) / cl_mid) * 100 <= confluence_tolerance_pct:
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


def calc_ema(candles, period):
    if len(candles) < period:
        return None
    multiplier = 2 / (period + 1)
    ema = sum(c.close for c in candles[:period]) / period
    for i in range(period, len(candles)):
        ema = (candles[i].close - ema) * multiplier + ema
    return ema


def check_trend(candles_bias, is_buy, slope_lookback):
    if len(candles_bias) < EMA_SLOW_PERIOD + slope_lookback:
        return True
    ef = calc_ema(candles_bias, EMA_FAST_PERIOD)
    es = calc_ema(candles_bias, EMA_SLOW_PERIOD)
    esp = calc_ema(candles_bias[:-slope_lookback], EMA_SLOW_PERIOD)
    if ef is None or es is None or esp is None:
        return True
    price = candles_bias[-1].close
    if is_buy:
        return ef > es or (es > esp and abs(price - es) / es < EMA_PULLBACK_TOLERANCE)
    else:
        return ef < es or (es < esp and abs(price - es) / es < EMA_PULLBACK_TOLERANCE)


def check_bounce(candles, zone_low, zone_high, is_buy):
    if len(candles) < 3:
        return False
    latest = candles[-1]
    prev = candles[-2]
    if is_buy:
        body = abs(latest.close - latest.open)
        lower_wick = min(latest.open, latest.close) - latest.low
        if lower_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close > zone_low:
            return True
        if latest.close > zone_high and prev.close > zone_high and prev.low <= zone_high:
            return True
    else:
        body = abs(latest.close - latest.open)
        upper_wick = latest.high - max(latest.open, latest.close)
        if upper_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close < zone_high:
            return True
        if latest.close < zone_low and prev.close < zone_low and prev.high >= zone_low:
            return True
    vol_candles = candles[-21:-1]
    if len(vol_candles) >= 10 and latest.volume > 0:
        avg_vol = sum(c.volume for c in vol_candles) / len(vol_candles)
        if avg_vol > 0 and latest.volume >= VOLUME_SPIKE_RATIO * avg_vol:
            return True
    return False


def compute_targets(zone, all_fib_prices, is_buy):
    sorted_prices = sorted(all_fib_prices)
    if is_buy:
        below = [p for p in sorted_prices if p < zone.low]
        sl = below[-1] * 0.995 if below else zone.mid * 0.985
        above = [p for p in sorted_prices if p > zone.high]
        t1 = above[0] if above else zone.mid * 1.03
        t2 = above[1] if len(above) > 1 else t1 * 1.015
    else:
        above = [p for p in sorted_prices if p > zone.high]
        sl = above[0] * 1.005 if above else zone.mid * 1.015
        below = [p for p in sorted_prices if p < zone.low]
        t1 = below[-1] if below else zone.mid * 0.97
        t2 = below[-2] if len(below) > 1 else t1 * 0.985
    return t1, t2, sl


def compute_score(zone, is_buy, rr):
    score = 0
    if zone.strength >= 4: score += 30
    elif zone.strength >= 3: score += 20
    else: score += 10
    if zone.tf_count >= 2: score += 5
    score += 15  # EMA aligned
    score += 8   # bounce confirmed
    if rr >= 3.0: score += 15
    elif rr >= 2.0: score += 10
    elif rr >= 1.5: score += 7
    elif rr >= 1.0: score += 5
    else: score += 2
    score += 10  # macro base
    return min(score, 100)


# ─── Signal Resolution ──────────────────────────────────────────────────────

def resolve_signal(signal, candle, candle_time):
    if signal.status != "triggered":
        return
    is_buy = signal.is_buy
    entry_mid = signal.entry_mid
    t1 = signal.target1
    sl = signal.stop_loss
    risk_1r = signal.risk_1r
    t1_already_hit = signal.t1_hit_at is not None
    best_price = signal.best_price or entry_mid
    runner_stop = signal.runner_stop or sl
    duration = int((candle_time - signal.entry_time).total_seconds() / 3600)

    if candle_time >= signal.expires_at:
        exit_price = candle.close
        if t1_already_hit:
            rpnl = ((exit_price - entry_mid) / entry_mid * 100) if is_buy else ((entry_mid - exit_price) / entry_mid * 100)
            total = (signal.t1_pnl_pct + rpnl) / 2
            signal.outcome = "win" if total > 0 else "loss"
            signal.outcome_pct = round(total, 2)
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
                signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration; return
            if candle.high >= t1:
                signal.t1_hit_at = candle_time
                signal.t1_pnl_pct = round(((t1 - entry_mid) / entry_mid) * 100, 2)
                signal.best_price = candle.high; signal.runner_stop = entry_mid
        else:
            best_price = max(best_price, candle.high)
            runner_stop = max(runner_stop, best_price - risk_1r)
            signal.best_price = best_price; signal.runner_stop = runner_stop
            if candle.low <= runner_stop:
                rpnl = ((runner_stop - entry_mid) / entry_mid) * 100
                total = (signal.t1_pnl_pct + rpnl) / 2
                signal.outcome = "win" if total > 0 else "loss"
                signal.outcome_pct = round(total, 2)
                signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration
    else:
        if not t1_already_hit:
            if candle.high >= sl:
                signal.outcome = "loss"
                signal.outcome_pct = round(((entry_mid - sl) / entry_mid) * 100, 2)
                signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration; return
            if candle.low <= t1:
                signal.t1_hit_at = candle_time
                signal.t1_pnl_pct = round(((entry_mid - t1) / entry_mid) * 100, 2)
                signal.best_price = candle.low; signal.runner_stop = entry_mid
        else:
            best_price = min(best_price, candle.low)
            runner_stop = min(runner_stop, best_price + risk_1r)
            signal.best_price = best_price; signal.runner_stop = runner_stop
            if candle.high >= runner_stop:
                rpnl = ((entry_mid - runner_stop) / entry_mid) * 100
                total = (signal.t1_pnl_pct + rpnl) / 2
                signal.outcome = "win" if total > 0 else "loss"
                signal.outcome_pct = round(total, 2)
                signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration


# ─── Portfolio-Aware Backtest Runner ─────────────────────────────────────────

def run_portfolio_backtest(candles_cache, min_rr):
    """
    Run the daily-only pipeline across all assets, tracking a simulated
    portfolio with 2% risk per trade. Returns (all_signals, monthly_snapshots, final_value).
    """
    portfolio_value = STARTING_CAPITAL
    tier = DAILY_TIER

    all_signals = []
    open_signals = []

    # Monthly tracking
    monthly_data = defaultdict(lambda: {
        "start_value": 0.0, "end_value": 0.0,
        "signals": 0, "wins": 0, "losses": 0,
        "pnl_dollars": 0.0,
    })

    # Use the first asset's 1D candles as reference timeline
    ref_symbol = ASSETS[0]["symbol"]
    ref_candles = candles_cache[ref_symbol]["1d"]
    if not ref_candles:
        return [], {}, STARTING_CAPITAL

    # Determine backtest start: skip warmup candles
    if len(ref_candles) <= WARMUP_CANDLES:
        print(f"  WARNING: Only {len(ref_candles)} daily candles, need >{WARMUP_CANDLES} for warmup")
        return [], {}, STARTING_CAPITAL

    backtest_start_idx = WARMUP_CANDLES
    backtest_start_time = ref_candles[backtest_start_idx].open_time

    first_month_key = None

    for ref_idx in range(backtest_start_idx, len(ref_candles)):
        ref_candle = ref_candles[ref_idx]
        eval_time = ref_candle.open_time

        month_key = eval_time.strftime("%Y-%m")
        if first_month_key is None:
            first_month_key = month_key
            monthly_data[month_key]["start_value"] = portfolio_value
        if month_key not in monthly_data or monthly_data[month_key]["start_value"] == 0:
            monthly_data[month_key]["start_value"] = portfolio_value

        # Resolve open signals against current daily candle for their respective assets
        for sig in open_signals[:]:
            if sig.status != "triggered":
                continue
            sym = [a["symbol"] for a in ASSETS if a["ticker"] == sig.ticker][0]
            asset_candles = candles_cache[sym]["1d"]

            # Find the daily candle at eval_time for this asset
            resolution_candle = None
            for c in asset_candles:
                if c.open_time <= eval_time:
                    resolution_candle = c
                else:
                    break

            if resolution_candle is None:
                continue

            old_status = sig.status
            resolve_signal(sig, resolution_candle, eval_time)

            if sig.status == "closed" and old_status == "triggered":
                risk_pct_move = abs(sig.entry_mid - sig.stop_loss) / sig.entry_mid * 100
                if risk_pct_move > 0:
                    sig.dollar_pnl = sig.position_size * sig.outcome_pct / 100
                else:
                    sig.dollar_pnl = 0

                portfolio_value += sig.dollar_pnl

                close_month = sig.closed_at.strftime("%Y-%m") if sig.closed_at else month_key
                monthly_data[close_month]["signals"] += 1
                monthly_data[close_month]["pnl_dollars"] += sig.dollar_pnl
                if sig.outcome == "win":
                    monthly_data[close_month]["wins"] += 1
                else:
                    monthly_data[close_month]["losses"] += 1

        # Remove closed signals from open list
        open_signals = [s for s in open_signals if s.status == "triggered"]

        # Generate new signals for each asset
        for asset in ASSETS:
            ticker = asset["ticker"]
            sym = asset["symbol"]

            # Gather candle history up to eval_time
            tf_candles = candles_cache[sym].get("1d", [])
            history = [c for c in tf_candles if c.open_time <= eval_time]

            if len(history) < WARMUP_CANDLES:
                continue

            current_price = history[-1].close

            # Detect swings and compute fibs on daily candles
            swings = detect_swings(history[-tier["history_slice"]:], "1d")
            fibs = compute_fibs(swings, "1d")

            if not fibs:
                continue

            zones = cluster_levels(fibs, current_price, tier["confluence_tolerance_pct"])
            all_fib_prices = [f.price for f in fibs]

            for zone in zones:
                dist = abs((current_price - zone.mid) / current_price) * 100
                if dist > tier["signal_proximity_pct"]:
                    continue

                # Check for duplicate
                dup = any(s.status == "triggered" and s.ticker == ticker
                          and abs(s.entry_mid - zone.mid) / zone.mid < 0.005
                          for s in open_signals)
                if dup:
                    continue

                is_buy = zone.zone_type == "support"

                # Trend check on daily EMAs
                if not check_trend(history, is_buy, tier["slope_lookback"]):
                    continue

                # Bounce check on daily candle
                if not check_bounce(history[-25:], zone.low, zone.high, is_buy):
                    continue

                t1, t2, sl = compute_targets(zone, all_fib_prices, is_buy)
                entry_mid = current_price
                risk_dist = abs(entry_mid - sl)
                reward_dist = abs(t1 - entry_mid)
                rr = reward_dist / risk_dist if risk_dist > 0 else 0

                if rr < min_rr:
                    continue

                score = compute_score(zone, is_buy, rr)
                if score < MIN_SCORE:
                    continue

                is_strong = rr >= STRONG_MIN_RR_RATIO and zone.strength >= STRONG_MIN_CONFLUENCE
                sig_type = ("strong_buy" if is_strong else "buy") if is_buy else ("strong_sell" if is_strong else "sell")

                # Position sizing: risk 2% of current portfolio
                risk_amount = portfolio_value * (RISK_PER_TRADE_PCT / 100)
                risk_pct_of_entry = (risk_dist / entry_mid) * 100
                if risk_pct_of_entry > 0:
                    position_size = risk_amount / (risk_pct_of_entry / 100)
                else:
                    position_size = 0

                signal = Signal(
                    entry_time=eval_time, signal_type=sig_type,
                    tier="daily", ticker=ticker,
                    entry_mid=entry_mid, entry_low=zone.low, entry_high=zone.high,
                    target1=t1, target2=t2, stop_loss=sl,
                    risk_1r=risk_dist, rr_ratio=round(rr, 2),
                    confluence_strength=zone.strength, score=score,
                    expires_at=eval_time + timedelta(hours=tier["expiry_hours"]),
                    best_price=entry_mid, runner_stop=sl,
                    position_size=round(position_size, 2),
                    risk_amount=round(risk_amount, 2),
                )
                all_signals.append(signal)
                open_signals.append(signal)

    # Force-close any still open
    for sig in open_signals:
        if sig.status == "triggered":
            sym = [a["symbol"] for a in ASSETS if a["ticker"] == sig.ticker][0]
            last_candle = candles_cache[sym]["1d"][-1]
            resolve_signal(sig, last_candle, last_candle.open_time)
            if sig.status == "closed":
                risk_pct_move = abs(sig.entry_mid - sig.stop_loss) / sig.entry_mid * 100
                if risk_pct_move > 0:
                    sig.dollar_pnl = sig.position_size * sig.outcome_pct / 100
                else:
                    sig.dollar_pnl = 0
                portfolio_value += sig.dollar_pnl
                close_month = sig.closed_at.strftime("%Y-%m") if sig.closed_at else "unknown"
                monthly_data[close_month]["signals"] += 1
                monthly_data[close_month]["pnl_dollars"] += sig.dollar_pnl
                if sig.outcome == "win":
                    monthly_data[close_month]["wins"] += 1
                else:
                    monthly_data[close_month]["losses"] += 1

    # Fill in end values for each month
    sorted_months = sorted(monthly_data.keys())
    running_value = STARTING_CAPITAL
    for mk in sorted_months:
        monthly_data[mk]["start_value"] = running_value
        running_value += monthly_data[mk]["pnl_dollars"]
        monthly_data[mk]["end_value"] = running_value

    return all_signals, dict(monthly_data), portfolio_value


# ─── Reporting ───────────────────────────────────────────────────────────────

def print_monthly_table(label, monthly_data, final_value, all_signals):
    print(f"\n{'='*120}")
    print(f"  {label}")
    print(f"{'='*120}")

    sorted_months = sorted(monthly_data.keys())
    if not sorted_months:
        print("  No data.")
        return

    print(f"\n  {'Month':<10} {'Start $':>10} {'Signals':>8} {'W':>4} {'L':>4} {'WR%':>7} {'P&L $':>10} {'End $':>10} {'Return':>8}")
    print(f"  {'─'*82}")

    total_sigs = 0
    total_wins = 0
    total_losses = 0
    total_pnl = 0.0

    for mk in sorted_months:
        md = monthly_data[mk]
        sigs = md["signals"]
        wins = md["wins"]
        losses = md["losses"]
        wr = (wins / sigs * 100) if sigs > 0 else 0
        pnl = md["pnl_dollars"]
        start_v = md["start_value"]
        end_v = md["end_value"]
        ret = ((end_v - start_v) / start_v * 100) if start_v > 0 else 0

        total_sigs += sigs
        total_wins += wins
        total_losses += losses
        total_pnl += pnl

        print(f"  {mk:<10} ${start_v:>9.2f} {sigs:>8} {wins:>4} {losses:>4} {wr:>6.1f}% ${pnl:>+9.2f} ${end_v:>9.2f} {ret:>+7.1f}%")

    print(f"  {'─'*82}")
    total_wr = (total_wins / total_sigs * 100) if total_sigs > 0 else 0
    total_ret = ((final_value - STARTING_CAPITAL) / STARTING_CAPITAL * 100)
    print(f"  {'TOTAL':<10} ${STARTING_CAPITAL:>9.2f} {total_sigs:>8} {total_wins:>4} {total_losses:>4} {total_wr:>6.1f}% ${total_pnl:>+9.2f} ${final_value:>9.2f} {total_ret:>+7.1f}%")

    # By-asset breakdown
    closed = [s for s in all_signals if s.status == "closed"]
    print(f"\n  {'Asset':<6} {'Sigs':>5} {'W':>4} {'L':>4} {'WR%':>7} {'$ P&L':>10} {'Avg $Win':>9} {'Avg $Loss':>10} {'Avg RR':>7} {'Avg Score':>9}")
    print(f"  {'─'*77}")

    for asset in ASSETS:
        ticker = asset["ticker"]
        asset_sigs = [s for s in closed if s.ticker == ticker]
        if not asset_sigs:
            print(f"  {ticker:<6} {'(no signals)':>5}")
            continue
        wins = [s for s in asset_sigs if s.outcome == "win"]
        losses = [s for s in asset_sigs if s.outcome == "loss"]
        wr = (len(wins) / len(asset_sigs) * 100) if asset_sigs else 0
        dpnl = sum(s.dollar_pnl for s in asset_sigs)
        avg_win_d = (sum(s.dollar_pnl for s in wins) / len(wins)) if wins else 0
        avg_loss_d = (sum(s.dollar_pnl for s in losses) / len(losses)) if losses else 0
        avg_rr = sum(s.rr_ratio for s in asset_sigs) / len(asset_sigs)
        avg_score = sum(s.score for s in asset_sigs) / len(asset_sigs)
        print(f"  {ticker:<6} {len(asset_sigs):>5} {len(wins):>4} {len(losses):>4} {wr:>6.1f}% ${dpnl:>+9.2f} ${avg_win_d:>+8.2f} ${avg_loss_d:>+9.2f} {avg_rr:>6.1f}x {avg_score:>8.0f}")

    # Direction breakdown
    print(f"\n  Direction Breakdown:")
    buys = [s for s in closed if s.is_buy]
    sells = [s for s in closed if not s.is_buy]
    if buys:
        bw = len([s for s in buys if s.outcome == "win"])
        print(f"    LONG:  {len(buys)} signals, {bw} wins ({bw/len(buys)*100:.1f}%), P&L: ${sum(s.dollar_pnl for s in buys):+.2f}")
    if sells:
        sw = len([s for s in sells if s.outcome == "win"])
        print(f"    SHORT: {len(sells)} signals, {sw} wins ({sw/len(sells)*100:.1f}%), P&L: ${sum(s.dollar_pnl for s in sells):+.2f}")

    # Duration stats
    if closed:
        durations = [s.duration_hours for s in closed]
        avg_dur = sum(durations) / len(durations)
        print(f"\n  Avg signal duration: {avg_dur:.0f} hours ({avg_dur/24:.1f} days)")
        print(f"  Min: {min(durations)}h | Max: {max(durations)}h ({max(durations)/24:.1f} days)")


def main():
    print("=" * 120)
    print("DAILY (1D) TIMEFRAME PORTFOLIO BACKTEST: MIN_RR = 1.0 vs MIN_RR = 1.5")
    print(f"Assets: {', '.join(a['ticker'] for a in ASSETS)}")
    print(f"Tier: DAILY ONLY (1D candles, 1D trend, 1D bounce)")
    print(f"Expiry: 168h (7 days) | Proximity: 3.0% | Confluence tol: 1.5%")
    print(f"Slope lookback: 5 | Score floor: {MIN_SCORE}")
    print(f"Starting capital: ${STARTING_CAPITAL:,.0f} | Risk per trade: {RISK_PER_TRADE_PCT}%")
    print("=" * 120)

    # Fetch daily candle data
    candles_cache = {}
    print("\nFetching daily candle data...")
    for asset in ASSETS:
        symbol = asset["symbol"]
        ticker = asset["ticker"]
        candles_cache[symbol] = {}
        for tf, limit in CANDLE_LIMITS.items():
            print(f"  {ticker} {tf} (requesting {limit})...", end=" ", flush=True)
            candles = fetch_candles(symbol, tf, limit)
            candles_cache[symbol][tf] = candles
            if candles:
                span_days = (candles[-1].open_time - candles[0].open_time).days
                print(f"got {len(candles)} candles spanning {span_days} days ({candles[0].open_time.strftime('%Y-%m-%d')} to {candles[-1].open_time.strftime('%Y-%m-%d')})", flush=True)
            else:
                print("got 0 candles", flush=True)
            time.sleep(0.3)

    # Run MIN_RR = 1.0
    print("\n" + "=" * 60)
    print("Running daily portfolio simulation with MIN_RR = 1.0...")
    print("=" * 60)
    signals_10, monthly_10, final_10 = run_portfolio_backtest(candles_cache, min_rr=1.0)
    closed_10 = [s for s in signals_10 if s.status == "closed"]
    print(f"  Complete: {len(closed_10)} closed signals, final value: ${final_10:,.2f}")

    # Run MIN_RR = 1.5
    print("\n" + "=" * 60)
    print("Running daily portfolio simulation with MIN_RR = 1.5...")
    print("=" * 60)
    signals_15, monthly_15, final_15 = run_portfolio_backtest(candles_cache, min_rr=1.5)
    closed_15 = [s for s in signals_15 if s.status == "closed"]
    print(f"  Complete: {len(closed_15)} closed signals, final value: ${final_15:,.2f}")

    # Print detailed tables
    print_monthly_table("MIN_RR = 1.0 — Daily Timeframe Monthly Portfolio Performance", monthly_10, final_10, signals_10)
    print_monthly_table("MIN_RR = 1.5 — Daily Timeframe Monthly Portfolio Performance", monthly_15, final_15, signals_15)

    # Final comparison
    print(f"\n\n{'='*120}")
    print("  FINAL COMPARISON: DAILY TIMEFRAME — MIN_RR = 1.0 vs MIN_RR = 1.5")
    print(f"{'='*120}")

    wins_10 = len([s for s in closed_10 if s.outcome == "win"])
    wins_15 = len([s for s in closed_15 if s.outcome == "win"])
    wr_10 = (wins_10 / len(closed_10) * 100) if closed_10 else 0
    wr_15 = (wins_15 / len(closed_15) * 100) if closed_15 else 0

    gp_10 = sum(s.dollar_pnl for s in closed_10 if s.dollar_pnl > 0)
    gl_10 = abs(sum(s.dollar_pnl for s in closed_10 if s.dollar_pnl < 0))
    pf_10 = gp_10 / gl_10 if gl_10 > 0 else float("inf")

    gp_15 = sum(s.dollar_pnl for s in closed_15 if s.dollar_pnl > 0)
    gl_15 = abs(sum(s.dollar_pnl for s in closed_15 if s.dollar_pnl < 0))
    pf_15 = gp_15 / gl_15 if gl_15 > 0 else float("inf")

    ret_10 = ((final_10 - STARTING_CAPITAL) / STARTING_CAPITAL * 100)
    ret_15 = ((final_15 - STARTING_CAPITAL) / STARTING_CAPITAL * 100)

    # Max drawdown calculation
    def calc_max_drawdown(monthly):
        peak = STARTING_CAPITAL
        max_dd = 0
        running = STARTING_CAPITAL
        for mk in sorted(monthly.keys()):
            running += monthly[mk]["pnl_dollars"]
            peak = max(peak, running)
            dd = ((peak - running) / peak) * 100
            max_dd = max(max_dd, dd)
        return max_dd

    dd_10 = calc_max_drawdown(monthly_10)
    dd_15 = calc_max_drawdown(monthly_15)

    print(f"\n  {'Metric':<25} {'MIN_RR=1.0':>15} {'MIN_RR=1.5':>15} {'Diff':>15}")
    print(f"  {'─'*70}")
    print(f"  {'Starting Capital':<25} {'$1,000.00':>15} {'$1,000.00':>15}")
    print(f"  {'Final Value':<25} ${final_10:>14,.2f} ${final_15:>14,.2f} ${final_10-final_15:>+14,.2f}")
    print(f"  {'Total Return':<25} {ret_10:>+14.1f}% {ret_15:>+14.1f}% {ret_10-ret_15:>+14.1f}%")
    print(f"  {'Max Drawdown':<25} {dd_10:>14.1f}% {dd_15:>14.1f}%")
    print(f"  {'Total Signals':<25} {len(closed_10):>15} {len(closed_15):>15} {len(closed_10)-len(closed_15):>+15}")
    print(f"  {'Wins':<25} {wins_10:>15} {wins_15:>15} {wins_10-wins_15:>+15}")
    print(f"  {'Win Rate':<25} {wr_10:>14.1f}% {wr_15:>14.1f}% {wr_10-wr_15:>+14.1f}%")
    print(f"  {'Profit Factor':<25} {pf_10:>15.2f} {pf_15:>15.2f} {pf_10-pf_15:>+15.2f}")
    print(f"  {'Gross Profit':<25} ${gp_10:>14,.2f} ${gp_15:>14,.2f}")
    print(f"  {'Gross Loss':<25} ${gl_10:>14,.2f} ${gl_15:>14,.2f}")

    # Verdict
    print(f"\n  {'─'*70}")
    if final_10 > final_15:
        print(f"  VERDICT: MIN_RR = 1.0 outperformed by ${final_10 - final_15:,.2f} ({ret_10 - ret_15:+.1f}%)")
    elif final_15 > final_10:
        print(f"  VERDICT: MIN_RR = 1.5 outperformed by ${final_15 - final_10:,.2f} ({ret_15 - ret_10:+.1f}%)")
    else:
        print(f"  VERDICT: Both configurations performed identically")

    # Risk-adjusted note
    if dd_10 > 0 and dd_15 > 0:
        ra_10 = ret_10 / dd_10 if dd_10 > 0 else 0
        ra_15 = ret_15 / dd_15 if dd_15 > 0 else 0
        print(f"  Risk-adjusted (Return/MaxDD): MIN_RR=1.0: {ra_10:.2f} | MIN_RR=1.5: {ra_15:.2f}")
        if ra_15 > ra_10:
            print(f"  MIN_RR = 1.5 is more risk-efficient (better return per unit of drawdown)")
        elif ra_10 > ra_15:
            print(f"  MIN_RR = 1.0 is more risk-efficient (better return per unit of drawdown)")

    print()


if __name__ == "__main__":
    main()
