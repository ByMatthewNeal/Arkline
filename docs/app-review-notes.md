# App Review Notes — Arkline 1.1.0 (build 107)

Paste the **Review Notes** block below into App Store Connect →
App Review Information → Notes. Fill in the password before submitting.

---

## Review Notes (paste this)

```
DEMO ACCOUNT
Email:    reviewer@arkline.io
Password: <FILL IN>

HOW TO SIGN IN
1. Launch the app and let the intro carousel appear.
2. Tap "I already have an account" (below the main button).
3. Enter the email and password above, tap "Sign In".

The demo account has a complimentary active subscription, so it goes
straight to the main app — no purchase or paywall is required to review
any feature.

ABOUT THE SUBSCRIPTION
Arkline is a single-tier subscription ("Arkline Pro", $39.99/month,
com.arkline.app.founding.monthly, with a 7-day free trial). There is no
free tier — all functionality is behind the subscription, which is why
the demo account above is provided.

Subscriptions can also be purchased on our website. Existing web
subscribers sign in with the same email and get access with no second
charge. The app contains no links or prompts directing users to the
website to subscribe.

WHAT THE APP DOES
Arkline is a market-information and research tool for cryptocurrency and
traditional markets. It provides AI-generated market briefings, price and
risk data, portfolio tracking, and configurable reminders.

It is NOT a brokerage, exchange, or trading app. It cannot execute trades,
hold funds, or connect to any exchange account. Portfolio holdings are
entered manually by the user for tracking purposes only. All market
commentary is general information, not personalized investment advice,
and is labeled as such in the app.

CONTACT
Matthew Neal — mneal.jw@gmail.com
```

---

## Pre-submission verification (done 2026-07-25)

Checked directly against Supabase and the deployed edge functions:

| Item | Status |
|---|---|
| `reviewer@arkline.io` password set in Supabase Auth | yes |
| Email confirmed | yes |
| `profiles` row exists | yes (role `user`) |
| `is_user_subscribed()` returns true | yes (active to 2027-12-31) |
| Sign-in path is email + password, no OTP required | yes — `OnboardingViewModel.signInWithPassword()` |
| Password sign-in bypasses the paywall | yes — `.paywall` is only in the sign-up branch |

The reviewer account is deliberately role `user`, not `admin`, so the
reviewer sees exactly what a paying member sees.

## Known review risks

- **Guideline 3.1.1 (IAP):** all purchasing is via RevenueCat → StoreKit.
  No external payment UI, no card entry, and no copy steering users to the
  cheaper web checkout. Anti-steering language was deliberately kept out of
  the paywall.
- **Guideline 4.8 (Login Services):** does not apply. The app offers only
  first-party email sign-in — no Google/Facebook/third-party login — so no
  Sign in with Apple equivalent is required.
- **Guideline 3.1.2 / financial content:** the app is informational only.
  Disclaimers appear on the Trade Signals list and in market commentary.
