#!/usr/bin/env python3
"""
Backtest: Credit Stress Exit Overlay for QPS

Tests whether a credit stress indicator (HY spreads widening / SOFR stress)
can improve QPS by providing earlier EXIT signals — not faster entries.

Thesis: When credit markets start pricing in risk (HY spreads widen, treasury
volatility rises) BEFORE equities sell off, an early exit signal can reduce
drawdowns. The QPS SMA framework handles entries well; the gap is exits.

Proxy indicators (available via yfinance):
  - HYG (iShares High Yield Corporate Bond ETF) — drops when credit stress rises
  - LQD (Investment Grade Corporate Bond ETF) — drops on broader credit concern
  - HYG/SPY ratio — divergence = credit leading equities lower
  - TLT (20Y Treasury) — flight to safety indicator

Overlay logic tested:
  - When HYG drops X% over N days while SPY is flat/up → "credit divergence"
  - This CAPS bullish signals to neutral (exit warning)
  - Does NOT force bearish — just removes the bullish green light

Period: Jan 2020 – Apr 2026
Assets tested: SPY, BTC-USD

Usage:
    python3 scripts/backtest_credit_stress.py
"""

import math
from datetime import datetime
from dataclasses import dataclass, field
from typing import Optional

try:
    import yfinance as yf
except ImportError:
    print("Install yfinance: pip install yfinance")
    exit(1)


# ─── Configuration ───────────────────────────────────────────────────────────

BACKTEST_START = "2020-01-01"
BACKTEST_END = "2026-04-17"

# QPS scoring weights (matches production)
ABOVE_200_SMA = 18
BELOW_200_SMA = -8
ABOVE_50_SMA = 8
ABOVE_21_SMA = 8
BELOW_21_SMA = -10
SMA_21_ABOVE_50 = 6
SMA_21_BELOW_50 = -6
RSI_OVERSOLD_30 = 5
RSI_OVERSOLD_40 = 3
RSI_OVERBOUGHT_75 = -3
BMSB_ABOVE = 4
BMSB_IN_BAND = 1
BMSB_BELOW = -2
BULLISH_THRESHOLD = 70
NEUTRAL_THRESHOLD = 45

# Credit stress overlay configs to test
CREDIT_CONFIGS = [
    {
        "name": "HYG 5d drop >1.5%",
        "indicator": "hyg_roc",
        "lookback": 5,
        "threshold": -1.5,
        "spy_floor": -1.0,  # SPY must not be down more than this (divergence)
    },
    {
        "name": "HYG 5d drop >2.0%",
        "indicator": "hyg_roc",
        "lookback": 5,
        "threshold": -2.0,
        "spy_floor": -1.0,
    },
    {
        "name": "HYG 10d drop >2.5%",
        "indicator": "hyg_roc",
        "lookback": 10,
        "threshold": -2.5,
        "spy_floor": -2.0,
    },
    {
        "name": "HYG/SPY ratio 10d drop >1.5%",
        "indicator": "hyg_spy_ratio_roc",
        "lookback": 10,
        "threshold": -1.5,
        "spy_floor": None,
    },
    {
        "name": "HYG/SPY ratio 5d drop >1.0%",
        "indicator": "hyg_spy_ratio_roc",
        "lookback": 5,
        "threshold": -1.0,
        "spy_floor": None,
    },
    {
        "name": "HYG 5d >1.5% + TLT up >1%",
        "indicator": "hyg_tlt_divergence",
        "lookback": 5,
        "threshold": -1.5,
        "tlt_threshold": 1.0,
        "spy_floor": None,
    },
]


# ─── Data Structures ─────────────────────────────────────────────────────────

@dataclass
class DayData:
    date: str
    close: float
    sma21: Optional[float] = None
    sma50: Optional[float] = None
    sma200: Optional[float] = None
    sma140: Optional[float] = None
    ema147: Optional[float] = None
    rsi: Optional[float] = None
    # Credit stress data
    hyg_roc: Optional[float] = None
    spy_roc: Optional[float] = None
    hyg_spy_ratio_roc: Optional[float] = None
    tlt_roc: Optional[float] = None
    credit_stress: bool = False


@dataclass
class Signal:
    date: str
    score: float
    signal: str
    price: float
    credit_stress: bool = False
    original_signal: str = ""  # before credit cap


@dataclass
class DrawdownEvent:
    start_date: str
    peak_price: float
    trough_price: float
    trough_date: str
    drawdown_pct: float
    recovery_date: Optional[str] = None
    # Signal context
    signal_at_peak: str = ""
    days_warning: int = 0  # days between credit stress warning and drawdown start


