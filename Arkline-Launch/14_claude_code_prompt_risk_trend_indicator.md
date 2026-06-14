# Claude Code Prompt — Add Trend Indicator (7D / 30D) to Crypto Risk Levels Screen

Copy everything below the `---` line and paste into Claude Code as a single prompt.

---

# Task

On the `CryptoRiskLevelsScreen` (just shipped in prompt #12), add a trend / momentum indicator to each row showing whether that coin's regression risk score is *rising*, *falling*, or *flat* over a user-selectable window. Add a `7D / 30D` toggle at the top of the screen so the user picks which window drives the trend display.

This turns the screen from a static snapshot ("what's the risk *right now*") into a directional view ("where is the risk *headed*"). It's the difference between a barometer reading and a barometer with an arrow.

## Why

A user scanning the bucketed list wants to know more than the current band — they want to know which way each asset is moving. SHIB at 0.305 today could be a coin that's just dropped from 0.50 and is heading lower (good — falling risk), or one that's just climbed from 0.15 and is heading higher (bad — rising risk). Same current score, very different implications. The trend indicator solves this without needing the user to tap into each detail view.

## Files involved

- **Modify:** `ArkLine/Features/Home/ViewModels/CryptoRiskLevelsViewModel.swift` — extend to fetch recent history (not just latest) and expose a per-coin trend delta.
- **Modify:** `ArkLine/Features/Home/Views/CryptoRiskLevelsScreen.swift` — add the 7D/30D toggle, render trend indicator on each row.
- **No other files should need changes.**

## Existing infrastructure to use

- `itcRiskService.fetchRiskHistory(coin:days:)` — async per-coin history fetcher. Returns an array of `ITCRiskLevel` ordered by date. **Verify exact signature** before writing — search the codebase. If the only available method returns less than 30 days of history, request 30 days. If it returns more, slice.
- The existing data shape `ITCRiskLevel` (`riskLevel: Double`, `date: String`).
- `TaskGroup` pattern already in use for parallel fetching (see CryptoRiskLevelsViewModel).
- `AppColors.error` / `AppColors.success` / `AppColors.textSecondary` — semantic colors for the rising/falling/flat indicator.
- `RiskColors.color(for:)` — only used for the headline score; the trend indicator uses *semantic* colors (red rising / green falling), not risk-band colors.

## Design spec

### 7D / 30D toggle (top of screen)

Place directly below the subtitle row (`"Regression model • N assets bucketed"`).

- Segmented-style pill control with two options: **"7D"** and **"30D"**.
- Width: hug content (e.g. ~140pt total), left-aligned in line with the subtitle (or right-aligned next to it — whichever reads cleaner in the dark mode you're already rendering).
- Selected segment: filled with `AppColors.accent` (~12% opacity tint background + accent text color); unselected: transparent background with `textSecondary` color.
- Tap to switch. Default: **7D**.
- Trigger Haptics.light() on switch.

Selecting a window updates the trend indicator on every row in place — no re-fetch needed if you've fetched the full 30 days up front (which you should).

### Trend indicator (each row)

Render the indicator vertically stacked **below the score**, right-aligned, so the headline score stays the visually dominant element:

```
                                    0.359   >
                                  ↑ +0.045
```

- Arrow: `arrow.up` or `arrow.down` SF Symbol at ~10pt, in the trend color.
- Delta: signed numeric value to 3 decimals (e.g., `+0.045`, `-0.022`). 11pt, weight medium.
- Both arrow and delta the same color.

### Colors

Trend colors are *semantic*, NOT risk-band colors:

- **Rising risk** (delta > +0.02): `AppColors.error` (red). The arrow + delta both red. Rising risk = bad for the holder.
- **Falling risk** (delta < -0.02): `AppColors.success` (green). The arrow + delta both green.
- **Flat** (|delta| ≤ 0.02): show **"—"** in `AppColors.textSecondary` (muted gray). No arrow, no number. Reads as "no meaningful change."
- **No data** (insufficient history for this window): same as flat — render "—" muted. New coins may not have 30 days of history yet; degrade gracefully.

### Threshold rationale

±0.02 is the threshold for "flat." Below that, the change is noise (well within typical daily fluctuation for most coins). Above ±0.02, the directional signal is meaningful. Use this for both 7D and 30D windows.

## Implementation steps

### 1. Extend `CryptoRiskLevelsViewModel`

Replace the per-coin `fetchLatestRiskLevel` call inside the `TaskGroup` with `fetchRiskHistory(coin: , days: 30)`. From the returned array, you derive three values per coin:

```swift
struct CoinRiskRow {
    let coin: String          // ticker
    let current: ITCRiskLevel // today's value (last element of history)
    let delta7d: Double?      // current - value 7 days ago. nil if insufficient history.
    let delta30d: Double?     // current - value 30 days ago. nil if insufficient history.
}
```

Store these in the bucketed dictionary (`[RiskBand: [CoinRiskRow]]`). Replace existing `(coin: String, riskLevel: ITCRiskLevel)` tuple type accordingly.

Add a published property:

```swift
@Observable
class CryptoRiskLevelsViewModel {
    enum TrendWindow {
        case sevenDay, thirtyDay
    }
    var selectedTrendWindow: TrendWindow = .sevenDay
    // ...
}
```

Add a small helper to read the right delta off a row:

```swift
func delta(for row: CoinRiskRow) -> Double? {
    switch selectedTrendWindow {
    case .sevenDay:  return row.delta7d
    case .thirtyDay: return row.delta30d
    }
}
```

### 2. Build the trend-indicator subview

Add a small reusable view that takes a delta and renders the arrow + value, handling the three states (rising / falling / flat-or-missing):

```swift
struct TrendIndicator: View {
    let delta: Double?

    private let threshold: Double = 0.02

    var body: some View {
        if let d = delta, abs(d) > threshold {
            let isUp = d > 0
            let color: Color = isUp ? AppColors.error : AppColors.success
            HStack(spacing: 2) {
                Image(systemName: isUp ? "arrow.up" : "arrow.down")
                    .font(.system(size: 10, weight: .semibold))
                Text(String(format: "%+.3f", d))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(color)
        } else {
            Text("—")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
    }
}
```

### 3. Wire toggle UI into the screen

Below the subtitle row, add the segmented pill. Approximately:

```swift
HStack(spacing: 6) {
    ForEach([CryptoRiskLevelsViewModel.TrendWindow.sevenDay, .thirtyDay], id: \.self) { window in
        Button {
            Haptics.light()
            viewModel.selectedTrendWindow = window
        } label: {
            Text(window == .sevenDay ? "7D" : "30D")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    viewModel.selectedTrendWindow == window
                        ? AppColors.accent.opacity(0.12)
                        : Color.clear
                )
                .foregroundColor(
                    viewModel.selectedTrendWindow == window
                        ? AppColors.accent
                        : AppColors.textSecondary
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
.padding(.horizontal, ArkSpacing.md)
.padding(.bottom, ArkSpacing.sm)
```

### 4. Add `TrendIndicator` to each row

In the row view (currently rendering logo + ticker + name + score), put the score and trend indicator inside a right-aligned VStack:

```swift
VStack(alignment: .trailing, spacing: 2) {
    Text(String(format: "%.3f", row.current.riskLevel))
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(RiskColors.color(for: row.current.riskLevel))
    TrendIndicator(delta: viewModel.delta(for: row))
}
```

Keep the existing chevron after this VStack so the tap-affordance reads.

### 5. Handle the loading and refresh paths

- On first load, `fetchRiskHistory(coin: , days: 30)` for all 41 coins in parallel. Expect ~2–4s — slower than the previous fetchLatestRiskLevel-only load. Make sure the loading state is visible.
- On pull-to-refresh, re-fetch the full history.
- Toggle switching does NOT trigger a re-fetch — just rebinds the displayed delta from already-fetched data.

## Test plan

1. Build and run.
2. Open the Crypto Risk Levels screen via "See all".
3. Initial state: 7D toggle is selected (filled accent color).
4. Verify each row shows a trend indicator below its score: most should be `↑ +0.0XX` (red), `↓ -0.0XX` (green), or `—` (gray).
5. Verify rising/falling colors match the semantic: rising = red, falling = green.
6. Tap **30D** in the toggle. Indicators on every row update *instantly* (no re-fetch flicker). Some `—`s may become arrows and vice versa as the longer window catches different movements.
7. Verify newer coins (SEI, TIA, KAS, PEPE) likely show `—` on 30D if they don't have full 30-day history.
8. Pull to refresh. History refetches; toggle state preserved.
9. Tap a row → detail view opens (unchanged).
10. Navigate back to home → no regression on existing risk cards.

Screenshot the screen with one band fully visible, in both 7D and 30D mode if you can, so we can eyeball the visual hierarchy.

## Out of scope (do NOT do)

- **Do not** add the trend indicator to the home risk cards. Home is the snapshot view; the bucketed screen is the directional view. Keep them differentiated.
- **Do not** add a custom date range. 7D and 30D only for v1.
- **Do not** sort within each band by delta (sort stays by current score, ascending). Trend is informational, not the sort key.
- **Do not** change the bucketing logic. Buckets are still driven by current regression score.
- **Do not** chart the trend (sparkline). The arrow + delta is the v1 representation.
- **Do not** add this feature to the home `CompactRiskCard`. Different surface, different purpose.

## Reporting

When done, report:

1. Files modified.
2. The exact name and signature of the history-fetching method you used (`fetchRiskHistory(coin:days:)` or whatever the real one is called).
3. Total load time for 41 coins on first open (rough estimate).
4. Whether any coin returned insufficient history for the 30-day window — list those tickers in your report.
5. Screenshot of the screen with both bands and trend indicators visible.

Keep the report under 250 words.
