#!/usr/bin/env python3
"""
90-Day Backtest: MIN_RR = 1.0 vs MIN_RR = 1.5
Focus 5 assets: BTC, ETH, SOL, SUI, ADA
Both tiers: 1H scalp + 4H swing

Usage:
    python3 scripts/backtest_minrr_90d.py
"""

import json
import time
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

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
    "1h": {"lookback": 10, "min_reversal": 2.5},
    "4h": {"lookback": 8,  "min_reversal": 5.0},
    "1d": {"lookback": 5,  "min_reversal": 8.0},
}

FIB_RATIOS = [0.618, 0.786]
CONFLUENCE_TOLERANCE_PCT = 1.0
SIGNAL_PROXIMITY_PCT = 2.0
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
WICK_REJECTION_RATIO = 1.5
VOLUME_SPIKE_RATIO = 1.3
EMA_FAST_PERIOD = 20
EMA_SLOW_PERIOD = 50
EMA_PULLBACK_TOLERANCE = 0.008
WARMUP_CANDLES = 60
BACKTEST_DAYS = 90
MIN_SCORE = 60

# Tier configs
TIERS = {
    "scalp": {
        "entry_tf": "1h",
        "bias_tf": "4h",
        "slope_lookback": 12,
        "expiry_hours": 48,
        "eval_interval": 2,
        "history_slice": 500,
    },
    "swing": {
        "entry_tf": "4h",
        "bias_tf": "1d",
        "slope_lookback": 6,
        "expiry_hours": 72,
        "eval_interval": 3,
        "history_slice": 500,
    },
}

# Candle fetch limits
CANDLE_LIMITS = {
    "1h": 2400,  # ~100 days
    "4h": 1200,  # ~200 days
    "1d": 500,   # ~500 days
}

COINBASE_GRANULARITY = {"1h": "ONE_HOUR", "4h": "FOUR_HOUR", "1d": "ONE_DAY"}
COINBASE_SECONDS = {"1h": 3600, "4h": 14400, "1d": 86400}


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
    tier: str  # "scalp" or "swing"
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

def fetch_candles(symbol: str, interval: str, limit: int) -> list:
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
        time.sleep(0.2)

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


def cluster_levels(fibs, current_price):
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
        if abs((level.price - cl_mid) / cl_mid) * 100 <= CONFLUENCE_TOLERANCE_PCT:
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
        sl = below[-1] * 0.995 if below else zone.mid * 0.985  # 0.5% stop buffer
        above = [p for p in sorted_prices if p > zone.high]
        t1 = above[0] if above else zone.mid * 1.03
        t2 = above[1] if len(above) > 1 else t1 * 1.015
    else:
        above = [p for p in sorted_prices if p > zone.high]
        sl = above[0] * 1.005 if above else zone.mid * 1.015  # 0.5% stop buffer
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


# ─── Backtest Runner ─────────────────────────────────────────────────────────

def run_tier(candles_cache, ticker, symbol, tier_name, min_rr):
    tier = TIERS[tier_name]
    entry_tf = tier["entry_tf"]
    bias_tf = tier["bias_tf"]
    slope_lookback = tier["slope_lookback"]
    expiry_hours = tier["expiry_hours"]
    eval_interval = tier["eval_interval"]

    entry_candles = candles_cache[symbol][entry_tf]
    bias_candles = candles_cache[symbol][bias_tf]

    if len(entry_candles) < WARMUP_CANDLES or len(bias_candles) < 50:
        return []

    cutoff = datetime.now(timezone.utc) - timedelta(days=BACKTEST_DAYS)
    signals = []

    for i in range(WARMUP_CANDLES, len(entry_candles)):
        candle = entry_candles[i]
        eval_time = candle.open_time
        current_price = candle.close

        if eval_time < cutoff:
            continue

        for sig in signals:
            if sig.status == "triggered":
                resolve_signal(sig, candle, eval_time)

        if i % eval_interval != 0:
            continue

        history_entry = entry_candles[:i + 1]
        history_bias = [c for c in bias_candles if c.open_time <= eval_time]

        swings_entry = detect_swings(history_entry[-tier["history_slice"]:], entry_tf)
        swings_bias = detect_swings(history_bias[-250:], bias_tf)

        fibs_entry = compute_fibs(swings_entry, entry_tf)
        fibs_bias = compute_fibs(swings_bias, bias_tf)
        all_fibs = fibs_entry + fibs_bias

        if not all_fibs:
            continue

        zones = cluster_levels(all_fibs, current_price)
        all_fib_prices = [f.price for f in all_fibs]

        for zone in zones:
            dist = abs((current_price - zone.mid) / current_price) * 100
            if dist > SIGNAL_PROXIMITY_PCT:
                continue

            dup = any(s.status == "triggered" and abs(s.entry_mid - zone.mid) / zone.mid < 0.005 for s in signals)
            if dup:
                continue

            is_buy = zone.zone_type == "support"
            if not check_trend(history_bias, is_buy, slope_lookback):
                continue
            if not check_bounce(history_entry[-25:], zone.low, zone.high, is_buy):
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

            signal = Signal(
                entry_time=eval_time, signal_type=sig_type,
                tier=tier_name, ticker=ticker,
                entry_mid=entry_mid, entry_low=zone.low, entry_high=zone.high,
                target1=t1, target2=t2, stop_loss=sl,
                risk_1r=risk_dist, rr_ratio=round(rr, 2),
                confluence_strength=zone.strength, score=score,
                expires_at=eval_time + timedelta(hours=expiry_hours),
                best_price=entry_mid, runner_stop=sl,
            )
            signals.append(signal)

    # Force-close any still open
    if signals and entry_candles:
        last_candle = entry_candles[-1]
        for sig in signals:
            if sig.status == "triggered":
                resolve_signal(sig, last_candle, last_candle.open_time)

    cutoff_filter = datetime.now(timezone.utc) - timedelta(days=BACKTEST_DAYS)
    return [s for s in signals if s.entry_time >= cutoff_filter]


