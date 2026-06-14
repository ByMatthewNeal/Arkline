# Claude Code Prompt — Add 7-Factor Composite Cross-Check Chip to Home Risk Cards

Copy everything below the `---` line and paste into Claude Code as a single prompt.

---

# Task

Add a small "7-factor cross-check" chip to each crypto risk card on the home screen. The card's headline stays as the regression-only score (current behavior), but a new chip below the risk band displays the composite (multi-factor) risk score and category. The chip is color-tinted by the composite's own risk band, so when the two models *agree* the chip blends in (calm uniform color); when they *diverge* the chip stands out (e.g. amber chip on a green card) and pulls the user's eye to look closer.

This surfaces the multi-factor risk score that today lives only in the detail view, without changing what the user perceives as the headline number.

## Why

You already compute two risk scores: a single-factor regression-only score (shown today on the home card and in `viewModel.riskLevels`) and a 7-factor composite score (`MultiFactorRiskPoint`, surfaced only via `fetchMultiFactorRisk` in the detail view). Right now the home user never sees the composite read, which can be meaningfully different from the regression read — e.g. regression = 0.359 (Low Risk), composite = 0.495 (Neutral). That's an information gap. The chip closes it without overwhelming the simpler regression-first UX.

## Files involved

- `ArkLine/Features/Home/Views/HomePortfolioComponents.swift` — `MultiCoinRiskSection` (section header + grid) and `CompactRiskCard` (the actual card UI). The chip renders inside `CompactRiskCard`.
- `ArkLine/Features/Home/ViewModels/HomeViewModel.swift` — add multi-factor storage, fetch on refresh, expose via `userSelectedRiskLevels` tuple.
- `ArkLine/Features/Home/Views/ReorderableWidgetStack.swift` — only if the tuple shape change requires a call-site tweak (line ~214, the `MultiCoinRiskSection(...)` invocation).
- `ArkLine/Features/Home/Views/ITCRiskWidget.swift` — **do not modify**. This is the legacy `RiskLevelWidget` used only in previews; the home actually uses `CompactRiskCard` in `HomePortfolioComponents.swift`. Verify this by grepping; don't get tricked by the name.

## Existing infrastructure to use (don't reinvent)

- `MultiFactorRiskPoint` model — already defined; produced by `itcRiskService.calculateMultiFactorRisk(coin:)`. Has `riskLevel: Double` and supporting factor data. See `RiskFactorBreakdownView.swift` and `RiskLevelDetailView.swift` for example consumption.
- `SentimentViewModel.fetchMultiFactorRisk(coin:)` — the existing fetcher used by the detail view. Returns `MultiFactorRiskPoint?`. Wraps `itcRiskService.calculateMultiFactorRisk(coin:)`.
- `RiskColors.color(for:)` and `RiskColors.category(for:)` — utility for mapping a risk score (0.0–1.0) to a `Color` and a category label like "Low risk" / "Neutral" / "High risk". Use these for the chip exactly as they're used for the headline so the two reads share a visual vocabulary.
- `ArkSpacing`, `AppColors`, `AppFonts`, `ArkColors` — design tokens. **Do not hardcode** colors or sizes.
- `ITCRiskLevel` model — already used for the regression read. Don't extend it; the multi-factor data flows through a separate `MultiFactorRiskPoint`.

## Visual spec for the chip

Render the chip inside `CompactRiskCard`, **between the risk-band badge row** (the green dot + "Low risk" text) **and the "X days at this level" subtext**.

