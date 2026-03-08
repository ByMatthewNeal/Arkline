#!/usr/bin/env python3
"""
Backtest: Fibonacci Confluence Swing Signal System
Replays the pipeline logic over 90 days of Binance historical data.
Supports spot, isolated margin, and cross margin leverage modes.
"""

import json
import time
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone

# ─── Configuration (mirrors pipeline) ────────────────────────────────────────

ASSETS = {
    "BTCUSDT": "BTC",
    "ETHUSDT": "ETH",
    "SOLUSDT": "SOL",
}

TIMEFRAMES = [
    {"tf": "1h", "interval": "1h", "limit": 1000, "lookback_days": 42},
    {"tf": "4h", "interval": "4h", "limit": 1000, "lookback_days": 120},
    {"tf": "1d", "interval": "1d", "limit": 180, "lookback_days": 180},
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

BACKTEST_DAYS = 90
WARMUP_DAYS = 30

# ─── Leverage Configuration ──────────────────────────────────────────────────

# Margin mode: "spot", "isolated", or "cross"
MARGIN_MODE = "spot"

# Leverage levels to test
LEVERAGE_LEVELS = [1, 3, 5, 10, 20]

# Starting account balance (USD)
STARTING_BALANCE = 10_000

# Position size as % of available balance per trade
POSITION_SIZE_PCT = 7  # 7% of balance per trade

# Binance futures maintenance margin rates (simplified, by position notional)
# In reality these are tiered, but this covers the common range
MAINTENANCE_MARGIN_RATE = 0.004  # 0.4% for most positions under $50k

# Trading fees (Binance futures maker/taker)
MAKER_FEE = 0.0002   # 0.02%
TAKER_FEE = 0.0004   # 0.04%

# Funding rate (approximate average per 8h for perpetual futures)
FUNDING_RATE_8H = 0.0001  # 0.01% per 8h


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


@dataclass
class LeveragedTrade:
    """Tracks a single leveraged position."""
    signal: Signal
    leverage: int
    margin_mode: str  # "isolated" or "cross"
    position_size_usd: float  # notional position value
    margin_used: float  # collateral locked
    entry_price: float
    liquidation_price: float
    is_long: bool
    # Outcome
    pnl_usd: float = 0.0
    pnl_pct_on_margin: float = 0.0  # ROI on margin (leveraged return)
    fees_paid: float = 0.0
    funding_paid: float = 0.0
    liquidated: bool = False


# ─── Fetch Historical Data ───────────────────────────────────────────────────

def fetch_binance_klines(symbol: str, interval: str, limit: int) -> list[Candle]:
    url = f"https://api.binance.com/api/v3/klines?symbol={symbol}&interval={interval}&limit={limit}"
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

        is_high = True
        for j in range(i - lookback, i + lookback + 1):
            if j == i:
                continue
            if candles[j].high >= high:
                is_high = False
                break

        if is_high:
            surrounding_lows = [candles[j].low for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_lows:
                min_surrounding = min(surrounding_lows)
                reversal_pct = ((high - min_surrounding) / min_surrounding) * 100
                if reversal_pct >= min_reversal:
                    swings.append(SwingPoint(asset, tf, candles[i].open_time, "high", high))

        is_low = True
        for j in range(i - lookback, i + lookback + 1):
            if j == i:
                continue
            if candles[j].low <= low:
                is_low = False
                break

        if is_low:
            surrounding_highs = [candles[j].high for j in range(max(0, i - lookback), min(len(candles), i + lookback + 1)) if j != i]
            if surrounding_highs:
                max_surrounding = max(surrounding_highs)
                reversal_pct = ((max_surrounding - low) / low) * 100
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


# ─── Confluence Clustering ────────────────────────────────────────────────────

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


# ─── Bounce Confirmation ─────────────────────────────────────────────────────

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


# ─── Target & Stop Computation ────────────────────────────────────────────────

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


# ─── Leverage Calculations ────────────────────────────────────────────────────

def calc_liquidation_price(entry: float, leverage: int, is_long: bool, mmr: float = MAINTENANCE_MARGIN_RATE) -> float:
    """
    Binance-style liquidation price for isolated margin.
    Long:  liq = entry * (1 - 1/leverage + MMR)
    Short: liq = entry * (1 + 1/leverage - MMR)
    """
    if is_long:
        return entry * (1 - 1 / leverage + mmr)
    else:
        return entry * (1 + 1 / leverage - mmr)


def calc_leveraged_pnl(entry: float, exit_price: float, leverage: int, is_long: bool,
                        position_usd: float, hours_held: float) -> tuple[float, float, float, float]:
    """
    Returns: (pnl_usd, pnl_pct_on_margin, fees, funding)
    """
    # Raw P&L
    if is_long:
        raw_pnl_pct = (exit_price - entry) / entry
    else:
        raw_pnl_pct = (entry - exit_price) / entry

    leveraged_pnl_pct = raw_pnl_pct * leverage

    # Fees: entry taker + exit taker (conservative)
    fees = position_usd * TAKER_FEE * 2

    # Funding: approximate cost for holding a perp futures position
    funding_periods = hours_held / 8
    funding = position_usd * FUNDING_RATE_8H * funding_periods

    margin = position_usd / leverage
    pnl_usd = margin * leveraged_pnl_pct - fees - funding
    pnl_pct_on_margin = (pnl_usd / margin) * 100 if margin > 0 else 0

    return pnl_usd, pnl_pct_on_margin, fees, funding


# ─── Generate Base Signals ────────────────────────────────────────────────────

def generate_signals(all_data: dict) -> list[Signal]:
    """Run the signal generation logic (same as spot backtest)."""
    signals: list[Signal] = []
    now = datetime.now(tz=timezone.utc)
    start_date = now - timedelta(days=BACKTEST_DAYS)

    for ticker in ASSETS.values():
        daily_candles = all_data[ticker].get("1d", [])
        hourly_candles = all_data[ticker].get("1h", [])
        four_h_candles = all_data[ticker].get("4h", [])

        if len(daily_candles) < WARMUP_DAYS + 10:
            continue

        for day_idx in range(WARMUP_DAYS, len(daily_candles)):
            eval_candle = daily_candles[day_idx]
            if eval_candle.open_time < start_date:
                continue

            current_price = eval_candle.close
            eval_time = eval_candle.open_time

            daily_history = daily_candles[:day_idx + 1]
            four_h_history = [c for c in four_h_candles if c.open_time <= eval_time]
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
                    nearby_hourly = daily_history[-3:]

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
                    asset=ticker, signal_type=sig_type, entry_time=eval_time,
                    entry_mid=entry_mid, entry_low=zone["low"], entry_high=zone["high"],
                    target1=t1, target2=t2, stop_loss=sl,
                    rr_ratio=round(rr, 2), confluence_strength=zone["strength"],
                    expires_at=eval_time + timedelta(hours=SIGNAL_EXPIRY_HOURS),
                )
                signals.append(signal)

            # Resolve open signals
            for s in signals:
                if s.outcome != "open" or s.asset != ticker:
                    continue

                is_buy_signal = "buy" in s.signal_type

                if eval_time > s.expires_at:
                    s.outcome = "expired"
                    s.exit_time = eval_time
                    s.exit_price = current_price
                    s.pnl_pct = ((current_price - s.entry_mid) / s.entry_mid * 100) if is_buy_signal else ((s.entry_mid - current_price) / s.entry_mid * 100)
                    continue

                if is_buy_signal:
                    if eval_candle.low <= s.stop_loss:
                        s.outcome = "partial" if s.t1_hit else "loss"
                        s.exit_price = s.stop_loss
                        s.exit_time = eval_time
                        s.pnl_pct = (s.exit_price - s.entry_mid) / s.entry_mid * 100
                        continue
                    if not s.t1_hit and eval_candle.high >= s.target1:
                        s.t1_hit = True
                    if eval_candle.high >= s.target2:
                        s.outcome = "win"
                        s.exit_price = s.target2
                        s.exit_time = eval_time
                        s.pnl_pct = (s.exit_price - s.entry_mid) / s.entry_mid * 100
                else:
                    if eval_candle.high >= s.stop_loss:
                        s.outcome = "partial" if s.t1_hit else "loss"
                        s.exit_price = s.stop_loss
                        s.exit_time = eval_time
                        s.pnl_pct = (s.entry_mid - s.exit_price) / s.entry_mid * 100
                        continue
                    if not s.t1_hit and eval_candle.low <= s.target1:
                        s.t1_hit = True
                    if eval_candle.low <= s.target2:
                        s.outcome = "win"
                        s.exit_price = s.target2
                        s.exit_time = eval_time
                        s.pnl_pct = (s.entry_mid - s.exit_price) / s.entry_mid * 100

    # Mark remaining open with current unrealized P&L
    for s in signals:
        if s.outcome == "open":
            is_buy = "buy" in s.signal_type
            for tn in ASSETS.values():
                daily = all_data[tn].get("1d", [])
                if daily and tn == s.asset:
                    price = daily[-1].close
                    s.pnl_pct = ((price - s.entry_mid) / s.entry_mid * 100) if is_buy else ((s.entry_mid - price) / s.entry_mid * 100)

    return signals


# ─── Simulate Leveraged Portfolio ─────────────────────────────────────────────

def simulate_leverage(signals: list[Signal], leverage: int, margin_mode: str,
                       all_data: dict) -> dict:
    """
    Simulate a leveraged portfolio for a given leverage level.
    Returns performance summary dict.
    """
    balance = STARTING_BALANCE
    peak_balance = balance
    max_drawdown = 0.0
    trades: list[LeveragedTrade] = []
    total_fees = 0.0
    total_funding = 0.0
    liquidations = 0

    # For cross margin: track all open positions sharing the balance
    open_trades: list[LeveragedTrade] = []

    for signal in sorted(signals, key=lambda s: s.entry_time):
        if signal.outcome == "open":
            continue  # Skip still-open signals

        is_long = "buy" in signal.signal_type
        entry = signal.entry_mid

        # Position sizing
        margin_for_trade = balance * (POSITION_SIZE_PCT / 100)
        if margin_for_trade < 1:
            continue  # Can't afford to trade

        position_usd = margin_for_trade * leverage

        # Liquidation price
        liq_price = calc_liquidation_price(entry, leverage, is_long)

        # Check if price hit liquidation before stop loss
        # For isolated: liquidation is independent per position
        # For cross: we check if unrealized loss exceeds total balance
        was_liquidated = False

        if is_long:
            # Liquidated if price dropped to liq price (which is above stop for high leverage)
            if liq_price > signal.stop_loss and signal.outcome == "loss":
                # Check: did price actually reach liq before stop?
                # Since stop_loss < entry and liq < entry, compare them
                if liq_price >= signal.stop_loss:
                    # At high leverage, liquidation kicks in before stop loss
                    was_liquidated = True
            # Also check if daily low went below liq during the trade
            if signal.exit_price <= liq_price and signal.outcome in ("loss", "expired"):
                was_liquidated = True
        else:
            if liq_price < signal.stop_loss and signal.outcome == "loss":
                if liq_price <= signal.stop_loss:
                    was_liquidated = True
            if signal.exit_price >= liq_price and signal.outcome in ("loss", "expired"):
                was_liquidated = True

        # Calculate hours held
        if signal.exit_time and signal.entry_time:
            hours_held = (signal.exit_time - signal.entry_time).total_seconds() / 3600
        else:
            hours_held = SIGNAL_EXPIRY_HOURS

        if was_liquidated:
            # Isolated: lose the margin for this trade
            # Cross: lose the margin (simplified - in real cross, could lose more)
            pnl_usd = -margin_for_trade
            fees = position_usd * TAKER_FEE  # Only entry fee, liq engine closes
            funding = position_usd * FUNDING_RATE_8H * (hours_held / 8)
            pnl_pct_on_margin = -100.0
            liquidations += 1
        else:
            exit_price = signal.exit_price if signal.exit_price > 0 else entry
            pnl_usd, pnl_pct_on_margin, fees, funding = calc_leveraged_pnl(
                entry, exit_price, leverage, is_long, position_usd, hours_held
            )

        trade = LeveragedTrade(
            signal=signal, leverage=leverage, margin_mode=margin_mode,
            position_size_usd=position_usd, margin_used=margin_for_trade,
            entry_price=entry, liquidation_price=liq_price, is_long=is_long,
            pnl_usd=pnl_usd, pnl_pct_on_margin=pnl_pct_on_margin,
            fees_paid=fees, funding_paid=funding, liquidated=was_liquidated,
        )
        trades.append(trade)

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

    # Compute stats
    closed_trades = [t for t in trades if not t.liquidated]
    winning = [t for t in trades if t.pnl_usd > 0]
    losing = [t for t in trades if t.pnl_usd <= 0 and not t.liquidated]

    total_return = ((balance - STARTING_BALANCE) / STARTING_BALANCE) * 100

    return {
        "leverage": leverage,
        "margin_mode": margin_mode,
        "trades": len(trades),
        "wins": len(winning),
        "losses": len(losing),
        "liquidations": liquidations,
        "win_rate": len(winning) / len(trades) * 100 if trades else 0,
        "starting_balance": STARTING_BALANCE,
        "ending_balance": round(balance, 2),
        "total_return_pct": round(total_return, 2),
        "total_pnl_usd": round(balance - STARTING_BALANCE, 2),
        "max_drawdown_pct": round(max_drawdown, 2),
        "total_fees": round(total_fees, 2),
        "total_funding": round(total_funding, 2),
        "avg_pnl_per_trade": round(sum(t.pnl_usd for t in trades) / len(trades), 2) if trades else 0,
        "avg_roi_per_trade": round(sum(t.pnl_pct_on_margin for t in trades) / len(trades), 2) if trades else 0,
        "best_trade_pct": round(max(t.pnl_pct_on_margin for t in trades), 2) if trades else 0,
        "worst_trade_pct": round(min(t.pnl_pct_on_margin for t in trades), 2) if trades else 0,
        "trades_list": trades,
    }


# ─── Print Results ────────────────────────────────────────────────────────────

def print_spot_results(signals: list[Signal]):
    print()
    print("=" * 70)
    print("SPOT (1x) BASELINE RESULTS")
    print("=" * 70)

    closed = [s for s in signals if s.outcome in ("win", "partial", "loss")]
    wins = [s for s in signals if s.outcome == "win"]
    partials = [s for s in signals if s.outcome == "partial"]
    losses = [s for s in signals if s.outcome == "loss"]
    expired = [s for s in signals if s.outcome == "expired"]

    print(f"\nTotal: {len(signals)} | W: {len(wins)} | P: {len(partials)} | L: {len(losses)} | Exp: {len(expired)}")

    if closed:
        win_rate = (len(wins) + len(partials)) / len(closed) * 100
        avg_win = sum(s.pnl_pct for s in wins) / len(wins) if wins else 0
        avg_loss = sum(s.pnl_pct for s in losses) / len(losses) if losses else 0
        total_pnl = sum(s.pnl_pct for s in closed)
        gross_profit = sum(s.pnl_pct for s in closed if s.pnl_pct > 0)
        gross_loss = abs(sum(s.pnl_pct for s in closed if s.pnl_pct < 0))
        pf = gross_profit / gross_loss if gross_loss > 0 else float("inf")

        print(f"Win Rate: {win_rate:.1f}% | Avg Win: {avg_win:+.2f}% | Avg Loss: {avg_loss:+.2f}%")
        print(f"Total P&L: {total_pnl:+.2f}% | Profit Factor: {pf:.2f}")


def print_leverage_comparison(results: list[dict]):
    print()
    print("=" * 70)
    print("LEVERAGE COMPARISON TABLE")
    print("=" * 70)

    # Header
    print(f"\n{'':>6} {'Mode':<10} {'Trades':>6} {'Win%':>6} {'Liq':>4} {'End Bal':>10} "
          f"{'Return':>8} {'MaxDD':>7} {'Fees':>7} {'Fund':>7} {'Avg ROI':>8} {'Best':>8} {'Worst':>8}")
    print(f"  {'-'*104}")

    for r in results:
        mode_str = r['margin_mode'][:4].title()
        print(f"  {r['leverage']:>2}x  {mode_str:<10} {r['trades']:>6} {r['win_rate']:>5.1f}% {r['liquidations']:>4} "
              f"${r['ending_balance']:>9,.2f} {r['total_return_pct']:>+7.1f}% {r['max_drawdown_pct']:>6.1f}% "
              f"${r['total_fees']:>6.2f} ${r['total_funding']:>5.2f} {r['avg_roi_per_trade']:>+7.1f}% "
              f"{r['best_trade_pct']:>+7.1f}% {r['worst_trade_pct']:>+7.1f}%")


def print_trade_log(results: list[dict]):
    # Print detailed log for a couple key leverage levels
    for r in results:
        if r["leverage"] not in [1, 5, 10]:
            continue

        print(f"\n{'='*70}")
        print(f"TRADE LOG — {r['leverage']}x {r['margin_mode'].upper()}")
        print(f"{'='*70}")
        print(f"{'Date':<12} {'Asset':<7} {'Dir':<5} {'Entry':>10} {'Exit':>10} {'Liq':>10} "
              f"{'Margin':>8} {'P&L $':>9} {'ROI%':>8} {'Notes'}")
        print(f"{'-'*100}")

        running = STARTING_BALANCE
        for t in r["trades_list"]:
            s = t.signal
            date_str = s.entry_time.strftime("%Y-%m-%d")
            direction = "LONG" if t.is_long else "SHORT"
            exit_p = s.exit_price if s.exit_price > 0 else s.entry_mid
            notes = []
            if t.liquidated:
                notes.append("LIQUIDATED")
            else:
                notes.append(s.outcome.upper())
            if s.t1_hit and s.outcome != "win":
                notes.append("T1 hit")

            running += t.pnl_usd
            print(f"{date_str:<12} {s.asset:<7} {direction:<5} {t.entry_price:>10,.2f} {exit_p:>10,.2f} "
                  f"{t.liquidation_price:>10,.2f} ${t.margin_used:>7,.0f} {t.pnl_usd:>+9,.2f} "
                  f"{t.pnl_pct_on_margin:>+7.1f}% {' '.join(notes)}")

        print(f"\n  Final Balance: ${running:,.2f}")


def print_risk_warnings(results: list[dict]):
    print(f"\n{'='*70}")
    print("RISK ANALYSIS")
    print(f"{'='*70}")

    for r in results:
        lev = r["leverage"]
        mode = r["margin_mode"]
        liqs = r["liquidations"]
        dd = r["max_drawdown_pct"]
        ret = r["total_return_pct"]

        risk_level = "LOW" if dd < 15 else "MEDIUM" if dd < 30 else "HIGH" if dd < 50 else "EXTREME"

        warnings = []
        if liqs > 0:
            warnings.append(f"{liqs} liquidation(s) — you would have lost 100% of margin on those trades")
        if dd > 50:
            warnings.append(f"Max drawdown {dd:.1f}% — account nearly wiped")
        if dd > 30:
            warnings.append(f"Max drawdown {dd:.1f}% — significant recovery needed")

        emoji = {"LOW": "  ", "MEDIUM": "  ", "HIGH": "  ", "EXTREME": "  "}
        print(f"\n{emoji.get(risk_level, '')} {lev}x {mode}: Risk = {risk_level}")
        print(f"  Return: {ret:+.1f}% | Max DD: {dd:.1f}% | Liquidations: {liqs}")
        if warnings:
            for w in warnings:
                print(f"  -> {w}")

        # Calculate required win rate to break even at this leverage
        if r["trades"] > 0:
            avg_win_roi = max(1, abs(r["best_trade_pct"]) * 0.6)  # estimate
            avg_loss_roi = max(1, abs(r["worst_trade_pct"]) * 0.6)
            be_wr = avg_loss_roi / (avg_win_roi + avg_loss_roi) * 100
            print(f"  Approx break-even win rate at {lev}x: ~{be_wr:.0f}%")


# ─── Main ─────────────────────────────────────────────────────────────────────

def run_backtest():
    print("=" * 70)
    print("FIBONACCI SWING SIGNAL BACKTEST — LEVERAGE ANALYSIS")
    print("=" * 70)
    print(f"Period: {BACKTEST_DAYS} days | Assets: {len(ASSETS)}")
    print(f"Starting Balance: ${STARTING_BALANCE:,} | Position Size: {POSITION_SIZE_PCT}% per trade")
    print(f"Fees: {TAKER_FEE*100:.2f}% taker | Funding: {FUNDING_RATE_8H*100:.3f}%/8h")
    print()

    # Fetch data
    print("Fetching historical data from Binance...")
    all_data = fetch_all_data()
    print()

    # Generate base signals
    print("Generating signals...")
    signals = generate_signals(all_data)
    closed = [s for s in signals if s.outcome in ("win", "partial", "loss")]
    print(f"Generated {len(signals)} signals ({len(closed)} closed)\n")

    # Print spot baseline
    print_spot_results(signals)

    # Run leverage simulations
    all_results = []

    for mode in ["isolated", "cross"]:
        for lev in LEVERAGE_LEVELS:
            result = simulate_leverage(signals, lev, mode, all_data)
            all_results.append(result)

    # Print comparison
    print_leverage_comparison(all_results)

    # Print trade logs for key levels
    # Filter to isolated only for trade logs (avoid duplication)
    isolated_results = [r for r in all_results if r["margin_mode"] == "isolated"]
    print_trade_log(isolated_results)

    # Risk analysis
    print_risk_warnings(all_results)

    # Signal log
    print(f"\n{'='*70}")
    print("SIGNAL LOG (BASE)")
    print(f"{'='*70}")
    print(f"{'Date':<12} {'Asset':<8} {'Type':<12} {'Entry':>10} {'T1':>10} {'SL':>10} {'R:R':>5} {'Outcome':<8} {'P&L':>7}")
    print(f"{'-'*85}")

    for s in sorted(signals, key=lambda x: x.entry_time):
        date_str = s.entry_time.strftime("%Y-%m-%d")
        pnl_str = f"{s.pnl_pct:+.1f}%" if s.outcome != "open" else "..."
        print(f"{date_str:<12} {s.asset:<8} {s.signal_type:<12} {s.entry_mid:>10,.2f} {s.target1:>10,.2f} {s.stop_loss:>10,.2f} {s.rr_ratio:>5.1f} {s.outcome:<8} {pnl_str:>7}")

    print()


if __name__ == "__main__":
    run_backtest()
