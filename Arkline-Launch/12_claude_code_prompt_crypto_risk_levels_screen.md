# Claude Code Prompt — Dedicated Crypto Risk Levels Screen

Copy everything below the `---` line and paste into Claude Code as a single prompt.

---

# Task

Build a new full-screen view that shows all of ArkLine's supported crypto assets bucketed by their current regression risk band (Low Risk, Neutral, Elevated Risk, High Risk, Extreme Risk). The user reaches it by tapping a new "See all" affordance on the existing "Crypto Risk Levels" section header on the home screen.

This turns the home risk widget — which today only shows the user's selected coins — into a launching pad for *discovery*: "what's currently in Low Risk that I'm not watching?" Most crypto apps show price + 24h change; nobody shows risk-band as a discovery filter. That's the differentiation.

## Why

- The home widget is portfolio-shaped (your selected coins). This screen is discovery-shaped (the whole supported universe).
- All the data already exists — every coin in `AssetRiskConfig.cryptoConfigs` already has a calibrated regression model. We just don't surface them all on one screen anywhere.
- The screen sets up a strong marketing moment: screenshot-able, brand-on-message, demonstrates ArkLine's sophistication.

## Scope decisions (already made — do NOT relitigate)

- **Universe:** the existing `AssetRiskConfig.cryptoConfigs` list (currently 17 coins: BTC, ETH, SOL, BNB, SUI, UNI, ONDO, RENDER, TAO, ZEC, XRP, LTC, AAVE, ENA, JUP, SYRUP, TRX). The screen automatically reflects this list — if more coins are added to `cryptoConfigs` later, they appear without code changes.
- **Bucket source:** regression-only score (matches what the user sees on the home headline). Composite is shown per-row only via the existing divergence chip pattern when it disagrees significantly.
- **Entry point:** tap-through from the home `MultiCoinRiskSection` header. Add a "See all" affordance there — no new tab, no Market-tab embedding.

## Files involved