Layout:
- Horizontal pill, inline-flex, fits content (does NOT span full card width).
- Padding: `4pt vertical, 8pt horizontal` (use `ArkSpacing.xs` vertical, ~`ArkSpacing.sm` horizontal).
- Corner radius: 6pt (slightly tighter than the card itself; if there's a token like `ArkSpacing.xs` or a small radius token, use it; otherwise `RoundedRectangle(cornerRadius: 6)`).
- Background: composite risk color at ~10% opacity (e.g. `RiskColors.color(for: composite.riskLevel).opacity(0.10)`).
- Content (left to right, spacing ~6pt):
  - 5pt × 5pt filled circle in `RiskColors.color(for: composite.riskLevel)`.
  - Label text **"7-factor:"** — 11pt, weight regular, color `AppColors.textSecondary` (slight gray). Sentence case (not "7-Factor:").
  - Value text **"{score} {category}"** — 11pt, weight medium, color `RiskColors.color(for: composite.riskLevel)`. Score formatted with 3 decimals (e.g. `0.495`). Category from `RiskColors.category(for:)`.
- Top margin from the risk band badge above: `ArkSpacing.sm` (~8pt).
- Bottom margin to the "X days at this level" subtext below: `ArkSpacing.sm` (~8pt) — adjust so the visual rhythm matches the spacing already used in the card.

**Loading / missing data:** if `multiFactorRisk` is `nil` (data not yet fetched, or fetch failed), render NO chip and NO placeholder skeleton — collapse the space gracefully so the card just looks like today. Do not show "Loading..." or a spinner — silent absence is preferred to noisy in-progress UI on a small card.

**Tap behavior:** the entire card already has a tap handler (`showingDetail = true`) — do not add a separate tap target on the chip. The chip is informational; tapping the card anywhere still opens `RiskLevelChartView`.

## Section header copy change

In `MultiCoinRiskSection` (HomePortfolioComponents.swift around line 514–523), the subtitle currently reads **"Regression from genesis"**. Change it to:

> **"Regression with 7-factor cross-check"**

Keep the headline ("Crypto Risk Levels") unchanged. Keep the "X selected" pill on the right unchanged.

## Implementation steps

### 1. Extend `HomeViewModel` to fetch and store composite scores

In `HomeViewModel.swift`:

- Add a new dictionary near `riskLevels` (around line 333):
  ```swift
  /// Composite (7-factor) risk per coin. Loaded in parallel with regression.
  var multiFactorRiskLevels: [String: MultiFactorRiskPoint] = [:]
  ```
- Update the `userSelectedRiskLevels` computed property (line 348) so each tuple element also exposes the composite. The new tuple shape:
  ```swift
  var userSelectedRiskLevels: [(
      coin: String,
      riskLevel: ITCRiskLevel?,
      daysAtLevel: Int?,
      weeklyAvgRisk: Double?,
      multiFactorRisk: MultiFactorRiskPoint?
  )] {
      userRiskCoins
          .filter { AssetRiskConfig.forCoin($0) != nil }
          .map { coin in
              let level = riskLevels[coin]
              let history = riskHistories[coin] ?? []
              return (
                  coin,
                  level,
                  consecutiveDaysAtCurrentLevel(history: history, current: level),
                  weeklyAverageRiskLevel(for: coin),
                  multiFactorRiskLevels[coin]
              )
          }
  }
  ```
- Find the existing regression-fetch path that populates `riskLevels[coin]` (around line 927). Right after the regression score is stored, kick off (in parallel — don't block the regression result) a fetch for the composite via `itcRiskService.calculateMultiFactorRisk(coin: coin)` and store the result in `multiFactorRiskLevels[coin]`. Use a `Task { ... }` so it doesn't extend the duration of the parent refresh. Handle errors silently (logError, then continue) — the chip just won't render if it fails.
- If `HomeViewModel` doesn't already hold a reference to `itcRiskService`, inject it from `ServiceContainer.shared` (match the pattern of other services in this VM).

### 2. Update `MultiCoinRiskSection` and `CompactRiskCard` signatures

In `HomePortfolioComponents.swift`:

- Update `MultiCoinRiskSection.riskLevels` type to match the new tuple shape (add the `multiFactorRisk: MultiFactorRiskPoint?` field).
- In the `ForEach` body (around line 536), pass `multiFactorRisk: item.multiFactorRisk` into `CompactRiskCard`.
- Add a new optional parameter to `CompactRiskCard`:
  ```swift
  var multiFactorRisk: MultiFactorRiskPoint? = nil
  ```
- Inside `CompactRiskCard`'s body, after the risk-band badge HStack, render the chip if `multiFactorRisk` is non-nil. Follow the visual spec above.

### 3. Update the section subtitle

Change line 520 from:
```swift
Text("Regression from genesis")
```
to:
```swift
Text("Regression with 7-factor cross-check")
```

### 4. Verify `ReorderableWidgetStack.swift` call-site still compiles

Around line 214–217, the existing call passes `viewModel.userSelectedRiskLevels` directly into `MultiCoinRiskSection`. The tuple type change means Swift will infer the new shape automatically — no edits should be needed at the call site. Verify by compiling.

### 5. Stocks are out of scope

`StockRiskLevelSection` (line 219 in ReorderableWidgetStack.swift, fed by `stockSelectedRiskLevels`) does NOT get a chip. The stock risk model is regression-only today; no composite exists. Leave it untouched.

## Test plan

After implementation:

1. Run the app, sign in as a user with at least BTC and ETH in their `userRiskCoins` (the default).
2. On the home screen, scroll to "Crypto Risk Levels" section.
3. Verify the subtitle now reads **"Regression with 7-factor cross-check"**.
4. Verify each card shows the headline regression score (unchanged) plus a chip below the risk band that says **"7-factor: 0.XXX [Category]"** in the composite's color.
5. If composite ≈ regression, chip should be the same color family as the headline (calm visual).
6. To force a divergence for visual verification: temporarily edit the composite calculation (or wait for real divergence — BTC's composite has been Neutral while regression is Low Risk, which produces an amber chip on a green card).
7. Pull-to-refresh — chip should refresh without flicker; if composite fetch fails, chip silently disappears rather than showing an error.
8. Tap any card → still opens `RiskLevelChartView` (no change to tap target).

Take a screenshot of the home risk section showing one divergent and one agreement case if possible, and include it in your report.

## Out of scope (do NOT do)

- **Do not modify** `RiskLevelDetailView.swift`. The existing "Regression Only → 7-Factor Composite" comparison block there should stay (it adds context the chip doesn't, like timestamp and side-by-side category pills).
- **Do not modify** `RiskLevelWidget` / `ITCRiskWidget` in `ITCRiskWidget.swift`. That's the legacy/preview widget, not the home card.
- **Do not add** a multi-factor chip to `StockRiskLevelSection` — stocks don't have a composite model.
- **Do not** change the headline score logic on the home card. Regression-only stays as the headline.
- **Do not** add new caching infrastructure. If `itcRiskService.calculateMultiFactorRisk` already caches (check), rely on it. If it doesn't, just let each home refresh refetch — multi-factor calc is cheap.
- **Do not** add a loading spinner, skeleton, or "Composite unavailable" copy. Silent absence is the spec.

## Reporting

When done, report:

1. List of files modified, with line ranges.
2. Whether `itcRiskService` was already injected in `HomeViewModel` or you had to add it (and via what mechanism).
3. Whether the multi-factor fetch is currently cached at the service layer (worth knowing for future perf work).
4. Screenshot(s) of the home risk section after the change.
5. Any unexpected edge cases — e.g. did the call-site in `ReorderableWidgetStack` need explicit tuple type annotations, did Swift's type inference still work cleanly, was there a place where the composite category mapping returned an empty string for some score, etc.

Keep the report tight. No need to recap the design rationale — Matt already approved it.
