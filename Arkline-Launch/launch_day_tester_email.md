# Launch Day: Tester Thank-You Email

**When to send:** Right after you hit "Release This Version" in App Store Connect (or within an hour of the app going live).

**Send to (3 TestFlight testers):**
- dakota.c.scott@gmail.com
- ravi.lokhai1@gmail.com
- nxa.crypto@pm.me

**Comp status:** All three already have 3-month Founding Pro entitlements in Supabase (`source='comp'`, `current_period_end = 2026-10-24`). They will bypass the paywall automatically when they sign in on the App Store version — no code to redeem.

---

## Subject line

`ArkLine is live — and your first 3 months are on me`

## Body

Hey —

Quick one. ArkLine is officially live on the App Store today.

**Download it here →** https://apps.apple.com/app/arkline-market-intelligence/id6760355430

Big thanks for testing over the last few weeks. You helped catch bugs and shape the product before it was ready for the world. As a thank you, **your first 3 months of ArkLine Pro are on me** — no code to enter, nothing to do. Just sign in with the same email you used in TestFlight and you're good.

Two things:

1. Delete the TestFlight version of ArkLine from your device
2. Download the App Store version and sign in with the same email

Your data is intact — portfolios, DCA settings, everything you had in TestFlight is still there. Nothing to migrate.

Truly grateful. Reply anytime — this comes to me directly.

— Matt

---

## Notes

- Send from your personal email (mneal.jw@gmail.com) or matt@arkline.io — do not send from a marketing automation tool. This should feel personal.
- Optional: personalize the greeting ("Hey Dakota —") if you want to spend the extra minute.
- Their comp expires 2026-10-24. If you want to extend, run a manual UPDATE on `public.subscriptions` for those user_ids.
