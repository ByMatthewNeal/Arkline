# Arkline — IAP Implementation Plan

**Created:** 2026-06-15
**Reason:** Apple rejected the 3.1.3(a) reader-app argument under Guideline 3.1.1. The path to App Store approval requires implementing In-App Purchase. This plan brings the app back into compliance while preserving the web/Stripe path for invited members.

---

## North star

**Two payment paths, one product:**

- **Web (arkline.io → Stripe):** Invited members + organic web traffic. **0% Apple commission.** This is your primary funnel and stays unchanged.
- **iOS (App Store IAP):** App Store discoveries who land in the app without an existing account. **15% Apple commission via Small Business Program.**

Both paths feed the same Supabase user account. The iOS app doesn't know or care which path a user used — it just checks Supabase for `subscription_status = active`.

---

## Key decisions locked in

| Decision | Choice | Reasoning |
| --- | --- | --- |
| **IAP framework** | RevenueCat | Cuts engineering time by 60-70% vs raw StoreKit 2. Free under $2.5K MRR. We removed it 6 weeks ago; re-adding is mostly reverting a known-good state. |
| **Apple commission tier** | Small Business Program (15%) | Under $1M annual proceeds → 15% from day 1, not 30%. Free to enroll. |
| **Pricing parity** | Same price on iOS and web ($39.99/mo Founding) | Anti-steering rules don't require parity, but it's customer-friendly and simpler to operate. You absorb the 15% on App Store-acquired customers — but Stripe customers are still 0%. |
| **Products at launch** | Founding monthly + Founding annual | Mirror what's on arkline.io for the current launch window. Add Standard tier when Founding sells out. |

---

## Phases

### Phase 1: Setup (Days 1-2)

Most of this is forms and configuration, not engineering. Knock it out first to unblock everything else.

- [ ] **Enroll in Apple Small Business Program**
  - URL: developer.apple.com/app-store/small-business-program/
  - Requires: agreeing you'll be under $1M proceeds in 2026
  - Approval: 1-3 business days
  - Effective: from approval date
- [ ] **Sign Paid Applications Agreement** in App Store Connect → Agreements, Tax, and Banking
  - You currently have only Free Apps Agreement (since no IAP). Need to sign Paid Applications Agreement now.
- [ ] **Submit tax + banking info** for payouts
  - W-9 for Arkline Technologies LLC (you already have EIN)
  - US bank account info for ACH payouts
- [ ] **Create RevenueCat account** at app.revenuecat.com
  - Connect Apple Developer account
  - Connect Stripe (optional but recommended — lets RevenueCat track both payment paths for analytics)
- [ ] **Create subscription products in App Store Connect**
  - Navigate to: Apps → Arkline → Monetization → Subscriptions
  - Create subscription group: "Arkline Pro"
  - Create products:
    - `com.arkline.app.founding.monthly` — Arkline Founding Member (Monthly) — $39.99/mo
    - `com.arkline.app.founding.annual` — Arkline Founding Member (Annual) — $399/year (matches web)
  - Fill in localized display names + descriptions
  - Submit for review (separate from app review — usually fast)
- [ ] **Wire RevenueCat to App Store Connect**
  - Generate App Store Connect Shared Secret in App Store Connect → My Apps → Arkline → App Information → App-Specific Shared Secret
  - Paste into RevenueCat → Project Settings → Apple App Store
  - Create "Entitlements" in RevenueCat: `pro` (granted by any active subscription product)
  - Create "Offerings" in RevenueCat: `default` (contains both monthly + annual packages)

---

### Phase 2: Backend (Days 3-5)

Get Supabase ready to track subscriptions from two sources.

- [ ] **Schema migration**
  - Add columns to `users` (or wherever subscription is tracked):
    - `subscription_source` text — values: `'stripe' | 'apple' | null`
    - `apple_original_transaction_id` text — Apple's stable subscription identifier
    - `apple_product_id` text — which IAP product
    - `subscription_status` text — `'active' | 'trialing' | 'past_due' | 'canceled' | 'expired'`
    - `current_period_end` timestamp
  - Write migration SQL
