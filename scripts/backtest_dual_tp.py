#!/usr/bin/env python3
"""
90-Day Portfolio Backtest: Dual TP Strategy (0.3R TP1 + 0.6R TP2)
Assets: BTC, ETH, SOL, SUI, ADA
Both tiers: 1H scalp + 4H swing
No EMA slope regime filter
Simulated $1,000 portfolio with 2% risk per trade

Risk model:
  - Position sized based on ORIGINAL 1R stop loss distance
  - Half position exits at 0.3R TP1 (30% of entry-to-T1)
  - Runner half targets 0.6R TP2 (60% of entry-to-T1)
  - After TP1, runner stop moves to breakeven
  - SL at 0.8R (80% of original SL distance)

Scenarios:
  1. 0.3R TP1 / 0.6R TP2 / 0.8R SL, MIN_RR = 1.0
  2. 0.3R TP1 / 0.6R TP2 / 0.8R SL, MIN_RR = 1.5
  3. 0.3R TP1 / 0.6R TP2 / 1.0R SL (full SL), MIN_RR = 1.0

Usage:
    python3 scripts/backtest_dual_tp.py
"""

import json
import time
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from collections import defaultdict

# ─── Assets ─────────────────────────────────────────────────────────────────

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
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
WICK_REJECTION_RATIO = 1.2
VOLUME_SPIKE_RATIO = 1.15
EMA_FAST_PERIOD = 20
EMA_SLOW_PERIOD = 50
EMA_PULLBACK_TOLERANCE = 0.015
EMA_SLOPE_LOOKBACK = 6
WARMUP_CANDLES = 60
BACKTEST_DAYS = 90
MIN_SCORE = 60

# Portfolio config
STARTING_CAPITAL = 1000.0
RISK_PER_TRADE_PCT = 2.0

# TP/SL fractions — dual TP
TP1_FRACTION = 0.3   # 30% of entry-to-T1 (first half)
TP2_FRACTION = 0.6   # 60% of entry-to-T1 (runner half)
SL_FRACTION = 0.8    # 80% of original SL distance

# Tier configs
TIERS = {
    "scalp": {
        "tier_name": "1h",
        "swing_timeframes": ["1h", "4h"],
        "trend_timeframe": "4h",
        "bounce_timeframes": ["1h"],
        "signal_proximity_pct": 2.0,
        "confluence_tolerance_pct": 1.0,
        "expiry_hours": 48,
        "slope_lookback": EMA_SLOPE_LOOKBACK,
        "eval_interval": 2,
        "history_slice": 500,
    },
    "swing": {
        "tier_name": "4h",
        "swing_timeframes": ["4h", "1d"],
        "trend_timeframe": "4h",
        "bounce_timeframes": ["1h", "4h"],
        "signal_proximity_pct": 3.0,
        "confluence_tolerance_pct": 1.5,
        "expiry_hours": 72,
        "slope_lookback": EMA_SLOPE_LOOKBACK,
        "eval_interval": 3,
        "history_slice": 500,
    },
}

