# Claude Code Prompt — Subscription Enforcement (Lock Out Canceled Users)

Copy everything below the `---` line and paste into Claude Code as a single prompt.

---

# Task

Add subscription enforcement to the ArkLine iOS app so users whose subscription has ended can no longer access the app's content. Today, `User.isAccessGranted` exists but is **never read as a gate** — `ContentView.swift` only checks `isOnboarded` and `isAuthenticated`, meaning a canceled user remains fully functional indefinitely after their billing period ends. This is launch-blocking: it breaks the business model (the app is the paid product) and creates Apple App Review risk.

The fix must also comply with **Apple App Store Review Guideline 3.1.2** — *"users must be able to access the content they have already paid for during the period for which they have paid."* A user who cancels mid-period (Stripe `cancel_at_period_end=true`) should retain access until `current_period_end`. Only after that timestamp should the lockout kick in.

## Background

- Business model: invite-only, web-paid (Stripe), single tier. The iOS app is a **client** to a paid service. See `CLAUDE.md` ("Business Model" section) and `memory/business-info.md` for full context.
- No StoreKit / IAP exists. **Do not add any.** Re-subscribe must be handled outside the app (web checkout, support email).
- Brand styling: **ArkLine** (capital L) = app/product name; **Arkline** (lowercase L) = legal entity, domain, copyright. Use the right spelling in the right place. UI copy uses "ArkLine."
- Admins (`user.role == .admin`) must always pass the gate regardless of subscription state — the test admin account would otherwise lock itself out the moment a webhook fires.
- A `SubscriptionBannerView` already exists for soft warnings (past_due / canceled / trialing) shown on `HomeView`. Keep it — the new full-screen lockout is for the *terminal* state after the paid period ends. Past-due users still inside their paid window get the banner, not the lockout.

## Files involved

- `ArkLine/Domain/Models/User.swift` — add `currentPeriodEnd: Date?` field, update `isAccessGranted` to honor it
- `ArkLine/Data/Supabase/SupabaseDatabase.swift` — add `currentPeriodEnd` to `ProfileDTO`
- `ArkLine/App/ArkLineApp.swift` — `refreshUserProfile()` needs to copy `currentPeriodEnd` from DTO onto `User`
- `ArkLine/App/ContentView.swift` — add lockout branch in `mainContent`
- `ArkLine/Features/Subscription/Views/SubscriptionExpiredView.swift` — **new file**, full-screen lockout UI
- `supabase/migrations/{TODAYS_DATE}_add_current_period_end_to_profiles.sql` — **new migration**, adds `current_period_end TIMESTAMPTZ` column
- `supabase/functions/stripe-webhook/index.ts` — update `syncProfileStatus()` to also write `current_period_end` from the `subscriptions` row to the `profiles` row

## Existing infrastructure to use (don't reinvent)

- `User.isAccessGranted` (User.swift:349-353) — extend this, don't create a parallel concept.
- `AppState.refreshUserProfile()` (ArkLineApp.swift:574) — already runs on app launch and on `scenePhase == .active` (line 84 via `refreshUserProfileCancellable()`). No new refresh wiring needed — just make sure the new field flows through.
- `ProfileDTO` (SupabaseDatabase.swift:380) — central place where Supabase profile rows are decoded.
- `SupabaseAuthManager.shared.signOut()` — used by Settings → Sign Out; you'll need this for the "Sign Out" button on the lockout screen so a different account can sign in.
- `ArkColors`, `ArkSpacing`, `AppFonts`, `ArkTypography` — design tokens. **Do not hardcode** colors / fonts / spacing.
- `MeshGradientBackground` (used in HomeView) — reuse for the lockout view's background so it visually feels like the app, not a system error screen.
- `Haptics.warning()` / `Haptics.light()` — haptic patterns.
- `stripe-webhook/index.ts` already has `syncProfileStatus()` (line 316) that reads `user_id` + `trial_end` from the `subscriptions` row. Extend the same query to also pull `current_period_end`, and write it to `profiles`.

## The semantics that matter

The lockout decision boils down to:

```
GRANTED if:
  role == .admin                                  // admins always in
  OR subscriptionStatus == .active                // paying
  OR subscriptionStatus == .trialing              // in trial
  OR (subscriptionStatus == .canceled AND
      currentPeriodEnd != nil AND
      currentPeriodEnd > now)                     // canceled but still inside paid window
  OR (subscriptionStatus == .pastDue AND
      currentPeriodEnd != nil AND
      currentPeriodEnd > now)                     // dunning grace — still inside paid window

LOCKED OUT if:
  None of the above
  (covers: canceled+expired, pastDue+expired, status == .none for some reason)
```

`.none` should always be locked out for non-admins — it means we have no record of payment. In practice authenticated users without a subscription record shouldn't exist (invite-redemption sets at least `pending_payment`), but defend the boundary anyway.

## Implementation steps

### 1. Add Supabase migration for `current_period_end` on `profiles`

