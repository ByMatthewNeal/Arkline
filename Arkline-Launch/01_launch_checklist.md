# Arkline — iOS Launch Checklist

**Last updated:** 2026-04-30
**App name:** Arkline: Market Intelligence
**Target:** iOS 17+ / macOS 14+ (Apple Silicon)
**Distribution model:** **Unlisted App Distribution** — invite-only, payment via Stripe on web

This checklist assumes the build is done and 7 TestFlight users are actively testing. Critical-path blocker is Apple Developer Program enrollment under the new LLC. The second blocker is the Unlisted App Distribution request, which Apple reviews separately from app review.

---

## Phase 0 — Critical-path: Legal & Apple enrollment

These block everything. Treat as the gating sequence.

- [ ] LLC formation complete (target: 2026-05-01)
- [ ] EIN issued for the LLC (request from IRS immediately after formation; usually same-day online for US)
- [ ] Business bank account opened in the LLC name
- [ ] D-U-N-S Number requested for the LLC at developer.apple.com/enrollment (free, 1–5 business days)
- [ ] Apple Developer Program enrollment submitted as **Organization** (not Individual) using the LLC's legal name + D-U-N-S
- [ ] Apple Developer enrollment approved ($99/year, plan for 1–7 business days)
- [ ] Existing App Store Connect record re-attached to the new org account if needed (or re-created under the org team)
- [ ] App Store Connect Agreements, Tax forms signed (note: **Paid Apps Agreement is NOT needed** since you have no IAP — the free apps agreement is sufficient)

> **Risk note:** Apple sometimes requests follow-up verification (a phone callback to the listed business number, additional D-U-N-S verification). Have the LLC's listed phone number monitored during this window. If you can't answer, enrollment stalls.

---

## Phase 1 — Identifiers, capabilities, and provisioning

- [ ] Confirm Bundle ID is registered to the org team
- [ ] App ID has the right capabilities enabled:
  - [ ] Push Notifications
  - [ ] Sign in with Apple (if used)
  - [ ] Associated Domains (for universal links to arkline.io if you do them)
  - [ ] Background Modes if needed (for price refresh / notifications)
  - [ ] **No In-App Purchase capability** — important: don't enable it, since you don't sell IAP. Adding the entitlement and not using it can trigger review questions.
- [ ] Production APNs key generated and stored in your push provider / Supabase
- [ ] Distribution certificate created in the org team
- [ ] App Store provisioning profile generated
- [ ] Build signed with the org team's distribution cert

---

## Phase 2 — Unlisted App Distribution request (do this in parallel with Phase 1)

This is the special step that makes Arkline unsearchable on the App Store. Apple reviews the request separately from regular app review.

- [ ] Submit the request at https://developer.apple.com/contact/request/unlisted-app/ — it's a small form
- [ ] Justification text — paste something like:
  > Arkline is an invite-only financial intelligence application for our founding-member program. Distribution is limited to vetted members who have completed account setup and payment through our website. The app is not designed for general public discovery, and unlisted distribution ensures it reaches only authorized users via direct link.
- [ ] Provide your Bundle ID, app name, and a one-paragraph description
- [ ] Apple typically responds in 2–10 business days
- [ ] Once approved, you'll see a "Distribution: Unlisted" toggle in App Store Connect for your app

> **Important:** The unlisted request can be filed before app review submission, but the app must be in App Store Connect with a build uploaded. Apple's reviewer for the unlisted request just confirms eligibility — they'll do a separate full review of the app when you submit it.

---

## Phase 3 — App Privacy & legal

This is where most rejections happen. Be thorough.

- [ ] Privacy Policy hosted at a stable URL (e.g. arkline.io/privacy) — required
- [ ] Terms of Service / EULA hosted (e.g. arkline.io/terms) — strongly recommended given financial subject matter
- [ ] Privacy Manifest (`PrivacyInfo.xcprivacy`) added to the app and to any third-party SDKs (Supabase, Kingfisher) that require it
- [ ] App Privacy "Nutrition Label" filled in App Store Connect:
  - [ ] Identifiers (User ID for Supabase auth)
  - [ ] Contact info (email for account creation)
  - [ ] Financial info — declare what's collected for portfolio holdings (purpose: app functionality, not tracking)
  - [ ] Usage data, diagnostics — declare any analytics
  - [ ] Confirm "data is not used for tracking" if you don't run ads
- [ ] App Tracking Transparency (ATT) — only required if you actually track across apps/websites; otherwise skip
- [ ] Required usage descriptions in Info.plist for any permission your app requests:
  - `NSCameraUsageDescription` (if scanning QR for wallets)
  - `NSFaceIDUsageDescription` (if biometric unlock)
  - Push notification rationale string
- [ ] Confirm `Secrets.plist` is git-ignored AND stripped from Release builds (your build phase script handles this)

---

## Phase 4 — Financial / regulatory disclaimers (Arkline-specific)

Apple's Section 5.2.3 and 1.4.1 reject apps that look like investment advice without proper disclaimers. Your "AI Briefings" + "Risk Scoring" features are exactly the kind of thing review pays attention to.

