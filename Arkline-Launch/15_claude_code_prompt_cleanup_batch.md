# Claude Code Prompt — Cleanup Batch (Renew Page Copy + Risk Screen Resilience + QPS Alt/BTC Price Hide)

Copy everything below the `---` line and paste into Claude Code as a single prompt. This is a small mixed batch — five copy fixes on the web renew page, one resilience fix on the iOS risk screen, and a tiny visual fix on the QPS positioning screen.

---

# Task

Three unrelated cleanups bundled for efficiency:

**Part A: Web /renew page copy and structure fixes** — five items found during testing of the subscription-enforcement lockout flow.

**Part B: iOS Crypto Risk Levels screen — add fetch resilience** — the screen sometimes shows "40 assets bucketed" instead of 41 because a single coin's risk fetch fails on first load. Add a single-retry and a visible "loading" state for any coin that still fails so the universe count stays correct.

**Part C: iOS QPS Daily Positioning screen — hide price on Alt/BTC pairs.** Alt/BTC pairs render as `$0.0000` because the BTC-denominated value of most alts is sub-cent. The price string is noise. Hide it for Alt/BTC; keep it for USD-denominated pairs.

The three parts touch separate files and have no dependency on each other. Do them in any order.

---

# Part A: /renew page copy fixes

## File involved

- `web/src/app/renew/page.tsx`

## Changes

### 1. Brand styling — "Arkline" → "ArkLine" (capital L)

Per the brand styling rule, "ArkLine" (capital L) is the product/app name, "Arkline" (lowercase L) is the legal entity / domain / copyright. The /renew page is product-facing UI, so it must use the capital-L form.

Two places to fix:

- Page headline: `Renew your Arkline membership` → `Renew your ArkLine membership`
- Mailto URL — the `subject` query param currently reads `Renew%20my%20Arkline%20membership`. Update to `Renew%20my%20ArkLine%20membership`.

### 2. Soften the SLA in the footer copy

Current footer text reads something like *"We typically respond within a few hours and will have you back up and running the same day."* That sets an aggressive same-day expectation that's hard to meet on weekends or holidays.

Change it to:

> Most renewals are processed within a few hours, Mon–Fri.

### 3. Add a prefilled body to the mailto URL

Currently the mailto link probably has only a `subject` param and no `body`. Add a prefilled body so users don't start from a blank email:

```
mailto:support@arkline.io
  ?subject=Renew%20my%20ArkLine%20membership
  &body=Hi%20Arkline%20team%2C%0A%0AI%27d%20like%20to%20renew%20my%20ArkLine%20membership.%20Please%20send%20me%20a%20new%20checkout%20link.%0A%0AThanks%21
```