Create a new migration file. Use today's date in `YYYYMMDD000001` format. Follow the pattern of `20260219000006_add_trial_end_to_profiles.sql`:

```sql
-- Add current_period_end to profiles for subscription enforcement.
-- iOS app reads this to determine whether to lock out canceled users
-- after their paid billing period ends (Apple guideline 3.1.2 compliance).
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS current_period_end TIMESTAMPTZ;
```

Do NOT run `supabase db push` — Matt will deploy migrations manually after review. Just create the file and tell him the deploy command at the end.

### 2. Update `stripe-webhook/index.ts` to sync `current_period_end` to profiles

In `supabase/functions/stripe-webhook/index.ts`, modify `syncProfileStatus()` (currently lines 316-336). It currently queries `subscriptions` for `user_id, trial_end`. Extend it to also read `current_period_end` and write it to the `profiles` row.

After the change, the function should:

- Read `user_id, trial_end, current_period_end` from `subscriptions`
- Always write `current_period_end` to the `profiles` update (use the value from `subscriptions`, fall back to `null` if missing)
- Keep existing `subscription_status` and `trial_end` handling intact

This means every status-change webhook (`invoice.paid`, `invoice.payment_failed`, `customer.subscription.deleted`, `customer.subscription.updated`) will keep the profile's `current_period_end` in sync without any other webhook changes.

