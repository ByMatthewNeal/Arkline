#!/usr/bin/env python3
"""
Backfill ETH and SOL risk scores into model_portfolio_risk_history.

Uses the same log-regression methodology as BTC:
  1. Fetch full price history from FMP
  2. Least-squares regression in log-log space (log10(price) vs log10(days_since_origin))
  3. Compute fair_value, deviation, and normalize to 0–1 risk_level
  4. Upsert one row per asset per day

Usage:
  python3 scripts/backfill_eth_sol_risk.py [--start 2024-01-01] [--dry-run]

Requires env vars: FMP_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
"""

import argparse
import math
import os
import sys
from datetime import date, datetime, timedelta
from typing import Optional

import requests

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
FMP_KEY = os.environ.get("FMP_API_KEY", "")

ASSET_CONFIGS = {
    "ETH": {
        "fmp_symbol": "ETHUSD",
        "origin_date": date(2015, 7, 30),
        "deviation_bounds": (-0.8, 0.8),
        "min_points": 100,
    },
    "SOL": {
        "fmp_symbol": "SOLUSD",
        "origin_date": date(2020, 4, 10),
        "deviation_bounds": (-1.0, 1.0),
        "min_points": 50,
    },
}


def fetch_price_history(fmp_symbol: str) -> list[dict]:
    """Fetch full EOD history from FMP, sorted oldest-first."""
    url = f"https://financialmodelingprep.com/stable/historical-price-eod/full?symbol={fmp_symbol}&apikey={FMP_KEY}"
    resp = requests.get(url, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    if not isinstance(data, list):
        print(f"  Unexpected response for {fmp_symbol}: {type(data)}")
        return []
    # Sort oldest first
    return sorted(data, key=lambda r: r["date"])


def compute_risk(
    history: list[dict],
    origin: date,
    target_date: str,
    deviation_bounds: tuple[float, float],
    min_points: int,
) -> Optional[dict]:
    """Compute log-regression risk for a single date."""
    filtered = [p for p in history if p["date"] <= target_date]
    if len(filtered) < min_points:
        return None

    valid = []
    for p in filtered:
        d = datetime.strptime(p["date"], "%Y-%m-%d").date()
        days = (d - origin).days
        price = float(p["close"])
        if days > 0 and price > 0:
            valid.append((days, price))

    if len(valid) < min_points:
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

    target_dt = datetime.strptime(target_date, "%Y-%m-%d").date()
    target_days = (target_dt - origin).days
    if target_days <= 0:
        return None

    log_fair = a + b * math.log10(target_days)
    fair_value = 10**log_fair

    current_price = float(filtered[-1]["close"])
    deviation = math.log10(current_price) - math.log10(fair_value)

    low, high = deviation_bounds
    clamped = max(low, min(high, deviation))
    risk_level = (clamped - low) / (high - low)

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


def upsert_rows(rows: list[dict], dry_run: bool) -> None:
    """Upsert rows into model_portfolio_risk_history."""
    if dry_run:
        print(f"  [dry-run] Would upsert {len(rows)} rows")
        return

    # Supabase REST API upsert
    url = f"{SUPABASE_URL}/rest/v1/model_portfolio_risk_history"
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "resolution=merge-duplicates",
    }

    # Batch in chunks of 100
    for i in range(0, len(rows), 100):
        chunk = rows[i : i + 100]
        resp = requests.post(url, json=chunk, headers=headers, timeout=30)
        if resp.status_code not in (200, 201):
            print(f"  Error upserting chunk {i}: {resp.status_code} {resp.text}")
        else:
            print(f"  Upserted rows {i+1}–{i+len(chunk)}")


def main():
    parser = argparse.ArgumentParser(description="Backfill ETH/SOL risk history")
    parser.add_argument("--start", default="2024-01-01", help="Start date (YYYY-MM-DD)")
    parser.add_argument("--dry-run", action="store_true", help="Print results without writing to DB")
    parser.add_argument("--assets", default="ETH,SOL", help="Comma-separated assets to backfill")
    args = parser.parse_args()

    if not FMP_KEY:
        print("Error: FMP_API_KEY env var required")
        sys.exit(1)
    if not args.dry_run and (not SUPABASE_URL or not SUPABASE_KEY):
        print("Error: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY env vars required")
        sys.exit(1)

    assets = [a.strip() for a in args.assets.split(",")]
    start_date = datetime.strptime(args.start, "%Y-%m-%d").date()
    end_date = date.today()

    for asset in assets:
        config = ASSET_CONFIGS.get(asset)
        if not config:
            print(f"Skipping unknown asset: {asset}")
            continue

        print(f"\n{'='*60}")
        print(f"Backfilling {asset} risk ({args.start} → {end_date})")
        print(f"  Origin: {config['origin_date']}, Bounds: {config['deviation_bounds']}")
        print(f"{'='*60}")

        history = fetch_price_history(config["fmp_symbol"])
        if not history:
            print(f"  No price data from FMP for {config['fmp_symbol']}")
            continue
        print(f"  Fetched {len(history)} price points ({history[0]['date']} → {history[-1]['date']})")

        rows = []
        current = start_date
        while current <= end_date:
            date_str = current.strftime("%Y-%m-%d")
            result = compute_risk(
                history,
                config["origin_date"],
                date_str,
                config["deviation_bounds"],
                config["min_points"],
            )
            if result:
                rows.append({
                    "asset": asset,
                    "risk_date": date_str,
                    "risk_level": result["risk_level"],
                    "price": result["price"],
                    "fair_value": result["fair_value"],
                    "deviation": result["deviation"],
                })
                if current == start_date or current == end_date or current.day == 1:
                    print(f"  {date_str}: risk={result['risk_level']:.4f} ({result['category']}), "
                          f"price=${result['price']:,.2f}, fair=${result['fair_value']:,.2f}")
            current += timedelta(days=1)

        print(f"\n  Total rows computed: {len(rows)}")
        if rows:
            upsert_rows(rows, args.dry_run)

    print("\nDone.")


if __name__ == "__main__":
    main()
