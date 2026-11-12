# Arkline 1.3.0 (111) — App Store Submission Kit

The "free Arkline" release. Everything below is copy-paste ready for App Store Connect.

---

## 1. Version — DONE in code
- `MARKETING_VERSION` → **1.3.0**, `CURRENT_PROJECT_VERSION` → **111** (set in `ArkLine/project.yml`).
- ⚠️ **Regenerate the project before archiving** so the new version reaches the build settings:
  ```bash
  cd ~/Arkline/ArkLine
  xcodegen generate
  ```
  Then open in Xcode, select a Release/"Any iOS Device" destination, and **Product → Archive**. Confirm the Organizer shows **1.3.0 (111)**.

---

## 2. Pricing (App Store Connect → Pricing and Availability)
- Set the app price to **Free** (was paid/invite).
- Existing IAP subscription products can stay configured — nothing in the app depends on them anymore, so they simply won't be exercised. No need to delete them (keeps the plumbing for re-introducing paid later).

---

## 3. What's New in This Version  *(paste into the version's release-notes field)*

Arkline is now free. Every feature — market signals, model portfolios, DCA tools, and insights — is open to everyone, no subscription and no invite code required.

New in this version:
• Brent crude oil in Traditional Markets, alongside WTI and the major indices
• Learn: guided trails on crypto and traditional markets, plus a built-in dictionary for terms throughout the app
• Budget calculator to plan contributions and hand them straight off to DCA reminders
• Tap any holding for a full breakdown — entry price, cost basis, and time-range performance
• Faster, more reliable market and portfolio data

Thanks for being here early. Send feedback anytime from Settings.

---

## 4. App Review Information → Notes  *(paste as-is, then fill the demo credentials)*

Arkline is now a free app. There is no paywall, subscription gate, or invite code — a new user signs up with their email and immediately has full access to every feature.

Sign-up normally uses a one-time email code, which isn't practical for review. Please sign in with the demo account below using the "Sign In" option on the welcome screen (email + password):

  Email:    __________________________
  Password: __________________________

Additional notes:
• The app still contains RevenueCat/StoreKit code from when Arkline offered a subscription. It is dormant — no purchase, upgrade, or paywall UI is presented anywhere, and no feature depends on a subscription. "Restore Purchases" remains in Settings per Guideline 3.1.1 so any prior purchaser can recover entitlement on a new device.
• Content is intended for users 18+. Arkline provides market information and educational tools, not personalized investment advice.
• Some admin-only screens exist for the operator account and are not reachable by a normal user account.

---

## 5. App Review Information → Sign-In
- **Sign-in required: YES**
- Provide the demo email + password from section 4.
- ⚠️ **The demo account must have a password.** Accounts created through the app's normal email-code flow are passwordless, so the password Sign-In path won't work for them. Create the demo user with a password first:
  - Supabase → Authentication → Users → **Add user** → set email + password (auto-confirm).
  - Then open the app once and sign in with it, or confirm a `profiles` row exists for that user, so it lands on the home screen cleanly.

---

## 6. Pre-submission checklist
- [ ] `xcodegen generate` in `~/Arkline/ArkLine`, then Archive — Organizer shows **1.3.0 (111)**
- [ ] **On-device fresh-signup test**: brand-new email → lands on home with full access, no paywall, no invite prompt
- [ ] Demo account created **with a password** and verified it signs in via the "Sign In" path
- [ ] Demo email + password pasted into Review Notes; **Sign-in required = Yes**
- [ ] App price set to **Free**
- [ ] "What's New" pasted into the version
- [ ] Screenshots still representative — none show a subscribe/pricing/paywall screen (swap any that do)
- [ ] Build attached to the 1.3.0 version in App Store Connect
- [ ] Submit for review

---

## 7. Likely review question, pre-answered
**"You have subscription code but the app is free / we can't find the purchase."** — Covered in the Review Notes: the billing code is intentionally dormant, nothing gates on it, and no purchase UI is shown. If a reviewer pushes, the honest one-liner is: *Arkline moved to a free model this release; the subscription infrastructure remains in the binary but is not user-reachable.*