- [ ] Add a clear "Not investment advice" disclaimer:
  - Inside the AI Briefings feature header or footer
  - Inside Risk Scoring detail screens
  - In the onboarding flow
  - In your Terms of Service
- [ ] No promises of returns, gains, "alpha", or specific outcomes anywhere in the app or copy
- [ ] If the broadcast feature has user-generated content, add in-app reporting / blocking + EULA prohibiting objectionable content (Apple 1.2 requirement)
- [ ] Confirm the AI chat doesn't give explicit "buy/sell X" recommendations — it explains, doesn't advise

---

## Phase 5 — Payment compliance (the part that's specific to your model)

Since you're invite-only with web Stripe checkout, the iOS app must be carefully scrubbed of anything Apple could read as "selling digital subscriptions outside IAP." Done correctly, this passes review under guideline 3.1.3(d) "Free standalone apps that act as a companion to a paid web-based tool."

- [ ] **Verify the in-app paywall code is fully removed.** ✅ Done — `PaywallView`, `PremiumFeatureGate`, `PremiumRequiredModifier`, `PremiumFeature`, `SubscriptionService`, `ArkLineProducts.storekit`, RevenueCat package dependencies all removed. (See `04_paywall_removal_summary.md` for the full diff.)
- [ ] **The iOS app must NOT contain:**
  - "Subscribe" / "Upgrade" / "Buy" / "Purchase" CTAs anywhere visible to users
  - Pricing copy ($39.99/mo, $400/yr, etc.) anywhere in user-facing UI
  - Links from inside the iOS app pointing to arkline.io's pricing or signup pages (Apple 3.1.3 forbids "calls to action" pointing users to outside-iOS purchase)
  - Mentions of "Pro tier" / "Premium" / "Membership" with pricing or upgrade language
- [ ] **The iOS app CAN contain:**
  - A login screen with "Sign in" (no signup or pricing)
  - Sign-in error messages like "No account found — request an invite at arkline.io" (debatable; Apple sometimes flags even this. Safer: just "Sign in failed. Please try again or contact support.")
  - Settings → Subscription status (read-only, e.g. "Active member" / "Trial ends Jun 12") with NO upgrade button
  - A "Manage subscription" link out to arkline.io's account page IF you DON'T mention pricing or upgrade — but Apple's safest interpretation is to just remove this entirely
  - The admin-only Send Invite flow (Stripe checkout link generation) — fine because regular reviewers won't see it (gated to admin role)
- [ ] **Demo account for Apple Reviewers** — must be a real, fully-paid invitee account. If reviewers log in and the app says "trial ended" or "subscription required," they'll reject for missing functionality. Make a permanent demo account that's flagged in Supabase as an active member.
- [ ] **Walk through the app as an unauthenticated user.** Look for any string that mentions price, subscription, premium, upgrade, restore purchases, free trial. Each one is a potential rejection reason.

---

## Phase 6 — Build & metadata in App Store Connect

- [ ] Final production archive uploaded via Xcode → Organizer → Distribute App, or via Transporter
- [ ] Build appears in App Store Connect → TestFlight (10–60 minutes after upload)
- [ ] Build selected as the version to submit
- [ ] App Store metadata complete (see `02_app_store_metadata.md`)
  - [ ] Name: Arkline: Market Intelligence
  - [ ] Subtitle (30 chars)
  - [ ] Promotional text (170 chars)
  - [ ] Description (4000 chars)
  - [ ] Keywords (100 chars)
  - [ ] Support URL
  - [ ] Marketing URL (arkline.io)
  - [ ] Privacy Policy URL
- [ ] Age rating questionnaire completed
- [ ] Category: Primary = **Finance**, Secondary = **News**
- [ ] Screenshots uploaded for required device sizes (see `03_screenshots_and_assets.md`)
- [ ] App icon (1024×1024, no alpha, no rounded corners) uploaded
- [ ] Copyright field: "© 2026 [LLC name]"

> **Pricing field in App Store Connect:** Set "Free" — since the app does no IAP. Stripe handles all billing on the web side.

---

## Phase 7 — TestFlight expansion (before public submit)

- [ ] Move from internal testing (the 7 testers) to external TestFlight if you want broader pre-launch testing — invite founding-list members
- [ ] External TestFlight requires its own brief Review (~24 hours)
- [ ] Critical bugs from external testing are triaged and fixed
- [ ] Crash-free rate tracked (target ≥99.5% on the build that goes to App Review)
- [ ] One last build with all fixes uploaded; let it bake on TestFlight for 48 hours before submitting to App Review

> **Note for invite-only model:** TestFlight users don't need to be paying members yet — they can test pre-payment. Once you submit to App Review and ship, the production build only lets paid members in.

---

## Phase 8 — Submission to App Review