After editing, the deployment command will be:
```
supabase functions deploy stripe-webhook --project-ref mprbbjgrshfbupheuscn --no-verify-jwt
```
Include that in your final report (don't run it).

### 3. Update `User` model

In `ArkLine/Domain/Models/User.swift`:

- Add `var currentPeriodEnd: Date?` next to `trialEnd` (around line 61).
- Add `case currentPeriodEnd = "current_period_end"` to `CodingKeys`.
- Add the corresponding `decodeIfPresent` in the custom `init(from:)` decoder (around line 112, next to `trialEnd`).
- Add the corresponding `encodeIfPresent` in `encode(to:)` (around line 138).
- Add `currentPeriodEnd: Date? = nil` parameter to the convenience `init(...)` (around line 163) and assign it in the body.
- Update the `isAccessGranted` computed property (line 349) to:

```swift
var isAccessGranted: Bool {
    // Admins always have access
    if role == .admin { return true }

    // Active or trialing subscriptions = full access
    if subscriptionStatus == .active || subscriptionStatus == .trialing {
        return true
    }

    // Canceled or past-due: honor remaining paid period (Apple guideline 3.1.2)
    if subscriptionStatus == .canceled || subscriptionStatus == .pastDue {
        if let periodEnd = currentPeriodEnd, periodEnd > Date() {
            return true
        }
    }

    return false
}
```

### 4. Update `ProfileDTO`

In `ArkLine/Data/Supabase/SupabaseDatabase.swift` (around line 380):

- Add `let currentPeriodEnd: Date?` after `trialEnd`.
- Add `case currentPeriodEnd = "current_period_end"` to `CodingKeys`.

### 5. Wire `currentPeriodEnd` through `refreshUserProfile()`

In `ArkLine/App/ArkLineApp.swift`, inside `refreshUserProfile()` (around line 607, next to `updatedUser.trialEnd = profile.trialEnd`):

```swift
updatedUser.trialEnd = profile.trialEnd
updatedUser.currentPeriodEnd = profile.currentPeriodEnd
```

Verify the cached user persisted to `UserDefaults` (the `JSONEncoder().encode(sanitized)` block lower in the function) will include the new field — it will, because `User.encode(to:)` writes `currentPeriodEnd` via `encodeIfPresent`.

### 6. Create `SubscriptionExpiredView`

New file: `ArkLine/Features/Subscription/Views/SubscriptionExpiredView.swift` (create the `Subscription/Views/` subdirectory if it doesn't exist).

Requirements:

- Full-screen, no nav bar, blocks all access.
- Visual style consistent with the rest of the app — use `MeshGradientBackground` behind it, `AppColors` / `AppFonts` / `ArkSpacing` throughout. No system gray screens.
- Centered layout: small lock-style SF Symbol icon (`lock.shield.fill` or similar) at top, headline, supporting body copy, two buttons.
- Headline: **"Your ArkLine membership has ended"**
- Body: **"Renew to continue receiving signals, briefings, and portfolio insights. Your data is safe — when you re-subscribe, everything will be right where you left it."**
- Primary button: **"Renew Subscription"** — opens `https://arkline.io/renew` via `UIApplication.shared.open(_:)`. (Matt will set up that route later; using a stable URL now means no app update is needed when the renewal page lands. **Do not** link to any Stripe URL directly — Apple's anti-steering rules + we don't want to expose Stripe Payment Link URLs publicly.)
- Secondary button: **"Sign Out"** — calls `SupabaseAuthManager.shared.signOut()` (async), then resets `AppState` via `appState.signOut()` if that exists, otherwise sets `appState.setAuthenticated(false, user: nil)`. After sign-out the user falls through to `AuthenticationCoordinator` (the existing `ContentView` gate handles this — no manual navigation needed).
- Tertiary link below: small "Need help? Contact support@arkline.io" → `mailto:support@arkline.io`.
- Use `@EnvironmentObject var appState: AppState` for sign-out wiring.
- Trigger `Haptics.warning()` in `.onAppear` so the lockout feels intentional, not a glitch.
- Add a `#Preview { SubscriptionExpiredView().environmentObject(AppState()) }` at the bottom.

**Important copy rules:**
- Never display a price.
- Never link to Stripe Checkout, App Store payment URLs, or in-app pricing.
- Don't say "upgrade" — there's only one tier; this is "renew."

### 7. Add the lockout branch to `ContentView`

In `ArkLine/App/ContentView.swift`, modify `mainContent` (lines 34-43):

```swift
@ViewBuilder
private var mainContent: some View {
    if !appState.isOnboarded {
        OnboardingCoordinator()
    } else if !appState.isAuthenticated {
        AuthenticationCoordinator()
    } else if let user = appState.currentUser, !user.isAccessGranted {
        SubscriptionExpiredView()
    } else {
        MainTabView()
    }
}
```

Order matters: onboarding gate → auth gate → subscription gate → main app. The `let user = appState.currentUser` binding ensures we don't lock out a transient state where `isAuthenticated == true` but `currentUser == nil` (e.g. mid-refresh after biometric unlock). Defaulting to "let them in" in the nil case is intentional — `refreshUserProfile()` will catch up within seconds and re-evaluate.

## Out of scope (do NOT do)

- **Do not add StoreKit, IAP, or any in-app payment UI.** Re-subscribe is web-only.
- **Do not add a "Buy now" button with pricing inside the app.** Apple anti-steering.
- **Do not modify** `HomeView`'s `SubscriptionBannerView` block — the soft banner stays for past_due / trial-ending nudges.
- **Do not gate individual features** (Insights, Portfolio, etc.) — the gate is at the app shell level, all-or-nothing.
- **Do not remove or change** the `.premium` enum case on `UserRole` — it's forward-compatible scaffolding per `CLAUDE.md`.
- **Do not change `isPro`** behavior anywhere (it's intentionally hardcoded to `true`).
- **Do not** auto-sign-out the user from the lockout view. They should remain signed in so re-subscribe + return is seamless; only the explicit "Sign Out" button signs them out.
- **Do not** run `supabase db push` or `supabase functions deploy` — Matt will run these manually.
- **Do not** touch `create-checkout-session/index.ts`, `generate-invite/index.ts`, or any other Stripe-adjacent functions — they're already correct.

## Test plan

After implementing, walk through these manually and confirm each works:

1. **Admin (mneal.jw@gmail.com):** with `subscriptionStatus = canceled` and `current_period_end = null`, signs in and lands in `MainTabView`. The home banner may show, but no lockout. (This is the regression bug Matt hit yesterday.)

2. **Active subscriber:** lands in `MainTabView`. No lockout, no banner.

3. **Canceled, period not yet ended:** `subscriptionStatus = canceled`, `current_period_end = (now + 5 days)`. User lands in `MainTabView`, sees the existing red `SubscriptionBannerView` on home, but is **not** locked out.

4. **Canceled, period ended:** `subscriptionStatus = canceled`, `current_period_end = (now - 1 day)`. User is shown `SubscriptionExpiredView`, can't reach `MainTabView`. "Sign Out" sends them back to `AuthenticationCoordinator`. "Renew Subscription" opens arkline.io/renew in Safari.

5. **Past-due (dunning):** `subscriptionStatus = past_due`, `current_period_end = (now + 2 days)`. Not locked out. Banner shown on home.

6. **Foreground refresh:** Sign in as an active user, lock the phone, manually flip the profile to `canceled` + `current_period_end = (now - 1 hour)` via Supabase SQL editor, reopen the app. On `scenePhase == .active`, `refreshUserProfileCancellable()` should fetch the new state and the `SubscriptionExpiredView` should appear within a few seconds (no app restart required). This is the critical flow — verify it.

You won't be able to execute these tests yourself in this environment. Just make sure the code paths are wired so Matt can run them.

## Reporting

When done, tell Matt:

1. The list of files created and modified.
2. The migration file path and the exact `supabase db push` / `migration up` command to run it.
3. The exact `supabase functions deploy stripe-webhook --project-ref mprbbjgrshfbupheuscn --no-verify-jwt` command.
4. A SQL snippet he can paste into the Supabase SQL editor to simulate each of the 6 test cases above by flipping his admin or a test account's `subscription_status` and `current_period_end` columns directly.
5. Any edge cases or trade-offs you encountered that Matt should know about (especially: did `AppState` have a `signOut()` method, or did you fall back to `setAuthenticated(false, user: nil)`? Did the `Subscription/Views/` directory exist?).

Keep the report tight. Matt prefers terse outputs without recap of what he already asked for.