- [ ] **Webhook endpoint: Apple App Store Server Notifications V2**
  - New Supabase Edge Function: `apple-subscription-webhook`
  - Verifies Apple's signed JWS notification
  - Parses notification type: `SUBSCRIBED`, `DID_RENEW`, `DID_CHANGE_RENEWAL_STATUS`, `EXPIRED`, `REFUND`, etc.
  - Updates user's subscription_status in Supabase
  - Register endpoint URL in App Store Connect → App Information → App Store Server Notifications
- [ ] **Webhook endpoint: RevenueCat (alternative to Apple direct)**
  - If using RevenueCat, you can let RevenueCat handle Apple's notification firehose and forward simplified webhooks to you
  - New Supabase Edge Function: `revenuecat-webhook`
  - Simpler than direct Apple webhooks — RevenueCat normalizes the events
  - **Recommended over direct Apple webhooks** for speed
- [ ] **Unified subscription check helper**
  - Create RPC: `is_user_subscribed(user_id)` that returns true if EITHER stripe_status='active' OR apple_status='active'
  - iOS app calls this on launch to decide: show app vs show paywall

---

### Phase 3: iOS implementation (Days 5-10)

The bulk of the engineering work. Revives code we deleted in commit `54a3a38`.

- [ ] **Re-add RevenueCat + RevenueCatUI packages** to Xcode project
  - Same packages we removed
  - Configure with new RevenueCat public API key in `Constants.swift`
- [ ] **Initialize RevenueCat on app launch**
  - In `ArkLineApp.swift` (or wherever the app initializes services)
  - Set anonymous user ID first, then log in with Supabase user ID after auth
- [ ] **Build the paywall screen**
  - Use RevenueCatUI's `PaywallView` (out-of-the-box) OR build custom SwiftUI screen
  - Shows: Founding tier monthly + annual options
  - "Subscribe" → RevenueCat purchase flow → Apple Pay sheet
  - On success: navigate user into the app
  - On failure: show error, allow retry
- [ ] **Update app launch flow**
  - Current state: Welcome carousel → Sign In screen → app
  - New state: Welcome carousel → choose path:
    - "I already have an account" → Sign In (unchanged)
    - "Get Arkline Pro" → Paywall → IAP → account creation → app
  - Update `ContentView` / `AuthenticationView` / wherever the entry routing is
- [ ] **Account creation on IAP purchase**
  - After successful IAP, prompt user to create an email/password account
  - This account links to their apple_original_transaction_id in Supabase
  - User can then sign in on other devices using email/password
- [ ] **Restore Purchases**
  - Required by Apple — must be discoverable from the paywall
  - "Restore Purchases" button → RevenueCat `restorePurchases()` → updates subscription status
- [ ] **Subscription management**
  - In Settings tab, add "Manage Subscription" row
  - For Apple subscribers: links to `https://apps.apple.com/account/subscriptions` (or uses `Linking` to deep-link)
  - For Stripe subscribers: shows "Manage at arkline.io" — actually this might violate anti-steering. **TODO: verify Apple's allowed phrasing for cross-platform subscription management.**
- [ ] **Re-add `isPro` gating where it makes sense**
  - Currently hardcoded `true` — we removed the gating
  - Decide: do you want to gate ANY features for free-tier discovery, or keep "every authenticated user is pro"?
  - **Recommendation: keep "every authenticated user is pro" — there is no free tier.** Don't introduce gating that doesn't exist in the business model.

---

### Phase 4: Testing (Days 10-12)

- [ ] **Set up Apple Sandbox tester accounts**
  - App Store Connect → Users and Access → Sandbox Testers
  - Create 2-3 fake Apple IDs for testing (e.g., reviewer-sandbox@arkline.io)
