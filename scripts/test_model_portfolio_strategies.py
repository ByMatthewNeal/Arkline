#!/usr/bin/env python3
"""
Stress tests for model portfolio strategy logic.
Tests multi-alt helpers, Core/Edge/Alpha allocation functions,
edge cases, and data integrity.

Usage:
    python scripts/test_model_portfolio_strategies.py
"""

import sys
import math

# Import the backfill module
sys.path.insert(0, "scripts")
from backfill_model_portfolios import (
    get_top_bullish_alts,
    distribute_alt_pct,
    compute_core_allocation,
    compute_edge_allocation,
    compute_alpha_allocation,
    apply_defensive,
    get_defensive_mix,
    derive_signal,
    compute_trend_score,
    compute_nav,
    STARTING_NAV,
)

passed = 0
failed = 0

def assert_eq(name, actual, expected, tolerance=0.001):
    global passed, failed
    if isinstance(expected, float):
        if abs(actual - expected) <= tolerance:
            passed += 1
        else:
            failed += 1
            print(f"  FAIL: {name}: expected {expected}, got {actual}")
    elif actual == expected:
        passed += 1
    else:
        failed += 1
        print(f"  FAIL: {name}: expected {expected}, got {actual}")

def assert_true(name, condition):
    global passed, failed
    if condition:
        passed += 1
    else:
        failed += 1
        print(f"  FAIL: {name}")

def assert_alloc_sums_to_1(name, alloc):
    global passed, failed
    total = sum(v for k, v in alloc.items() if not k.startswith("_"))
    if abs(total - 1.0) < 0.01:
        passed += 1
    else:
        failed += 1
        print(f"  FAIL: {name}: allocation sums to {total}, expected ~1.0 → {alloc}")


# ══════════════════════════════════════════════════════════════════════════════
# 1. Multi-Alt Helper Tests
# ══════════════════════════════════════════════════════════════════════════════
print("=== 1. Multi-Alt Helpers ===")

# get_top_bullish_alts
signals = {
    "LINK/BTC": {"signal": "bullish", "trend_score": 85},
    "AVAX/BTC": {"signal": "bullish", "trend_score": 72},
    "DOGE/BTC": {"signal": "bearish", "trend_score": 30},
    "SUI/BTC": {"signal": "bullish", "trend_score": 90},
    "ETH/BTC": {"signal": "bullish", "trend_score": 80},  # Should be excluded
    "SOL/BTC": {"signal": "bullish", "trend_score": 78},  # Should be excluded
    "BNB/BTC": {"signal": "bullish", "trend_score": 60},
    "AAVE/BTC": {"signal": "bullish", "trend_score": 77},
}

top3 = get_top_bullish_alts(signals, n=3)
assert_eq("top3 count", len(top3), 3)
assert_eq("top3[0] is SUI", top3[0][0], "SUI")
assert_eq("top3[1] is LINK", top3[1][0], "LINK")
assert_eq("top3[2] is AAVE", top3[2][0], "AAVE")

top1 = get_top_bullish_alts(signals, n=1)
assert_eq("top1 count", len(top1), 1)
assert_eq("top1[0] is SUI", top1[0][0], "SUI")

# No bullish alts
no_bull = {"DOGE/BTC": {"signal": "bearish", "trend_score": 30}}
assert_eq("no bullish alts", len(get_top_bullish_alts(no_bull)), 0)

# Empty signals
assert_eq("empty signals", len(get_top_bullish_alts({})), 0)

# BTC/ETH/SOL excluded
only_core = {
    "BTC/BTC": {"signal": "bullish", "trend_score": 99},
    "ETH/BTC": {"signal": "bullish", "trend_score": 95},
    "SOL/BTC": {"signal": "bullish", "trend_score": 90},
}
assert_eq("core assets excluded", len(get_top_bullish_alts(only_core)), 0)

# distribute_alt_pct
dist = distribute_alt_pct([("SUI", 90), ("LINK", 60)], 0.15)
assert_eq("distribute total", sum(dist.values()), 0.15)
assert_true("SUI gets more than LINK", dist["SUI"] > dist["LINK"])
assert_eq("SUI pct", dist["SUI"], 0.15 * 90 / 150)
assert_eq("LINK pct", dist["LINK"], 0.15 * 60 / 150)

# distribute with empty
assert_eq("distribute empty", distribute_alt_pct([], 0.15), {})