@dataclass
class BacktestResult:
    name: str
    signals: list = field(default_factory=list)
    bullish_signals: int = 0
    neutral_signals: int = 0
    bearish_signals: int = 0
    signal_changes: int = 0
    # Credit-specific
    credit_caps: int = 0  # times credit stress capped bullish → neutral
    # Drawdown analysis
    max_drawdowns_avoided: list = field(default_factory=list)
    max_drawdown_pct: float = 0
    # Return simulation
    total_return_pct: float = 0
    time_in_market_pct: float = 0


# ─── Technical Indicators ────────────────────────────────────────────────────

def compute_sma(closes, period):
    result = [None] * len(closes)
    for i in range(period - 1, len(closes)):
        result[i] = sum(closes[i - period + 1:i + 1]) / period
    return result


def compute_ema(closes, period):
    result = [None] * len(closes)
    if len(closes) < period:
        return result
    k = 2.0 / (period + 1)
    result[period - 1] = sum(closes[:period]) / period
    for i in range(period, len(closes)):
        if result[i - 1] is not None:
            result[i] = closes[i] * k + result[i - 1] * (1 - k)
    return result


def compute_rsi(closes, period=14):
    result = [None] * len(closes)
    if len(closes) < period + 1:
        return result
    gains, losses = [], []
    for i in range(1, period + 1):
        change = closes[i] - closes[i - 1]
        gains.append(max(0, change))
        losses.append(max(0, -change))
    avg_gain = sum(gains) / period
    avg_loss = sum(losses) / period
    if avg_loss == 0:
        result[period] = 100.0
    else:
        result[period] = 100.0 - (100.0 / (1.0 + avg_gain / avg_loss))
    for i in range(period + 1, len(closes)):
        change = closes[i] - closes[i - 1]
        avg_gain = (avg_gain * (period - 1) + max(0, change)) / period
        avg_loss = (avg_loss * (period - 1) + max(0, -change)) / period
        if avg_loss == 0:
            result[i] = 100.0
        else:
            result[i] = 100.0 - (100.0 / (1.0 + avg_gain / avg_loss))
    return result


def compute_roc(closes, lookback):
    """Rate of change (%) over lookback period."""
    result = [None] * len(closes)
    for i in range(lookback, len(closes)):
        if closes[i - lookback] > 0:
            result[i] = ((closes[i] - closes[i - lookback]) / closes[i - lookback]) * 100
    return result


# ─── QPS Scoring ─────────────────────────────────────────────────────────────

def compute_trend_score(day):
    score = 50.0
    if day.sma200 is not None:
        score += ABOVE_200_SMA if day.close > day.sma200 else BELOW_200_SMA
    if day.sma50 is not None and day.close > day.sma50:
        score += ABOVE_50_SMA
    if day.sma21 is not None:
        score += ABOVE_21_SMA if day.close > day.sma21 else BELOW_21_SMA
    if day.sma21 is not None and day.sma50 is not None:
        score += SMA_21_ABOVE_50 if day.sma21 > day.sma50 else SMA_21_BELOW_50
    if day.rsi is not None:
        if day.rsi <= 30:
            score += RSI_OVERSOLD_30
        elif day.rsi <= 40:
            score += RSI_OVERSOLD_40
        elif day.rsi >= 75:
            score += RSI_OVERBOUGHT_75
    if day.sma140 is not None and day.ema147 is not None:
        band_top = max(day.sma140, day.ema147)
        band_bottom = min(day.sma140, day.ema147)
        if day.close > band_top:
            score += BMSB_ABOVE
        elif day.close >= band_bottom:
            score += BMSB_IN_BAND
        else:
            score += BMSB_BELOW
    return max(0, min(100, score))


def derive_signal(score, day):
    if score >= BULLISH_THRESHOLD:
        if day.sma200 is not None and day.close <= day.sma200:
            return "neutral"
        if (day.sma21 is not None and day.close < day.sma21 and
                day.sma50 is not None and day.close < day.sma50):
            return "neutral"
        return "bullish"
    elif score >= NEUTRAL_THRESHOLD:
        return "neutral"
    else:
        return "bearish"


# ─── Data Fetching ───────────────────────────────────────────────────────────