- [ ] **Test happy path** on a real device (sandbox doesn't work in simulator for IAP)
  - Fresh install → onboarding → paywall → purchase → land in app
- [ ] **Test Restore Purchases** — buy, delete app, reinstall, restore
- [ ] **Test cancellation** — buy, cancel from sandbox Settings, verify status updates
- [ ] **Test renewal** — sandbox renews every few minutes; verify webhooks fire
- [ ] **Test refund** — request refund in sandbox, verify subscription_status updates
- [ ] **Test cross-device** — buy on iPhone, restore on iPad with same Apple ID
- [ ] **Test web-Stripe customer signing in to iOS app** — make sure invited members can still use the app without going through IAP
- [ ] **Anti-steering audit**
  - Walk through every screen
  - Make sure no language directs users to arkline.io for cheaper subscription
  - No "subscribe at our website" buttons
  - No price comparisons
  - The website mention in App Store description is fine (just informational)
- [ ] **TestFlight beta** — distribute to your 7 active testers, get feedback
- [ ] **Update App Review notes** — remove the 3.1.3(a) argument, replace with simple IAP explanation

---

### Phase 5: Submission (Days 12-14)

- [ ] **Bump build version** (Info.plist `CFBundleVersion` 100 → 101; CURRENT_PROJECT_VERSION in pbxproj too)
- [ ] **Archive build in Xcode**, validate, upload to App Store Connect
- [ ] **Attach new build to 1.0 version**
- [ ] **Update App Review notes** (clean, simple — IAP is now in place)
- [ ] **Verify app metadata** — can now mention pricing in description since IAP exists (or keep it out for cleaner messaging)
- [ ] **Submit for review**
- [ ] **Expected outcome:** approval within 24-48 hours

---

## Risks & open questions

**Risk: Subscription product approval delay.** Apple reviews subscription products separately from the app itself. First-time IAP products sometimes get held in metadata review. Mitigation: submit products as early as possible in Phase 1, even before the app code is ready.

**Risk: Anti-steering Settings UI.** The "Manage Subscription" row needs careful wording. For Apple subscribers, easy (deep-link to Apple). For Stripe subscribers, we need a non-violating way to say "manage at arkline.io." **Action: research Apple's allowed phrasing for cross-platform subscription management before building this UI.**

**Risk: User confusion at sign-in vs subscribe path.** Some users may try to sign in with credentials they don't have, get confused. **Mitigation: make the "Get Arkline Pro" CTA the primary one, "I already have an account" secondary.**

**Open question: existing Stripe customers — do we migrate them to Apple IAP?** No. They stay on Stripe forever (0% Apple cut). New iOS-acquired users are the only ones using IAP. The two systems run in parallel indefinitely.

**Open question: paywall pricing visibility.** Apple lets you show pricing in the paywall (you have IAP now), but you need to localize correctly using `StoreKit.Product.displayPrice`. Easy with RevenueCatUI.

---

## Timeline summary

| Phase | Days | Status |
| --- | --- | --- |
| 1. Setup (forms + Apple config) | 1-2 | Not started |
| 2. Backend (Supabase + webhooks) | 3-5 | Not started |
| 3. iOS implementation | 5-10 | Not started |
| 4. Testing | 10-12 | Not started |
| 5. Submission | 12-14 | Not started |

**Total: ~2 weeks of focused work.** Could be faster with heavy Cursor use, or if you parallelize Phase 1 (waiting on Apple approvals anyway) with Phase 2 backend work.

**Realistic launch:** Late June / early July 2026 (vs. the late May target — but we end up with a more durable foundation).

---

## What stays the same

- **Web/Stripe flow is unchanged.** Invited members continue to sign up at arkline.io, pay via Stripe, get credentials emailed, sign in to the app. Their flow is identical.
- **Existing app architecture, navigation, and design.** Only adds an IAP entry point — doesn't rewire anything.
- **Founding member tier limits (150 spots).** Counts both Stripe + IAP toward the 150 cap.
- **Apple Developer Program enrollment, LLC, all legal docs.** Already done. No changes.

---

## What's different vs. before

- **iOS app is no longer login-only.** It now has a paywall path for App Store discoveries.
- **You're now collecting payments through Apple (for iOS-acquired customers only).**
- **Supabase tracks two subscription sources.** Status reconciliation logic across both.
- **Two webhook endpoints to monitor** (or one if going RevenueCat).
- **Apple deposits monthly payouts to your bank** (Arkline Technologies LLC). Separate from Stripe payouts.

---

## Decision points still open

1. **RevenueCat vs raw StoreKit 2** — strong recommendation: RevenueCat. Confirm before starting Phase 1.
2. **Pricing parity vs higher iOS pricing** — strong recommendation: parity. Confirm before creating products in App Store Connect.
3. **Manage Subscription wording for cross-platform users** — research needed before Phase 3.
4. **Free trial?** — Apple supports free trials. We don't currently offer one on Stripe. Decide: match Stripe (no trial) or offer 7-day trial on iOS for conversion?

---

## Next action

Phase 1 step 1: **Enroll in Apple Small Business Program.** 5 minutes. Doesn't require any other prereqs. Do this first.
