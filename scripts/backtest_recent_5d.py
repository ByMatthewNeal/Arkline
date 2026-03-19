#!/usr/bin/env python3
"""
Show what scalp (1H/4H) signals would have been generated in the past 5 days.
Uses Coinbase API and same parameters as the live dual-tier pipeline.
"""

import json
import time
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

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

COINBASE_GRANULARITY = {"1h": "ONE_HOUR", "4h": "FOUR_HOUR", "1d": "ONE_DAY"}
COINBASE_SECONDS = {"1h": 3600, "4h": 14400, "1d": 86400}

# Scalp tier params
SWING_PARAMS = {
    "1h": {"lookback": 10, "min_reversal": 2.5},
    "4h": {"lookback": 8,  "min_reversal": 5.0},
}
FIB_RATIOS = [0.618, 0.786]
CONFLUENCE_TOLERANCE_PCT = 1.0
SIGNAL_PROXIMITY_PCT = 2.0
MIN_RR_RATIO = 1.0
STRONG_MIN_RR_RATIO = 2.0
STRONG_MIN_CONFLUENCE = 2
SIGNAL_EXPIRY_HOURS = 48
WICK_REJECTION_RATIO = 1.5
VOLUME_SPIKE_RATIO = 1.3
EMA_FAST_PERIOD = 20
EMA_SLOW_PERIOD = 50
EMA_SLOPE_LOOKBACK = 12
EMA_PULLBACK_TOLERANCE = 0.008
WARMUP_CANDLES = 60
LOOKBACK_DAYS = 5
MIN_SCORE = 60  # B grade minimum


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


def fetch_candles(symbol: str, interval: str, limit: int) -> list[Candle]:
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
            print(f"  Error: {e}")
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


def detect_swings(candles, lookback, min_reversal):
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


def check_trend(candles_4h, is_buy):
    if len(candles_4h) < EMA_SLOW_PERIOD + EMA_SLOPE_LOOKBACK:
        return True
    ef = calc_ema(candles_4h, EMA_FAST_PERIOD)
    es = calc_ema(candles_4h, EMA_SLOW_PERIOD)
    esp = calc_ema(candles_4h[:-EMA_SLOPE_LOOKBACK], EMA_SLOW_PERIOD)
    if ef is None or es is None or esp is None:
        return True
    price = candles_4h[-1].close
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
        sl = below[-1] * 0.997 if below else zone.mid * 0.985
        above = [p for p in sorted_prices if p > zone.high]
        t1 = above[0] if above else zone.mid * 1.03
        t2 = above[1] if len(above) > 1 else t1 * 1.015
    else:
        above = [p for p in sorted_prices if p > zone.high]
        sl = above[0] * 1.003 if above else zone.mid * 1.015
        below = [p for p in sorted_prices if p < zone.low]
        t1 = below[-1] if below else zone.mid * 0.97
        t2 = below[-2] if len(below) > 1 else t1 * 0.985
    return t1, t2, sl


def compute_score(zone, is_buy, rr, bounce_type="volume"):
    score = 0
    # Confluence
    if zone.strength >= 4: score += 30
    elif zone.strength >= 3: score += 20
    else: score += 10
    if zone.tf_count >= 2: score += 5
    # EMA (assumed aligned since we filter)
    score += 15
    # Volume/bounce
    score += 8
    # R:R
    if rr >= 3.0: score += 15
    elif rr >= 2.0: score += 10
    elif rr >= 1.0: score += 5
    # Macro base
    score += 10
    return min(score, 100)


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


def grade(score):
    if score >= 90: return "A+"
    if score >= 80: return "A"
    if score >= 70: return "B+"
    if score >= 60: return "B"
    return "C"


