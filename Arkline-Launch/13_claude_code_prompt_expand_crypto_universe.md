# Claude Code Prompt — Expand `AssetRiskConfig.cryptoConfigs` with 24 New Coins

Copy everything below the `---` line and paste into Claude Code as a single prompt. Run this **before** the Crypto Risk Levels screen prompt (#12) so the new screen picks up all 41 coins on first build.

---

# Task

Add 24 new crypto assets to `AssetRiskConfig.cryptoConfigs` in `ArkLine/Domain/Models/AssetRiskConfig.swift`. The existing list has 17 coins; this brings the total to 41. Each new entry needs a static `AssetRiskConfig` constant, an entry in the `cryptoImagePaths` dictionary (for logo rendering), and inclusion in the `cryptoConfigs` static array.

The new coins are: **ADA, DOT, NEAR, AVAX, ARB, OP, LINK, ATOM, INJ, SEI, TIA, FET, ETC, BCH, FIL, IMX, LDO, MKR, PEPE, DOGE, SHIB, HBAR, KAS, ALGO**.

## Why

The dedicated Crypto Risk Levels screen (separate prompt #12) buckets assets by risk band as a discovery tool. With only 17 coins, the screen feels thin and discovery is limited. Expanding to ~40 coins makes the screen feel substantive without being noisy, covers the major sectors (L1s, L2s, DeFi, AI/compute, memes, payments), and gives ArkLine's positioning ("we evaluate everything you'd actually care about") credibility.

## Files involved

- **Modify:** `ArkLine/Domain/Models/AssetRiskConfig.swift` — the only file you should touch.

## What each new entry needs

For each coin, you need to add a `static let` constant following the existing pattern (see `.btc`, `.eth`, `.sol` for reference). Each constant requires:

- `assetId` — ticker in caps (e.g., `"ADA"`)
- `geckoId` — CoinGecko's slug for this coin (e.g., `"cardano"`). **You must verify these via WebSearch or WebFetch against `https://www.coingecko.com/en/coins/<slug>` because some are non-obvious** (e.g., AVAX is `"avalanche-2"` not `"avalanche"`, MATIC was `"matic-network"`, etc.).
- `originDate` — token launch / mainnet date. Use `safeDate(year: YYYY, month: MM, day: DD)`. When in doubt, use the date the coin started trading on major exchanges. Verify via WebSearch if you're unsure.
- `deviationBounds` — `(low: Double, high: Double)` — set based on volatility and history. Use these heuristics:
  - **Long history + lower volatility (BTC-class)**: `(-0.75, 0.75)` to `(-0.80, 0.80)`
  - **Established mid-cap, multi-cycle (LINK, ETC, BCH-class)**: `(-0.65, 0.65)` to `(-0.70, 0.70)`
  - **Newer L1s / L2s / DeFi (~3–5 yrs, single full cycle)**: `(-0.55, 0.55)` to `(-0.60, 0.60)`
  - **Very new, <2 yrs (SEI, TIA, KAS, PEPE-class)**: `(-0.50, 0.50)`
  - **Memes (DOGE/SHIB-class, high vol but long history for DOGE)**: `(-0.75, 0.75)`
- `confidenceLevel` — integer 1–9 based on years of available history:
  - 8–9: 10+ years (none of the new coins qualify)
  - 7: 6–10 years (ETC ✓, BCH ✓, DOGE ✓, LINK ✓)
  - 6: 4–6 years (DOT, AVAX, NEAR, ATOM, FIL, HBAR, ALGO, FET, MKR, SHIB)
  - 5: 2–4 years (LDO, IMX, INJ, OP)
  - 4: 1–2 years (ARB, KAS, PEPE)
  - 3: <1 year (SEI, TIA — but they're approaching 2 yrs by 2026; bump to 4 if so)
- `displayName` — full name (e.g., `"Cardano"`, `"Avalanche"`, `"Pepe"`)
- `binanceSymbol` — Binance trading pair (e.g., `"ADAUSDT"`). Verify the coin is listed on Binance Spot via WebSearch; if not listed, pass `nil`. As of 2026, all 24 listed coins **should** be on Binance — but PEPE, KAS, and SEI are worth double-checking.

You also need to add an entry to the `cryptoImagePaths` static dictionary at line ~64. The format is `"<geckoId>": "<numericId>/<size>/<filename>"`. You can find these by:
1. Visiting `https://www.coingecko.com/en/coins/<slug>`
2. Inspecting the page's coin image URL — it looks like `https://assets.coingecko.com/coins/images/975/large/cardano.png`
3. The path you need is everything after `/coins/images/` — so for that example: `"975/large/cardano.png"`

**Use WebFetch to get these from CoinGecko.** Do NOT guess the numeric IDs — they're not predictable.

Finally, add each new constant to the `cryptoConfigs` array at line ~351, keeping a sensible visual grouping (e.g., L1s together, DeFi together, memes together — your call, but be consistent).

## Suggested groupings within `cryptoConfigs` array

```swift
static let cryptoConfigs: [AssetRiskConfig] = [
    // Majors
    .btc, .eth, .sol,
    // L1s
    .bnb, .ada, .dot, .avax, .near, .atom, .sui, .tao, .hbar, .algo, .kas,
    // L2s
    .arb, .op, .imx,
    // DeFi
    .uni, .aave, .mkr, .ldo, .ena, .jup, .syrup,
    // Infra / Oracles / AI
    .link, .render, .fet,
    // Payments / Privacy
    .xrp, .ltc, .zec, .bch, .etc, .trx,
    // RWA / Specific narratives
    .ondo, .fil, .inj, .sei, .tia,
    // Memes
    .doge, .shib, .pepe
]
```

(Exact order matters less than completeness — make sure all 41 are in there with no duplicates.)

## Verification

Use WebFetch on these URLs to verify gecko slugs and image paths for the trickier ones (the obvious ones you can skip if you're confident):

- AVAX: `https://www.coingecko.com/en/coins/avalanche`
- FET: `https://www.coingecko.com/en/coins/fetch-ai` (note: FET rebranded to ASI in 2024 but coin still trades as FET on most CEXes — verify current state)
- LDO: `https://www.coingecko.com/en/coins/lido-dao`
- IMX: `https://www.coingecko.com/en/coins/immutable-x`
- MKR: `https://www.coingecko.com/en/coins/maker` (note: MKR migrated to SKY in 2024 but MKR still exists — verify which one ArkLine should track)
- KAS: `https://www.coingecko.com/en/coins/kaspa`
- TIA: `https://www.coingecko.com/en/coins/celestia`
- SEI: `https://www.coingecko.com/en/coins/sei-network`
- INJ: `https://www.coingecko.com/en/coins/injective-protocol`

For everything else (ADA, DOT, NEAR, ATOM, LINK, ETC, BCH, FIL, PEPE, DOGE, SHIB, HBAR, ALGO, ARB, OP) the gecko slugs are the obvious lowercase-hyphenated names — but verify the image paths since those numeric IDs aren't predictable.

## Implementation order

1. Use WebFetch to gather all 24 gecko slugs + image paths in one batch (or as few batches as possible).
2. Add the 24 `static let` constants in the existing alphabetical-ish style, with brief comments per the existing pattern (`/// Cardano — proof-of-stake L1`, etc.).
3. Add 24 entries to `cryptoImagePaths`.
4. Add 24 entries to `cryptoConfigs` (in your chosen grouping).
5. Build the app — no other code should need changing. The `MultiCoinRiskSection` filter (`.filter { AssetRiskConfig.forCoin($0) != nil }`) and any consumers that iterate `cryptoConfigs` will automatically pick up the new coins.

## Test plan

1. Build the app.
2. In the home Crypto Risk Levels section, the existing 17 coins should still render correctly.
3. Open Profile → Settings → Risk Coins (or wherever users select which coins to track) — verify the new 24 appear as selectable options.
4. Add one new coin (e.g., ADA) to your tracked list — verify it renders a risk score on the home card.
5. Open `RiskLevelChartView` for ADA — verify the regression chart loads.

## Out of scope (do NOT do)

- **Do not** modify any other Swift files. The new screen (`CryptoRiskLevelsScreen`) is being built in a separate prompt; it will auto-pick-up these coins.
- **Do not** add stock entries. Stocks are managed separately.
- **Do not** "calibrate" the deviation bounds with backtests or external data — use the heuristic table above as best-effort initial values. Matt will refine post-launch as he watches scores against his intuition.
- **Do not** try to add multi-factor data for new coins. The composite uses BTC's market-wide indicators (F&G, VIX, DXY), so it works for any crypto without per-coin calibration.

## Reporting

When done, report:

1. The 24 gecko slugs and image paths you used (for Matt to spot-check).
2. Any coin where you had to use `binanceSymbol: nil` (not listed on Binance Spot).
3. Any coin where the originDate or deviationBounds required a judgment call beyond the heuristic table.
4. Confirmation that `cryptoConfigs.count == 41` after the change.
5. Whether the build succeeded.

Keep the report under 300 words.
