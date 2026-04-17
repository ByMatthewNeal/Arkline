#!/usr/bin/env python3
"""
Backfill Model Portfolios from Jan 1, 2019 (or custom start) to today.

Replays QPS signal computation + BTC log regression risk day-by-day,
then runs Arkline Core and Edge strategy rules to compute daily NAV.

Uses yfinance for pre-2021 traditional market data (SPY, VIX, etc.)
and Coinbase/FMP for crypto + post-2021 data.

Usage:
    python scripts/backfill_model_portfolios.py [--dry-run] [--start-date 2019-01-01]
"""

import argparse
import json
import math
import os
import sys
import time
from datetime import datetime, timedelta, date
from typing import Optional

import requests
import yfinance as yf
from supabase import create_client

# ─── Configuration ──────────────────────────────────────────────────────────

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://mprbbjgrshfbupheuscn.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
FMP_API_KEY = os.environ.get("FMP_API_KEY", "paZFjsoaxMRSmSR82AbYHskweit7aCd8")

STARTING_NAV = 50000.0
STABLECOIN_APY = 0.045
DAILY_STABLE_RATE = (1 + STABLECOIN_APY) ** (1 / 365) - 1

# BTC log regression config (from AssetRiskConfig.swift)
BTC_ORIGIN_DATE = date(2009, 1, 3)
BTC_DEVIATION_BOUNDS = (-0.8, 0.8)

# QPS assets we need signals for
CRYPTO_ASSETS = ["BTC", "ETH", "SOL", "BNB", "XRP", "SUI", "LINK", "UNI",
                 "ONDO", "RENDER", "HYPE", "TAO", "ZEC", "AVAX", "DOGE", "BCH", "AAVE"]
ALT_BTC_PAIRS = ["ETH/BTC", "SOL/BTC", "LINK/BTC", "AVAX/BTC", "DOGE/BTC",
                 "BCH/BTC", "UNI/BTC", "XRP/BTC", "BNB/BTC", "HYPE/BTC",
                 "ZEC/BTC", "TAO/BTC", "SUI/BTC", "ONDO/BTC", "RENDER/BTC", "AAVE/BTC"]
MACRO_ASSETS = ["VIX", "DXY", "TLT"]
INDEX_ASSETS = ["SPY", "QQQ", "DIA", "IWM"]
COMMODITY_ASSETS = ["GOLD"]

# Coinbase pair mapping
COINBASE_PAIRS = {
    "BTC": "BTC-USD", "ETH": "ETH-USD", "SOL": "SOL-USD", "BNB": "BNB-USD",
    "XRP": "XRP-USD", "SUI": "SUI-USD", "LINK": "LINK-USD", "UNI": "UNI-USD",
    "ONDO": "ONDO-USD", "RENDER": "RENDER-USD", "TAO": "TAO-USD",
    "ZEC": "ZEC-USD", "AVAX": "AVAX-USD", "DOGE": "DOGE-USD", "BCH": "BCH-USD",
    "PAXG": "PAXG-USD",
    "AAVE": "AAVE-USD",
}

# FMP symbol mapping (stable API)
FMP_SYMBOLS = {
    "SPY": "SPY", "QQQ": "QQQ", "DIA": "DIA", "IWM": "IWM",
    "VIX": "^VIX", "DXY": "UUP", "TLT": "TLT",
    "GOLD": "GCUSD",
}

# Alt/BTC pair → Coinbase pair mapping
ALT_BTC_COINBASE = {}
for pair in ALT_BTC_PAIRS:
    alt = pair.split("/")[0]
    ALT_BTC_COINBASE[pair] = f"{alt}-BTC"

# ─── Data Fetching ──────────────────────────────────────────────────────────

_candle_cache = {}

def fetch_coinbase_candles(pair: str, days: int = 2700) -> list[dict]:
    """Fetch daily candles from Coinbase. Returns oldest-first."""
    cache_key = f"coinbase_{pair}_{days}"
    if cache_key in _candle_cache:
        return _candle_cache[cache_key]

    end = int(time.time())
    start = end - (days * 86400)
    granularity = 86400  # daily

    url = f"https://api.exchange.coinbase.com/products/{pair}/candles"

    all_candles = []
    # Coinbase returns max 300 candles per request
    chunk_end = end
    while chunk_end > start:
        chunk_start = max(start, chunk_end - 300 * 86400)
        params = {
            "start": datetime.fromtimestamp(chunk_start, tz=None).isoformat(),
            "end": datetime.fromtimestamp(chunk_end, tz=None).isoformat(),
            "granularity": granularity,
        }
        try:
            resp = requests.get(url, params=params, timeout=10)
            resp.raise_for_status()
            data = resp.json()
            # Coinbase returns [timestamp, low, high, open, close, volume] newest-first
            for row in data:
                all_candles.append({
                    "date": datetime.fromtimestamp(row[0], tz=None).strftime("%Y-%m-%d"),
                    "open": float(row[3]),
                    "high": float(row[2]),
                    "low": float(row[1]),
                    "close": float(row[4]),
                    "volume": float(row[5]),
                })
        except Exception as e:
            print(f"  Warning: Coinbase fetch failed for {pair}: {e}")
            break
        chunk_end = chunk_start
        time.sleep(0.15)  # rate limit

    # Deduplicate by date and sort oldest-first
    seen = set()
    unique = []
    for c in all_candles:
        if c["date"] not in seen:
            seen.add(c["date"])
            unique.append(c)
    unique.sort(key=lambda x: x["date"])

    _candle_cache[cache_key] = unique
    return unique


def fetch_fmp_candles(symbol: str, days: int = 2700) -> list[dict]:
    """Fetch daily candles from FMP stable API. Returns oldest-first."""
    cache_key = f"fmp_{symbol}_{days}"
    if cache_key in _candle_cache:
        return _candle_cache[cache_key]

    url = f"https://financialmodelingprep.com/stable/historical-price-eod/full"
    params = {"symbol": symbol, "apikey": FMP_API_KEY}

    try:
        resp = requests.get(url, params=params, timeout=15)
        resp.raise_for_status()
        if not resp.text.strip():
            return []
        data = resp.json()
        # stable endpoint returns a flat list, newest-first
        if not isinstance(data, list):
            data = data.get("historical", [])
        candles = []
        for h in data:
            candles.append({
                "date": h["date"],
                "open": float(h["open"]),
                "high": float(h["high"]),
                "low": float(h["low"]),
                "close": float(h["close"]),
                "volume": float(h.get("volume", 0)),
            })
        candles.sort(key=lambda x: x["date"])
        # Trim to requested days
        if len(candles) > days:
            candles = candles[-days:]
        _candle_cache[cache_key] = candles
        return candles
    except Exception as e:
        print(f"  Warning: FMP fetch failed for {symbol}: {e}")
        return []