def run_full_backtest(candles_cache, min_rr):
    all_signals = []
    for asset in ASSETS:
        ticker = asset["ticker"]
        symbol = asset["symbol"]
        for tier_name in ["scalp", "swing"]:
            sigs = run_tier(candles_cache, ticker, symbol, tier_name, min_rr)
            all_signals.extend(sigs)
    all_signals.sort(key=lambda s: s.entry_time)
    return all_signals


# ─── Reporting ───────────────────────────────────────────────────────────────

def compute_stats(signals):
    closed = [s for s in signals if s.status == "closed"]
    wins = [s for s in closed if s.outcome == "win"]
    losses = [s for s in closed if s.outcome == "loss"]
    total = len(closed)
    w = len(wins)
    l = len(losses)
    wr = (w / total * 100) if total > 0 else 0
    pnl = sum(s.outcome_pct for s in closed)
    gross_profit = sum(s.outcome_pct for s in closed if s.outcome_pct > 0)
    gross_loss = abs(sum(s.outcome_pct for s in closed if s.outcome_pct < 0))
    pf = gross_profit / gross_loss if gross_loss > 0 else float("inf")
    avg_win = (sum(s.outcome_pct for s in wins) / w) if w > 0 else 0
    avg_loss = (sum(s.outcome_pct for s in losses) / l) if l > 0 else 0
    return {
        "total": total, "wins": w, "losses": l,
        "win_rate": wr, "pnl": pnl, "pf": pf,
        "avg_win": avg_win, "avg_loss": avg_loss,
    }


def print_report(label, signals):
    print(f"\n{'='*130}")
    print(f"  {label}")
    print(f"{'='*130}")

    # Overall
    stats = compute_stats(signals)
    print(f"\n  OVERALL: {stats['total']} signals | {stats['wins']}W / {stats['losses']}L | "
          f"WR: {stats['win_rate']:.1f}% | P&L: {stats['pnl']:+.2f}% | PF: {stats['pf']:.2f} | "
          f"Avg Win: {stats['avg_win']:+.2f}% | Avg Loss: {stats['avg_loss']:+.2f}%")

    # By tier
    for tier_name in ["scalp", "swing"]:
        tier_sigs = [s for s in signals if s.tier == tier_name]
        ts = compute_stats(tier_sigs)
        print(f"  {tier_name.upper():>6}: {ts['total']:>3} signals | {ts['wins']}W / {ts['losses']}L | "
              f"WR: {ts['win_rate']:.1f}% | P&L: {ts['pnl']:+.2f}% | PF: {ts['pf']:.2f}")

    # By asset
    print(f"\n  {'Asset':<6} {'Tier':<7} {'Sigs':>5} {'Wins':>5} {'Loss':>5} {'WR%':>7} {'P&L':>9} {'PF':>7} {'AvgWin':>8} {'AvgLoss':>8}")
    print(f"  {'─'*75}")

    for asset in ASSETS:
        ticker = asset["ticker"]
        for tier_name in ["scalp", "swing"]:
            asset_tier_sigs = [s for s in signals if s.ticker == ticker and s.tier == tier_name]
            if not asset_tier_sigs:
                continue
            ats = compute_stats(asset_tier_sigs)
            print(f"  {ticker:<6} {tier_name:<7} {ats['total']:>5} {ats['wins']:>5} {ats['losses']:>5} "
                  f"{ats['win_rate']:>6.1f}% {ats['pnl']:>+8.2f}% {ats['pf']:>6.2f} "
                  f"{ats['avg_win']:>+7.2f}% {ats['avg_loss']:>+7.2f}%")

        # Asset total
        asset_sigs = [s for s in signals if s.ticker == ticker]
        if asset_sigs:
            ats = compute_stats(asset_sigs)
            print(f"  {ticker:<6} {'TOTAL':<7} {ats['total']:>5} {ats['wins']:>5} {ats['losses']:>5} "
                  f"{ats['win_rate']:>6.1f}% {ats['pnl']:>+8.2f}% {ats['pf']:>6.2f} "
                  f"{ats['avg_win']:>+7.2f}% {ats['avg_loss']:>+7.2f}%")
            print(f"  {'─'*75}")


