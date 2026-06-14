# Arkline — Paywall Removal Summary

**Date:** 2026-04-30
**Repo:** `~/Arkline/`

This doc records exactly what changed during the paywall removal pass. Use it as a checklist when reviewing the diff and committing.

---

## Why this work happened

The iOS app shipped with a full StoreKit + RevenueCat in-app paywall, even though the launch model is invite-only with web-based Stripe checkout. Apple's guideline 3.1.1 makes a Stripe-paywall-on-iOS submission an automatic rejection. Two safer paths existed:

- **Option A** — login-only iOS, no in-app upgrade UI, paid via Stripe on web (chosen)
- **Option B** — Apple IAP on iOS + Stripe on web (rejected: Apple takes 15–30%, you don't want that)

This pass implements Option A. The web Stripe flow + admin invite flow is untouched.

`appState.isPro` was already hardcoded to `true` before this pass (in `ArkLineApp.swift`). That meant runtime gating was already a no-op. What remained was dead paywall *code* in the binary that Apple's static analysis would have flagged. This pass removes that dead code.

---

## Files deleted (6)

```
ArkLine/Features/Settings/Views/PaywallView.swift
ArkLine/SharedComponents/Premium/PremiumFeatureGate.swift
ArkLine/SharedComponents/Premium/PremiumRequiredModifier.swift
ArkLine/SharedComponents/Premium/PremiumFeature.swift
ArkLine/Data/Services/API/SubscriptionService.swift
ArkLine/Resources/ArkLineProducts.storekit
```

The `SharedComponents/Premium/` directory itself was also removed (was empty after deletes).

---

## Xcode project changes (`ArkLine.xcodeproj/project.pbxproj`)

- Removed `PBXBuildFile` entries for the 5 deleted Swift files + `ArkLineProducts.storekit`
- Removed `PBXFileReference` entries for the 5 deleted Swift files + `ArkLineProducts.storekit`
- Removed the `Premium` group definition entirely
- Removed the `Premium` group from `SharedComponents` group children
- Removed `SubscriptionService.swift` from the `API` group children
- Removed `PaywallView.swift` from the `Settings/Views` group children
- Removed `ArkLineProducts.storekit` from the `Resources` group children
- Removed all 5 deleted files from the Sources build phase
- Removed `ArkLineProducts.storekit` from the Resources build phase
- Removed `RevenueCat in Frameworks` and `RevenueCatUI in Frameworks` from the Frameworks build phase
- Removed `RevenueCat` and `RevenueCatUI` from `packageProductDependencies` on the ArkLine target
- Removed the `purchases-ios-spm` entry from `packageReferences`
- Removed the `XCRemoteSwiftPackageReference` block for `purchases-ios-spm`
- Removed the `XCSwiftPackageProductDependency` blocks for `RevenueCat` and `RevenueCatUI`

After these edits the pbxproj is structurally sound: 1178 open braces / 1178 close braces, all `Begin/End <section>` markers paired.

---

## xcscheme change (`ArkLine.xcodeproj/xcshareddata/xcschemes/ArkLine.xcscheme`)

Removed the `<StoreKitConfigurationFileReference>` block that pointed at the deleted `ArkLineProducts.storekit`.

---

## Source-code call-site changes (12 files)

Each of these had `PaywallView`, `PremiumFeatureGate`, or `.premiumRequired(...)` references that needed to be removed. Since `appState.isPro` is hardcoded `true`, the user-visible behavior is unchanged — the deleted branches were dead at runtime.

| File | Change |
| --- | --- |
| `Features/Settings/Views/NewsTopicsSettingsView.swift` | Removed `.premiumRequired(.customNews)` modifier |
| `Features/Portfolio/Views/PerformanceView.swift` | Removed three `.premiumRequired(...)` modifiers |
| `Features/Home/Views/CustomizeHomeView.swift` | Collapsed dead `else` branches (BTC/asset gating, premium widget gating); removed two `.premiumRequired(...)` modifiers |
| `Features/PortfolioShowcase/Views/PortfolioShowcaseView.swift` | Removed `if appState.isPro / else PremiumFeatureGate` wrapper; shows content directly |
| `Features/Broadcast/Views/User/BroadcastFeedView.swift` | Same pattern — direct content |
| `Features/Home/Views/AssetTechnicalDetailSheet.swift` | Same — direct content |
| `Features/Home/Views/FlashIntelCard.swift` | Removed `showPaywall` state, paywall sheet, locked-card `else` branch, and the `lockedCard` view definition |
| `Features/Home/Views/QPSSignalChangesCard.swift` | Same pattern |
| `Features/Home/Views/MacroDashboardWidget.swift` | Removed `showPaywall` state, removed `else { PaywallView(...) }` from sheet |
| `Features/Home/Views/RiskLevelDetailView.swift` | Removed paywall sheet, `showPaywall` state, `onUpgrade`/`isPro` params from `RiskCoinPickerSheet`, "Unlock All Coins" button |
| `Features/Settings/Views/SettingsSubviews.swift` | Removed `showPaywall` state, paywall sheet, "PRO" badge UI, free-vs-pro coin gating (everyone gets all coins) |
| `Features/DCAReminder/Views/DCAListView.swift` | Removed `showPaywall` state, paywall sheet, the `count >= 3` paywall trigger (no DCA limit) |
| `Features/Market/Components/SwingSetupsSummarySection.swift` | Removed lock badge in header, `if isPro / else lockedCard`, the `lockedCard` view, conditional task |
| `Features/Market/Components/QPSGridSection.swift` | Same pattern |

---

## Constants & secrets changes

- `ArkLine/Core/Utilities/ObfuscatedSecrets.swift` — removed the `RevenueCat API Key` section (key bytes + getter)
- `ArkLine/Core/Utilities/Constants.swift` — removed `Constants.API.revenueCatAPIKey` and updated the comment to drop the RevenueCat reference

You should also remove `REVENUECAT_API_KEY` from your `Secrets.plist` if it's there, since nothing reads it anymore. (Not edited automatically — `Secrets.plist` was flagged sensitive.)

The XOR-obfuscation script that generated `ObfuscatedSecrets.swift` should also have its source-of-truth list updated so a future regen doesn't reintroduce the RevenueCat key. Look for whatever script generates `ObfuscatedSecrets.swift` (mentioned in the file's comment as "Generated from Secrets.plist — do not edit manually").

