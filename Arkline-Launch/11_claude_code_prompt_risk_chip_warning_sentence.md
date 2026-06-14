# Claude Code Prompt — Risk Card Chip: Warning Sentence + Show Only on Divergence

Copy everything below the `---` line and paste into Claude Code as a single prompt.

---

# Task

Refine the 7-factor cross-check chip on the home crypto risk cards. The previous version (which now reads "0.496 Neutral" on the BTC card and "0.556 Elevated Risk" on the ETH card) creates user confusion — having two different risk conclusions on the same card ("Low Risk" headline + a chip saying "Elevated Risk") reads as a contradiction rather than a useful nuance.

New behavior:

1. **The chip becomes a directional warning sentence**, not a competing number. No more "0.XXX [Category]" in the chip — instead the chip reads "↑ Broader signals more cautious" or "↓ Broader signals more bullish" depending on which way the composite leans relative to the regression headline.
2. **The chip only appears when divergence is meaningful** — defined as the composite landing in a *different risk category* than the regression AND the absolute gap being at least 0.05. When the two models agree (same category, or within 0.05), no chip renders and the card looks calm.

The composite's specific score and category are still available in the detail view via the existing "Regression Only → 7-Factor Composite" comparison block — we're not losing the data, just removing the cognitive contradiction from the home glance.

## Files involved

- `ArkLine/Features/Home/Views/HomePortfolioComponents.swift` — `CompactRiskCard` chip block (currently around lines 636–657). Only this file needs editing.
- **No changes to** `HomeViewModel.swift` (fetching logic stays), `ReorderableWidgetStack.swift`, `RiskLevelDetailView.swift`, or the section subtitle.

## Existing infrastructure to use

- `riskLevel: ITCRiskLevel?` — regression score, headline on the card.
- `multiFactorRisk: MultiFactorRiskPoint?` — composite score, source for divergence comparison.
- `RiskColors.category(for: Double)` — returns the risk-band string ("Low risk", "Neutral", "Elevated risk", etc.). Use this for comparing categories.
- `AppColors.warning`, `AppColors.info`, `AppColors.textSecondary` — semantic colors. Don't hardcode.

## Implementation

### 1. Add a divergence-state computed property to `CompactRiskCard`

Inside `CompactRiskCard` (after the existing private color properties, before `body`):

```swift
private enum DivergenceState {
    case none              // models agree (same category, or gap < 0.05)
    case moreCautious      // composite > regression by a meaningful margin
    case moreBullish       // composite < regression by a meaningful margin
}

private var divergenceState: DivergenceState {
    guard let regression = riskLevel?.riskLevel,
          let composite = multiFactorRisk?.riskLevel else {
        return .none
    }

    let gap = composite - regression
    let absGap = abs(gap)

    // Threshold: require both categorical AND numeric divergence
    let sameCategory = RiskColors.category(for: regression) == RiskColors.category(for: composite)
    guard !sameCategory, absGap >= 0.05 else {
        return .none
    }

    return gap > 0 ? .moreCautious : .moreBullish
}

private var divergenceCopy: String {
    switch divergenceState {
    case .none:           return ""
    case .moreCautious:   return "↑ Broader signals more cautious"
    case .moreBullish:    return "↓ Broader signals more bullish"
    }
}

private var divergenceTint: Color {
    switch divergenceState {
    case .none:           return .clear
    case .moreCautious:   return AppColors.warning  // soft amber
    case .moreBullish:    return AppColors.info     // soft blue
    }
}
```

### 2. Replace the existing chip rendering

Find the chip HStack block added in the previous task (the one currently rendering "0.XXX Category" with a colored dot). Replace it entirely with this:

```swift
if divergenceState != .none {
    HStack(spacing: 5) {
        Text(divergenceCopy)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(divergenceTint)
            .lineLimit(2)  // arrow + 4 words; should fit on one line but allow wrap as safety
            .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 8)
    .background(
        RoundedRectangle(cornerRadius: 6)
            .fill(divergenceTint.opacity(0.10))
    )
    .padding(.top, ArkSpacing.sm)
    .fixedSize(horizontal: true, vertical: false)  // chip hugs content, doesn't stretch
}
```

Key changes from the previous version:
- No colored dot (the arrow does the directional work)
- No second number (the warning sentence replaces it)
- Background is a soft tint of the warning/info semantic color, not the composite's risk-band color
- Whole block is conditional on `divergenceState != .none` — when models agree, the chip simply isn't in the view hierarchy and the card collapses gracefully

### 3. Verify spacing

Confirm the `.padding(.top, ArkSpacing.sm)` above gives the right rhythm between the "Low Risk" badge and the chip when present, and that "X days at this level" still sits with `ArkSpacing.sm` below the chip. If the existing VStack has its own `spacing:` set, the explicit `.padding(.top)` may double up — pick one source of truth.

## Visual outcome

After this change:

- **When BTC's regression is "Low risk" (0.359) and composite is "Neutral" (0.496):** chip appears with amber tint, "↑ Broader signals more cautious". The card looks like: headline 0.359 green / Low Risk badge / amber warning chip / 107 days at this level.
- **When ETH's regression is "Low risk" (0.352) and composite is "Elevated risk" (0.556):** chip appears with amber tint (same direction — more cautious — even though the magnitude is larger). The bigger composite vs. regression gap doesn't change the chip's text; the chip is intentionally binary (direction, not magnitude). Magnitude lives in the detail view.
- **When both models are in the same band (e.g., both Low):** no chip. Card looks like the original pre-multi-factor design.
- **When models differ by category but the numeric gap is < 0.05:** no chip. Filters out boundary-hopping noise.

## Test plan

1. Build and run on simulator.
2. Open the Crypto Risk Levels section on home.
3. With BTC and ETH in their current states (both showing divergence), confirm both cards display the amber "↑ Broader signals more cautious" chip — no numbers, no category words on the chip itself.
4. To test the no-chip state, run this SQL or temporarily fake the composite to be near the regression:
   - Either find a coin where regression and composite agree naturally, OR
   - In dev only, manually override `multiFactorRiskLevels[coin]` to a value close to `riskLevels[coin]?.riskLevel` to verify the chip disappears.
5. To test the bullish-direction state, manually override the composite to a value 0.10 *below* the regression (e.g. regression Low 0.40, composite "very low" 0.20) and confirm the chip shows "↓ Broader signals more bullish" with the info-blue tint.
6. Tap any card — should still open the detail view unchanged.

Screenshot the home risk section after the change and include in your report.

## Out of scope (do NOT do)

- **Do not change the data fetching** in `HomeViewModel`. The multi-factor data still flows the same way.
- **Do not change the section subtitle** — "Regression with 7-factor cross-check" is still accurate since the cross-check is happening; it just renders silently when models agree.
- **Do not change the detail view.** The composite's specific number and category continue to live there for users who tap through.
- **Do not surface the composite number anywhere on the home card.** That's the whole point of this revision — no competing numbers on the surface.
- **Do not** add a "tap for details" CTA or icon on the chip. The whole card already has a tap target; the chip is informational only.
- **Do not** add caching or change the multi-factor fetch path.

## Reporting

Briefly:

1. Lines changed in `HomePortfolioComponents.swift`.
2. Whether `AppColors.warning` and `AppColors.info` exist as-named in your design tokens (if not, what equivalents you used).
3. Screenshot of the home risk section showing divergence-state chips.
4. Anything unexpected.

Keep the report tight.