def fetch_btc_full_history() -> list[dict]:
    """Fetch BTC full price history from CoinGecko Pro for log regression."""
    cache_key = "btc_full_history"
    if cache_key in _candle_cache:
        return _candle_cache[cache_key]

    url = "https://pro-api.coingecko.com/api/v3/coins/bitcoin/market_chart"
    params = {"vs_currency": "usd", "days": "max"}
    headers = {"x-cg-pro-api-key": "CG-Ggho8wQf8mXQeyPUzcgTJc3B"}

    try:
        resp = requests.get(url, params=params, headers=headers, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        prices = []
        for p in data.get("prices", []):
            ts_ms, price = p
            d = datetime.fromtimestamp(ts_ms / 1000, tz=None).strftime("%Y-%m-%d")
            prices.append({"date": d, "price": float(price)})
        # Deduplicate
        seen = set()
        unique = []
        for p in prices:
            if p["date"] not in seen:
                seen.add(p["date"])
                unique.append(p)
        unique.sort(key=lambda x: x["date"])
        _candle_cache[cache_key] = unique
        print(f"  Got {len(unique)} BTC prices from CoinGecko Pro")
        return unique
    except Exception as e:
        print(f"  CoinGecko Pro failed: {e}, falling back to FMP...")

    # Fallback: use FMP BTC-USD historical
    try:
        fmp_url = "https://financialmodelingprep.com/stable/historical-price-eod/full"
        params = {"symbol": "BTCUSD", "apikey": FMP_API_KEY}
        resp = requests.get(fmp_url, params=params, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        if isinstance(data, list):
            prices = [{"date": h["date"], "price": float(h["close"])} for h in data]
            prices.sort(key=lambda x: x["date"])
            _candle_cache[cache_key] = prices
            print(f"  Got {len(prices)} BTC prices from FMP")
            return prices
    except Exception as e:
        print(f"  FMP BTC fallback also failed: {e}")

    return []


def fetch_yfinance_candles(ticker: str, start: str = "2018-01-01") -> list[dict]:
    """Fetch daily candles from yfinance. Returns oldest-first."""
    cache_key = f"yf_{ticker}_{start}"
    if cache_key in _candle_cache:
        return _candle_cache[cache_key]

    try:
        df = yf.download(ticker, start=start, progress=False)
        if df.empty:
            return []
        # Flatten MultiIndex columns (yfinance returns (Price, Ticker) tuples)
        if isinstance(df.columns, __import__('pandas').MultiIndex):
            df.columns = [col[0] for col in df.columns]
        candles = []
        for idx, row in df.iterrows():
            candles.append({
                "date": idx.strftime("%Y-%m-%d"),
                "open": float(row["Open"]) if not math.isnan(row["Open"]) else 0,
                "high": float(row["High"]) if not math.isnan(row["High"]) else 0,
                "low": float(row["Low"]) if not math.isnan(row["Low"]) else 0,
                "close": float(row["Close"]) if not math.isnan(row["Close"]) else 0,
                "volume": float(row["Volume"]) if not math.isnan(row["Volume"]) else 0,
            })
        candles.sort(key=lambda x: x["date"])
        _candle_cache[cache_key] = candles
        print(f"    yfinance: {len(candles)} candles for {ticker}")
        return candles
    except Exception as e:
        print(f"  Warning: yfinance fetch failed for {ticker}: {e}")
        return []


# yfinance ticker mapping for traditional assets
YFINANCE_TICKERS = {
    "SPY": "SPY", "QQQ": "QQQ", "DIA": "DIA", "IWM": "IWM",
    "VIX": "^VIX", "DXY": "UUP", "TLT": "TLT",
    "GOLD": "GC=F",  # yfinance uses the futures ticker for gold history
}


def fetch_combined_candles(asset: str, fmp_symbol: str, days: int = 2700) -> list[dict]:
    """Fetch candles combining yfinance (pre-2021) and FMP (post-2021) data."""
    # First try FMP (more recent, authoritative)
    fmp_candles = fetch_fmp_candles(fmp_symbol, days=days)

    # If FMP has enough history (back to 2019), just use it
    if fmp_candles and fmp_candles[0]["date"] <= "2019-02-01":
        return fmp_candles

    # Otherwise, get yfinance for the full range
    yf_ticker = YFINANCE_TICKERS.get(asset, fmp_symbol)
    yf_candles = fetch_yfinance_candles(yf_ticker, start="2018-01-01")

    if not yf_candles:
        return fmp_candles

    if not fmp_candles:
        return yf_candles

    # Merge: use yfinance for dates before FMP's earliest, then FMP
    fmp_earliest = fmp_candles[0]["date"]
    merged = [c for c in yf_candles if c["date"] < fmp_earliest]
    merged.extend(fmp_candles)
    merged.sort(key=lambda x: x["date"])
    print(f"    Merged {asset}: {len(merged)} candles ({merged[0]['date']} to {merged[-1]['date']})")
    return merged


# ─── QPS Signal Computation ────────────────────────────────────────────────

def compute_sma(closes: list[float], period: int) -> list[float]:
    """Compute Simple Moving Average."""
    if len(closes) < period:
        return []
    sma = []
    for i in range(period - 1, len(closes)):
        avg = sum(closes[i - period + 1:i + 1]) / period
        sma.append(avg)
    return sma


def compute_ema(closes: list[float], period: int) -> list[float]:
    """Compute Exponential Moving Average."""
    if len(closes) < period:
        return []
    k = 2 / (period + 1)
    ema = [sum(closes[:period]) / period]
    for i in range(period, len(closes)):
        ema.append(closes[i] * k + ema[-1] * (1 - k))
    return ema


def compute_rsi(closes: list[float], period: int = 14) -> Optional[float]:
    """Compute RSI."""
    if len(closes) < period + 1:
        return None
    changes = [closes[i] - closes[i - 1] for i in range(1, len(closes))]
    gains = [max(0, c) for c in changes[:period]]
    losses = [max(0, -c) for c in changes[:period]]
    avg_gain = sum(gains) / period
    avg_loss = sum(losses) / period

    for c in changes[period:]:
        avg_gain = (avg_gain * (period - 1) + max(0, c)) / period
        avg_loss = (avg_loss * (period - 1) + max(0, -c)) / period

    if avg_loss == 0:
        return 100.0
    rs = avg_gain / avg_loss
    return 100 - 100 / (1 + rs)


def compute_trend_score(candles: list[dict]) -> dict:
    """Replicate the QPS trend score computation (v4)."""
    closes = [c["close"] for c in candles]
    price = closes[-1]

    sma21 = compute_sma(closes, 21)
    sma50 = compute_sma(closes, 50)
    rsi = compute_rsi(closes)

    latest_sma21 = sma21[-1] if sma21 else None
    latest_sma50 = sma50[-1] if sma50 else None

    sma200 = compute_sma(closes, 200) if len(closes) >= 200 else []
    latest_sma200 = sma200[-1] if sma200 else None
    above_200_sma = latest_sma200 is not None and price > latest_sma200

    # BMSB: 20W SMA (~140D) + 21W EMA (~147D)
    has_bmsb = len(closes) >= 148
    sma140 = compute_sma(closes, 140) if has_bmsb else []
    ema147 = compute_ema(closes, 147) if has_bmsb else []
    bmsb_sma = sma140[-1] if sma140 else None
    bmsb_ema = ema147[-1] if ema147 else None

    above_sma21 = latest_sma21 is not None and price > latest_sma21
    above_sma50 = latest_sma50 is not None and price > latest_sma50

    score = 50

    # PRIMARY: SMA position
    if above_200_sma:
        score += 18
    elif latest_sma200 is not None:
        score -= 8

    if above_sma50:
        score += 8

    if above_sma21:
        score += 8
    elif latest_sma21 is not None:
        score -= 10

    # SECONDARY: SMA crossover
    if latest_sma21 is not None and latest_sma50 is not None:
        if latest_sma21 > latest_sma50:
            score += 6
        else:
            score -= 6

    # TERTIARY: RSI
    if rsi is not None:
        if rsi <= 30:
            score += 5
        elif rsi <= 40:
            score += 3
        elif rsi >= 75:
            score -= 3

    # TERTIARY: BMSB
    if bmsb_sma is not None and bmsb_ema is not None:
        bmsb_top = max(bmsb_sma, bmsb_ema)
        bmsb_bot = min(bmsb_sma, bmsb_ema)
        if price > bmsb_top:
            score += 4
        elif price >= bmsb_bot:
            score += 1
        else:
            score -= 2

    score = max(0, min(100, score))

    return {
        "trend_score": round(score, 1),
        "rsi": round(rsi, 1) if rsi else None,
        "above_200_sma": above_200_sma,
        "price": price,
        "above_sma21": above_sma21,
        "above_sma50": above_sma50,
    }


def derive_signal(trend_score: float, above_200_sma: bool, has_200_sma: bool,
                  above_sma21: bool, above_sma50: bool) -> str:
    """Derive bullish/neutral/bearish/mild_bearish signal from trend score."""
    if trend_score >= 70:
        if has_200_sma and not above_200_sma:
            return "neutral"
        if not above_sma21 and not above_sma50:
            return "neutral"
        return "bullish"
    if trend_score >= 45:
        return "neutral"
    if trend_score >= 36:
        return "mild_bearish"
    return "bearish"


def get_signal_for_date(candles: list[dict], target_date: str) -> Optional[dict]:
    """Get QPS signal for a specific date using candles up to that date."""
    # Filter candles up to and including target_date
    filtered = [c for c in candles if c["date"] <= target_date]
    if len(filtered) < 22:
        return None

    result = compute_trend_score(filtered)
    has_200 = len(filtered) >= 200
    signal = derive_signal(
        result["trend_score"], result["above_200_sma"], has_200,
        result["above_sma21"], result["above_sma50"]
    )
    return {
        "signal": signal,
        "trend_score": result["trend_score"],
        "rsi": result["rsi"],
        "price": result["price"],
    }


# ─── BTC Log Regression Risk ───────────────────────────────────────────────

def compute_btc_risk(btc_history: list[dict], target_date: str) -> Optional[dict]:
    """Compute BTC log regression risk level for a given date."""
    # Filter history up to target_date
    filtered = [p for p in btc_history if p["date"] <= target_date]
    if len(filtered) < 100:
        return None

    target_dt = datetime.strptime(target_date, "%Y-%m-%d").date()
    origin = BTC_ORIGIN_DATE

    # Prepare data for regression
    valid = []
    for p in filtered:
        d = datetime.strptime(p["date"], "%Y-%m-%d").date()
        days = (d - origin).days
        if days > 0 and p["price"] > 0:
            valid.append((days, p["price"]))

    if len(valid) < 100:
        return None

    # Least squares in log-log space
    n = len(valid)
    sum_x = sum_y = sum_xx = sum_xy = 0.0
    for days, price in valid:
        x = math.log10(days)
        y = math.log10(price)
        sum_x += x
        sum_y += y
        sum_xx += x * x
        sum_xy += x * y

    denom = n * sum_xx - sum_x * sum_x
    if abs(denom) < 1e-10:
        return None

    b = (n * sum_xy - sum_x * sum_y) / denom
    a = (sum_y - b * sum_x) / n

    # Fair value at target date
    target_days = (target_dt - origin).days
    if target_days <= 0:
        return None
    log_fair = a + b * math.log10(target_days)
    fair_value = 10 ** log_fair

    # Current price
    current_price = filtered[-1]["price"]

    # Log deviation
    deviation = math.log10(current_price) - math.log10(fair_value)

    # Normalize to 0-1
    low, high = BTC_DEVIATION_BOUNDS
    clamped = max(low, min(high, deviation))
    risk_level = (clamped - low) / (high - low)

    # Category
    if risk_level < 0.20:
        category = "Very Low Risk"
    elif risk_level < 0.40:
        category = "Low Risk"
    elif risk_level < 0.55:
        category = "Neutral"
    elif risk_level < 0.70:
        category = "Elevated Risk"
    elif risk_level < 0.90:
        category = "High Risk"
    else:
        category = "Extreme Risk"

    return {
        "risk_level": round(risk_level, 4),
        "price": current_price,
        "fair_value": round(fair_value, 2),
        "deviation": round(deviation, 4),
        "category": category,
    }


# ─── Strategy Rules ─────────────────────────────────────────────────────────

def get_defensive_mix(gold_signal: str) -> dict:
    """Compute defensive allocation split between PAXG and USDC."""
    if gold_signal == "bullish":
        return {"PAXG": 0.70, "USDC": 0.30}
    elif gold_signal == "neutral":
        return {"PAXG": 0.40, "USDC": 0.60}
    else:
        return {"PAXG": 0.0, "USDC": 1.0}


def apply_defensive(base_alloc: dict, defensive_pct: float, gold_signal: str) -> dict:
    """Apply defensive mix to a base allocation."""
    mix = get_defensive_mix(gold_signal)
    alloc = dict(base_alloc)
    for asset, pct in mix.items():
        if pct > 0:
            alloc[asset] = alloc.get(asset, 0) + defensive_pct * pct
    return alloc


def get_top_bullish_alts(alt_btc_signals: dict, n: int = 3) -> list[tuple[str, float]]:
    """Return top N bullish alts by trend score (excluding BTC/ETH/SOL)."""
    candidates = []
    for pair, sig in alt_btc_signals.items():
        if sig.get("signal") == "bullish":
            alt = pair.split("/")[0]
            if alt not in ("BTC", "ETH", "SOL"):
                candidates.append((alt, sig.get("trend_score", 0)))
    candidates.sort(key=lambda x: x[1], reverse=True)
    return candidates[:n]


def distribute_alt_pct(top_alts: list[tuple[str, float]], total_pct: float) -> dict:
    """Distribute total_pct among top alts weighted by trend score."""
    if not top_alts:
        return {}
    total_score = sum(score for _, score in top_alts)
    if total_score <= 0:
        # Equal weight fallback
        weight = total_pct / len(top_alts)
        return {alt: weight for alt, _ in top_alts}
    return {alt: total_pct * (score / total_score) for alt, score in top_alts}


def compute_core_allocation(btc_signal: str, btc_risk_category: str,
                            gold_signal: str, macro_regime: str) -> dict:
    """Compute Arkline Core allocation based on strategy rules."""
    # Macro override: Risk-Off + High/Extreme → 100% defensive
    is_risk_off = "Risk-Off" in macro_regime if macro_regime else False
    is_high_risk = btc_risk_category in ("High Risk", "Extreme Risk", "Elevated Risk")

    if is_risk_off and is_high_risk:
        return apply_defensive({}, 1.0, gold_signal)

    if btc_signal == "bullish":
        return {"BTC": 0.60, "ETH": 0.40}

    if btc_signal == "neutral":
        if btc_risk_category in ("Very Low Risk", "Low Risk"):
            return apply_defensive({"BTC": 0.50, "ETH": 0.30}, 0.20, gold_signal)
        else:
            return apply_defensive({"BTC": 0.30, "ETH": 0.20}, 0.50, gold_signal)

    # Mild bearish (scores 36-44): reduced crypto but not full exit
    if btc_signal == "mild_bearish":
        if btc_risk_category in ("Very Low Risk", "Low Risk"):
            return apply_defensive({"BTC": 0.30, "ETH": 0.15}, 0.55, gold_signal)
        else:
            return apply_defensive({"BTC": 0.20, "ETH": 0.10}, 0.70, gold_signal)

    # Full bearish
    if btc_risk_category == "Very Low Risk":
        return apply_defensive({"BTC": 0.40, "ETH": 0.20}, 0.40, gold_signal)
    elif btc_risk_category == "Low Risk":
        return apply_defensive({"BTC": 0.25, "ETH": 0.15}, 0.60, gold_signal)
    else:
        # Bearish + Neutral/Elevated risk: keep small crypto position
        return apply_defensive({"BTC": 0.15, "ETH": 0.05}, 0.80, gold_signal)


def compute_edge_allocation(btc_signal: str, btc_risk_category: str,
                            gold_signal: str, macro_regime: str,
                            crypto_signals: dict, alt_btc_signals: dict) -> dict:
    """Compute Arkline Edge allocation based on strategy rules.
    Now deploys into top 2-3 bullish alts instead of single dominant alt."""
    is_risk_off = "Risk-Off" in macro_regime if macro_regime else False
    is_high_risk = btc_risk_category in ("High Risk", "Extreme Risk", "Elevated Risk")

    if is_risk_off and is_high_risk:
        return apply_defensive({}, 1.0, gold_signal)

    # Risk-Off accumulation
    if is_risk_off:
        if btc_risk_category == "Very Low Risk":
            return apply_defensive({"BTC": 0.30, "ETH": 0.20}, 0.50, gold_signal)
        elif btc_risk_category == "Low Risk":
            return apply_defensive({"BTC": 0.20, "ETH": 0.10}, 0.70, gold_signal)
        else:
            return apply_defensive({"BTC": 0.10, "ETH": 0.05}, 0.85, gold_signal)

    # Risk-On: deploy into bullish assets
    bullish_assets = []
    for asset in ["BTC", "ETH", "SOL"]:
        sig = crypto_signals.get(asset, {})
        if sig.get("signal") == "bullish":
            bullish_assets.append(asset)

    # Top 2-3 bullish alts (replaces single dominant_alt)
    top_alts = get_top_bullish_alts(alt_btc_signals, n=3)

    if len(bullish_assets) >= 2 or btc_signal == "bullish":
        alloc = {}
        if "BTC" in bullish_assets or btc_signal == "bullish":
            alloc["BTC"] = 0.30
        if "ETH" in bullish_assets or crypto_signals.get("ETH", {}).get("signal") == "bullish":
            alloc["ETH"] = 0.25
        if "SOL" in bullish_assets:
            alloc["SOL"] = 0.20
        # Distribute 15% among top bullish alts
        alt_alloc = distribute_alt_pct(top_alts, 0.15)
        alloc.update(alt_alloc)

        deployed = sum(alloc.values())
        remaining = 1.0 - deployed
        if remaining > 0.01:
            return apply_defensive(alloc, remaining, gold_signal)
        return alloc

    # Mild bearish: reduced but not zero crypto
    if btc_signal == "mild_bearish":
        alloc = {"BTC": 0.15}
        if "ETH" in bullish_assets:
            alloc["ETH"] = 0.10
        alt_alloc = distribute_alt_pct(top_alts, 0.05)
        alloc.update(alt_alloc)
        deployed = sum(alloc.values())
        return apply_defensive(alloc, 1.0 - deployed, gold_signal)

    # Full bearish on Risk-On
    if btc_signal == "bearish":
        if btc_risk_category in ("Very Low Risk", "Low Risk"):
            return apply_defensive({"BTC": 0.20, "ETH": 0.10}, 0.70, gold_signal)
        else:
            return apply_defensive({"BTC": 0.10, "ETH": 0.05}, 0.85, gold_signal)

    # Mixed: deploy into bullish only
    alloc = {}
    if bullish_assets:
        weight = 0.60 / len(bullish_assets)
        for a in bullish_assets:
            alloc[a] = weight
    alt_alloc = distribute_alt_pct(top_alts, 0.10)
    alloc.update(alt_alloc)
    deployed = sum(alloc.values())
    remaining = 1.0 - deployed
    return apply_defensive(alloc, max(0, remaining), gold_signal)


def compute_alpha_allocation(btc_signal: str, btc_risk_category: str,
                             gold_signal: str, macro_regime: str,
                             crypto_signals: dict, alt_btc_signals: dict) -> dict:
    """Compute Arkline Alpha allocation — alt-heavy, 40-50% in top-performing alts.
    BTC/ETH/SOL base + aggressive alt rotation."""
    is_risk_off = "Risk-Off" in macro_regime if macro_regime else False
    is_high_risk = btc_risk_category in ("High Risk", "Extreme Risk", "Elevated Risk")

    if is_risk_off and is_high_risk:
        return apply_defensive({}, 1.0, gold_signal)

    # Risk-Off accumulation
    if is_risk_off:
        if btc_risk_category == "Very Low Risk":
            return apply_defensive({"BTC": 0.25, "ETH": 0.15}, 0.60, gold_signal)
        elif btc_risk_category == "Low Risk":
            return apply_defensive({"BTC": 0.15, "ETH": 0.10}, 0.75, gold_signal)
        else:
            return apply_defensive({"BTC": 0.10, "ETH": 0.05}, 0.85, gold_signal)

    # Risk-On: heavy alt deployment
    bullish_assets = []
    for asset in ["BTC", "ETH", "SOL"]:
        sig = crypto_signals.get(asset, {})
        if sig.get("signal") == "bullish":
            bullish_assets.append(asset)

    top_alts = get_top_bullish_alts(alt_btc_signals, n=3)

    if len(bullish_assets) >= 2 or btc_signal == "bullish":
        # Full deployment: BTC 20%, ETH 15%, SOL 15%, alts 40%, defensive 10%
        alloc = {}
        if "BTC" in bullish_assets or btc_signal == "bullish":
            alloc["BTC"] = 0.20
        if "ETH" in bullish_assets or crypto_signals.get("ETH", {}).get("signal") == "bullish":
            alloc["ETH"] = 0.15
        if "SOL" in bullish_assets:
            alloc["SOL"] = 0.15
        # 40% into top bullish alts
        alt_alloc = distribute_alt_pct(top_alts, 0.40)
        alloc.update(alt_alloc)

        deployed = sum(alloc.values())
        remaining = 1.0 - deployed
        if remaining > 0.01:
            return apply_defensive(alloc, remaining, gold_signal)
        return alloc

    # Mild bearish
    if btc_signal == "mild_bearish":
        alloc = {"BTC": 0.10}
        if "ETH" in bullish_assets:
            alloc["ETH"] = 0.08
        alt_alloc = distribute_alt_pct(top_alts, 0.12)
        alloc.update(alt_alloc)
        deployed = sum(alloc.values())
        return apply_defensive(alloc, 1.0 - deployed, gold_signal)

    # Full bearish
    if btc_signal == "bearish":
        if btc_risk_category in ("Very Low Risk", "Low Risk"):
            alloc = {"BTC": 0.15, "ETH": 0.10}
            alt_alloc = distribute_alt_pct(top_alts, 0.10)
            alloc.update(alt_alloc)
            deployed = sum(alloc.values())
            return apply_defensive(alloc, 1.0 - deployed, gold_signal)
        else:
            return apply_defensive({"BTC": 0.08, "ETH": 0.04}, 0.88, gold_signal)

    # Mixed: deploy into whatever is bullish + alts
    alloc = {}
    if bullish_assets:
        weight = 0.45 / len(bullish_assets)
        for a in bullish_assets:
            alloc[a] = weight
    alt_alloc = distribute_alt_pct(top_alts, 0.25)
    alloc.update(alt_alloc)
    deployed = sum(alloc.values())
    remaining = 1.0 - deployed
    return apply_defensive(alloc, max(0, remaining), gold_signal)


def determine_macro_regime(index_signals: dict, vix_signal: dict) -> str:
    """Determine macro regime from index + VIX signals."""
    bearish_count = 0
    total = 0
    for asset, sig in index_signals.items():
        if sig and sig.get("signal"):
            total += 1
            if sig["signal"] == "bearish":
                bearish_count += 1

    # VIX bearish (high VIX) = risk-off
    vix_sig = vix_signal.get("signal", "neutral") if vix_signal else "neutral"
    if vix_sig == "bearish":
        bearish_count += 1
    total += 1

    if total == 0:
        return "Mixed"

    bearish_pct = bearish_count / total
    if bearish_pct >= 0.5:
        return "Risk-Off"
    return "Risk-On"


# ─── NAV Computation ────────────────────────────────────────────────────────

def compute_nav(prev_positions: dict, prev_nav: float, prices: dict,
                new_allocation: dict, rebalance: bool) -> tuple[float, dict]:
    """
    Compute NAV and new positions.
    positions = {"BTC": {"qty": 0.5, "value": 50000}, ...}
    """
    if not prev_positions or rebalance:
        # Rebalance: sell everything, reallocate at new weights
        # First compute current NAV from existing positions
        if prev_positions:
            current_nav = 0.0
            for asset, pos in prev_positions.items():
                if asset == "USDC":
                    current_nav += pos["value"] * (1 + DAILY_STABLE_RATE)
                else:
                    p = prices.get(asset, pos.get("price", 0))
                    if p > 0 and pos["qty"] > 0:
                        current_nav += pos["qty"] * p
                    else:
                        current_nav += pos["value"]
        else:
            current_nav = prev_nav

        # Allocate at new weights
        new_positions = {}
        for asset, weight in new_allocation.items():
            if weight <= 0:
                continue
            value = current_nav * weight
            if asset == "USDC":
                new_positions[asset] = {"qty": value, "value": value, "price": 1.0}
            else:
                p = prices.get(asset, 0)
                qty = value / p if p > 0 else 0
                new_positions[asset] = {"qty": qty, "value": value, "price": p}

        return current_nav, new_positions
    else:
        # No rebalance: mark to market
        current_nav = 0.0
        updated_positions = {}
        for asset, pos in prev_positions.items():
            if asset == "USDC":
                new_value = pos["value"] * (1 + DAILY_STABLE_RATE)
                updated_positions[asset] = {"qty": new_value, "value": new_value, "price": 1.0}
                current_nav += new_value
            else:
                p = prices.get(asset, pos.get("price", 0))
                new_value = pos["qty"] * p if p > 0 else pos["value"]
                updated_positions[asset] = {"qty": pos["qty"], "value": new_value, "price": p}
                current_nav += new_value

        return current_nav, updated_positions


# ─── Main Backfill Loop ─────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Backfill Model Portfolios")
    parser.add_argument("--dry-run", action="store_true", help="Print without writing to DB")
    parser.add_argument("--start-date", default="2019-01-01", help="Start date (YYYY-MM-DD)")
    parser.add_argument("--end-date", default=None, help="End date (YYYY-MM-DD), defaults to today")
    args = parser.parse_args()

    start_date = datetime.strptime(args.start_date, "%Y-%m-%d").date()
    end_date = datetime.strptime(args.end_date, "%Y-%m-%d").date() if args.end_date else date.today()

    if not args.dry_run:
        if not SUPABASE_KEY:
            print("ERROR: SUPABASE_SERVICE_ROLE_KEY not set")
            sys.exit(1)
        supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
        # Get portfolio IDs
        portfolios = supabase.table("model_portfolios").select("id, strategy").execute()
        portfolio_ids = {p["strategy"]: p["id"] for p in portfolios.data}
        print(f"Portfolio IDs: {portfolio_ids}")
    else:
        supabase = None
        portfolio_ids = {"core": "dry-run-core", "edge": "dry-run-edge", "alpha": "dry-run-alpha"}

    # ── Step 1: Fetch all historical data ────────────────────────────────
    print("\n=== Fetching historical data ===")

    print("  Fetching BTC full history for log regression...")
    btc_full_history = fetch_btc_full_history()
    print(f"  Got {len(btc_full_history)} BTC daily prices")

    print("  Fetching Coinbase candles...")
    all_candles = {}
    for asset, pair in COINBASE_PAIRS.items():
        print(f"    {asset} ({pair})...")
        all_candles[asset] = fetch_coinbase_candles(pair, days=2700)
        time.sleep(0.2)

    # Alt/BTC pairs
    for pair_name, cb_pair in ALT_BTC_COINBASE.items():
        print(f"    {pair_name} ({cb_pair})...")
        candles = fetch_coinbase_candles(cb_pair, days=2700)
        if candles:
            all_candles[pair_name] = candles
        else:
            # Compute synthetic from USD pairs
            alt = pair_name.split("/")[0]
            alt_candles = all_candles.get(alt, [])
            btc_candles = all_candles.get("BTC", [])
            if alt_candles and btc_candles:
                btc_by_date = {c["date"]: c for c in btc_candles}
                synthetic = []
                for ac in alt_candles:
                    bc = btc_by_date.get(ac["date"])
                    if bc and bc["close"] > 0:
                        synthetic.append({
                            "date": ac["date"],
                            "open": ac["open"] / bc["open"] if bc["open"] > 0 else 0,
                            "high": ac["high"] / bc["low"] if bc["low"] > 0 else 0,
                            "low": ac["low"] / bc["high"] if bc["high"] > 0 else 0,
                            "close": ac["close"] / bc["close"],
                            "volume": ac["volume"],
                        })
                all_candles[pair_name] = synthetic
        time.sleep(0.2)

    print("  Fetching traditional asset candles (FMP + yfinance)...")
    for asset, symbol in FMP_SYMBOLS.items():
        print(f"    {asset} ({symbol})...")
        all_candles[asset] = fetch_combined_candles(asset, symbol, days=2700)
        time.sleep(0.3)

    # PAXG launched Sep 2019 — use GLD ETF as price proxy before that
    paxg_candles = all_candles.get("PAXG", [])
    if paxg_candles:
        paxg_earliest = paxg_candles[0]["date"]
        if paxg_earliest > "2019-02-01":
            print(f"  Supplementing PAXG with GLD proxy (earliest Coinbase: {paxg_earliest})...")
            gld = fetch_yfinance_candles("GLD", start="2018-01-01")
            if gld:
                # Scale GLD prices to match PAXG value at overlap point
                paxg_first_price = paxg_candles[0]["close"]
                gld_at_overlap = [c for c in gld if c["date"] <= paxg_earliest]
                if gld_at_overlap:
                    scale = paxg_first_price / gld_at_overlap[-1]["close"]
                    scaled_gld = []
                    for c in gld:
                        if c["date"] < paxg_earliest:
                            scaled_gld.append({
                                **c,
                                "open": c["open"] * scale,
                                "high": c["high"] * scale,
                                "low": c["low"] * scale,
                                "close": c["close"] * scale,
                            })
                    scaled_gld.extend(paxg_candles)
                    all_candles["PAXG"] = scaled_gld
                    print(f"    PAXG: {len(scaled_gld)} candles ({scaled_gld[0]['date']} to {scaled_gld[-1]['date']})")

    # Supplement crypto with yfinance for pre-Coinbase data
    for crypto_asset, yf_ticker in [("BTC", "BTC-USD"), ("ETH", "ETH-USD")]:
        if all_candles.get(crypto_asset):
            earliest = all_candles[crypto_asset][0]["date"]
            if earliest > "2019-02-01":
                print(f"  Supplementing {crypto_asset} with yfinance (earliest Coinbase: {earliest})...")
                yf_data = fetch_yfinance_candles(yf_ticker, start="2018-01-01")
                if yf_data:
                    merged = [c for c in yf_data if c["date"] < earliest]
                    merged.extend(all_candles[crypto_asset])
                    all_candles[crypto_asset] = merged
                    print(f"    {crypto_asset}: {len(merged)} candles ({merged[0]['date']} to {merged[-1]['date']})")

    # ── Step 2: Replay day by day ────────────────────────────────────────
    print(f"\n=== Replaying {start_date} to {end_date} ===")

    # State
    core_positions = {}
    edge_positions = {}
    alpha_positions = {}
    core_nav = STARTING_NAV
    edge_nav = STARTING_NAV
    alpha_nav = STARTING_NAV
    core_prev_alloc = {}
    edge_prev_alloc = {}
    alpha_prev_alloc = {}
    spy_shares = None
    spy_start_price = None

    nav_rows_core = []
    nav_rows_edge = []
    nav_rows_alpha = []
    trade_rows = []
    benchmark_rows = []
    risk_rows = []

    current = start_date
    day_count = 0

    while current <= end_date:
        ds = current.strftime("%Y-%m-%d")
        is_weekend = current.weekday() >= 5  # Sat=5, Sun=6

        # Skip weekends for SPY, but still process crypto
        # Get prices for today
        prices = {}
        for asset in ["BTC", "ETH", "SOL", "PAXG", "BNB", "XRP", "SUI", "LINK",
                       "UNI", "ONDO", "RENDER", "TAO", "ZEC", "AVAX", "DOGE", "BCH", "HYPE", "AAVE"]:
            candles = all_candles.get(asset, [])
            for c in candles:
                if c["date"] == ds:
                    prices[asset] = c["close"]
                    break
            # If no exact match, use most recent before
            if asset not in prices:
                prev = [c for c in candles if c["date"] <= ds]
                if prev:
                    prices[asset] = prev[-1]["close"]

        # SPY price
        spy_candles = all_candles.get("SPY", [])
        spy_price = None
        for c in spy_candles:
            if c["date"] == ds:
                spy_price = c["close"]
                break
        if spy_price is None:
            prev = [c for c in spy_candles if c["date"] <= ds]
            if prev:
                spy_price = prev[-1]["close"]

        if spy_price and spy_shares is None:
            spy_start_price = spy_price
            spy_shares = STARTING_NAV / spy_price

        # Compute QPS signals for all relevant assets
        crypto_signals = {}
        for asset in CRYPTO_ASSETS:
            sig = get_signal_for_date(all_candles.get(asset, []), ds)
            if sig:
                crypto_signals[asset] = sig

        alt_btc_signals = {}
        for pair in ALT_BTC_PAIRS:
            sig = get_signal_for_date(all_candles.get(pair, []), ds)
            if sig:
                alt_btc_signals[pair] = sig

        index_signals = {}
        for asset in INDEX_ASSETS:
            sig = get_signal_for_date(all_candles.get(asset, []), ds)
            if sig:
                index_signals[asset] = sig

        gold_sig = get_signal_for_date(all_candles.get("GOLD", []), ds)
        gold_signal_raw = gold_sig["signal"] if gold_sig else "neutral"
        # Map mild_bearish → bearish for gold (used in defensive mix)
        gold_signal = "bearish" if gold_signal_raw == "mild_bearish" else gold_signal_raw

        vix_sig = get_signal_for_date(all_candles.get("VIX", []), ds)

        # BTC risk
        btc_risk = compute_btc_risk(btc_full_history, ds)
        btc_risk_level = btc_risk["risk_level"] if btc_risk else 0.5
        btc_risk_category = btc_risk["category"] if btc_risk else "Neutral"

        btc_signal_data = crypto_signals.get("BTC", {})
        btc_signal = btc_signal_data.get("signal", "neutral")

        # Macro regime
        macro_regime = determine_macro_regime(index_signals, vix_sig)

        # ── Core strategy ──
        new_core_alloc = compute_core_allocation(btc_signal, btc_risk_category,
                                                  gold_signal, macro_regime)
        # Normalize
        total = sum(new_core_alloc.values())
        if total > 0:
            new_core_alloc = {k: v / total for k, v in new_core_alloc.items()}

        # Round allocations to 4 decimal places for comparison (avoid float noise)
        def round_alloc(alloc):
            return {k: round(v, 4) for k, v in alloc.items() if not k.startswith("_")}

        core_rebalance = (round_alloc(new_core_alloc) != round_alloc(core_prev_alloc)) and day_count > 0
        core_nav, core_positions = compute_nav(
            core_positions, core_nav, prices, new_core_alloc,
            rebalance=(core_rebalance or day_count == 0)
        )

        if core_rebalance:
            # Find what triggered the change
            triggers = []
            prev_btc_sig = core_prev_alloc.get("_btc_signal", "")
            if prev_btc_sig != btc_signal:
                triggers.append(f"BTC {prev_btc_sig} → {btc_signal}")
            prev_regime = core_prev_alloc.get("_macro_regime", "")
            if prev_regime != macro_regime:
                triggers.append(f"Regime {prev_regime} → {macro_regime}")
            prev_gold = core_prev_alloc.get("_gold_signal", "")
            if prev_gold != gold_signal:
                triggers.append(f"Gold {prev_gold} → {gold_signal}")
            prev_risk = core_prev_alloc.get("_btc_risk_cat", "")
            if prev_risk != btc_risk_category:
                triggers.append(f"BTC Risk {prev_risk} → {btc_risk_category}")

            trigger_str = "; ".join(triggers) if triggers else "Rebalance"

            from_alloc = {k: round(v * 100, 1) for k, v in core_prev_alloc.items() if not k.startswith("_")}
            to_alloc = {k: round(v * 100, 1) for k, v in new_core_alloc.items()}

            trade_rows.append({
                "portfolio_id": portfolio_ids["core"],
                "trade_date": ds,
                "trigger": trigger_str,
                "from_allocation": from_alloc,
                "to_allocation": to_alloc,
            })

        # Store metadata in alloc for change detection
        core_prev_alloc = dict(new_core_alloc)
        core_prev_alloc["_btc_signal"] = btc_signal
        core_prev_alloc["_macro_regime"] = macro_regime
        core_prev_alloc["_gold_signal"] = gold_signal
        core_prev_alloc["_btc_risk_cat"] = btc_risk_category

        # ── Edge strategy (multi-alt) ──
        new_edge_alloc = compute_edge_allocation(
            btc_signal, btc_risk_category, gold_signal, macro_regime,
            crypto_signals, alt_btc_signals
        )
        total = sum(new_edge_alloc.values())
        if total > 0:
            new_edge_alloc = {k: v / total for k, v in new_edge_alloc.items()}

        # Track top alt for dominant_alt field (highest weight alt in allocation)
        top_alts_edge = get_top_bullish_alts(alt_btc_signals, n=3)
        dominant_alt = top_alts_edge[0][0] if top_alts_edge else None

        edge_rebalance = (round_alloc(new_edge_alloc) != round_alloc(edge_prev_alloc)) and day_count > 0

        edge_nav, edge_positions = compute_nav(
            edge_positions, edge_nav, prices, new_edge_alloc,
            rebalance=(edge_rebalance or day_count == 0)
        )

        if edge_rebalance:
            triggers = []
            prev_btc_sig = edge_prev_alloc.get("_btc_signal", "")
            if prev_btc_sig != btc_signal:
                triggers.append(f"BTC {prev_btc_sig} → {btc_signal}")
            prev_regime = edge_prev_alloc.get("_macro_regime", "")
            if prev_regime != macro_regime:
                triggers.append(f"Regime {prev_regime} → {macro_regime}")
            prev_gold = edge_prev_alloc.get("_gold_signal", "")
            if prev_gold != gold_signal:
                triggers.append(f"Gold {prev_gold} → {gold_signal}")
            prev_risk = edge_prev_alloc.get("_btc_risk_cat", "")
            if prev_risk != btc_risk_category:
                triggers.append(f"BTC Risk {prev_risk} → {btc_risk_category}")

            trigger_str = "; ".join(triggers) if triggers else "Rebalance"
            from_alloc = {k: round(v * 100, 1) for k, v in edge_prev_alloc.items() if not k.startswith("_")}
            to_alloc = {k: round(v * 100, 1) for k, v in new_edge_alloc.items()}

            trade_rows.append({
                "portfolio_id": portfolio_ids["edge"],
                "trade_date": ds,
                "trigger": trigger_str,
                "from_allocation": from_alloc,
                "to_allocation": to_alloc,
            })

        edge_prev_alloc = dict(new_edge_alloc)
        edge_prev_alloc["_btc_signal"] = btc_signal
        edge_prev_alloc["_macro_regime"] = macro_regime
        edge_prev_alloc["_gold_signal"] = gold_signal
        edge_prev_alloc["_btc_risk_cat"] = btc_risk_category

        # ── Alpha strategy (alt-heavy) ──
        new_alpha_alloc = compute_alpha_allocation(
            btc_signal, btc_risk_category, gold_signal, macro_regime,
            crypto_signals, alt_btc_signals
        )
        total = sum(new_alpha_alloc.values())
        if total > 0:
            new_alpha_alloc = {k: v / total for k, v in new_alpha_alloc.items()}

        alpha_rebalance = (round_alloc(new_alpha_alloc) != round_alloc(alpha_prev_alloc)) and day_count > 0

        alpha_nav, alpha_positions = compute_nav(
            alpha_positions, alpha_nav, prices, new_alpha_alloc,
            rebalance=(alpha_rebalance or day_count == 0)
        )

        if alpha_rebalance:
            triggers = []
            prev_btc_sig = alpha_prev_alloc.get("_btc_signal", "")
            if prev_btc_sig != btc_signal:
                triggers.append(f"BTC {prev_btc_sig} → {btc_signal}")
            prev_regime = alpha_prev_alloc.get("_macro_regime", "")
            if prev_regime != macro_regime:
                triggers.append(f"Regime {prev_regime} → {macro_regime}")
            prev_gold = alpha_prev_alloc.get("_gold_signal", "")
            if prev_gold != gold_signal:
                triggers.append(f"Gold {prev_gold} → {gold_signal}")
            prev_risk = alpha_prev_alloc.get("_btc_risk_cat", "")
            if prev_risk != btc_risk_category:
                triggers.append(f"BTC Risk {prev_risk} → {btc_risk_category}")

            trigger_str = "; ".join(triggers) if triggers else "Rebalance"
            from_alloc = {k: round(v * 100, 1) for k, v in alpha_prev_alloc.items() if not k.startswith("_")}
            to_alloc = {k: round(v * 100, 1) for k, v in new_alpha_alloc.items()}

            trade_rows.append({
                "portfolio_id": portfolio_ids["alpha"],
                "trade_date": ds,
                "trigger": trigger_str,
                "from_allocation": from_alloc,
                "to_allocation": to_alloc,
            })

        alpha_prev_alloc = dict(new_alpha_alloc)
        alpha_prev_alloc["_btc_signal"] = btc_signal
        alpha_prev_alloc["_macro_regime"] = macro_regime
        alpha_prev_alloc["_gold_signal"] = gold_signal
        alpha_prev_alloc["_btc_risk_cat"] = btc_risk_category

        # ── NAV rows ──
        alloc_pcts_core = {k: round(v * 100, 1) for k, v in new_core_alloc.items()}
        # Map mild_bearish → bearish for DB storage (iOS only knows bullish/neutral/bearish)
        db_btc_signal = "bearish" if btc_signal == "mild_bearish" else btc_signal

        nav_rows_core.append({
            "portfolio_id": portfolio_ids["core"],
            "nav_date": ds,
            "nav": round(core_nav, 2),
            "allocations": alloc_pcts_core,
            "btc_signal": db_btc_signal,
            "btc_risk_level": btc_risk_level,
            "btc_risk_category": btc_risk_category,
            "gold_signal": gold_signal,
            "macro_regime": macro_regime,
        })

        alloc_pcts_edge = {k: round(v * 100, 1) for k, v in new_edge_alloc.items()}
        nav_rows_edge.append({
            "portfolio_id": portfolio_ids["edge"],
            "nav_date": ds,
            "nav": round(edge_nav, 2),
            "allocations": alloc_pcts_edge,
            "btc_signal": db_btc_signal,
            "btc_risk_level": btc_risk_level,
            "btc_risk_category": btc_risk_category,
            "gold_signal": gold_signal,
            "macro_regime": macro_regime,
            "dominant_alt": dominant_alt,
        })

        # Alpha NAV row
        top_alts_alpha = get_top_bullish_alts(alt_btc_signals, n=3)
        alpha_dominant = top_alts_alpha[0][0] if top_alts_alpha else None
        alloc_pcts_alpha = {k: round(v * 100, 1) for k, v in new_alpha_alloc.items()}
        nav_rows_alpha.append({
            "portfolio_id": portfolio_ids["alpha"],
            "nav_date": ds,
            "nav": round(alpha_nav, 2),
            "allocations": alloc_pcts_alpha,
            "btc_signal": db_btc_signal,
            "btc_risk_level": btc_risk_level,
            "btc_risk_category": btc_risk_category,
            "gold_signal": gold_signal,
            "macro_regime": macro_regime,
            "dominant_alt": alpha_dominant,
        })

        # SPY benchmark
        if spy_price and spy_shares:
            spy_nav = spy_shares * spy_price
            benchmark_rows.append({
                "nav_date": ds,
                "spy_price": round(spy_price, 2),
                "nav": round(spy_nav, 2),
            })

        # Risk history
        if btc_risk:
            risk_rows.append({
                "asset": "BTC",
                "risk_date": ds,
                "risk_level": btc_risk["risk_level"],
                "price": btc_risk["price"],
                "fair_value": btc_risk["fair_value"],
                "deviation": btc_risk["deviation"],
            })

        # Progress
        if day_count % 7 == 0:
            core_ret = ((core_nav / STARTING_NAV) - 1) * 100
            edge_ret = ((edge_nav / STARTING_NAV) - 1) * 100
            alpha_ret = ((alpha_nav / STARTING_NAV) - 1) * 100
            spy_str = ""
            if spy_shares and spy_price:
                spy_nav_now = spy_shares * spy_price
                spy_ret = ((spy_nav_now / STARTING_NAV) - 1) * 100
                spy_str = f"SPY ${spy_nav_now:,.0f} ({spy_ret:+.1f}%) | "
            print(f"  {ds}: Core ${core_nav:,.0f} ({core_ret:+.1f}%) | "
                  f"Edge ${edge_nav:,.0f} ({edge_ret:+.1f}%) | "
                  f"Alpha ${alpha_nav:,.0f} ({alpha_ret:+.1f}%) | "
                  f"{spy_str}"
                  f"BTC: {btc_signal}/{btc_risk_category} | Regime: {macro_regime}")

        current += timedelta(days=1)
        day_count += 1

    # ── Step 3: Write to database ────────────────────────────────────────
    print(f"\n=== Results ===")
    print(f"Days processed: {day_count}")
    print(f"Core NAV:  ${core_nav:,.2f} ({((core_nav / STARTING_NAV) - 1) * 100:+.1f}%)")
    print(f"Edge NAV:  ${edge_nav:,.2f} ({((edge_nav / STARTING_NAV) - 1) * 100:+.1f}%)")
    print(f"Alpha NAV: ${alpha_nav:,.2f} ({((alpha_nav / STARTING_NAV) - 1) * 100:+.1f}%)")
    if spy_shares and spy_price:
        spy_final = spy_shares * spy_price
        print(f"SPY NAV:   ${spy_final:,.2f} ({((spy_final / STARTING_NAV) - 1) * 100:+.1f}%)")
    print(f"Core trades:  {len([t for t in trade_rows if t['portfolio_id'] == portfolio_ids['core']])}")
    print(f"Edge trades:  {len([t for t in trade_rows if t['portfolio_id'] == portfolio_ids['edge']])}")
    print(f"Alpha trades: {len([t for t in trade_rows if t['portfolio_id'] == portfolio_ids['alpha']])}")

    if args.dry_run:
        print("\n[DRY RUN] Not writing to database.")
        for label, pid in [("Core", "core"), ("Edge", "edge"), ("Alpha", "alpha")]:
            trades = [t for t in trade_rows if t["portfolio_id"] == portfolio_ids[pid]]
            print(f"\nRecent {label} trades:")
            for t in trades[-5:]:
                print(f"  {t['trade_date']}: {t['trigger']}")
                print(f"    {t['to_allocation']}")
        return

    print("\n=== Writing to Supabase ===")

    # NAV rows
    all_nav = nav_rows_core + nav_rows_edge + nav_rows_alpha
    print(f"  Writing {len(all_nav)} NAV rows...")
    for i in range(0, len(all_nav), 100):
        batch = all_nav[i:i + 100]
        supabase.table("model_portfolio_nav").upsert(batch, on_conflict="portfolio_id,nav_date").execute()

    # Trade rows
    if trade_rows:
        print(f"  Writing {len(trade_rows)} trade rows...")
        for i in range(0, len(trade_rows), 100):
            batch = trade_rows[i:i + 100]
            supabase.table("model_portfolio_trades").insert(batch).execute()

    # Benchmark
    if benchmark_rows:
        print(f"  Writing {len(benchmark_rows)} benchmark rows...")
        for i in range(0, len(benchmark_rows), 100):
            batch = benchmark_rows[i:i + 100]
            supabase.table("benchmark_nav").upsert(batch, on_conflict="nav_date").execute()

    # Risk history
    if risk_rows:
        print(f"  Writing {len(risk_rows)} risk history rows...")
        for i in range(0, len(risk_rows), 100):
            batch = risk_rows[i:i + 100]
            supabase.table("model_portfolio_risk_history").upsert(batch, on_conflict="asset,risk_date").execute()

    print("\nDone!")


if __name__ == "__main__":
    main()
