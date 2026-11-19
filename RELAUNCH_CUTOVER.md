# Arkline Paid Relaunch — Cutover Runbook

Status as of 2026-11-19. Target go-live: beginning of 2027.

Everything below is **prepared but not live**. The iOS side is gated behind
`paidModeEnabled = false`; the web/Stripe changes are staged in code but not
deployed. Nothing charges anyone until the explicit cutover steps are run.

---

## Pricing (final)

| Plan | Price | Apple product ID | Stripe price ID | RevenueCat offering |
|------|-------|------------------|-----------------|---------------------|
| Standard Monthly | $69.99/mo | `com.arkline.app.pro.monthly` | `price_1TXCPTPHuageZ7zbCrDoFlRO` | `default` |
| Standard Annual | $699/yr | `com.arkline.app.pro.annual` | `price_1UdUlxPHuageZ7zbkgyVJ7f5` (new) | `default` |
| Founding Monthly | $39.99/mo | `com.arkline.app.founding.monthly` | `price_1TXCJyPHuageZ7zbIGTJCHPl` | `founding` |
| Founding Annual | $399.99/yr | `com.arkline.app.founding.annual` | `price_1UdUnGPHuageZ7zbdLqwrlkW` (new) | `founding` |

Trial: **14-day free trial on Standard only** (new users). Founding members
(existing users) are grandfathered into discounted pricing with no extra trial.

### Grandfathering model (decided 2026-11-19 — charging starts now, not Jan 1)

- **New members** pay Standard ($69.99 / $699, 14-day trial) as soon as the gate
  is live (web immediately; iOS once the build + products clear Apple review).
- **Founding cohort** = the **10 accounts active within 14 days** before relaunch,
  snapshotted now via the `profiles.is_founding_member` flag. They keep **free
  access through 2027-01-01** (grace enforced in the `is_user_subscribed` RPC),
  then subscribe at the **$39.99 founding rate**.
- **Dormant old accounts** are treated as new users (Standard pricing).

Old Stripe prices to **archive at cutover** (replaced by the new ones above):
- Standard Annual $700 — `prod_UWEug5vuKr5A5x`'s original $700 price
- Founding Annual $400 — `price_1TXCOPPHuageZ7zb7d2HyeHc`

(0 active subscriptions on either, so archiving is safe.)

---

## DONE (staged / configured, not yet live)

**App Store Connect**
- Created Standard Monthly ($69.99) + Standard Annual ($699) auto-renewable subs,
  each with a 14-day free introductory offer, display name "Arkline Pro".
- Founding Monthly/Annual already existed and are Approved.
- ⚠️ Still needs a **review screenshot** on each new product before it can be
  submitted with the next build (needs an image of the running paywall).

**RevenueCat**
- Imported both new products, attached to the "Arkline Pro" entitlement.
- `default` offering → new Standard products; `founding` offering → founding products.
- Paywall "ArkLine Pro Paywall" (default) fixed: title "Unlock Arkline Pro",
  "2 weeks free" copy — published. Discount badge is dynamic (auto-calculates ~17%).
- Duplicated paywall "Arkline Pro Paywall (Founding)" attached to `founding` — published.

**Supabase DB (APPLIED live now — safe, since the iOS gate is still off)**
- Added `profiles.is_founding_member` boolean.
- Stamped it `true` for the 10 accounts active within 14 days (snapshot cohort).
- Updated `is_user_subscribed` RPC: founding members count as subscribed (free)
  until 2027-01-01, then fall through to the paywall.

**iOS app code** (in `/Users/matt/Arkline/ArkLine`, no new files → no xcodegen needed)
- `Constants.RevenueCat`: `foundingOfferingIdentifier = "founding"` (the old
  `foundingCutoffDate` was removed — membership is now the server flag).
- `User.isFoundingMember` is now a stored field decoded from the
  `is_founding_member` profile column (threaded through `ProfileDTO` and the
  three User-build sites: ArkLineApp, AuthViewModel, OnboardingViewModel).
- `RevenueCatService.paywallOffering(foundingMember:)` picks founding vs default.
- `ArkPaywallSheet` resolves and presents the right offering.
- Call sites wired: `ProGate`, `SubscriptionExpiredView` (use currentUser flag),
  `PaywallStepView` (new signup → always Standard; also fixed "7-day"→"2-week" copy).

**Stripe dashboard**
- Created the new $699 standard-annual and $399.99 founding-annual prices
  (lookup keys `standard_annual`, `founding_annual`). Old prices left active for now.

**Supabase edge functions** (staged in repo, NOT deployed)
- `create-self-checkout`: added standard price IDs, 14-day trial (standard only),
  new founding-annual ID.
- `create-checkout-session`: updated founding-annual ID.
- `stripe-webhook`: added new founding-annual ID to the tier-labeling set
  (kept the legacy $400 ID for historical subs).

**Web frontend** (staged in repo, NOT deployed) — decisions: Standard-only
public pricing, founding = existing users only, founding-spots angle retired.
- `web/src/lib/pricing.ts`: `TRIAL_DAYS` → 14; Standard is now primary
  ($69.99 / $699); founding kept as grandfathered reference ($39.99 / $399.99);
  `TRIAL_COPY` now references standard $69.99; removed dead `foundingSpots`.
- `web/src/lib/onboarding/config.ts`: `PRICE_IDS` now has standard + founding
  (new IDs); `PAYMENT_PLANS` (new-signup selector) switched to Standard only.
- `web/src/app/(marketing)/page.tsx` + `pricing/page.tsx`: full free→paid copy
  rewrite (hero, pricing card, FAQ, CTAs) — now "$69.99/mo, 14-day free trial";
  prices pull from `pricing.ts`. Founding is NOT advertised publicly (existing
  users only, per decision).

---

## CUTOVER STEPS (run at go-live)

1. **Deploy edge functions**
   `supabase functions deploy create-self-checkout`
   `supabase functions deploy create-checkout-session`
   `supabase functions deploy stripe-webhook`
2. **Deploy web** (Vercel Git auto-deploy on push, Root Directory = web).
3. **Archive old Stripe prices** (Standard Annual $700, Founding Annual $400)
   in the Stripe dashboard.
4. **Flip iOS paid mode**: set `paidModeEnabled = true` in `ArkLineApp.swift`
   (AppState), run `xcodegen generate`, bump version, build.
5. **Add the paywall review screenshots** to the two new App Store products,
   then submit the build for review (products are reviewed with the app).
6. Verify a real purchase on both Standard and Founding paths (sandbox first).

---

## STILL NEEDS YOU

1. **Review screenshots** for the two new App Store products — best captured once
   Apple approves them so they show real $69.99/$699 pricing. To grab them now:
   run the app with the DEBUG `debugForceFree` toggle on to force the paywall,
   screenshot it, and add it to each product in App Store Connect.
2. **Read the marketing copy** — the free→paid rewrite is done and staged, but
   give it a pass to make sure the wording sounds like you before it deploys.