# distribute with zero scores (equal weight fallback)
dist_zero = distribute_alt_pct([("A", 0), ("B", 0)], 0.20)
assert_eq("zero score A", dist_zero["A"], 0.10)
assert_eq("zero score B", dist_zero["B"], 0.10)

# distribute single alt
dist_single = distribute_alt_pct([("AAVE", 75)], 0.40)
assert_eq("single alt gets all", dist_single["AAVE"], 0.40)


# ══════════════════════════════════════════════════════════════════════════════
# 2. Defensive Mix Tests
# ══════════════════════════════════════════════════════════════════════════════
print("=== 2. Defensive Mix ===")

mix_bull = get_defensive_mix("bullish")
assert_eq("bullish PAXG", mix_bull["PAXG"], 0.70)
assert_eq("bullish USDC", mix_bull["USDC"], 0.30)

mix_neut = get_defensive_mix("neutral")
assert_eq("neutral PAXG", mix_neut["PAXG"], 0.40)
assert_eq("neutral USDC", mix_neut["USDC"], 0.60)

mix_bear = get_defensive_mix("bearish")
assert_eq("bearish PAXG", mix_bear["PAXG"], 0.0)
assert_eq("bearish USDC", mix_bear["USDC"], 1.0)

# apply_defensive
alloc = apply_defensive({"BTC": 0.60}, 0.40, "bullish")
assert_eq("defensive BTC", alloc["BTC"], 0.60)
assert_eq("defensive PAXG", alloc["PAXG"], 0.28)
assert_eq("defensive USDC", alloc["USDC"], 0.12)
assert_alloc_sums_to_1("defensive total", alloc)


# ══════════════════════════════════════════════════════════════════════════════
# 3. Core Allocation Tests
# ══════════════════════════════════════════════════════════════════════════════
print("=== 3. Core Allocation ===")

# Bullish
alloc = compute_core_allocation("bullish", "Neutral", "neutral", "Risk-On")
assert_eq("core bullish BTC", alloc["BTC"], 0.60)
assert_eq("core bullish ETH", alloc["ETH"], 0.40)
assert_alloc_sums_to_1("core bullish total", alloc)

# Neutral + Low Risk
alloc = compute_core_allocation("neutral", "Low Risk", "neutral", "Risk-On")
assert_eq("core neutral/low BTC", alloc["BTC"], 0.50)
assert_eq("core neutral/low ETH", alloc["ETH"], 0.30)
assert_alloc_sums_to_1("core neutral/low total", alloc)

# Neutral + Elevated Risk
alloc = compute_core_allocation("neutral", "Elevated Risk", "neutral", "Risk-On")
assert_eq("core neutral/elevated BTC", alloc["BTC"], 0.30)
assert_eq("core neutral/elevated ETH", alloc["ETH"], 0.20)
assert_alloc_sums_to_1("core neutral/elevated total", alloc)

# Mild bearish + Low Risk
alloc = compute_core_allocation("mild_bearish", "Low Risk", "neutral", "Risk-On")
assert_eq("core mild_bear/low BTC", alloc["BTC"], 0.30)
assert_eq("core mild_bear/low ETH", alloc["ETH"], 0.15)
assert_alloc_sums_to_1("core mild_bear/low total", alloc)

# Mild bearish + Neutral Risk
alloc = compute_core_allocation("mild_bearish", "Neutral", "neutral", "Risk-On")
assert_eq("core mild_bear/neutral BTC", alloc["BTC"], 0.20)
assert_eq("core mild_bear/neutral ETH", alloc["ETH"], 0.10)
assert_alloc_sums_to_1("core mild_bear/neutral total", alloc)

# Bearish + Very Low Risk (accumulation)
alloc = compute_core_allocation("bearish", "Very Low Risk", "neutral", "Risk-On")
assert_eq("core bear/verylow BTC", alloc["BTC"], 0.40)
assert_eq("core bear/verylow ETH", alloc["ETH"], 0.20)
assert_alloc_sums_to_1("core bear/verylow total", alloc)

# Bearish + Low Risk
alloc = compute_core_allocation("bearish", "Low Risk", "bearish", "Risk-On")
assert_eq("core bear/low BTC", alloc["BTC"], 0.25)
assert_eq("core bear/low ETH", alloc["ETH"], 0.15)
assert_alloc_sums_to_1("core bear/low total", alloc)