---

## What was kept intentionally

These look related but stay because they serve the post-paywall world:

- **`Domain/Models/Subscription.swift`** — Stripe subscription record from Supabase. Used for reading status (active/canceled/past_due) on the iOS side.
- **`Domain/Models/User.swift`** `SubscriptionStatus` enum + `User.subscriptionStatus` property — synced from Supabase on login. Used for status banners.
- **`SharedComponents/Misc/SubscriptionBannerView.swift`** — banners for `past_due` / `canceled` status (still useful when Stripe webhooks update Supabase). Trial banner remains too — Stripe trials still apply.
- **The whole admin Send-Invite + Stripe checkout flow** — admin-only, server-side, never user-facing. Untouched.
- **`appState.isPro = true`** — already hardcoded; left as-is. The 20 remaining `appState.isPro` references in the codebase are dead-true-path no-ops; they could be cleaned up in a future PR but are harmless.
- **The `Subscription` admin models in `Features/Admin/Models/StripePlan.swift`** — admin tooling for generating Stripe checkout links. Unrelated to paywall.

---

## Sanity checks performed

1. Grep for `PaywallView`, `PremiumFeatureGate`, `PremiumRequiredModifier`, `premiumRequired(`, `SubscriptionService`, `RevenueCat`, `ArkLineProducts.storekit`, `STRKT00`, `StoreKitConfigurationFile`, `purchases-ios-spm` — **zero matches** in `ArkLine/`
2. Grep for `^import StoreKit` and `^import RevenueCat` — **zero matches**
3. pbxproj brace balance — **balanced (1178/1178)**
4. pbxproj section markers — **all `Begin/End` pairs match**

---

## Next steps for you

In order:

1. **Open the project in Xcode.** It should open cleanly (the pbxproj edits were verified). If Xcode complains about anything, the most likely cause is a hand-typed file path I missed; check Xcode's "Issue Navigator" and ping me.
2. **Build (⌘B).** Expect zero errors. If you get errors, they'll be from:
   - A leftover `appState.isPro` reference somewhere — those should still compile (the property still exists, just always returns true)
   - A leftover `PaywallView` / `PremiumFeatureGate` / `.premiumRequired(...)` reference — let me know and I'll fix it
3. **Run on a device or simulator.** Sign in. Check that:
   - No paywall sheet appears anywhere
   - DCA can be created without limit
   - Risk Level Select View shows all coins as togglable (no PRO badges)
   - Macro Dashboard tap goes straight to detail (no paywall in between)
4. **Remove `REVENUECAT_API_KEY` from `Secrets.plist`** if present
5. **Remove the RevenueCat key from your secrets-generation script** (whatever generates `ObfuscatedSecrets.swift`)
6. **Commit.** Suggested message:

   ```
   chore: remove in-app paywall + RevenueCat for invite-only model

   Arkline ships as an Unlisted, invite-only iOS app with payment
   handled on web via Stripe. Removed all StoreKit/RevenueCat code
   so Apple's binary analysis doesn't flag missing IAP under 3.1.1.

   - Deleted PaywallView, PremiumFeatureGate, PremiumRequiredModifier,
     PremiumFeature, SubscriptionService, ArkLineProducts.storekit
   - Removed RevenueCat + RevenueCatUI package dependencies
   - Cleaned up call sites in 14 files (sheets, modifiers, lockedCard UI)
   - Removed RevenueCat API key from ObfuscatedSecrets / Constants

   appState.isPro remains hardcoded true; 20 dead-true call sites
   left for a future cleanup pass.
   ```

7. **Re-archive and upload to App Store Connect.** From this point you're ready to follow `01_launch_checklist.md` Phase 5+ (payment compliance verification → metadata → review submission with the new App Review notes from `02_app_store_metadata.md`).