def main():
    print("=" * 130)
    print("90-DAY BACKTEST: MIN_RR = 1.0 vs MIN_RR = 1.5")
    print(f"Assets: {', '.join(a['ticker'] for a in ASSETS)}")
    print(f"Tiers: scalp (1H entry / 4H bias) + swing (4H entry / 1D bias)")
    print(f"Stop buffer: 0.5% | Score floor: {MIN_SCORE} | Backtest window: {BACKTEST_DAYS} days")
    print("=" * 130)

    # Fetch all candle data once
    candles_cache = {}
    print("\nFetching candle data...")
    for asset in ASSETS:
        symbol = asset["symbol"]
        ticker = asset["ticker"]
        candles_cache[symbol] = {}
        for tf, limit in CANDLE_LIMITS.items():
            print(f"  {ticker} {tf}...", end=" ", flush=True)
            candles = fetch_candles(symbol, tf, limit)
            candles_cache[symbol][tf] = candles
            print(f"{len(candles)} candles")
            time.sleep(0.3)

    # Run both
    print("\nRunning MIN_RR = 1.0...")
    signals_10 = run_full_backtest(candles_cache, min_rr=1.0)

    print("Running MIN_RR = 1.5...")
    signals_15 = run_full_backtest(candles_cache, min_rr=1.5)

    # Reports
    print_report("MIN_RR = 1.0", signals_10)
    print_report("MIN_RR = 1.5", signals_15)

    # Side-by-side comparison
    s10 = compute_stats(signals_10)
    s15 = compute_stats(signals_15)

    print(f"\n\n{'='*130}")
    print("  SIDE-BY-SIDE COMPARISON")
    print(f"{'='*130}")
    print(f"  {'Metric':<20} {'MIN_RR=1.0':>15} {'MIN_RR=1.5':>15} {'Diff':>15}")
    print(f"  {'─'*65}")
    print(f"  {'Total Signals':<20} {s10['total']:>15} {s15['total']:>15} {s10['total']-s15['total']:>+15}")
    print(f"  {'Wins':<20} {s10['wins']:>15} {s15['wins']:>15} {s10['wins']-s15['wins']:>+15}")
    print(f"  {'Losses':<20} {s10['losses']:>15} {s15['losses']:>15} {s10['losses']-s15['losses']:>+15}")
    print(f"  {'Win Rate':<20} {s10['win_rate']:>14.1f}% {s15['win_rate']:>14.1f}% {s10['win_rate']-s15['win_rate']:>+14.1f}%")
    print(f"  {'Cumulative P&L':<20} {s10['pnl']:>+14.2f}% {s15['pnl']:>+14.2f}% {s10['pnl']-s15['pnl']:>+14.2f}%")
    print(f"  {'Profit Factor':<20} {s10['pf']:>15.2f} {s15['pf']:>15.2f} {s10['pf']-s15['pf']:>+15.2f}")
    print(f"  {'Avg Win':<20} {s10['avg_win']:>+14.2f}% {s15['avg_win']:>+14.2f}% {s10['avg_win']-s15['avg_win']:>+14.2f}%")
    print(f"  {'Avg Loss':<20} {s10['avg_loss']:>+14.2f}% {s15['avg_loss']:>+14.2f}% {s10['avg_loss']-s15['avg_loss']:>+14.2f}%")

    # Tier comparison
    for tier_name in ["scalp", "swing"]:
        t10 = compute_stats([s for s in signals_10 if s.tier == tier_name])
        t15 = compute_stats([s for s in signals_15 if s.tier == tier_name])
        print(f"\n  {tier_name.upper()}")
        print(f"  {'Signals':<20} {t10['total']:>15} {t15['total']:>15} {t10['total']-t15['total']:>+15}")
        print(f"  {'Win Rate':<20} {t10['win_rate']:>14.1f}% {t15['win_rate']:>14.1f}% {t10['win_rate']-t15['win_rate']:>+14.1f}%")
        print(f"  {'P&L':<20} {t10['pnl']:>+14.2f}% {t15['pnl']:>+14.2f}% {t10['pnl']-t15['pnl']:>+14.2f}%")
        print(f"  {'Profit Factor':<20} {t10['pf']:>15.2f} {t15['pf']:>15.2f} {t10['pf']-t15['pf']:>+15.2f}")

    print()


if __name__ == "__main__":
    main()