# Bearish + Neutral/Elevated (keeps small position)
alloc = compute_core_allocation("bearish", "Neutral", "neutral", "Risk-On")
assert_eq("core bear/neutral BTC", alloc["BTC"], 0.15)
assert_eq("core bear/neutral ETH", alloc["ETH"], 0.05)
assert_alloc_sums_to_1("core bear/neutral total", alloc)

# Risk-Off + High Risk = 100% defensive
alloc = compute_core_allocation("bearish", "High Risk", "bullish", "Risk-Off")
assert_true("core riskoff/high no BTC", "BTC" not in alloc or alloc.get("BTC", 0) == 0)
assert_eq("core riskoff/high PAXG", alloc.get("PAXG", 0), 0.70)
assert_alloc_sums_to_1("core riskoff/high total", alloc)

# Gold signal affects defensive mix
alloc_gold_bull = compute_core_allocation("bearish", "Neutral", "bullish", "Risk-On")
alloc_gold_bear = compute_core_allocation("bearish", "Neutral", "bearish", "Risk-On")
assert_true("gold bullish has PAXG", alloc_gold_bull.get("PAXG", 0) > 0)
assert_true("gold bearish no PAXG", alloc_gold_bear.get("PAXG", 0) == 0)
assert_true("gold bearish has USDC", alloc_gold_bear.get("USDC", 0) > 0)


# ══════════════════════════════════════════════════════════════════════════════
# 4. Edge Allocation Tests (Multi-Alt)
# ══════════════════════════════════════════════════════════════════════════════
print("=== 4. Edge Allocation (Multi-Alt) ===")

crypto_signals_bullish = {
    "BTC": {"signal": "bullish", "trend_score": 75},
    "ETH": {"signal": "bullish", "trend_score": 72},
    "SOL": {"signal": "bullish", "trend_score": 68},
}
alt_signals_bullish = {
    "LINK/BTC": {"signal": "bullish", "trend_score": 85},
    "AAVE/BTC": {"signal": "bullish", "trend_score": 77},
    "SUI/BTC": {"signal": "bullish", "trend_score": 90},
    "DOGE/BTC": {"signal": "bearish", "trend_score": 30},
}

# Full bullish deployment with multi-alt
alloc = compute_edge_allocation("bullish", "Neutral", "neutral", "Risk-On",
                                 crypto_signals_bullish, alt_signals_bullish)
assert_eq("edge bull BTC", alloc.get("BTC", 0), 0.30)
assert_eq("edge bull ETH", alloc.get("ETH", 0), 0.25)
assert_eq("edge bull SOL", alloc.get("SOL", 0), 0.20)
# Should have SUI, LINK, AAVE splitting 15%
assert_true("edge bull has SUI", "SUI" in alloc)
assert_true("edge bull has LINK", "LINK" in alloc)
assert_true("edge bull has AAVE", "AAVE" in alloc)
alt_total = alloc.get("SUI", 0) + alloc.get("LINK", 0) + alloc.get("AAVE", 0)
assert_eq("edge bull alt total", alt_total, 0.15)
assert_true("edge SUI > LINK (higher score)", alloc.get("SUI", 0) > alloc.get("LINK", 0))
assert_alloc_sums_to_1("edge bull total", alloc)

# Edge with no bullish alts
alloc_no_alts = compute_edge_allocation("bullish", "Neutral", "neutral", "Risk-On",
                                         crypto_signals_bullish, {})
assert_eq("edge no alts BTC", alloc_no_alts.get("BTC", 0), 0.30)
assert_true("edge no alts no SUI", "SUI" not in alloc_no_alts)
assert_alloc_sums_to_1("edge no alts total", alloc_no_alts)

# Edge mild bearish
alloc = compute_edge_allocation("mild_bearish", "Neutral", "neutral", "Risk-On",
                                 {}, alt_signals_bullish)
assert_eq("edge mild_bear BTC", alloc.get("BTC", 0), 0.15)
assert_alloc_sums_to_1("edge mild_bear total", alloc)

# Edge Risk-Off + High = 100% defensive
alloc = compute_edge_allocation("bearish", "High Risk", "neutral", "Risk-Off",
                                 {}, {})
assert_true("edge riskoff/high no BTC", alloc.get("BTC", 0) == 0)
assert_alloc_sums_to_1("edge riskoff/high total", alloc)

# Edge Risk-Off + Very Low Risk (accumulation)
alloc = compute_edge_allocation("bearish", "Very Low Risk", "neutral", "Risk-Off",
                                 {}, {})
