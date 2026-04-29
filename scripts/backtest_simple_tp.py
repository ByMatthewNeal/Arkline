#!/usr/bin/env python3
"""
90-Day Portfolio Backtest: Simple 0.3R TP / 0.8R SL — No Regime Filter
Assets: BTC, ETH, SOL, SUI, ADA
Both tiers: 1H scalp + 4H swing
Simulated $1,000 portfolio with 2% risk per trade

Scenarios:
  1. 0.3R TP / 0.8R SL, MIN_RR = 1.0
  2. 0.3R TP / 0.8R SL, MIN_RR = 1.5
  3. 0.3R TP / 0.5R SL, MIN_RR = 1.0 (tighter SL)
  4. 0.3R TP / 0.5R SL, MIN_RR = 1.5

Usage:
    python3 scripts/backtest_simple_tp.py
"""

import json
import time
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from collections import defaultdict

ASSETS = [
    {"symbol": "BTC-USD",  "ticker": "BTC"},
    {"symbol": "ETH-USD",  "ticker": "ETH"},
    {"symbol": "SOL-USD",  "ticker": "SOL"},
    {"symbol": "SUI-USD",  "ticker": "SUI"},
    {"symbol": "ADA-USD",  "ticker": "ADA"},
]

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

STARTING_CAPITAL = 1000.0
RISK_PER_TRADE_PCT = 2.0

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

CANDLE_LIMITS = {"1h": 2400, "4h": 700, "1d": 200}
COINBASE_GRANULARITY = {"1h": "ONE_HOUR", "4h": "FOUR_HOUR", "1d": "ONE_DAY"}
COINBASE_SECONDS = {"1h": 3600, "4h": 14400, "1d": 86400}


@dataclass
class Candle:
    open_time: datetime
    open: float; high: float; low: float; close: float; volume: float

@dataclass
class SwingPoint:
    type: str; price: float; candle_time: datetime; reversal_pct: float

@dataclass
class FibLevel:
    timeframe: str; ratio: float; price: float; direction: str

@dataclass
class ConfluenceZone:
    low: float; high: float; mid: float; strength: int; zone_type: str; tf_count: int

@dataclass
class Signal:
    entry_time: datetime; signal_type: str; tier: str; ticker: str
    entry_mid: float; entry_low: float; entry_high: float
    target1: float; target2: float; stop_loss: float
    risk_1r: float; rr_ratio: float; confluence_strength: int; score: int
    expires_at: datetime
    position_size: float = 0.0; risk_amount: float = 0.0
    status: str = "triggered"; outcome: str = None
    outcome_pct: float = 0.0; dollar_pnl: float = 0.0
    closed_at: datetime = None; duration_hours: int = 0

    @property
    def is_buy(self) -> bool:
        return "buy" in self.signal_type


def fetch_candles(symbol, interval, limit):
    granularity = COINBASE_GRANULARITY[interval]
    interval_seconds = COINBASE_SECONDS[interval]
    all_candles = []
    end_ts = int(datetime.now(timezone.utc).timestamp())
    retries = 0
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
            if retries >= 3:
                print(f"  Error fetching {symbol} {interval}: {e}")
                break
            time.sleep(1); continue
        candles_data = data.get("candles", [])
        if not candles_data: break
        candles = [Candle(
            open_time=datetime.fromtimestamp(int(k["start"]), tz=timezone.utc),
            open=float(k["open"]), high=float(k["high"]),
            low=float(k["low"]), close=float(k["close"]), volume=float(k["volume"]),
        ) for k in candles_data]
        candles.sort(key=lambda c: c.open_time)
        all_candles = candles + all_candles
        end_ts = start_ts - 1
        if len(candles_data) < batch: break
        time.sleep(0.25)
    seen = set(); unique = []
    for c in all_candles:
        if c.open_time not in seen: seen.add(c.open_time); unique.append(c)
    unique.sort(key=lambda c: c.open_time)
    return unique[-limit:]


