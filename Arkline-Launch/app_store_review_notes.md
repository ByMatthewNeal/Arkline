# App Store Connect Review Information

**Use this when submitting a build for App Review.** Copy-paste the sections below into the appropriate fields in App Store Connect.

---

## Reviewer Sign-In Credentials

These go in App Store Connect → My App → (build) → **App Review Information** → **Sign-In Required (toggle ON)** → **Username / Password** fields. Do NOT put these in the Notes field — they have dedicated fields.

- **Username:** `reviewer@arkline.io`
- **Password:** `Reviewer2026!`

Account is pre-activated with `subscription_status = active`, `current_period_end = 1 year from creation`, `role = user`. Reviewer will land in MainTabView on first sign-in.

If you ever change the password (e.g., security rotation), update both Supabase (`auth.users.encrypted_password` for `reviewer@arkline.io`) AND this document AND App Store Connect.

---

## Review Notes (paste into "Notes" field)

```
RESUBMISSION CONTEXT

This build addresses the previous rejection under Guideline 3.1.1
(Payments — In-App Purchase Required). We've added In-App Purchase
support via RevenueCat (StoreKit 2). Two subscription tiers are now
available in the app:

  - Arkline Founding Monthly  — com.arkline.app.founding.monthly  — $39.99/month
  - Arkline Founding Annual   — com.arkline.app.founding.annual   — $399.00/year

Both subscriptions are in the "Arkline Pro" subscription group and
have completed metadata in App Store Connect. Settings now exposes:

  - "Manage Subscription" (routes Apple-IAP subscribers to iOS Settings)
  - "Restore Purchases" (required by 3.1.1)
  - Auto-renewal disclosure footer text

We've also audited the app and removed/replaced any in-app references
that previously pointed to an external subscription page. Privacy
Policy and Terms of Service remain linked in Settings → About
(allowed under Apple guidelines).

APP OVERVIEW

ArkLine is an invite-only crypto and traditional markets intelligence
app for serious individual investors. Going forward, new users sign up
via In-App Purchase. Legacy users (pre-IAP) subscribed via Stripe on
our website and can continue to use those credentials to sign in; the
"Manage Subscription" button is source-aware and routes them to the
correct billing portal for managing their existing subscription only
(no new external purchases).

PRIMARY TESTING PATH — SIGN IN WITH REVIEWER CREDENTIALS

1. Launch the app.
2. On the Welcome screen, tap "I already have an account."
3. Enter the email and password from the Sign-In fields above.
   (These credentials have an active subscription already provisioned,
   so you can verify all app functionality without making a purchase.)
4. The app routes to the home screen (MainTabView).

SECONDARY TESTING PATH — VERIFY THE IAP PURCHASE FLOW

To verify the new IAP integration end-to-end:

1. Sign out (Settings → Sign Out) or relaunch on a fresh device.
2. On the Welcome screen, tap "Get Arkline Pro".
3. The in-app paywall (powered by RevenueCat) appears with both
   subscription tiers and real App Store pricing.
4. Select a tier and tap "Purchase".
5. Complete the sandbox transaction with your sandbox test account.
6. On successful purchase, the "Arkline Pro" entitlement is granted
   via RevenueCat. The app records the subscription in our backend
   (Supabase) via our RevenueCat webhook with source='apple'.

NOTE ON POST-PURCHASE ONBOARDING: After a successful IAP purchase, the
current build still routes new users through our legacy onboarding
(invite-code entry → email verification → profile setup). This is a
UX bridge we are actively shortening in our next release. For your
testing, the simpler path is to use the reviewer account credentials
above (primary path).

PASSWORD RECOVERY (if needed)

If the sign-in screen shows a passcode/Face ID prompt instead of
email/password fields, tap "Sign in with a different account" at the
bottom — that opens an email+password sheet. If the password ever
needs reset, tap "Forgot password?" — an email arrives within ~30
seconds from auth@arkline.io.

KEY FEATURES TO TEST (once signed in)

- Home tab: portfolio value, daily AI briefing, crypto risk levels
- Market tab: daily positioning signals, sentiment indicators
- Portfolio tab: holdings tracking, model portfolios
- Insights tab: market deck broadcasts from admin
- Profile tab: account settings, DCA reminders, Manage Subscription,
  Restore Purchases
- Crypto Risk Levels (tap "See all" from home): 41 crypto assets
  bucketed by risk band, with 7D/30D trend indicators

CONTACT

Any issues with sign-in, testing, or the IAP flow: support@arkline.io
```

---

## Pre-Submission Checklist

Before clicking "Submit for Review," verify:

- [ ] Reviewer account `subscription_status = active` in Supabase (run the SQL check below)
- [ ] Reviewer account `current_period_end > now() + 30 days` (won't expire mid-review)
- [ ] Reviewer account `role = user` (NOT admin — admin tab reveals Stripe Payment Links)
- [ ] Reviewer account has `encrypted_password` set (so password sign-in works)
- [ ] App version + build number in App Store Connect matches what you uploaded
- [ ] Privacy Policy URL (`https://arkline.io/privacy`) and Support URL (`https://arkline.io/support` or similar) filled in
- [ ] App's Privacy declarations match actual data collection (no IAP, no third-party trackers beyond Meta Pixel on web)

### Verification SQL

```sql
select id, email, role, subscription_status, current_period_end,
       (encrypted_password is not null) as has_password
from profiles p
join auth.users u using (id)
where email = 'reviewer@arkline.io';
```

Expected row:
- role: `user`
- subscription_status: `active`
- current_period_end: future date (1+ year out)
- has_password: `true`

---

## If a Review Gets Rejected

Common reasons + responses:

- **2.1 (incomplete app):** make sure reviewer account is active and all main features are reachable. Pre-populate with realistic data if needed.
- **3.1.1 (in-app purchase missing):** add to Notes explicitly: "Architecture follows reader app model. No IAP. Payments handled on web." Reference guideline 3.1.3(a).
- **5.1 (privacy):** verify in-app links to Privacy Policy + Terms (Settings → About). Also confirm App Store Connect privacy declarations are accurate.

Reply to rejections via App Store Connect → Resolution Center. Keep tone professional. Reference specific guideline clauses.

---

## Reviewer Account Setup Audit Trail

For posterity / future re-setup if needed:

- Created: 2026-05-14 (per Supabase auth.users.created_at)
- Initial `subscription_status`: set to `active` on 2026-05-17 via SQL
- `current_period_end`: set to `now() + interval '1 year'` on 2026-05-17
- `role`: changed from `premium` → `user` on 2026-05-17 (premium had risk of exposing tier-gated UI)
- Password `Reviewer2026!` set on 2026-05-17 via password recovery flow + web reset
- Account email forwards to `mneal.jw@gmail.com` via ImprovMX