assert_eq("edge riskoff/verylow BTC", alloc.get("BTC", 0), 0.30)
assert_eq("edge riskoff/verylow ETH", alloc.get("ETH", 0), 0.20)
assert_alloc_sums_to_1("edge riskoff/verylow total", alloc)


# ══════════════════════════════════════════════════════════════════════════════
# 5. Alpha Allocation Tests
# ══════════════════════════════════════════════════════════════════════════════
print("=== 5. Alpha Allocation ===")

# Full bullish — 40% in alts
alloc = compute_alpha_allocation("bullish", "Neutral", "neutral", "Risk-On",
                                  crypto_signals_bullish, alt_signals_bullish)
assert_eq("alpha bull BTC", alloc.get("BTC", 0), 0.20)
assert_eq("alpha bull ETH", alloc.get("ETH", 0), 0.15)
assert_eq("alpha bull SOL", alloc.get("SOL", 0), 0.15)
alt_total = alloc.get("SUI", 0) + alloc.get("LINK", 0) + alloc.get("AAVE", 0)
assert_eq("alpha bull alt total", alt_total, 0.40)
assert_true("alpha SUI > LINK", alloc.get("SUI", 0) > alloc.get("LINK", 0))
assert_alloc_sums_to_1("alpha bull total", alloc)

# Alpha vs Edge: Alpha has more alts, less BTC
edge_alloc = compute_edge_allocation("bullish", "Neutral", "neutral", "Risk-On",
                                      crypto_signals_bullish, alt_signals_bullish)
assert_true("alpha more alts than edge", alt_total > (
    edge_alloc.get("SUI", 0) + edge_alloc.get("LINK", 0) + edge_alloc.get("AAVE", 0)
))
assert_true("alpha less BTC than edge", alloc.get("BTC", 0) < edge_alloc.get("BTC", 0))

# Alpha Risk-Off + High = 100% defensive
alloc = compute_alpha_allocation("bearish", "High Risk", "neutral", "Risk-Off",
                                  {}, {})
assert_true("alpha riskoff/high no BTC", alloc.get("BTC", 0) == 0)
assert_alloc_sums_to_1("alpha riskoff/high total", alloc)

# Alpha bearish + Low Risk: keeps some alts
alloc = compute_alpha_allocation("bearish", "Low Risk", "neutral", "Risk-On",
                                  {}, alt_signals_bullish)
assert_true("alpha bear/low has alts", any(k in alloc for k in ["SUI", "LINK", "AAVE"]))
assert_alloc_sums_to_1("alpha bear/low total", alloc)

# Alpha bearish + High Risk (no alts in accumulation)
alloc = compute_alpha_allocation("bearish", "Elevated Risk", "neutral", "Risk-On",
                                  {}, alt_signals_bullish)
assert_eq("alpha bear/elevated BTC", alloc.get("BTC", 0), 0.08)
assert_eq("alpha bear/elevated ETH", alloc.get("ETH", 0), 0.04)
assert_alloc_sums_to_1("alpha bear/elevated total", alloc)

# Alpha mild bearish
alloc = compute_alpha_allocation("mild_bearish", "Neutral", "neutral", "Risk-On",
                                  {}, alt_signals_bullish)
assert_eq("alpha mild BTC", alloc.get("BTC", 0), 0.10)
assert_alloc_sums_to_1("alpha mild total", alloc)

# Alpha with no alts — remainder goes to defensive
alloc = compute_alpha_allocation("bullish", "Neutral", "neutral", "Risk-On",
                                  crypto_signals_bullish, {})
assert_eq("alpha no alts BTC", alloc.get("BTC", 0), 0.20)
deployed = alloc.get("BTC", 0) + alloc.get("ETH", 0) + alloc.get("SOL", 0)
assert_true("alpha no alts remainder is defensive",
            alloc.get("PAXG", 0) + alloc.get("USDC", 0) > 0.4)
assert_alloc_sums_to_1("alpha no alts total", alloc)


# ══════════════════════════════════════════════════════════════════════════════
# 6. Signal Derivation Tests
# ══════════════════════════════════════════════════════════════════════════════
print("=== 6. Signal Derivation ===")

