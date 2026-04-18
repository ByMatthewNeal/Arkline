#!/usr/bin/env python3
"""
Backtest: QPS Volatility Compression Signal

Tests whether adding a VIX rate-of-change component to QPS scoring
improves signal timing on mechanical rallies without increasing false positives.

Compares:
  - QPS v2.2 (current): SMA position + RSI + BMSB
  - QPS v2.3 (proposed): v2.2 + VIX 5-day rate-of-change bonus/penalty

Test assets: BTC (via Coinbase), SPY (via yfinance)
VIX data: yfinance (^VIX)
Period: Jan 2020 – Apr 2026 (captures COVID crash, 2022 bear, 2025-26 tariff volatility)

Metrics:
  - Signal timing: days earlier/later on major rallies
  - False positive rate: bullish signals that led to >5% drawdown within 10 days
  - Hit rate: bullish signals followed by >5% gain within 20 days
  - Risk-adjusted return simulation

Usage:
    pip install yfinance
    python3 scripts/backtest_vol_compression.py
"""

import json
import math
import statistics
from datetime import datetime, timedelta
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

# Current QPS scoring weights (matches production pipeline)
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

# Proposed vol-compression parameters to test
VOL_COMPRESSION_CONFIGS = [
    {"name": "v2.3a (+4/-4, 5d, -20%/+30%)", "boost": 4, "penalty": -4, "lookback": 5, "compress_pct": -20, "expand_pct": 30},
    {"name": "v2.3b (+3/-3, 5d, -15%/+25%)", "boost": 3, "penalty": -3, "lookback": 5, "compress_pct": -15, "expand_pct": 25},
    {"name": "v2.3c (+5/-5, 5d, -20%/+30%)", "boost": 5, "penalty": -5, "lookback": 5, "compress_pct": -20, "expand_pct": 30},
    {"name": "v2.3d (+4/-4, 3d, -15%/+25%)", "boost": 4, "penalty": -4, "lookback": 3, "compress_pct": -15, "expand_pct": 25},
    {"name": "v2.3e (+4/-3, 5d, -20%/+35%)", "boost": 4, "penalty": -3, "lookback": 5, "compress_pct": -20, "expand_pct": 35},
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
    vix_close: Optional[float] = None
    vix_roc: Optional[float] = None  # VIX rate of change over lookback


@dataclass
class Signal:
    date: str
    score: float
    signal: str  # bullish/neutral/bearish
    price: float
    vix: Optional[float] = None
    vix_roc: Optional[float] = None


@dataclass
class BacktestResult:
    name: str
    signals: list = field(default_factory=list)
    # Timing
    first_bullish_dates: dict = field(default_factory=dict)  # rally_name → date
    # Quality
    bullish_signals: int = 0
    false_positives: int = 0  # bullish → >5% drawdown in 10 days
    true_positives: int = 0   # bullish → >5% gain in 20 days
    # Transitions
    signal_changes: int = 0


# ─── Technical Indicators ────────────────────────────────────────────────────

def compute_sma(closes: list[float], period: int) -> list[Optional[float]]:
    result = [None] * len(closes)
    for i in range(period - 1, len(closes)):
        result[i] = sum(closes[i - period + 1:i + 1]) / period
    return result


def compute_ema(closes: list[float], period: int) -> list[Optional[float]]:
    result: list[Optional[float]] = [None] * len(closes)
    if len(closes) < period:
        return result
    k = 2.0 / (period + 1)
    # Seed with SMA
    result[period - 1] = sum(closes[:period]) / period
    for i in range(period, len(closes)):
        prev = result[i - 1]
        if prev is not None:
            result[i] = closes[i] * k + prev * (1 - k)
    return result


def compute_rsi(closes: list[float], period: int = 14) -> list[Optional[float]]:
    result: list[Optional[float]] = [None] * len(closes)
    if len(closes) < period + 1:
        return result

    gains = []
    losses = []
    for i in range(1, period + 1):
        change = closes[i] - closes[i - 1]
        gains.append(max(0, change))
        losses.append(max(0, -change))

    avg_gain = sum(gains) / period
    avg_loss = sum(losses) / period

    if avg_loss == 0:
        result[period] = 100.0
    else:
        rs = avg_gain / avg_loss
        result[period] = 100.0 - (100.0 / (1.0 + rs))

    for i in range(period + 1, len(closes)):
        change = closes[i] - closes[i - 1]
        gain = max(0, change)
        loss = max(0, -change)
        avg_gain = (avg_gain * (period - 1) + gain) / period
        avg_loss = (avg_loss * (period - 1) + loss) / period
        if avg_loss == 0:
            result[i] = 100.0
        else:
            rs = avg_gain / avg_loss
            result[i] = 100.0 - (100.0 / (1.0 + rs))

    return result


def compute_vix_roc(vix_closes: list[float], lookback: int) -> list[Optional[float]]:
    """Compute VIX rate of change (%) over lookback period."""
    result: list[Optional[float]] = [None] * len(vix_closes)
    for i in range(lookback, len(vix_closes)):
        prev = vix_closes[i - lookback]
        if prev > 0:
            result[i] = ((vix_closes[i] - prev) / prev) * 100
    return result


# ─── QPS Scoring ─────────────────────────────────────────────────────────────

def compute_trend_score(day: DayData) -> float:
    """Current QPS v2.2 scoring — matches production pipeline exactly."""
    score = 50.0

    # SMA position
    if day.sma200 is not None:
        if day.close > day.sma200:
            score += ABOVE_200_SMA
        else:
            score += BELOW_200_SMA

    if day.sma50 is not None and day.close > day.sma50:
        score += ABOVE_50_SMA

    if day.sma21 is not None:
        if day.close > day.sma21:
            score += ABOVE_21_SMA
        else:
            score += BELOW_21_SMA

    # SMA crossover
    if day.sma21 is not None and day.sma50 is not None:
        if day.sma21 > day.sma50:
            score += SMA_21_ABOVE_50
        else:
            score += SMA_21_BELOW_50

    # RSI
    if day.rsi is not None:
        if day.rsi <= 30:
            score += RSI_OVERSOLD_30
        elif day.rsi <= 40:
            score += RSI_OVERSOLD_40
        elif day.rsi >= 75:
            score += RSI_OVERBOUGHT_75

    # BMSB
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


def derive_signal(score: float, day: DayData) -> str:
    """Derive signal with caps — matches production pipeline."""
    if score >= BULLISH_THRESHOLD:
        # Cap: below 200 SMA → neutral
        if day.sma200 is not None and day.close <= day.sma200:
            return "neutral"
        # Cap: below both 21 AND 50 → neutral
        if (day.sma21 is not None and day.close < day.sma21 and
                day.sma50 is not None and day.close < day.sma50):
            return "neutral"
        return "bullish"
    elif score >= NEUTRAL_THRESHOLD:
        return "neutral"
    else:
        return "bearish"


def compute_signal_v22(day: DayData) -> Signal:
    """Current production QPS v2.2."""
    score = compute_trend_score(day)
    signal = derive_signal(score, day)
    return Signal(date=day.date, score=score, signal=signal, price=day.close,
                  vix=day.vix_close, vix_roc=day.vix_roc)


def compute_signal_with_vol(day: DayData, config: dict) -> Signal:
    """QPS v2.3 — v2.2 + VIX rate-of-change modifier."""
    score = compute_trend_score(day)

    # Apply vol compression/expansion bonus
    if day.vix_roc is not None:
        if day.vix_roc <= config["compress_pct"]:
            score += config["boost"]
        elif day.vix_roc >= config["expand_pct"]:
            score += config["penalty"]

    score = max(0, min(100, score))
    signal = derive_signal(score, day)
    return Signal(date=day.date, score=score, signal=signal, price=day.close,
                  vix=day.vix_close, vix_roc=day.vix_roc)


# ─── Key Rally Events to Track ──────────────────────────────────────────────

RALLY_EVENTS = {
    "COVID Recovery (Mar 2020)": {"start": "2020-03-23", "end": "2020-04-20"},
    "Nov 2020 Election Rally": {"start": "2020-10-30", "end": "2020-11-20"},
    "Jan 2023 Crypto Bottom": {"start": "2023-01-01", "end": "2023-02-15"},
    "Oct 2023 Rally": {"start": "2023-10-27", "end": "2023-11-20"},
    "Liberation Day Recovery (Apr 2025)": {"start": "2025-04-07", "end": "2025-05-01"},
    "Ceasefire Rally (Mar-Apr 2026)": {"start": "2026-03-31", "end": "2026-04-17"},
}


# ─── Fetch Data ──────────────────────────────────────────────────────────────

def fetch_data(ticker: str, vix_ticker: str = "^VIX") -> tuple[list[DayData], list[float]]:
    """Fetch price data and VIX, compute all indicators."""
    print(f"  Fetching {ticker}...")
    asset_df = yf.download(ticker, start=BACKTEST_START, end=BACKTEST_END, progress=False)
    print(f"  Fetching {vix_ticker}...")
    vix_df = yf.download(vix_ticker, start=BACKTEST_START, end=BACKTEST_END, progress=False)

    # Handle MultiIndex columns from yfinance
    if hasattr(asset_df.columns, 'levels') and len(asset_df.columns.levels) > 1:
        asset_df.columns = asset_df.columns.get_level_values(0)
    if hasattr(vix_df.columns, 'levels') and len(vix_df.columns.levels) > 1:
        vix_df.columns = vix_df.columns.get_level_values(0)

    # Build date-indexed VIX lookup
    vix_map = {}
    for idx, row in vix_df.iterrows():
        date_str = idx.strftime("%Y-%m-%d")
        vix_map[date_str] = float(row["Close"])

    # Extract closes
    dates = []
    closes = []
    vix_closes_aligned = []

    for idx, row in asset_df.iterrows():
        date_str = idx.strftime("%Y-%m-%d")
        close = float(row["Close"])
        dates.append(date_str)
        closes.append(close)
        vix_closes_aligned.append(vix_map.get(date_str, 0))

    # Compute indicators
    sma21 = compute_sma(closes, 21)
    sma50 = compute_sma(closes, 50)
    sma200 = compute_sma(closes, 200)
    sma140 = compute_sma(closes, 140)
    ema147 = compute_ema(closes, 147)
    rsi = compute_rsi(closes, 14)

    # VIX rate of change (compute for multiple lookbacks)
    vix_roc_5 = compute_vix_roc(vix_closes_aligned, 5)
    vix_roc_3 = compute_vix_roc(vix_closes_aligned, 3)

    # Build DayData list
    days = []
    for i in range(len(dates)):
        days.append(DayData(
            date=dates[i],
            close=closes[i],
            sma21=sma21[i],
            sma50=sma50[i],
            sma200=sma200[i],
            sma140=sma140[i],
            ema147=ema147[i],
            rsi=rsi[i],
            vix_close=vix_closes_aligned[i] if vix_closes_aligned[i] > 0 else None,
            vix_roc=vix_roc_5[i],
        ))

    # Store alternate lookback ROCs for configs that need them
    for i, day in enumerate(days):
        day._vix_roc_3 = vix_roc_3[i] if i < len(vix_roc_3) else None

    return days, closes


# ─── Run Backtest ────────────────────────────────────────────────────────────

def run_backtest(days: list[DayData], closes: list[float], name: str,
                 signal_fn, config: Optional[dict] = None) -> BacktestResult:
    """Run a single backtest variant."""
    result = BacktestResult(name=name)

    # For configs with 3-day lookback, swap the VIX ROC
    if config and config.get("lookback") == 3:
        for day in days:
            day.vix_roc = getattr(day, '_vix_roc_3', day.vix_roc)

    prev_signal = None
    for i, day in enumerate(days):
        if day.sma21 is None:
            continue  # Not enough data yet

        if config:
            sig = signal_fn(day, config)
        else:
            sig = signal_fn(day)

        result.signals.append(sig)

        if sig.signal == "bullish":
            result.bullish_signals += 1

            # Check false positive: >5% drawdown in next 10 days
            max_drawdown = 0
            for j in range(i + 1, min(i + 11, len(closes))):
                dd = (closes[j] - day.close) / day.close * 100
                max_drawdown = min(max_drawdown, dd)
            if max_drawdown < -5:
                result.false_positives += 1

            # Check true positive: >5% gain in next 20 days
            max_gain = 0
            for j in range(i + 1, min(i + 21, len(closes))):
                gain = (closes[j] - day.close) / day.close * 100
                max_gain = max(max_gain, gain)
            if max_gain > 5:
                result.true_positives += 1

        # Track signal changes
        if prev_signal is not None and sig.signal != prev_signal:
            result.signal_changes += 1
        prev_signal = sig.signal

        # Track first bullish for each rally event
        for rally_name, rally in RALLY_EVENTS.items():
            if rally_name not in result.first_bullish_dates:
                if rally["start"] <= day.date <= rally["end"] and sig.signal == "bullish":
                    result.first_bullish_dates[rally_name] = day.date

    # Restore 5-day lookback
    if config and config.get("lookback") == 3:
        for day in days:
            day.vix_roc = getattr(day, '_vix_roc_5_backup', day.vix_roc)

    return result


# ─── Report ──────────────────────────────────────────────────────────────────

def print_report(asset_name: str, baseline: BacktestResult, variants: list[BacktestResult]):
    print(f"\n{'='*80}")
    print(f"  {asset_name} — QPS Volatility Compression Backtest")
    print(f"{'='*80}")

    # Summary table
    all_results = [baseline] + variants
    print(f"\n{'Model':<35} {'Bullish':>8} {'TP':>5} {'FP':>5} {'Hit%':>7} {'FP%':>7} {'Chg':>5}")
    print("-" * 80)
    for r in all_results:
        hit_rate = (r.true_positives / r.bullish_signals * 100) if r.bullish_signals > 0 else 0
        fp_rate = (r.false_positives / r.bullish_signals * 100) if r.bullish_signals > 0 else 0
        marker = " ◀ baseline" if r == baseline else ""
        print(f"{r.name:<35} {r.bullish_signals:>8} {r.true_positives:>5} {r.false_positives:>5} "
              f"{hit_rate:>6.1f}% {fp_rate:>6.1f}% {r.signal_changes:>5}{marker}")

    # Rally timing comparison
    print(f"\n  Rally Timing (first bullish signal date):")
    print(f"  {'Rally':<35} ", end="")
    for r in all_results:
        label = r.name[:12]
        print(f"{label:>14} ", end="")
    print()
    print("  " + "-" * (35 + 15 * len(all_results)))

    for rally_name in RALLY_EVENTS:
        print(f"  {rally_name:<35} ", end="")
        baseline_date = baseline.first_bullish_dates.get(rally_name, "—")
        for r in all_results:
            date = r.first_bullish_dates.get(rally_name, "—")
            if date != "—" and baseline_date != "—" and r != baseline:
                # Calculate days difference
                bd = datetime.strptime(baseline_date, "%Y-%m-%d")
                vd = datetime.strptime(date, "%Y-%m-%d")
                diff = (vd - bd).days
                if diff < 0:
                    print(f"{'↑' + str(abs(diff)) + 'd early':>14} ", end="")
                elif diff > 0:
                    print(f"{'↓' + str(diff) + 'd late':>14} ", end="")
                else:
                    print(f"{'same':>14} ", end="")
            else:
                if date == "—":
                    print(f"{'—':>14} ", end="")
                else:
                    print(f"{date[5:]:>14} ", end="")
        print()

    # VIX context during key moments
    print(f"\n  VIX Context During Ceasefire Rally (Mar 31 – Apr 17, 2026):")
    for sig in baseline.signals:
        if sig.date and "2026-03-31" <= sig.date <= "2026-04-17":
            vix_str = f"{sig.vix:>5.1f}" if sig.vix is not None else "  N/A"
            roc_str = f"{sig.vix_roc:>+6.1f}%" if sig.vix_roc is not None else "   N/A"
            arrow = ""
            if sig.vix_roc is not None:
                arrow = "▼" if sig.vix_roc < 0 else "▲"
            print(f"    {sig.date}  VIX={vix_str}  5d ROC={roc_str} {arrow}  "
                  f"Score={sig.score:>5.1f}  Signal={sig.signal}")


# ─── Main ────────────────────────────────────────────────────────────────────

def main():
    print("QPS Volatility Compression Backtest")
    print("=" * 50)

    for asset_ticker, asset_name in [("BTC-USD", "Bitcoin"), ("SPY", "S&P 500")]:
        print(f"\n▸ Loading data for {asset_name}...")

        days, closes = fetch_data(asset_ticker)
        print(f"  {len(days)} trading days loaded ({days[0].date} → {days[-1].date})")

        # Backup 5-day ROC for restoration after 3-day lookback tests
        for day in days:
            day._vix_roc_5_backup = day.vix_roc

        # Run baseline (v2.2)
        baseline = run_backtest(days, closes, "v2.2 (current)", compute_signal_v22)

        # Run variants
        variants = []
        for config in VOL_COMPRESSION_CONFIGS:
            # Restore VIX ROC to 5-day for each variant
            for day in days:
                day.vix_roc = day._vix_roc_5_backup
            result = run_backtest(days, closes, config["name"],
                                 compute_signal_with_vol, config)
            variants.append(result)

        print_report(asset_name, baseline, variants)

    print("\n" + "=" * 80)
    print("  INTERPRETATION GUIDE")
    print("=" * 80)
    print("""
  TP (True Positive): Bullish signal followed by >5% gain within 20 days
  FP (False Positive): Bullish signal followed by >5% drawdown within 10 days
  Hit%: TP / total bullish signals — higher is better
  FP%: FP / total bullish signals — lower is better
  Chg: Total signal changes — lower means less whipsaw

  Rally Timing: ↑Nd early = variant caught the rally N days before baseline
                ↓Nd late = variant was slower (bad)
                — = no bullish signal during that rally window

  Best variant: highest Hit%, lowest FP%, catches rallies earlier, minimal extra churn
""")


if __name__ == "__main__":
    main()