def main():
    cutoff = datetime.now(timezone.utc) - timedelta(days=LOOKBACK_DAYS)
    all_signals = []

    print(f"{'='*110}")
    print(f"SCALP SIGNALS (1H/4H) — Past {LOOKBACK_DAYS} Days")
    print(f"{'='*110}")

    for asset in ASSETS:
        ticker = asset["ticker"]
        symbol = asset["symbol"]
        print(f"\n  Fetching {ticker}...")

        candles_1h = fetch_candles(symbol, "1h", 300)
        time.sleep(0.2)
        candles_4h = fetch_candles(symbol, "4h", 300)
        time.sleep(0.2)

        if len(candles_1h) < WARMUP_CANDLES or len(candles_4h) < 50:
            print(f"    Not enough data")
            continue

        signals = []
        for i in range(WARMUP_CANDLES, len(candles_1h)):
            candle = candles_1h[i]
            eval_time = candle.open_time
            current_price = candle.close

            if eval_time < cutoff:
                continue

            for sig in signals:
                if sig.status == "triggered":
                    resolve_signal(sig, candle, eval_time)

            if i % 2 != 0:
                continue

            history_1h = candles_1h[:i + 1]
            history_4h = [c for c in candles_4h if c.open_time <= eval_time]

            swings_1h = detect_swings(history_1h[-200:], SWING_PARAMS["1h"]["lookback"], SWING_PARAMS["1h"]["min_reversal"])
            swings_4h = detect_swings(history_4h[-200:], SWING_PARAMS["4h"]["lookback"], SWING_PARAMS["4h"]["min_reversal"])

            fibs = compute_fibs(swings_1h, "1h") + compute_fibs(swings_4h, "4h")
            if not fibs:
                continue

            zones = cluster_levels(fibs, current_price)
            all_fib_prices = [f.price for f in fibs]

            for zone in zones:
                dist = abs((current_price - zone.mid) / current_price) * 100
                if dist > SIGNAL_PROXIMITY_PCT:
                    continue

                dup = any(s.status == "triggered" and abs(s.entry_mid - zone.mid) / zone.mid < 0.005 for s in signals)
                if dup:
                    continue

                is_buy = zone.zone_type == "support"
                if not check_trend(history_4h, is_buy):
                    continue
                if not check_bounce(history_1h[-25:], zone.low, zone.high, is_buy):
                    continue

                t1, t2, sl = compute_targets(zone, all_fib_prices, is_buy)
                entry_mid = current_price
                risk_dist = abs(entry_mid - sl)
                reward_dist = abs(t1 - entry_mid)
                rr = reward_dist / risk_dist if risk_dist > 0 else 0
                if rr < MIN_RR_RATIO:
                    continue

                score = compute_score(zone, is_buy, rr)
                if score < MIN_SCORE:
                    continue

                is_strong = rr >= STRONG_MIN_RR_RATIO and zone.strength >= STRONG_MIN_CONFLUENCE
                sig_type = ("strong_buy" if is_strong else "buy") if is_buy else ("strong_sell" if is_strong else "sell")

                signal = Signal(
                    entry_time=eval_time, signal_type=sig_type,
                    entry_mid=entry_mid, entry_low=zone.low, entry_high=zone.high,
                    target1=t1, target2=t2, stop_loss=sl,
                    risk_1r=risk_dist, rr_ratio=round(rr, 2),
                    confluence_strength=zone.strength, score=score,
                    expires_at=eval_time + timedelta(hours=SIGNAL_EXPIRY_HOURS),
                    best_price=entry_mid, runner_stop=sl,
                )
                signals.append(signal)

        # Resolve remaining
        if signals and candles_1h:
            for sig in signals:
                if sig.status == "triggered":
                    resolve_signal(sig, candles_1h[-1], candles_1h[-1].open_time)

        recent = [s for s in signals if s.entry_time >= cutoff]
        all_signals.extend([(ticker, s) for s in recent])

        closed = [s for s in recent if s.status == "closed"]
        wins = [s for s in closed if s.outcome == "win"]
        print(f"    {len(recent)} signals | {len(wins)}/{len(closed)} wins | Total P&L: {sum(s.outcome_pct for s in closed):+.2f}%")

    # Print all signals chronologically
    all_signals.sort(key=lambda x: x[1].entry_time)

    print(f"\n\n{'='*130}")
    print(f"ALL SCALP SIGNALS — Last {LOOKBACK_DAYS} Days (chronological)")
    print(f"{'='*130}")
    print(f"{'Time (UTC)':<18} {'Asset':<7} {'Type':<12} {'Grade':>5} {'Entry':>10} {'T1':>10} {'SL':>10} {'R:R':>5} {'Outcome':>8} {'PnL':>8} {'Dur':>5}")
    print("─" * 130)

    total_pnl = 0
    wins = 0
    losses = 0

    for ticker, sig in all_signals:
        time_str = sig.entry_time.strftime("%m/%d %H:%M")
        typ = sig.signal_type.replace("_", " ").title()
        g = grade(sig.score)
        entry = f"${sig.entry_mid:,.2f}" if sig.entry_mid > 1 else f"${sig.entry_mid:.4f}"
        t1 = f"${sig.target1:,.2f}" if sig.target1 > 1 else f"${sig.target1:.4f}"
        sl = f"${sig.stop_loss:,.2f}" if sig.stop_loss > 1 else f"${sig.stop_loss:.4f}"
        outcome = sig.outcome or "open"
        pnl = f"{sig.outcome_pct:+.2f}%" if sig.outcome_pct else "---"
        dur = f"{sig.duration_hours}h" if sig.duration_hours else "---"

        if sig.outcome == "win":
            wins += 1
            total_pnl += sig.outcome_pct
        elif sig.outcome == "loss":
            losses += 1
            total_pnl += sig.outcome_pct

        print(f"{time_str:<18} {ticker:<7} {typ:<12} {g:>5} {entry:>10} {t1:>10} {sl:>10} {sig.rr_ratio:>5.1f} {outcome:>8} {pnl:>8} {dur:>5}")

    print("─" * 130)
    total = wins + losses
    wr = (wins / total * 100) if total > 0 else 0
    print(f"\nSummary: {total} closed signals | {wins}W / {losses}L ({wr:.1f}% WR) | Total P&L: {total_pnl:+.2f}%")
    still_open = sum(1 for _, s in all_signals if s.status == "triggered")
    if still_open:
        print(f"         {still_open} signals still open")


if __name__ == "__main__":
    main()