- [ ] Demo account credentials provided in App Review notes (Apple needs to actually log in and use the app — this is critical for an invite-only app where they otherwise see only a login screen)
- [ ] App Review notes include:
  - Disclosure that AI briefings use Anthropic's Claude API
  - Note that data sources include CoinGecko, Alpha Vantage, FRED, FMP, Taapi.io
  - Explanation that the app is for informational purposes, not investment advice
  - **A clear statement of the distribution model:** "Arkline is an invite-only application. Membership is sold and managed through our website at arkline.io via Stripe. The iOS app does not include any in-app purchases, subscriptions, or signup flows. Reviewer credentials below provide full access to a permanently active member account."
  - Steps for the reviewer: login → home dashboard → portfolio → risk score → briefing → macro dashboard → DCA reminders
- [ ] Export Compliance — most apps select "uses standard exemptions" (HTTPS only, no custom crypto)
- [ ] "Manually release this version" selected — never "automatic"
- [ ] Submitted

> **Expected timeline:** First review usually 24–48 hours. For an invite-only app, the most common rejection is reviewers being unable to use the app (so demo credentials must work). The second most common is "we see your app references subscriptions but found no in-app purchase" — your App Review notes head that off.

---

## Phase 9 — Pre-launch marketing prep (run in parallel with Phase 8)

Since the app is unlisted, "launch day" is mostly about activating the founding-member email list and getting paid invites flowing.

- [ ] Launch date picked (only after both app review approval AND unlisted distribution approval)
- [ ] Press kit assembled in `~/Documents/Arkline-Launch/press-kit/`:
  - 1-page fact sheet (description, six pillars, founder bio, contact)
  - High-res app icon
  - 5–8 hero screenshots
  - App preview video (mp4)
  - Founder headshot
  - Logo (light + dark, SVG + PNG)
- [ ] Email to waitlist drafted (T-7, T-1, launch day) — focused on "founding member access opens"
- [ ] Twitter/X launch thread drafted — emphasize the invite-only positioning ("limited to first 150 founding members")
- [ ] LinkedIn launch post drafted (you have banner assets in `social/`)
- [ ] Outreach list to crypto/fintech newsletters (Milk Road, The Defiant, Bankless, Decrypt) with personalized notes — pitch the founding-member angle
- [ ] App Store smart banner added to arkline.io once App Store URL is live (works fine for unlisted apps if you have the direct link)
- [ ] Universal Links / Associated Domains tested — important for invite emails that should deep-link into the app

---

## Phase 10 — Launch day

- [ ] Manually release the approved version in App Store Connect
- [ ] Verify the app shows up at the App Store URL (15–60 minutes after release). Note: it WON'T appear in search — that's expected for unlisted.
- [ ] Send launch email to waitlist with the direct App Store link + Stripe checkout link to claim founding-member spot
- [ ] Post launch thread on X/Twitter — emphasize "by invitation only"
- [ ] Post on LinkedIn
- [ ] Send to crypto newsletters with the live App Store link
- [ ] Monitor App Store Connect → Sales (will show 0 revenue since no IAP, but install counts work normally)
- [ ] Monitor Stripe dashboard for new founding-member checkouts
- [ ] Monitor crash reports and ratings every few hours for the first 48h
- [ ] Be ready to ship a 1.0.1 hotfix within 72h if anything obvious breaks

---

## Phase 11 — Post-launch (week 1–4)

- [ ] Respond to every App Store review (Apple penalizes apps that ignore reviews)
- [ ] Track Stripe conversion rate from email list → checkout
- [ ] Iterate the email/landing-page copy based on what converts
- [ ] Plan a 1.1 release with a "what's new" hook
- [ ] Reach out to early founding members for testimonials → use on the website + social proof section
- [ ] Once first 150 founding member spots fill, decide on next pricing tier ($69.99 standard, $99.99 future) or whether to keep going with founding pricing

---

## Common Apple rejection reasons for fintech/crypto apps under this model

- **2.1 Performance** — crashes during reviewer testing. Mitigation: bake the build on TestFlight first.
- **3.1.1 In-App Purchase** — Apple sees subscription-related code/strings and asks why there's no IAP. Mitigation: the cleanup pass we did. Plus the App Review notes explanation.
- **4.0 Design / 4.3 Spam** — looking like a clone. Your bento + macro dashboard is distinctive; lean into it in screenshots.
- **5.1.1 Privacy** — missing privacy manifest, missing usage descriptions, or unclear data collection.
- **5.2.3 Investment advice** — implying personalized financial recommendations. Mitigation: disclaimers everywhere, AI never says "buy X."
- **2.3.10 Mentioning other platforms** — no "also on Android" or "as seen on Twitter" in screenshots/copy.
- **4.2 Minimum Functionality** — for invite-only apps that show only a login screen to reviewers, this is the biggest risk. Solution: working demo credentials in App Review notes.

---

## Useful links

- App Store Connect: https://appstoreconnect.apple.com
- Apple Developer enrollment: https://developer.apple.com/programs/enroll/
- **Unlisted App Distribution request:** https://developer.apple.com/contact/request/unlisted-app/
- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Privacy Manifest reference: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- D-U-N-S Number lookup: https://developer.apple.com/enrollment/duns-lookup/