def detect_swings(candles, tf):
    params = SWING_PARAMS[tf]; lookback = params["lookback"]; min_reversal = params["min_reversal"]
    swings = []
    if len(candles) < lookback * 2 + 1: return swings
    for i in range(lookback, len(candles) - lookback):
        c = candles[i]
        is_high = all(candles[j].high < c.high for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_high:
            surrounding_lows = [candles[j].low for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_lows:
                rev = ((c.high - min(surrounding_lows)) / min(surrounding_lows)) * 100
                if rev >= min_reversal: swings.append(SwingPoint("high", c.high, c.open_time, rev))
        is_low = all(candles[j].low > c.low for j in range(i - lookback, i + lookback + 1) if j != i)
        if is_low:
            surrounding_highs = [candles[j].high for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_highs:
                rev = ((max(surrounding_highs) - c.low) / c.low) * 100
                if rev >= min_reversal: swings.append(SwingPoint("low", c.low, c.open_time, rev))
    return swings


def compute_fibs(swings, tf):
    highs = sorted([s for s in swings if s.type == "high"], key=lambda s: s.candle_time, reverse=True)[:3]
    lows = sorted([s for s in swings if s.type == "low"], key=lambda s: s.candle_time, reverse=True)[:3]
    levels = []
    for sh in highs:
        for sl in lows:
            if sh.price <= sl.price: continue
            diff = sh.price - sl.price
            for ratio in FIB_RATIOS:
                levels.append(FibLevel(tf, ratio, sh.price - diff * ratio, "from_high"))
                levels.append(FibLevel(tf, ratio, sl.price + diff * ratio, "from_low"))
    return levels


def cluster_levels(fibs, current_price, tol):
    if not fibs: return []
    nearby = sorted([l for l in fibs if abs((l.price - current_price) / current_price) * 100 <= 15], key=lambda l: l.price)
    if not nearby: return []
    clusters = []; current_cluster = [nearby[0]]; cl_low = cl_high = nearby[0].price
    for i in range(1, len(nearby)):
        level = nearby[i]; cl_mid = (cl_low + cl_high) / 2
        if abs((level.price - cl_mid) / cl_mid) * 100 <= tol:
            current_cluster.append(level); cl_high = max(cl_high, level.price); cl_low = min(cl_low, level.price)
        else:
            if len(current_cluster) >= 2:
                mid = (cl_low + cl_high) / 2; tfs = set(l.timeframe for l in current_cluster)
                clusters.append(ConfluenceZone(cl_low, cl_high, mid, len(current_cluster), "support" if mid < current_price else "resistance", len(tfs)))
            current_cluster = [level]; cl_low = cl_high = level.price
    if len(current_cluster) >= 2:
        mid = (cl_low + cl_high) / 2; tfs = set(l.timeframe for l in current_cluster)
        clusters.append(ConfluenceZone(cl_low, cl_high, mid, len(current_cluster), "support" if mid < current_price else "resistance", len(tfs)))
    return clusters


def calc_ema(candles, period):
    if len(candles) < period: return None
    m = 2 / (period + 1); ema = sum(c.close for c in candles[:period]) / period
    for i in range(period, len(candles)): ema = (candles[i].close - ema) * m + ema
    return ema


def check_trend(candles_bias, is_buy, slope_lookback):
    if len(candles_bias) < EMA_SLOW_PERIOD + slope_lookback: return True
    ef = calc_ema(candles_bias, EMA_FAST_PERIOD); es = calc_ema(candles_bias, EMA_SLOW_PERIOD)
    esp = calc_ema(candles_bias[:-slope_lookback], EMA_SLOW_PERIOD)
    if ef is None or es is None or esp is None: return True
    price = candles_bias[-1].close
    if is_buy: return ef > es or (es > esp and abs(price - es) / es < EMA_PULLBACK_TOLERANCE)
    else: return ef < es or (es < esp and abs(price - es) / es < EMA_PULLBACK_TOLERANCE)


def check_bounce(candles, zone_low, zone_high, is_buy):
    if len(candles) < 3: return False
    latest = candles[-1]; prev = candles[-2]
    if is_buy:
        body = abs(latest.close - latest.open); lower_wick = min(latest.open, latest.close) - latest.low
        if lower_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close > zone_low: return True
        if latest.close > zone_high and prev.close > zone_high and prev.low <= zone_high: return True
    else:
        body = abs(latest.close - latest.open); upper_wick = latest.high - max(latest.open, latest.close)
        if upper_wick >= WICK_REJECTION_RATIO * max(body, 0.001) and latest.close < zone_high: return True
        if latest.close < zone_low and prev.close < zone_low and prev.high >= zone_low: return True
    vol_candles = candles[-21:-1]
    if len(vol_candles) >= 10 and latest.volume > 0:
        avg_vol = sum(c.volume for c in vol_candles) / len(vol_candles)
        if avg_vol > 0 and latest.volume >= VOLUME_SPIKE_RATIO * avg_vol: return True
    return False


def compute_targets(zone, all_fib_prices, is_buy):
    sp = sorted(all_fib_prices)
    if is_buy:
        below = [p for p in sp if p < zone.low]; sl = below[-1] * 0.995 if below else zone.mid * 0.985
        above = [p for p in sp if p > zone.high]; t1 = above[0] if above else zone.mid * 1.03
        t2 = above[1] if len(above) > 1 else t1 * 1.015
    else:
        above = [p for p in sp if p > zone.high]; sl = above[0] * 1.005 if above else zone.mid * 1.015
        below = [p for p in sp if p < zone.low]; t1 = below[-1] if below else zone.mid * 0.97
        t2 = below[-2] if len(below) > 1 else t1 * 0.985
    return t1, t2, sl


def compute_score(zone, is_buy, rr):
    score = 30 if zone.strength >= 4 else 20 if zone.strength >= 3 else 10
    if zone.tf_count >= 2: score += 5
    score += 15 + 8  # EMA + bounce
    score += 15 if rr >= 3.0 else 10 if rr >= 2.0 else 7 if rr >= 1.5 else 5 if rr >= 1.0 else 2
    score += 10
    return min(score, 100)


def make_resolver(tp_frac, sl_frac):
    def resolve(signal, candle, candle_time):
        if signal.status != "triggered": return
        is_buy = signal.is_buy; entry = signal.entry_mid; t1 = signal.target1; orig_sl = signal.stop_loss
        dur = int((candle_time - signal.entry_time).total_seconds() / 3600)

        if is_buy:
            tp_price = entry + tp_frac * (t1 - entry)
            sl_dist = entry - orig_sl
            new_sl = entry - sl_frac * sl_dist
        else:
            tp_price = entry - tp_frac * (entry - t1)
            sl_dist = orig_sl - entry
            new_sl = entry + sl_frac * sl_dist

        if candle_time >= signal.expires_at:
            exit_p = candle.close
            pnl = ((exit_p - entry) / entry * 100) if is_buy else ((entry - exit_p) / entry * 100)
            signal.outcome = "win" if pnl > 0 else "loss"
            signal.outcome_pct = round(pnl, 2)
            signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = dur
            return

        if is_buy:
            if candle.low <= new_sl:
                signal.outcome = "loss"; signal.outcome_pct = round(((new_sl - entry) / entry) * 100, 2)
                signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = dur; return
            if candle.high >= tp_price:
                signal.outcome = "win"; signal.outcome_pct = round(((tp_price - entry) / entry) * 100, 2)
                signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = dur; return
        else:
            if candle.high >= new_sl:
                signal.outcome = "loss"; signal.outcome_pct = round(((entry - new_sl) / entry) * 100, 2)
                signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = dur; return
            if candle.low <= tp_price:
                signal.outcome = "win"; signal.outcome_pct = round(((entry - tp_price) / entry) * 100, 2)
                signal.status = "closed"; signal.closed_at = candle_time; signal.duration_hours = dur; return
    return resolve


def run_backtest(candles_cache, min_rr, resolve_fn):
    pv = STARTING_CAPITAL; peak = STARTING_CAPITAL; max_dd = 0.0
    cutoff = datetime.now(timezone.utc) - timedelta(days=BACKTEST_DAYS)
    all_signals = []; open_signals = []
    monthly = defaultdict(lambda: {"start_value": 0.0, "end_value": 0.0, "signals": 0, "wins": 0, "losses": 0, "pnl_dollars": 0.0})

    ref_candles = candles_cache[ASSETS[0]["symbol"]]["1h"]
    if not ref_candles: return [], {}, STARTING_CAPITAL, 0.0

    c4h_times = {a["symbol"]: set(c.open_time for c in candles_cache[a["symbol"]]["4h"]) for a in ASSETS}
    gen_ctr = {(a["ticker"], t): 0 for a in ASSETS for t in ["scalp", "swing"]}
    first_mk = None

    for ref_c in ref_candles:
        et = ref_c.open_time
        if et < cutoff: continue
        mk = et.strftime("%Y-%m")
        if first_mk is None: first_mk = mk; monthly[mk]["start_value"] = pv
        if mk not in monthly or monthly[mk]["start_value"] == 0: monthly[mk]["start_value"] = pv

        for sig in open_signals:
            if sig.status != "triggered": continue
            sym = [a["symbol"] for a in ASSETS if a["ticker"] == sig.ticker][0]
            ac = candles_cache[sym]["1h" if sig.tier == "scalp" else "4h"]
            if sig.tier == "swing" and et not in c4h_times.get(sym, set()): continue
            rc = None
            for c in ac:
                if c.open_time <= et: rc = c
                else: break
            if rc is None: continue
            old = sig.status
            resolve_fn(sig, rc, et)
            if sig.status == "closed" and old == "triggered":
                rp = abs(sig.entry_mid - sig.stop_loss) / sig.entry_mid * 100
                sig.dollar_pnl = sig.position_size * sig.outcome_pct / 100 if rp > 0 else 0
                pv += sig.dollar_pnl; peak = max(peak, pv)
                if peak > 0: dd = ((peak - pv) / peak) * 100; max_dd = max(max_dd, dd)
                cm = sig.closed_at.strftime("%Y-%m") if sig.closed_at else mk
                monthly[cm]["signals"] += 1; monthly[cm]["pnl_dollars"] += sig.dollar_pnl
                if sig.outcome == "win": monthly[cm]["wins"] += 1
                else: monthly[cm]["losses"] += 1

        open_signals = [s for s in open_signals if s.status == "triggered"]

        for asset in ASSETS:
            ticker = asset["ticker"]; sym = asset["symbol"]
            for tn in ["scalp", "swing"]:
                tier = TIERS[tn]
                if tn == "swing" and et not in c4h_times.get(sym, set()): continue
                key = (ticker, tn); gen_ctr[key] += 1
                if gen_ctr[key] % tier["eval_interval"] != 0: continue

                tfh = {}
                for tf in set(tier["swing_timeframes"] + [tier["trend_timeframe"]] + tier["bounce_timeframes"]):
                    tfh[tf] = [c for c in candles_cache[sym].get(tf, []) if c.open_time <= et]

                if len(tfh.get(tier["swing_timeframes"][0], [])) < WARMUP_CANDLES: continue
                if len(tfh.get(tier["trend_timeframe"], [])) < 50: continue
                pc = tfh.get(tier["bounce_timeframes"][0], [])
                if not pc: continue
                cp = pc[-1].close

                all_fibs = []
                for stf in tier["swing_timeframes"]:
                    sh = tfh.get(stf, [])
                    if len(sh) < WARMUP_CANDLES // 2: continue
                    all_fibs.extend(compute_fibs(detect_swings(sh[-tier["history_slice"]:], stf), stf))
                if not all_fibs: continue

                zones = cluster_levels(all_fibs, cp, tier["confluence_tolerance_pct"])
                afp = [f.price for f in all_fibs]

                for zone in zones:
                    if abs((cp - zone.mid) / cp) * 100 > tier["signal_proximity_pct"]: continue
                    if any(s.status == "triggered" and s.ticker == ticker and abs(s.entry_mid - zone.mid) / zone.mid < 0.005 for s in open_signals): continue
                    ib = zone.zone_type == "support"
                    if not check_trend(tfh.get(tier["trend_timeframe"], []), ib, tier["slope_lookback"]): continue
                    bc = False
                    for btf in tier["bounce_timeframes"]:
                        if check_bounce(tfh.get(btf, [])[-25:], zone.low, zone.high, ib): bc = True; break
                    if not bc: continue
                    t1, t2, sl = compute_targets(zone, afp, ib)
                    rd = abs(cp - sl); rwd = abs(t1 - cp); rr = rwd / rd if rd > 0 else 0
                    if rr < min_rr: continue
                    sc = compute_score(zone, ib, rr)
                    if sc < MIN_SCORE: continue
                    ist = rr >= STRONG_MIN_RR_RATIO and zone.strength >= STRONG_MIN_CONFLUENCE
                    st = ("strong_buy" if ist else "buy") if ib else ("strong_sell" if ist else "sell")
                    ra = pv * (RISK_PER_TRADE_PCT / 100)
                    rpe = (rd / cp) * 100; ps = ra / (rpe / 100) if rpe > 0 else 0
                    sig = Signal(entry_time=et, signal_type=st, tier=tn, ticker=ticker,
                                 entry_mid=cp, entry_low=zone.low, entry_high=zone.high,
                                 target1=t1, target2=t2, stop_loss=sl, risk_1r=rd, rr_ratio=round(rr, 2),
                                 confluence_strength=zone.strength, score=sc,
                                 expires_at=et + timedelta(hours=tier["expiry_hours"]),
                                 position_size=round(ps, 2), risk_amount=round(ra, 2))
                    all_signals.append(sig); open_signals.append(sig)

    for sig in open_signals:
        if sig.status == "triggered":
            sym = [a["symbol"] for a in ASSETS if a["ticker"] == sig.ticker][0]
            lc = candles_cache[sym]["1h" if sig.tier == "scalp" else "4h"][-1]
            resolve_fn(sig, lc, lc.open_time)
            if sig.status == "closed":
                rp = abs(sig.entry_mid - sig.stop_loss) / sig.entry_mid * 100
                sig.dollar_pnl = sig.position_size * sig.outcome_pct / 100 if rp > 0 else 0
                pv += sig.dollar_pnl; peak = max(peak, pv)
                if peak > 0: dd = ((peak - pv) / peak) * 100; max_dd = max(max_dd, dd)
                cm = sig.closed_at.strftime("%Y-%m") if sig.closed_at else "unknown"
                monthly[cm]["signals"] += 1; monthly[cm]["pnl_dollars"] += sig.dollar_pnl
                if sig.outcome == "win": monthly[cm]["wins"] += 1
                else: monthly[cm]["losses"] += 1

    rv = STARTING_CAPITAL
    for mk in sorted(monthly.keys()):
        monthly[mk]["start_value"] = rv; rv += monthly[mk]["pnl_dollars"]; monthly[mk]["end_value"] = rv
    return all_signals, dict(monthly), pv, max_dd


def print_monthly(label, md, fv):
    print(f"\n{'='*120}\n  {label}\n{'='*120}")
    sms = sorted(md.keys())
    if not sms: print("  No data."); return
    print(f"\n  {'Month':<10} {'Start $':>10} {'Signals':>8} {'W':>4} {'L':>4} {'WR%':>7} {'P&L $':>10} {'End $':>10} {'Return':>8}")
    print(f"  {'─'*82}")
    ts = tw = tl = 0; tp = 0.0
    for mk in sms:
        m = md[mk]; s = m["signals"]; w = m["wins"]; l = m["losses"]
        wr = (w / s * 100) if s > 0 else 0; p = m["pnl_dollars"]; sv = m["start_value"]; ev = m["end_value"]
        r = ((ev - sv) / sv * 100) if sv > 0 else 0
        ts += s; tw += w; tl += l; tp += p
        print(f"  {mk:<10} ${sv:>9.2f} {s:>8} {w:>4} {l:>4} {wr:>6.1f}% ${p:>+9.2f} ${ev:>9.2f} {r:>+7.1f}%")
    print(f"  {'─'*82}")
    twr = (tw / ts * 100) if ts > 0 else 0; tr = ((fv - STARTING_CAPITAL) / STARTING_CAPITAL * 100)
    print(f"  {'TOTAL':<10} ${STARTING_CAPITAL:>9.2f} {ts:>8} {tw:>4} {tl:>4} {twr:>6.1f}% ${tp:>+9.2f} ${fv:>9.2f} {tr:>+7.1f}%")


def print_assets(label, sigs):
    closed = [s for s in sigs if s.status == "closed"]
    print(f"\n  Per-Asset Breakdown — {label}")
    print(f"  {'Asset':<6} {'Tier':<7} {'Sigs':>5} {'W':>4} {'L':>4} {'WR%':>7} {'$ P&L':>10} {'Avg $W':>9} {'Avg $L':>10} {'PF':>7}")
    print(f"  {'─'*80}")
    for asset in ASSETS:
        tk = asset["ticker"]
        for tn in ["scalp", "swing"]:
            ts = [s for s in closed if s.ticker == tk and s.tier == tn]
            if not ts: continue
            w = [s for s in ts if s.outcome == "win"]; l = [s for s in ts if s.outcome == "loss"]
            wr = (len(w) / len(ts) * 100) if ts else 0; dp = sum(s.dollar_pnl for s in ts)
            aw = (sum(s.dollar_pnl for s in w) / len(w)) if w else 0; al = (sum(s.dollar_pnl for s in l) / len(l)) if l else 0
            gp = sum(s.dollar_pnl for s in w); gl = abs(sum(s.dollar_pnl for s in l)); pf = gp / gl if gl > 0 else float("inf")
            print(f"  {tk:<6} {tn:<7} {len(ts):>5} {len(w):>4} {len(l):>4} {wr:>6.1f}% ${dp:>+9.2f} ${aw:>+8.2f} ${al:>+9.2f} {pf:>7.2f}")
        ats = [s for s in closed if s.ticker == tk]
        if ats:
            w = [s for s in ats if s.outcome == "win"]; l = [s for s in ats if s.outcome == "loss"]
            wr = (len(w) / len(ats) * 100) if ats else 0; dp = sum(s.dollar_pnl for s in ats)
            gp = sum(s.dollar_pnl for s in w); gl = abs(sum(s.dollar_pnl for s in l)); pf = gp / gl if gl > 0 else float("inf")
            print(f"  {tk:<6} {'ALL':<7} {len(ats):>5} {len(w):>4} {len(l):>4} {wr:>6.1f}% ${dp:>+9.2f} {'':>9} {'':>10} {pf:>7.2f}")
            print(f"  {'─'*80}")


def main():
    print("=" * 120)
    print("90-DAY PORTFOLIO BACKTEST: SIMPLE 0.3R TP — NO REGIME FILTER")
    print(f"Assets: {', '.join(a['ticker'] for a in ASSETS)}")
    print(f"Tiers: scalp (1H) + swing (4H) | Score floor: {MIN_SCORE} | Period: {BACKTEST_DAYS} days")
    print(f"Starting capital: ${STARTING_CAPITAL:,.0f} | Risk per trade: {RISK_PER_TRADE_PCT}%")
    print()
    print("Scenarios:")
    print("  1. 0.3R TP / 0.8R SL, MIN_RR = 1.0")
    print("  2. 0.3R TP / 0.8R SL, MIN_RR = 1.5")
    print("  3. 0.3R TP / 0.5R SL, MIN_RR = 1.0")
    print("  4. 0.3R TP / 0.5R SL, MIN_RR = 1.5")
    print("=" * 120)

    cc = {}
    print("\nFetching candle data...")
    for a in ASSETS:
        sym = a["symbol"]; tk = a["ticker"]; cc[sym] = {}
        for tf, lim in CANDLE_LIMITS.items():
            print(f"  {tk} {tf} (need {lim})...", end=" ", flush=True)
            cc[sym][tf] = fetch_candles(sym, tf, lim)
            print(f"got {len(cc[sym][tf])} candles", flush=True)
            time.sleep(0.3)

    scenarios = [
        ("0.3R TP / 0.8R SL, RR≥1.0", 0.3, 0.8, 1.0),
        ("0.3R TP / 0.8R SL, RR≥1.5", 0.3, 0.8, 1.5),
        ("0.3R TP / 0.5R SL, RR≥1.0", 0.3, 0.5, 1.0),
        ("0.3R TP / 0.5R SL, RR≥1.5", 0.3, 0.5, 1.5),
    ]

    results = []
    for name, tp, sl, rr in scenarios:
        print(f"\n{'='*60}\nRunning: {name}...\n{'='*60}")
        resolver = make_resolver(tp, sl)
        sigs, md, fv, dd = run_backtest(cc, min_rr=rr, resolve_fn=resolver)
        closed = [s for s in sigs if s.status == "closed"]
        print(f"  Complete: {len(closed)} closed signals, final: ${fv:,.2f}")
        results.append((name, sigs, md, fv, dd))

    for name, sigs, md, fv, dd in results:
        print_monthly(name, md, fv)

    print(f"\n\n{'='*120}\n  SIDE-BY-SIDE COMPARISON\n{'='*120}")

    def stats(sigs, fv, dd):
        cl = [s for s in sigs if s.status == "closed"]
        w = [s for s in cl if s.outcome == "win"]; l = [s for s in cl if s.outcome == "loss"]
        wr = (len(w) / len(cl) * 100) if cl else 0
        gp = sum(s.dollar_pnl for s in cl if s.dollar_pnl > 0); gl = abs(sum(s.dollar_pnl for s in cl if s.dollar_pnl < 0))
        pf = gp / gl if gl > 0 else float("inf"); ret = ((fv - STARTING_CAPITAL) / STARTING_CAPITAL * 100)
        ad = (sum(s.duration_hours for s in cl) / len(cl)) if cl else 0
        return {"n": len(cl), "w": len(w), "l": len(l), "wr": wr, "gp": gp, "gl": gl, "pf": pf, "ret": ret, "dd": dd, "fv": fv, "ad": ad}

    st = [(n, stats(s, f, d)) for n, s, _, f, d in results]

    print(f"\n  {'Metric':<25}", end="")
    for n, _ in st: print(f" {n:>25}", end="")
    print(); print(f"  {'─'*125}")

    rows = [
        ("Final Value", lambda s: f"${s['fv']:>,.2f}"),
        ("Total Return", lambda s: f"{s['ret']:>+.1f}%"),
        ("Max Drawdown", lambda s: f"{s['dd']:>.1f}%"),
        ("Total Signals", lambda s: f"{s['n']}"),
        ("Wins / Losses", lambda s: f"{s['w']} / {s['l']}"),
        ("Win Rate", lambda s: f"{s['wr']:>.1f}%"),
        ("Profit Factor", lambda s: f"{s['pf']:>.2f}"),
        ("Gross Profit", lambda s: f"${s['gp']:>,.2f}"),
        ("Gross Loss", lambda s: f"${s['gl']:>,.2f}"),
        ("Avg Duration (hrs)", lambda s: f"{s['ad']:>.1f}"),
        ("Return / MaxDD", lambda s: f"{s['ret']/s['dd']:.2f}" if s['dd'] > 0 else "N/A"),
    ]
    for label, fn in rows:
        print(f"  {label:<25}", end="")
        for _, s in st: print(f" {fn(s):>25}", end="")
        print()

    # Best scenario
    print(f"\n  {'─'*125}")
    bi = max(range(len(st)), key=lambda i: st[i][1]["fv"])
    bn, bs = st[bi]
    print(f"  BEST: {bn}")
    print(f"    Final: ${bs['fv']:,.2f} ({bs['ret']:+.1f}%) | WR: {bs['wr']:.1f}% | PF: {bs['pf']:.2f} | DD: {bs['dd']:.1f}% | Signals: {bs['n']}")

    # Per-asset for best
    print_assets(bn, results[bi][1])
    print()


if __name__ == "__main__":
    main()