assert_eq("bullish score 75", derive_signal(75, True, True, True, True), "bullish")
assert_eq("neutral caps bullish below 200SMA", derive_signal(75, False, True, True, True), "neutral")
assert_eq("neutral caps bullish below both SMAs", derive_signal(75, True, True, False, False), "neutral")
assert_eq("neutral score 50", derive_signal(50, True, True, True, True), "neutral")
assert_eq("mild_bearish score 40", derive_signal(40, True, True, True, True), "mild_bearish")
assert_eq("mild_bearish score 36", derive_signal(36, True, True, True, True), "mild_bearish")
assert_eq("bearish score 35", derive_signal(35, True, True, True, True), "bearish")
assert_eq("bearish score 0", derive_signal(0, False, True, False, False), "bearish")
assert_eq("bullish no 200SMA", derive_signal(80, False, False, True, True), "bullish")


# ══════════════════════════════════════════════════════════════════════════════
# 7. NAV Computation Tests
# ══════════════════════════════════════════════════════════════════════════════
print("=== 7. NAV Computation ===")

# Initial allocation
prices = {"BTC": 50000, "ETH": 3000, "USDC": 1.0}
alloc = {"BTC": 0.60, "ETH": 0.30, "USDC": 0.10}
nav, positions = compute_nav({}, STARTING_NAV, prices, alloc, rebalance=True)
assert_eq("initial nav", nav, STARTING_NAV)
assert_eq("initial BTC value", positions["BTC"]["value"], 30000.0)
assert_eq("initial BTC qty", positions["BTC"]["qty"], 0.6)
assert_eq("initial ETH value", positions["ETH"]["value"], 15000.0)
assert_eq("initial ETH qty", positions["ETH"]["qty"], 5.0)

# Mark to market (no rebalance, BTC up 10%)
prices2 = {"BTC": 55000, "ETH": 3000, "USDC": 1.0}
nav2, pos2 = compute_nav(positions, nav, prices2, alloc, rebalance=False)
expected_nav = 0.6 * 55000 + 5.0 * 3000 + positions["USDC"]["value"] * 1.0001205
assert_eq("mtm nav", nav2, expected_nav, tolerance=1.0)
assert_eq("mtm BTC qty unchanged", pos2["BTC"]["qty"], 0.6)

# Rebalance into new allocation
new_alloc = {"BTC": 0.40, "ETH": 0.30, "PAXG": 0.20, "USDC": 0.10}
prices3 = {"BTC": 55000, "ETH": 3000, "PAXG": 2800, "USDC": 1.0}
nav3, pos3 = compute_nav(pos2, nav2, prices3, new_alloc, rebalance=True)
assert_true("rebalance preserves nav", abs(nav3 - nav2) < 1.0)
assert_true("rebalance has PAXG", "PAXG" in pos3)
assert_eq("rebalance PAXG value", pos3["PAXG"]["value"], nav3 * 0.20, tolerance=1.0)


# ══════════════════════════════════════════════════════════════════════════════
# 8. Exhaustive Allocation Sum-to-1 Stress Test
# ══════════════════════════════════════════════════════════════════════════════
print("=== 8. Exhaustive Allocation Sum-to-1 ===")

btc_signals = ["bullish", "neutral", "mild_bearish", "bearish"]
risk_categories = ["Very Low Risk", "Low Risk", "Neutral", "Elevated Risk", "High Risk", "Extreme Risk"]
gold_signals = ["bullish", "neutral", "bearish"]
regimes = ["Risk-On", "Risk-Off"]

alt_combos = [
    {},  # no alts
    {"LINK/BTC": {"signal": "bullish", "trend_score": 85}},  # 1 alt
    {"LINK/BTC": {"signal": "bullish", "trend_score": 85},
     "AAVE/BTC": {"signal": "bullish", "trend_score": 77},
     "SUI/BTC": {"signal": "bullish", "trend_score": 90}},  # 3 alts
]

crypto_combos = [
    {},
    {"BTC": {"signal": "bullish", "trend_score": 75}},
    {"BTC": {"signal": "bullish", "trend_score": 75},
     "ETH": {"signal": "bullish", "trend_score": 72},
     "SOL": {"signal": "bullish", "trend_score": 68}},
]

total_combos = 0
for bs in btc_signals:
    for rc in risk_categories:
        for gs in gold_signals:
            for regime in regimes:
                # Core
                alloc = compute_core_allocation(bs, rc, gs, regime)
                total = sum(alloc.values())
                if abs(total - 1.0) > 0.02:
                    failed += 1
                    print(f"  FAIL: Core sum={total} for {bs}/{rc}/{gs}/{regime}")
                else:
                    passed += 1
                total_combos += 1

                # Edge & Alpha with different alt/crypto combos
                for cs in crypto_combos:
                    for alts in alt_combos:
                        for fn, label in [(compute_edge_allocation, "Edge"),
                                          (compute_alpha_allocation, "Alpha")]:
                            alloc = fn(bs, rc, gs, regime, cs, alts)
                            total = sum(alloc.values())
                            if abs(total - 1.0) > 0.02:
                                failed += 1
                                print(f"  FAIL: {label} sum={total} for {bs}/{rc}/{gs}/{regime} cs={len(cs)} alts={len(alts)}")
                            else:
                                passed += 1
                            total_combos += 1