def fetch_all_data(asset_ticker):
    """Fetch asset, HYG, SPY, TLT data and compute all indicators."""
    print(f"  Fetching {asset_ticker}, HYG, SPY, TLT...")

    tickers = [asset_ticker, "HYG", "SPY", "TLT"]
    data = {}
    for t in tickers:
        df = yf.download(t, start=BACKTEST_START, end=BACKTEST_END, progress=False)
        if hasattr(df.columns, 'levels') and len(df.columns.levels) > 1:
            df.columns = df.columns.get_level_values(0)
        data[t] = {idx.strftime("%Y-%m-%d"): float(row["Close"]) for idx, row in df.iterrows()}

    # Build aligned date list from asset
    asset_df = yf.download(asset_ticker, start=BACKTEST_START, end=BACKTEST_END, progress=False)
    if hasattr(asset_df.columns, 'levels') and len(asset_df.columns.levels) > 1:
        asset_df.columns = asset_df.columns.get_level_values(0)

    dates = [idx.strftime("%Y-%m-%d") for idx in asset_df.index]
    asset_closes = [float(row["Close"]) for _, row in asset_df.iterrows()]

    # Align other tickers
    hyg_closes = [data["HYG"].get(d, 0) for d in dates]
    spy_closes = [data["SPY"].get(d, 0) for d in dates]
    tlt_closes = [data["TLT"].get(d, 0) for d in dates]

    # HYG/SPY ratio
    hyg_spy_ratio = []
    for h, s in zip(hyg_closes, spy_closes):
        if s > 0 and h > 0:
            hyg_spy_ratio.append(h / s)
        else:
            hyg_spy_ratio.append(0)

    # Compute asset indicators
    sma21 = compute_sma(asset_closes, 21)
    sma50 = compute_sma(asset_closes, 50)
    sma200 = compute_sma(asset_closes, 200)
    sma140 = compute_sma(asset_closes, 140)
    ema147 = compute_ema(asset_closes, 147)
    rsi = compute_rsi(asset_closes, 14)

    # Compute ROCs for all lookbacks we'll test
    hyg_roc_5 = compute_roc(hyg_closes, 5)
    hyg_roc_10 = compute_roc(hyg_closes, 10)
    spy_roc_5 = compute_roc(spy_closes, 5)
    spy_roc_10 = compute_roc(spy_closes, 10)
    ratio_roc_5 = compute_roc(hyg_spy_ratio, 5)
    ratio_roc_10 = compute_roc(hyg_spy_ratio, 10)
    tlt_roc_5 = compute_roc(tlt_closes, 5)

    # Build DayData
    days = []
    for i in range(len(dates)):
        day = DayData(
            date=dates[i], close=asset_closes[i],
            sma21=sma21[i], sma50=sma50[i], sma200=sma200[i],
            sma140=sma140[i], ema147=ema147[i], rsi=rsi[i],
        )
        # Store all ROC variants for config selection
        day._hyg_roc_5 = hyg_roc_5[i]
        day._hyg_roc_10 = hyg_roc_10[i]
        day._spy_roc_5 = spy_roc_5[i]
        day._spy_roc_10 = spy_roc_10[i]
        day._ratio_roc_5 = ratio_roc_5[i]
        day._ratio_roc_10 = ratio_roc_10[i]
        day._tlt_roc_5 = tlt_roc_5[i]
        days.append(day)

    return days, asset_closes


# ─── Credit Stress Detection ────────────────────────────────────────────────

def detect_credit_stress(day, config):
    """Check if credit stress conditions are met for a given config."""
    indicator = config["indicator"]
    lookback = config["lookback"]

    if indicator == "hyg_roc":
        hyg_roc = day._hyg_roc_5 if lookback == 5 else day._hyg_roc_10
        spy_roc = day._spy_roc_5 if lookback == 5 else day._spy_roc_10
        if hyg_roc is None:
            return False
        # HYG dropping while SPY isn't dropping as much (divergence)
        if hyg_roc <= config["threshold"]:
            if config["spy_floor"] is not None and spy_roc is not None:
                return spy_roc > config["spy_floor"]  # SPY relatively flat
            return True

    elif indicator == "hyg_spy_ratio_roc":
        ratio_roc = day._ratio_roc_5 if lookback == 5 else day._ratio_roc_10
        if ratio_roc is None:
            return False
        return ratio_roc <= config["threshold"]

    elif indicator == "hyg_tlt_divergence":
        hyg_roc = day._hyg_roc_5
        tlt_roc = day._tlt_roc_5
        if hyg_roc is None or tlt_roc is None:
            return False
        # HYG dropping AND TLT rising (flight to safety)
        return hyg_roc <= config["threshold"] and tlt_roc >= config.get("tlt_threshold", 1.0)

    return False