- **New file:** `ArkLine/Features/Home/Views/CryptoRiskLevelsScreen.swift` (or `ArkLine/Features/RiskLevels/Views/` if you want a new feature folder — your call, match the codebase's organizing convention)
- **New file (optional):** `ArkLine/Features/Home/ViewModels/CryptoRiskLevelsViewModel.swift` — a thin VM that fetches risk for all crypto coins. Don't extend `HomeViewModel` for this; the home VM is already large and we don't want it doing background work for a screen the user may never open.
- **Modify:** `ArkLine/Features/Home/Views/HomePortfolioComponents.swift` — `MultiCoinRiskSection`. Add a "See all" tap target to the header (right-aligned, next to or replacing the existing "X selected" pill). Wire it to push the new screen via the existing NavigationStack in `HomeView`.
- **Possibly modify:** `ArkLine/Features/Home/Views/HomeView.swift` — only if the navigation pattern needs an additional `.navigationDestination` modifier. Verify it already supports the push; the existing pattern of presenting `RiskLevelChartView` via sheet may need adapting (this screen should push, not modal).
- **Do NOT modify:** `AssetRiskConfig.swift`. Adding new coins to `cryptoConfigs` is a separate task that requires per-coin calibration; not part of this scope.

## Existing infrastructure to use (don't reinvent)

- `AssetRiskConfig.cryptoConfigs` — the source of truth for the universe. Iterate over this.
- `itcRiskService.fetchRiskLevel(coin:)` — async per-coin regression risk fetcher (returns `ITCRiskLevel?`). Used today in HomeViewModel around line 1428. Call this for each coin in parallel via `TaskGroup` to keep total load time reasonable.
- `itcRiskService.calculateMultiFactorRisk(coin:)` — composite risk fetcher (returns `MultiFactorRiskPoint?`). Optional per-row enrichment for the divergence chip — see below. If you skip this for v1, that's acceptable; the divergence chip is a nice-to-have on this screen, not a must.
- `RiskColors.color(for: Double)` and `RiskColors.category(for: Double)` — band color + band name (e.g., "Low risk", "Neutral", "Elevated risk").
- `ITCRiskLevel.riskCategory` — the existing computed property that returns the band. Use this for bucketing rather than re-deriving from the raw score.
- `RiskLevelChartView(initialCoin:)` — the existing detail view that opens when a card is tapped today. Reuse for row tap-through.
- `ServiceContainer.shared.itcRiskService` — DI source for the service.
- Coin logos: there's an existing pattern in `CompactRiskCard` (HomePortfolioComponents.swift around line 570 — the `cryptoIconFallback` plus Kingfisher image loader). Reuse it; don't redraw.
- Design tokens: `ArkSpacing`, `AppColors`, `AppFonts`, `ArkTypography`. Don't hardcode.

## Visual spec

### Screen frame

- Full-screen pushed view inside the existing `NavigationStack` on Home.
- Standard nav bar with title "Crypto Risk Levels" (left-aligned or centered to match the rest of ArkLine's nav-bar style — verify by looking at `RiskLevelChartView`'s nav).
- Pull-to-refresh enabled (`.refreshable { await viewModel.refresh() }`).
- Loading state: skeleton or spinner while initial fetch is in flight. Most coins should appear within ~1–2s given the underlying calls are math on cached data.
- Background: same MeshGradientBackground / app surface as the home screen so it feels native, not modal-y.

### Section structure (top to bottom)

1. **Small subtitle row** under the nav bar: "Regression model • {N} assets bucketed". Where N is the total count across all bands. Sentence case.

2. **One section per risk band**, in this order:
   - Low risk (green)
   - Neutral (amber)
   - Elevated risk (orange)
   - High risk (red)
   - Extreme risk (deep red)
3. **Hide empty bands** (do not render "Extreme Risk · 0 assets"). If a band has zero coins, omit the section entirely.

4. **Section header** for each band:
   - Left: small colored dot (the band color) + band name ("Low risk") + count pill ("12").
   - Right: nothing for v1. (No filter/sort controls.)
   - Font: ~15pt medium, band color for the name.
   - Vertical spacing above each section: `ArkSpacing.lg`.

5. **Within a section: rows sorted by ascending risk score** (so the safest within each band is at the top of that section).

### Row design

Compact horizontal row, ~48–56pt tall:

- **Left:** coin logo (32×32, rounded — reuse the existing pattern with Kingfisher + fallback gradient circle).
- **Middle (flex):** ticker symbol (e.g. "BTC") at 15pt medium, with optional short name below ("Bitcoin") at 12pt secondary if it doesn't crowd the row. Both left-aligned. If you only have ticker readily available without an extra lookup, ship ticker only.
- **Right:** risk score formatted to 3 decimals (e.g. "0.359") at 16pt medium, in the band's color. Optional: a small `chevron.right` icon at very low opacity to signal the row is tappable.
- **Optional divergence chip** below the score on the right side, only when the composite is at least one band away AND ≥0.05 numeric gap (same threshold as on home cards). Use the same compact "↑ More cautious" / "↓ More bullish" chip from `CompactRiskCard`. If you've already built that chip as a reusable view, reuse it; if it's still inlined inside `CompactRiskCard`, extract it now into a small standalone view so both surfaces can use it. If you choose to defer composite fetching for v1 to keep the prompt scope tight, do that — just leave a clean extension point (a nil-safe optional property on the row's view model).

### Row tap behavior

Tap a row → push `RiskLevelChartView(initialCoin: coin)` onto the navigation stack. Use the existing detail view — don't build a new one. Match how `CompactRiskCard` currently opens it (the home card opens it as a sheet today via `.sheet(isPresented:)`; on the new screen it should probably push within the same NavigationStack for consistency. Use your judgment — push reads more natural here since we're already in a nav hierarchy).

### "See all" affordance on home

In `MultiCoinRiskSection`'s header (HomePortfolioComponents.swift around line 514–530):

- Add a small right-aligned tap target: text "See all" + `chevron.right` icon, 13pt, color `AppColors.accent` (the brand blue).
- The existing "X selected" count pill can either move to the left of "See all" with a small spacer, or be replaced by the count being implicit (since the new screen shows all). Your call — pick whichever doesn't crowd the header.
- Wire to push `CryptoRiskLevelsScreen` onto the navigation stack. The cleanest way is `NavigationLink { CryptoRiskLevelsScreen() } label: { ... }` if you're inside a NavigationStack context, otherwise `@State` + `.navigationDestination`.

## Implementation order

1. Build `CryptoRiskLevelsViewModel`:
   - Property: `bucketed: [RiskBand: [(coin: String, riskLevel: ITCRiskLevel)]]`
   - Method: `func loadAll() async` — uses `TaskGroup` to fetch `fetchRiskLevel(coin:)` for every coin in `AssetRiskConfig.cryptoConfigs`. Stores results in the dictionary, grouped by `ITCRiskLevel.riskCategory`. Sort within each bucket by `riskLevel` ascending.
   - Method: `func refresh()` — clears and re-fetches.
   - Loading state property.
2. Build `CryptoRiskLevelsScreen`:
   - On `.task`: call `viewModel.loadAll()`.
   - Render the section structure described above.
   - `.refreshable` calling `viewModel.refresh()`.
3. Add the "See all" affordance to `MultiCoinRiskSection`.
4. Test navigation: tap "See all" → screen pushes → tap a row → detail view pushes → navigate back twice → home.

## Test plan

1. Build the app, sign in.
2. On home, scroll to "Crypto Risk Levels" — verify the new "See all" affordance appears on the right side of the section header.
3. Tap "See all" — verify a new screen pushes with a loading state, then populates with risk bands.
4. Verify all coins from `AssetRiskConfig.cryptoConfigs` appear somewhere across the bands (count the total = should equal `cryptoConfigs.count`, currently 17).
5. Verify bands are in the right order (Low → Neutral → Elevated → High → Extreme).
6. Verify empty bands don't render.
7. Verify rows within each band are sorted ascending by risk score.
8. Tap a row — verify `RiskLevelChartView` opens for that coin.
9. Back out — verify nav stack pops cleanly back to the bucketed screen, then to home.
10. Pull to refresh on the bucketed screen — verify scores refresh.
11. Screenshot the bucketed screen with at least 2 bands visible and include in your report.

## Out of scope (do NOT do)

- **Do not add coins to `AssetRiskConfig.cryptoConfigs`.** That's a separate task requiring per-coin calibration of regression parameters, genesis dates, and gecko IDs.
- **Do not** add stock support to this screen. Stocks have their own widget on home (`StockRiskLevelSection`); a stock equivalent of this screen is a future feature.
- **Do not** add filtering, sorting controls, or a search bar. The screen is intentionally minimal for v1 — readable at a glance.
- **Do not** add the composite (multi-factor) bucket assignment. Buckets are regression-only; composite shows only as the optional per-row divergence chip.
- **Do not** modify HomeViewModel to pre-fetch the wider universe on home load. Lazy-fetch only when the screen opens.
- **Do not** rebuild the detail view. Reuse `RiskLevelChartView`.
- **Do not** add this screen to the bottom tab bar. Entry is via the home section header only.

## Reporting

When done, report:

1. New files created (full paths) and existing files modified (with line ranges).
2. Whether you extracted the divergence chip into a reusable view (and what you called it), or left it inlined in `CompactRiskCard` and re-implemented for this screen.
3. Whether `RiskLevelChartView` opened cleanly as a push, or whether you had to wrap/adapt it for navigation.
4. The total time for `loadAll()` to populate all 17 coins on first open (rough estimate from logs or visual perception is fine).
5. A screenshot of the new bucketed screen.
6. Any unexpected friction or design choices you had to make on the fly.

Keep the report tight.