(URL must be one line in the actual code — newlines above are for readability. URL-encoded body decodes to: *"Hi Arkline team,\n\nI'd like to renew my ArkLine membership. Please send me a new checkout link.\n\nThanks!"* — note the salutation uses "Arkline" lowercase since it's addressed to the legal entity name, while the *product* references in subject + body use "ArkLine" capital.)

### 4. Add "Already renewed? Open ArkLine →" link at the bottom

Below the existing footer text, add a small inline link:

```tsx
<a href="arkline://invite" className="...muted text styling...">
  Already renewed? Open ArkLine →
</a>
```

Style: 13px, color matching the existing muted footer text, with the "→" arrow using a unicode rightward arrow or `lucide-react`'s `ArrowRight` icon at the same baseline. This deep links into the iOS app so users who renewed and need to refresh their subscription state can get back without re-launching from their home screen.

### 5. Verify the metadata is still intact

The page should still have `robots: { index: false, follow: false }` in its metadata export — Vercel must not index the renew page.

## Part A test plan

- Run the Next.js dev server or check Vercel preview.
- Visit `/renew`.
- Headline reads "Renew your ArkLine membership."
- Footer reads "Most renewals are processed within a few hours, Mon–Fri."
- "Already renewed?" link visible at the bottom; clicking it triggers the iOS deep-link prompt (or silently fails on desktop — that's fine).
- Tap the email button: mail composer opens with `support@arkline.io`, subject "Renew my ArkLine membership", body prefilled with the greeting and message.

---

# Part B: iOS Crypto Risk Levels screen — fetch resilience

## File involved

- `ArkLine/Features/Home/ViewModels/CryptoRiskLevelsViewModel.swift` (built in prompt #12; possibly being further modified by prompt #14's trend-indicator work — if so, layer this change on top of those changes)

## Problem

The current `loadAll()` (or whatever it's called) iterates `AssetRiskConfig.cryptoConfigs` and fetches risk for each coin via `TaskGroup`. If any individual coin's fetch throws or returns nil, it's silently dropped. The user sees the subtitle showing "40 assets bucketed" instead of 41 (with `cryptoConfigs.count == 41`).

## Fix

Add two things to the per-coin fetch path inside the TaskGroup:

### 1. Single-retry with short backoff

If the first fetch throws or returns nil, wait ~500ms and try once more. Most transient API failures recover on a single retry.

```swift
private func fetchWithRetry(coin: String) async -> ITCRiskLevel? {
    if let result = try? await itcRiskService.fetchLatestRiskLevel(coin: coin) {
        return result
    }
    try? await Task.sleep(for: .milliseconds(500))
    return try? await itcRiskService.fetchLatestRiskLevel(coin: coin)
}
```

(If prompt #14 changed the fetcher to `fetchRiskHistory(coin:days:)`, wrap that one instead. Same pattern.)

### 2. Render coins with no data in a separate "Loading…" section at the bottom

If a coin's fetch is still nil after the retry, don't drop it — collect it into a separate `failedCoins: [String]` array. Render these in a new section at the very bottom of the screen titled "Loading…" with a muted-gray dot, with one row per coin showing the ticker, name, and "—" where the risk score would be.

That way:

- The total visible row count always equals `cryptoConfigs.count` (currently 41).
- Users can see which specific coins are having data issues, not just notice the count is off.
- Pull-to-refresh re-fetches everything; on a successful retry, the coin moves out of "Loading…" and into its proper band.
- The subtitle line should say "Regression model • 41 assets bucketed" — based on the catalog count, not the count of successfully-fetched coins.

## Visual spec for the "Loading…" section

- Section header: `Loading…` in muted gray (`AppColors.textSecondary`), small dot in same gray.
- Row layout identical to the other rows, but score area shows `—` in muted gray instead of a number.
- No tap behavior — these rows should be `.disabled` or have no nav action, since the detail view won't have data either.

## Part B test plan

1. Build and run.
2. Open the Crypto Risk Levels screen.
3. On a normal fetch, all 41 coins should appear in their proper bands. No "Loading…" section visible.
4. To simulate a failure, you can temporarily edit the fetcher to randomly throw for one coin (e.g. `if coin == "ATOM" { throw ... }`) and verify ATOM appears in the "Loading…" section at the bottom rather than being silently dropped.
5. Pull to refresh — if the simulated failure is removed, ATOM moves into its proper band.
6. Verify the subtitle always says "41 assets bucketed" regardless of fetch success rate.

---

---

# Part C: QPS Daily Positioning — hide price on Alt/BTC pairs

## File involved

- `ArkLine/Features/Market/Views/QPSFullGridView.swift`

## Problem

On the Daily Positioning screen, each row shows `[trend strength] · [price]` (e.g., `Weak · $0.0000` or `Building · $0.0100`). When the screen is filtered to the **Alt/BTC** category, the price is the alt's value *denominated in BTC*, which rounds to `$0.0000` for most coins (and `$0.0100` for the few worth above 0.01 BTC). It's noise — the user is looking at trend strength + the bullish/bearish badge, not a price.

For USD-denominated pairs (BTC/USD, ETH/USD, etc.) the price is still useful and should remain.

## Fix

In `QPSFullGridView.swift` around lines 143–156 (the `HStack` rendering `[trendStrengthLabel] · [price]`), conditionally hide the separator dot and the price `Text` when the signal's category is `alt_btc`.

The `DailyPositioningSignal` model has a `category: String?` field (line 63) and a parser that maps to `QPSAssetCategory.alt_btc` for tickers containing `/BTC` (line 187). Use whichever access pattern is cleanest — either `signal.category == "alt_btc"` or via the enum.

Suggested diff shape:

```swift
HStack(spacing: 4) {
    Text(trendStrengthLabel(signal.trendScore))
        .font(.system(size: 10))
        .foregroundColor(trendStrengthColor(signal.trendScore))

    if signal.category != "alt_btc" {
        Text("·")
            .font(.system(size: 10))
            .foregroundColor(AppColors.textSecondary.opacity(0.3))

        Text(formatSignalPrice(signal.price))
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(AppColors.textSecondary.opacity(0.6))
    }
}
```

(If a parsed enum like `signal.categoryEnum == .alt_btc` is already accessible, prefer that over the raw string compare.)

## Part C test plan

- Open Market tab → Daily Positioning.
- Toggle the screen into Alt/BTC mode. Verify rows now show only the trend strength label (e.g. `Weak`, `Weakening`, `Building`) with no `·` and no `$0.0000` after it.
- Toggle to a USD-denominated mode (or open the screen with a non-Alt/BTC category). Verify the price still renders normally (e.g. `Building · $2.43`).
- No other rows on the screen should change.

---

## Reporting

Combined report:

1. Files modified in Parts A, B, and C (with line ranges).
2. For Part A: paste the full final mailto URL so I can spot-check the encoding.
3. For Part B: confirmation that the failure-simulation test put a coin in the Loading section and that retry/refresh recovered it.
4. For Part C: confirmation that Alt/BTC rows no longer show the price, USD-denominated rows still do.
5. Any unexpected friction.

Keep it under 300 words.