# ─── Run Backtest ────────────────────────────────────────────────────────────

def run_backtest(days, closes, name, use_credit=False, credit_config=None):
    result = BacktestResult(name=name)
    prev_signal = None
    peak_price = closes[0]
    peak_idx = 0
    max_dd = 0

    for i, day in enumerate(days):
        if day.sma21 is None:
            continue

        score = compute_trend_score(day)
        signal = derive_signal(score, day)
        original_signal = signal

        # Apply credit stress cap
        if use_credit and credit_config:
            is_stressed = detect_credit_stress(day, credit_config)
            if is_stressed and signal == "bullish":
                signal = "neutral"
                result.credit_caps += 1

        sig = Signal(date=day.date, score=score, signal=signal, price=day.close,
                     credit_stress=(signal != original_signal), original_signal=original_signal)
        result.signals.append(sig)

        if signal == "bullish":
            result.bullish_signals += 1
        elif signal == "neutral":
            result.neutral_signals += 1
        else:
            result.bearish_signals += 1

        if prev_signal is not None and signal != prev_signal:
            result.signal_changes += 1
        prev_signal = signal

        # Track drawdown (when signal is bullish = "in the market")
        if day.close > peak_price:
            peak_price = day.close
            peak_idx = i
        dd = (day.close - peak_price) / peak_price * 100
        if dd < max_dd:
            max_dd = dd

    result.max_drawdown_pct = max_dd

    # Simple return simulation: invested when bullish, cash when neutral/bearish
    portfolio = 10000.0
    invested = False
    entry_price = 0
    days_invested = 0

    for sig in result.signals:
        if sig.signal == "bullish" and not invested:
            invested = True
            entry_price = sig.price
        elif sig.signal != "bullish" and invested:
            invested = False
            if entry_price > 0:
                ret = (sig.price - entry_price) / entry_price
                portfolio *= (1 + ret)
            entry_price = 0

        if invested:
            days_invested += 1

    # Close final position
    if invested and entry_price > 0 and result.signals:
        ret = (result.signals[-1].price - entry_price) / entry_price
        portfolio *= (1 + ret)

    result.total_return_pct = (portfolio - 10000) / 10000 * 100
    result.time_in_market_pct = (days_invested / len(result.signals) * 100) if result.signals else 0

    return result


# ─── Key Drawdown Events ────────────────────────────────────────────────────

DRAWDOWN_EVENTS = {
    "COVID Crash (Feb-Mar 2020)": ("2020-02-19", "2020-03-23"),
    "2022 Bear Market Start": ("2022-01-03", "2022-06-17"),
    "SVB/Banking Crisis (Mar 2023)": ("2023-02-02", "2023-03-13"),
    "Aug 2024 Yen Carry Unwind": ("2024-07-16", "2024-08-05"),
    "Liberation Day (Mar 2025)": ("2025-02-19", "2025-04-08"),
    "Iran War Selloff (Feb-Mar 2026)": ("2026-02-18", "2026-03-31"),
}


def analyze_drawdown_protection(result, closes, days):
    """Check if the system was already neutral/bearish before major drawdowns."""
    protection = {}
    for event_name, (peak_date, trough_date) in DRAWDOWN_EVENTS.items():
        # Find signal 1 day before peak
        signal_before = None
        days_warning = 0
        for sig in result.signals:
            if sig.date <= peak_date:
                signal_before = sig.signal
                if sig.signal != "bullish":
                    # Count how many days before peak we exited
                    try:
                        peak_dt = datetime.strptime(peak_date, "%Y-%m-%d")
                        sig_dt = datetime.strptime(sig.date, "%Y-%m-%d")
                        days_warning = (peak_dt - sig_dt).days
                    except:
                        pass
            elif sig.date > peak_date:
                break

        # Was credit stress active during approach to peak?
        credit_active = False
        for sig in result.signals:
            if peak_date >= sig.date >= (datetime.strptime(peak_date, "%Y-%m-%d") -
                                          __import__('datetime').timedelta(days=10)).strftime("%Y-%m-%d"):
                if sig.credit_stress:
                    credit_active = True
                    break

        protection[event_name] = {
            "signal_at_peak": signal_before or "—",
            "credit_cap_active": credit_active,
            "days_warning": days_warning,
        }
    return protection