CANDLE_LIMITS = {
    "1h": 2400,
    "4h": 700,
    "1d": 200,
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
    t1_hit: bool = False
    t1_pnl: float = 0.0
    runner_pnl: float = 0.0
    best_price: float = 0.0
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


# ─── Signal Resolution — Dual TP (0.3R TP1 + 0.6R TP2) ─────────────────────

def make_resolver(sl_fraction):
    """Create a resolver with the given SL fraction for scenario comparison."""
    def resolve_signal_dual_tp(signal, candle, candle_time):
        """
        Dual target resolution:
          - Half position exits at TP1 (0.3R of entry-to-T1)
          - Runner half targets TP2 (0.6R of entry-to-T1)
          - After TP1 hit, runner stop moves to breakeven (entry)
          - Stop loss at sl_fraction of original SL distance
          - Final PnL = average of both halves
        """
        if signal.status != "triggered":
            return
        is_buy = signal.is_buy
        entry_mid = signal.entry_mid
        t1 = signal.target1
        original_sl = signal.stop_loss
        duration = int((candle_time - signal.entry_time).total_seconds() / 3600)

        if is_buy:
            reward_dist = t1 - entry_mid
            sl_dist = entry_mid - original_sl
            tp1_price = entry_mid + TP1_FRACTION * reward_dist
            tp2_price = entry_mid + TP2_FRACTION * reward_dist
            new_sl = entry_mid - sl_fraction * sl_dist
        else:
            reward_dist = entry_mid - t1
            sl_dist = original_sl - entry_mid
            tp1_price = entry_mid - TP1_FRACTION * reward_dist
            tp2_price = entry_mid - TP2_FRACTION * reward_dist
            new_sl = entry_mid + sl_fraction * sl_dist

        # Expiry — close at market
        if candle_time >= signal.expires_at:
            exit_price = candle.close
            if is_buy:
                pnl_pct = ((exit_price - entry_mid) / entry_mid) * 100
            else:
                pnl_pct = ((entry_mid - exit_price) / entry_mid) * 100

            if signal.t1_hit:
                # TP1 half already banked, runner exits at market
                runner_pnl_pct = pnl_pct
                signal.runner_pnl = runner_pnl_pct
                signal.outcome_pct = round((signal.t1_pnl + runner_pnl_pct) / 2, 2)
                signal.outcome = "win" if signal.outcome_pct > 0 else "loss"
            else:
                signal.outcome_pct = round(pnl_pct, 2)
                signal.outcome = "win" if pnl_pct > 0 else "loss"

            signal.status = "closed"
            signal.closed_at = candle_time
            signal.duration_hours = duration
            return

        if not signal.t1_hit:
            # Phase 1: Both halves active — check SL first, then TP1
            if is_buy:
                if candle.low <= new_sl:
                    # Full loss on both halves
                    loss_pct = ((new_sl - entry_mid) / entry_mid) * 100
                    signal.outcome = "loss"
                    signal.outcome_pct = round(loss_pct, 2)
                    signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration
                    return
                if candle.high >= tp1_price:
                    # TP1 hit — bank first half
                    signal.t1_hit = True
                    signal.t1_pnl = ((tp1_price - entry_mid) / entry_mid) * 100
                    # Check if TP2 also hit on same candle
                    if candle.high >= tp2_price:
                        signal.runner_pnl = ((tp2_price - entry_mid) / entry_mid) * 100
                        signal.outcome = "win"
                        signal.outcome_pct = round((signal.t1_pnl + signal.runner_pnl) / 2, 2)
                        signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration
                        return
                    # Runner continues with breakeven stop
            else:
                if candle.high >= new_sl:
                    loss_pct = ((entry_mid - new_sl) / entry_mid) * 100
                    signal.outcome = "loss"
                    signal.outcome_pct = round(loss_pct, 2)
                    signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration
                    return
                if candle.low <= tp1_price:
                    signal.t1_hit = True
                    signal.t1_pnl = ((entry_mid - tp1_price) / entry_mid) * 100
                    if candle.low <= tp2_price:
                        signal.runner_pnl = ((entry_mid - tp2_price) / entry_mid) * 100
                        signal.outcome = "win"
                        signal.outcome_pct = round((signal.t1_pnl + signal.runner_pnl) / 2, 2)
                        signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration
                        return
        else:
            # Phase 2: TP1 banked, runner active with breakeven stop
            if is_buy:
                # Runner stop at breakeven (entry)
                if candle.low <= entry_mid:
                    # Runner stopped at breakeven
                    signal.runner_pnl = 0.0
                    signal.outcome = "win"  # TP1 profit banked
                    signal.outcome_pct = round(signal.t1_pnl / 2, 2)  # Half of TP1 profit (other half is 0)
                    signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration
                    return
                if candle.high >= tp2_price:
                    signal.runner_pnl = ((tp2_price - entry_mid) / entry_mid) * 100
                    signal.outcome = "win"
                    signal.outcome_pct = round((signal.t1_pnl + signal.runner_pnl) / 2, 2)
                    signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration
                    return
            else:
                if candle.high >= entry_mid:
                    signal.runner_pnl = 0.0
                    signal.outcome = "win"
                    signal.outcome_pct = round(signal.t1_pnl / 2, 2)
                    signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration
                    return
                if candle.low <= tp2_price:
                    signal.runner_pnl = ((entry_mid - tp2_price) / entry_mid) * 100
                    signal.outcome = "win"
                    signal.outcome_pct = round((signal.t1_pnl + signal.runner_pnl) / 2, 2)
                    signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = duration
                    return

    return resolve_signal_dual_tp


# ─── Portfolio-Aware Backtest Runner ─────────────────────────────────────────

def run_portfolio_backtest(candles_cache, min_rr, resolve_fn):
    portfolio_value = STARTING_CAPITAL
    peak_value = STARTING_CAPITAL
    max_drawdown_pct = 0.0
    cutoff = datetime.now(timezone.utc) - timedelta(days=BACKTEST_DAYS)

    all_signals = []
    open_signals = []

    monthly_data = defaultdict(lambda: {
        "start_value": 0.0, "end_value": 0.0,
        "signals": 0, "wins": 0, "losses": 0,
        "pnl_dollars": 0.0,
    })

    ref_symbol = ASSETS[0]["symbol"]
    ref_candles = candles_cache[ref_symbol]["1h"]
    if not ref_candles:
        return [], {}, STARTING_CAPITAL, 0.0

    candle_4h_times = {}
    for asset in ASSETS:
        sym = asset["symbol"]
        candle_4h_times[sym] = set(c.open_time for c in candles_cache[sym]["4h"])

    gen_counter = {}
    for asset in ASSETS:
        for tier_name in ["scalp", "swing"]:
            gen_counter[(asset["ticker"], tier_name)] = 0

    first_month_key = None

    for ref_idx, ref_candle in enumerate(ref_candles):
        eval_time = ref_candle.open_time
        if eval_time < cutoff:
            continue

        month_key = eval_time.strftime("%Y-%m")
        if first_month_key is None:
            first_month_key = month_key
            monthly_data[month_key]["start_value"] = portfolio_value

        if month_key not in monthly_data or monthly_data[month_key]["start_value"] == 0:
            monthly_data[month_key]["start_value"] = portfolio_value

        # Resolve open signals
        for sig in open_signals:
            if sig.status != "triggered":
                continue
            sym = [a["symbol"] for a in ASSETS if a["ticker"] == sig.ticker][0]
            if sig.tier == "scalp":
                asset_candles = candles_cache[sym]["1h"]
            else:
                asset_candles = candles_cache[sym]["4h"]

            resolution_candle = None
            if sig.tier == "scalp":
                for c in asset_candles:
                    if c.open_time <= eval_time:
                        resolution_candle = c
                    else:
                        break
            else:
                if eval_time not in candle_4h_times.get(sym, set()):
                    continue
                for c in asset_candles:
                    if c.open_time <= eval_time:
                        resolution_candle = c
                    else:
                        break

            if resolution_candle is None:
                continue

            old_status = sig.status
            resolve_fn(sig, resolution_candle, eval_time)

            if sig.status == "closed" and old_status == "triggered":
                risk_pct_move = abs(sig.entry_mid - sig.stop_loss) / sig.entry_mid * 100
                if risk_pct_move > 0:
                    sig.dollar_pnl = sig.position_size * sig.outcome_pct / 100
                else:
                    sig.dollar_pnl = 0

                portfolio_value += sig.dollar_pnl

                peak_value = max(peak_value, portfolio_value)
                if peak_value > 0:
                    dd = ((peak_value - portfolio_value) / peak_value) * 100
                    max_drawdown_pct = max(max_drawdown_pct, dd)

                close_month = sig.closed_at.strftime("%Y-%m") if sig.closed_at else month_key
                monthly_data[close_month]["signals"] += 1
                monthly_data[close_month]["pnl_dollars"] += sig.dollar_pnl
                if sig.outcome == "win":
                    monthly_data[close_month]["wins"] += 1
                else:
                    monthly_data[close_month]["losses"] += 1

        open_signals = [s for s in open_signals if s.status == "triggered"]

        # Generate new signals
        for asset in ASSETS:
            ticker = asset["ticker"]
            sym = asset["symbol"]

            for tier_name in ["scalp", "swing"]:
                tier = TIERS[tier_name]
                swing_tfs = tier["swing_timeframes"]
                trend_tf = tier["trend_timeframe"]
                bounce_tfs = tier["bounce_timeframes"]
                proximity_pct = tier["signal_proximity_pct"]
                confluence_tol = tier["confluence_tolerance_pct"]

                if tier_name == "swing" and eval_time not in candle_4h_times.get(sym, set()):
                    continue

                key = (ticker, tier_name)
                gen_counter[key] += 1
                if gen_counter[key] % tier["eval_interval"] != 0:
                    continue

                tf_histories = {}
                for tf in set(swing_tfs + [trend_tf] + bounce_tfs):
                    tf_candles = candles_cache[sym].get(tf, [])
                    tf_histories[tf] = [c for c in tf_candles if c.open_time <= eval_time]

                finest_swing_tf = swing_tfs[0]
                if len(tf_histories.get(finest_swing_tf, [])) < WARMUP_CANDLES:
                    continue
                if len(tf_histories.get(trend_tf, [])) < 50:
                    continue

                price_tf = bounce_tfs[0]
                price_candles = tf_histories.get(price_tf, [])
                if not price_candles:
                    continue
                current_price = price_candles[-1].close

                all_fibs = []
                for stf in swing_tfs:
                    stf_history = tf_histories.get(stf, [])
                    if len(stf_history) < WARMUP_CANDLES // 2:
                        continue
                    swings = detect_swings(stf_history[-tier["history_slice"]:], stf)
                    fibs = compute_fibs(swings, stf)
                    all_fibs.extend(fibs)

                if not all_fibs:
                    continue

                zones = cluster_levels(all_fibs, current_price, confluence_tol)
                all_fib_prices = [f.price for f in all_fibs]

                for zone in zones:
                    dist = abs((current_price - zone.mid) / current_price) * 100
                    if dist > proximity_pct:
                        continue

                    dup = any(s.status == "triggered" and s.ticker == ticker
                              and abs(s.entry_mid - zone.mid) / zone.mid < 0.005
                              for s in open_signals)
                    if dup:
                        continue

                    is_buy = zone.zone_type == "support"

                    trend_candles = tf_histories.get(trend_tf, [])
                    if not check_trend(trend_candles, is_buy, tier["slope_lookback"]):
                        continue

                    bounce_confirmed = False
                    for btf in bounce_tfs:
                        bounce_candles = tf_histories.get(btf, [])
                        if check_bounce(bounce_candles[-25:], zone.low, zone.high, is_buy):
                            bounce_confirmed = True
                            break
                    if not bounce_confirmed:
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

                    risk_amount = portfolio_value * (RISK_PER_TRADE_PCT / 100)
                    risk_pct_of_entry = (risk_dist / entry_mid) * 100
                    if risk_pct_of_entry > 0:
                        position_size = risk_amount / (risk_pct_of_entry / 100)
                    else:
                        position_size = 0

                    signal = Signal(
                        entry_time=eval_time, signal_type=sig_type,
                        tier=tier_name, ticker=ticker,
                        entry_mid=entry_mid, entry_low=zone.low, entry_high=zone.high,
                        target1=t1, target2=t2, stop_loss=sl,
                        risk_1r=risk_dist, rr_ratio=round(rr, 2),
                        confluence_strength=zone.strength, score=score,
                        expires_at=eval_time + timedelta(hours=tier["expiry_hours"]),
                        best_price=entry_mid,
                        position_size=round(position_size, 2),
                        risk_amount=round(risk_amount, 2),
                    )
                    all_signals.append(signal)
                    open_signals.append(signal)

    # Force-close any still open
    for sig in open_signals:
        if sig.status == "triggered":
            sym = [a["symbol"] for a in ASSETS if a["ticker"] == sig.ticker][0]
            resolve_tf = "1h" if sig.tier == "scalp" else "4h"
            last_candle = candles_cache[sym][resolve_tf][-1]
            resolve_fn(sig, last_candle, last_candle.open_time)
            if sig.status == "closed":
                risk_pct_move = abs(sig.entry_mid - sig.stop_loss) / sig.entry_mid * 100
                if risk_pct_move > 0:
                    sig.dollar_pnl = sig.position_size * sig.outcome_pct / 100
                else:
                    sig.dollar_pnl = 0
                portfolio_value += sig.dollar_pnl
                peak_value = max(peak_value, portfolio_value)
                if peak_value > 0:
                    dd = ((peak_value - portfolio_value) / peak_value) * 100
                    max_drawdown_pct = max(max_drawdown_pct, dd)
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

    return all_signals, dict(monthly_data), portfolio_value, max_drawdown_pct


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


def print_asset_breakdown(label, all_signals):
    closed = [s for s in all_signals if s.status == "closed"]
    print(f"\n  Per-Asset Breakdown — {label}")
    print(f"  {'Asset':<6} {'Tier':<7} {'Sigs':>5} {'W':>4} {'L':>4} {'WR%':>7} {'$ P&L':>10} {'Avg $Win':>9} {'Avg $Loss':>10} {'PF':>7} {'T1 Hit%':>8}")
    print(f"  {'─'*88}")

    for asset in ASSETS:
        ticker = asset["ticker"]
        for tier_name in ["scalp", "swing"]:
            tier_sigs = [s for s in closed if s.ticker == ticker and s.tier == tier_name]
            if not tier_sigs:
                continue
            wins = [s for s in tier_sigs if s.outcome == "win"]
            losses = [s for s in tier_sigs if s.outcome == "loss"]
            wr = (len(wins) / len(tier_sigs) * 100) if tier_sigs else 0
            dpnl = sum(s.dollar_pnl for s in tier_sigs)
            avg_win_d = (sum(s.dollar_pnl for s in wins) / len(wins)) if wins else 0
            avg_loss_d = (sum(s.dollar_pnl for s in losses) / len(losses)) if losses else 0
            gp = sum(s.dollar_pnl for s in wins)
            gl = abs(sum(s.dollar_pnl for s in losses))
            pf = gp / gl if gl > 0 else float("inf")
            t1_hits = sum(1 for s in tier_sigs if s.t1_hit)
            t1_pct = (t1_hits / len(tier_sigs) * 100) if tier_sigs else 0
            print(f"  {ticker:<6} {tier_name:<7} {len(tier_sigs):>5} {len(wins):>4} {len(losses):>4} {wr:>6.1f}% ${dpnl:>+9.2f} ${avg_win_d:>+8.2f} ${avg_loss_d:>+9.2f} {pf:>7.2f} {t1_pct:>7.1f}%")

        asset_sigs = [s for s in closed if s.ticker == ticker]
        if asset_sigs:
            wins_a = [s for s in asset_sigs if s.outcome == "win"]
            losses_a = [s for s in asset_sigs if s.outcome == "loss"]
            wr_a = (len(wins_a) / len(asset_sigs) * 100) if asset_sigs else 0
            dpnl_a = sum(s.dollar_pnl for s in asset_sigs)
            gp_a = sum(s.dollar_pnl for s in wins_a)
            gl_a = abs(sum(s.dollar_pnl for s in losses_a))
            pf_a = gp_a / gl_a if gl_a > 0 else float("inf")
            t1_a = sum(1 for s in asset_sigs if s.t1_hit)
            t1_pct_a = (t1_a / len(asset_sigs) * 100) if asset_sigs else 0
            print(f"  {ticker:<6} {'ALL':<7} {len(asset_sigs):>5} {len(wins_a):>4} {len(losses_a):>4} {wr_a:>6.1f}% ${dpnl_a:>+9.2f} {'':>9} {'':>10} {pf_a:>7.2f} {t1_pct_a:>7.1f}%")
            print(f"  {'─'*88}")


def main():
    print("=" * 120)
    print("90-DAY PORTFOLIO BACKTEST: DUAL TP STRATEGY (0.3R TP1 + 0.6R TP2)")
    print(f"Assets: {', '.join(a['ticker'] for a in ASSETS)}")
    print(f"Tiers: scalp (1H/4H) + swing (4H/1D)")
    print(f"NO regime filter | Score floor: {MIN_SCORE} | Period: {BACKTEST_DAYS} days")
    print(f"Starting capital: ${STARTING_CAPITAL:,.0f} | Risk per trade: {RISK_PER_TRADE_PCT}%")
    print()
    print("Risk Model:")
    print(f"  TP1 = {TP1_FRACTION:.0%} of entry-to-T1 (half position exits here)")
    print(f"  TP2 = {TP2_FRACTION:.0%} of entry-to-T1 (runner half targets here)")
    print(f"  After TP1: runner stop moves to breakeven (entry)")
    print(f"  Final PnL = average of TP1 half + runner half")
    print()
    print("Scenarios:")
    print("  1. Dual TP + 0.8R SL, MIN_RR = 1.0")
    print("  2. Dual TP + 0.8R SL, MIN_RR = 1.5")
    print("  3. Dual TP + 1.0R SL (full), MIN_RR = 1.0")
    print("=" * 120)

    # Fetch all candle data once
    candles_cache = {}
    print("\nFetching candle data...")
    for asset in ASSETS:
        symbol = asset["symbol"]
        ticker = asset["ticker"]
        candles_cache[symbol] = {}
        for tf, limit in CANDLE_LIMITS.items():
            print(f"  {ticker} {tf} (need {limit})...", end=" ", flush=True)
            candles = fetch_candles(symbol, tf, limit)
            candles_cache[symbol][tf] = candles
            print(f"got {len(candles)} candles", flush=True)
            time.sleep(0.3)

    # ─── Scenario 1: Dual TP + 0.8R SL, MIN_RR = 1.0 ─────────────────────
    print("\n" + "=" * 60)
    print("Running Scenario 1: Dual TP + 0.8R SL, MIN_RR = 1.0...")
    print("=" * 60)
    resolve_08 = make_resolver(0.8)
    signals_1, monthly_1, final_1, dd_1 = run_portfolio_backtest(
        candles_cache, min_rr=1.0, resolve_fn=resolve_08
    )
    closed_1 = [s for s in signals_1 if s.status == "closed"]
    print(f"  Complete: {len(closed_1)} closed signals, final value: ${final_1:,.2f}")

    # ─── Scenario 2: Dual TP + 0.8R SL, MIN_RR = 1.5 ─────────────────────
    print("\n" + "=" * 60)
    print("Running Scenario 2: Dual TP + 0.8R SL, MIN_RR = 1.5...")
    print("=" * 60)
    signals_2, monthly_2, final_2, dd_2 = run_portfolio_backtest(
        candles_cache, min_rr=1.5, resolve_fn=resolve_08
    )
    closed_2 = [s for s in signals_2 if s.status == "closed"]
    print(f"  Complete: {len(closed_2)} closed signals, final value: ${final_2:,.2f}")

    # ─── Scenario 3: Dual TP + 1.0R SL, MIN_RR = 1.0 ─────────────────────
    print("\n" + "=" * 60)
    print("Running Scenario 3: Dual TP + 1.0R SL (full), MIN_RR = 1.0...")
    print("=" * 60)
    resolve_10 = make_resolver(1.0)
    signals_3, monthly_3, final_3, dd_3 = run_portfolio_backtest(
        candles_cache, min_rr=1.0, resolve_fn=resolve_10
    )
    closed_3 = [s for s in signals_3 if s.status == "closed"]
    print(f"  Complete: {len(closed_3)} closed signals, final value: ${final_3:,.2f}")

    # ─── Monthly Tables ──────────────────────────────────────────────────────
    print_monthly_table("Scenario 1: Dual TP (0.3R/0.6R) + 0.8R SL + MIN_RR=1.0", monthly_1, final_1, signals_1)
    print_monthly_table("Scenario 2: Dual TP (0.3R/0.6R) + 0.8R SL + MIN_RR=1.5", monthly_2, final_2, signals_2)
    print_monthly_table("Scenario 3: Dual TP (0.3R/0.6R) + 1.0R SL + MIN_RR=1.0", monthly_3, final_3, signals_3)

    # ─── Side-by-Side Comparison ─────────────────────────────────────────────
    print(f"\n\n{'='*120}")
    print("  SIDE-BY-SIDE COMPARISON")
    print(f"{'='*120}")

    scenarios = [
        ("0.3/0.6R + 0.8SL RR1.0", signals_1, monthly_1, final_1, dd_1),
        ("0.3/0.6R + 0.8SL RR1.5", signals_2, monthly_2, final_2, dd_2),
        ("0.3/0.6R + 1.0SL RR1.0", signals_3, monthly_3, final_3, dd_3),
    ]

    def compute_stats(sigs, final_val, dd):
        closed = [s for s in sigs if s.status == "closed"]
        wins = [s for s in closed if s.outcome == "win"]
        losses = [s for s in closed if s.outcome == "loss"]
        wr = (len(wins) / len(closed) * 100) if closed else 0
        gp = sum(s.dollar_pnl for s in closed if s.dollar_pnl > 0)
        gl = abs(sum(s.dollar_pnl for s in closed if s.dollar_pnl < 0))
        pf = gp / gl if gl > 0 else float("inf")
        ret = ((final_val - STARTING_CAPITAL) / STARTING_CAPITAL * 100)
        avg_dur = (sum(s.duration_hours for s in closed) / len(closed)) if closed else 0
        t1_hits = sum(1 for s in closed if s.t1_hit)
        t1_rate = (t1_hits / len(closed) * 100) if closed else 0
        both_tp = sum(1 for s in closed if s.t1_hit and s.runner_pnl > 0)
        both_rate = (both_tp / len(closed) * 100) if closed else 0
        return {
            "total": len(closed), "wins": len(wins), "losses": len(losses),
            "wr": wr, "gp": gp, "gl": gl, "pf": pf, "ret": ret, "dd": dd,
            "final": final_val, "avg_dur": avg_dur,
            "t1_rate": t1_rate, "both_rate": both_rate,
        }

    stats = [(name, compute_stats(sigs, fv, dd)) for name, sigs, _, fv, dd in scenarios]

    print(f"\n  {'Metric':<25}", end="")
    for name, _ in stats:
        print(f" {name:>25}", end="")
    print()
    print(f"  {'─'*100}")

    rows = [
        ("Starting Capital", lambda s: f"$1,000.00"),
        ("Final Value", lambda s: f"${s['final']:>,.2f}"),
        ("Total Return", lambda s: f"{s['ret']:>+.1f}%"),
        ("Max Drawdown", lambda s: f"{s['dd']:>.1f}%"),
        ("Total Signals", lambda s: f"{s['total']}"),
        ("Wins", lambda s: f"{s['wins']}"),
        ("Losses", lambda s: f"{s['losses']}"),
        ("Win Rate", lambda s: f"{s['wr']:>.1f}%"),
        ("Profit Factor", lambda s: f"{s['pf']:>.2f}"),
        ("Gross Profit", lambda s: f"${s['gp']:>,.2f}"),
        ("Gross Loss", lambda s: f"${s['gl']:>,.2f}"),
        ("Avg Duration (hrs)", lambda s: f"{s['avg_dur']:>.1f}"),
        ("TP1 Hit Rate", lambda s: f"{s['t1_rate']:>.1f}%"),
        ("Both TP Hit Rate", lambda s: f"{s['both_rate']:>.1f}%"),
        ("Return / MaxDD", lambda s: f"{s['ret']/s['dd']:.2f}" if s['dd'] > 0 else "N/A"),
    ]

    for label, fn in rows:
        print(f"  {label:<25}", end="")
        for _, s in stats:
            print(f" {fn(s):>25}", end="")
        print()

    # ─── Per-Asset Breakdown ─────────────────────────────────────────────────
    for name, sigs, _, _, _ in scenarios:
        print_asset_breakdown(name, sigs)

    print()


if __name__ == "__main__":
    main()