print(f"  Tested {total_combos} allocation combinations")


# ══════════════════════════════════════════════════════════════════════════════
# 9. No Negative Allocations
# ══════════════════════════════════════════════════════════════════════════════
print("=== 9. No Negative Allocations ===")

neg_count = 0
for bs in btc_signals:
    for rc in risk_categories:
        for gs in gold_signals:
            for regime in regimes:
                for fn in [compute_core_allocation]:
                    alloc = fn(bs, rc, gs, regime)
                    for k, v in alloc.items():
                        if v < -0.001:
                            neg_count += 1
                            print(f"  FAIL: Negative {k}={v} in Core {bs}/{rc}/{gs}/{regime}")

                for cs in crypto_combos:
                    for alts in alt_combos:
                        for fn, label in [(compute_edge_allocation, "Edge"),
                                          (compute_alpha_allocation, "Alpha")]:
                            alloc = fn(bs, rc, gs, regime, cs, alts)
                            for k, v in alloc.items():
                                if v < -0.001:
                                    neg_count += 1
                                    print(f"  FAIL: Negative {k}={v} in {label}")

if neg_count == 0:
    passed += 1
    print("  All allocations non-negative")
else:
    failed += neg_count


# ══════════════════════════════════════════════════════════════════════════════
# 10. Strategy Differentiation Tests
# ══════════════════════════════════════════════════════════════════════════════
print("=== 10. Strategy Differentiation ===")

# In bullish conditions, Alpha should have more alt exposure than Edge
cs = {"BTC": {"signal": "bullish", "trend_score": 75},
      "ETH": {"signal": "bullish", "trend_score": 72},
      "SOL": {"signal": "bullish", "trend_score": 68}}
alts = {"LINK/BTC": {"signal": "bullish", "trend_score": 85},
        "AAVE/BTC": {"signal": "bullish", "trend_score": 77},
        "SUI/BTC": {"signal": "bullish", "trend_score": 90}}

edge = compute_edge_allocation("bullish", "Neutral", "neutral", "Risk-On", cs, alts)
alpha = compute_alpha_allocation("bullish", "Neutral", "neutral", "Risk-On", cs, alts)
core = compute_core_allocation("bullish", "Neutral", "neutral", "Risk-On")

edge_alt = sum(v for k, v in edge.items() if k not in ("BTC", "ETH", "SOL", "PAXG", "USDC"))
alpha_alt = sum(v for k, v in alpha.items() if k not in ("BTC", "ETH", "SOL", "PAXG", "USDC"))

assert_true("alpha more alt than edge", alpha_alt > edge_alt)
assert_true("core has no alts", all(k in ("BTC", "ETH", "PAXG", "USDC") for k in core.keys()))
assert_true("edge BTC > alpha BTC", edge.get("BTC", 0) > alpha.get("BTC", 0))
assert_true("core BTC > edge BTC", core.get("BTC", 0) > edge.get("BTC", 0))

# In bearish conditions, Core should be most conservative
core_bear = compute_core_allocation("bearish", "Elevated Risk", "neutral", "Risk-On")
edge_bear = compute_edge_allocation("bearish", "Elevated Risk", "neutral", "Risk-On", {}, alts)
alpha_bear = compute_alpha_allocation("bearish", "Elevated Risk", "neutral", "Risk-On", {}, alts)

# Core keeps MORE crypto in bearish (accumulation strategy) — less defensive than Edge
core_crypto = core_bear.get("BTC", 0) + core_bear.get("ETH", 0)
edge_crypto = edge_bear.get("BTC", 0) + edge_bear.get("ETH", 0)
assert_true("core holds more crypto in bearish (accumulation)", core_crypto >= edge_crypto)


# ══════════════════════════════════════════════════════════════════════════════
# Results
# ══════════════════════════════════════════════════════════════════════════════
print(f"\n{'='*60}")
print(f"RESULTS: {passed} passed, {failed} failed")
print(f"{'='*60}")

sys.exit(1 if failed > 0 else 0)