# ─── Report ──────────────────────────────────────────────────────────────────

def print_report(asset_name, baseline, variants):
    print(f"\n{'='*90}")
    print(f"  {asset_name} — Credit Stress Exit Overlay Backtest")
    print(f"{'='*90}")

    all_results = [baseline] + variants

    # Summary
    print(f"\n  {'Model':<35} {'Bull':>5} {'Neut':>5} {'Bear':>5} {'Caps':>5} {'Chg':>5} {'Return':>8} {'InMkt':>6} {'MaxDD':>7}")
    print("  " + "-" * 87)
    for r in all_results:
        marker = " ◀" if r == baseline else ""
        print(f"  {r.name:<35} {r.bullish_signals:>5} {r.neutral_signals:>5} {r.bearish_signals:>5} "
              f"{r.credit_caps:>5} {r.signal_changes:>5} {r.total_return_pct:>+7.1f}% {r.time_in_market_pct:>5.1f}% "
              f"{r.max_drawdown_pct:>+6.1f}%{marker}")

    # Drawdown protection analysis
    print(f"\n  Drawdown Protection (signal at market peak):")
    print(f"  {'Event':<35} ", end="")
    for r in all_results:
        label = r.name[:14]
        print(f"{label:>16} ", end="")
    print()
    print("  " + "-" * (35 + 17 * len(all_results)))

    baseline_protection = analyze_drawdown_protection(baseline, None, None)
    variant_protections = [analyze_drawdown_protection(v, None, None) for v in variants]

    for event_name in DRAWDOWN_EVENTS:
        print(f"  {event_name:<35} ", end="")
        for i, r in enumerate(all_results):
            if i == 0:
                p = baseline_protection.get(event_name, {})
            else:
                p = variant_protections[i - 1].get(event_name, {})
            sig = p.get("signal_at_peak", "—")
            cap = " [C]" if p.get("credit_cap_active") else ""
            print(f"{sig + cap:>16} ", end="")
        print()

    # Credit stress events detail
    for r in variants:
        if r.credit_caps > 0:
            print(f"\n  Credit Cap Events for '{r.name}':")
            cap_dates = [s.date for s in r.signals if s.credit_stress]
            # Group consecutive dates
            if cap_dates:
                ranges = []
                start = cap_dates[0]
                prev = cap_dates[0]
                for d in cap_dates[1:]:
                    prev_dt = datetime.strptime(prev, "%Y-%m-%d")
                    curr_dt = datetime.strptime(d, "%Y-%m-%d")
                    if (curr_dt - prev_dt).days > 3:
                        ranges.append((start, prev, len([x for x in cap_dates if start <= x <= prev])))
                        start = d
                    prev = d
                ranges.append((start, prev, len([x for x in cap_dates if start <= x <= prev])))

                for s, e, count in ranges[:15]:
                    period = f"{s} → {e}" if s != e else s
                    print(f"    {period} ({count} days capped)")


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    print("QPS Credit Stress Exit Overlay Backtest")
    print("=" * 50)

    for asset_ticker, asset_name in [("SPY", "S&P 500"), ("BTC-USD", "Bitcoin")]:
        print(f"\n▸ Loading data for {asset_name}...")
        days, closes = fetch_all_data(asset_ticker)
        print(f"  {len(days)} trading days loaded ({days[0].date} → {days[-1].date})")

        # Baseline
        baseline = run_backtest(days, closes, "v2.2 (no credit overlay)")

        # Variants
        variants = []
        for config in CREDIT_CONFIGS:
            r = run_backtest(days, closes, config["name"],
                             use_credit=True, credit_config=config)
            variants.append(r)

        print_report(asset_name, baseline, variants)

    print(f"\n{'='*90}")
    print("  INTERPRETATION GUIDE")
    print(f"{'='*90}")
    print("""
  Caps: Number of days where credit stress capped a bullish signal to neutral
  Return: Simple long-when-bullish simulation ($10K start)
  InMkt: % of time the model had you invested (bullish)
  MaxDD: Maximum peak-to-trough drawdown during the period

  [C] in drawdown table = credit cap was active in the 10 days before that peak

  Good overlay: reduces MaxDD and improves Return/InMkt ratio (better risk-adjusted)
  Bad overlay: caps bullish during healthy periods (reduces Return without reducing MaxDD)

  Key question: Does the overlay cap you OUT of the market before drawdowns
  without capping you out during healthy bull runs?
""")


if __name__ == "__main__":
    main()
