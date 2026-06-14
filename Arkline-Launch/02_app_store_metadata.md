# Arkline — App Store Metadata (Unlisted, Invite-Only)

**Last updated:** 2026-04-30
**Distribution:** Unlisted — invite-only via Stripe on web

This metadata is written for an Unlisted, invite-only app. Two important constraints shaped the copy:

1. **No pricing language anywhere.** Apple guideline 3.1.3 forbids referencing prices, subscriptions, or upgrade paths in App Store copy when the app has no IAP. Pricing lives entirely on arkline.io.
2. **No "subscribe" / "upgrade" / "buy" CTAs.** Same reason. The App Store description describes what the app does, not how to pay for it.

Even though the app is unlisted (not searchable), the metadata still needs to satisfy review. Reviewers read it.

---

## App Name (30 char max)

**Arkline: Market Intelligence** (28 chars). ✅ Already set in App Store Connect — keep.

---

## Subtitle (30 char max)

| Option | Chars | Notes |
| --- | --- | --- |
| **Crypto risk & macro signals** | 29 | ✅ Recommended. Describes the differentiator without any "Pro" or "Premium" language. |
| Smart crypto portfolio tracker | 30 | Generic; doesn't capture what's distinctive. |
| Risk scoring for crypto investors | — | 33 chars, too long. |

---

## Promotional Text (170 char max)

Promotional text can be edited any time without re-submitting. Use it to surface what's new or what's in the latest briefings. **Do NOT use it for pricing or membership pitches** — that's pricing language Apple won't allow.

**Recommended:**

> Real-time risk scoring, macro regime detection, and twice-daily AI briefings — all in one app, built for investors who want signal, not noise.
>
> *(141 chars)*

**Alternate (timely):**

> New: morning + evening AI briefings now include personalized portfolio impact analysis and macro regime detection across VIX, DXY, and global liquidity.
>
> *(154 chars)*

---

## Description (4000 char max)

Apple weighs the **first 1–3 lines** heavily — that's all most users see before tapping "more". Note: zero pricing references, zero "subscribe" CTAs.

```
The market rewards the informed.

Arkline puts institutional-grade market intelligence in your pocket — risk scoring, macro signals, AI briefings, and smart DCA — designed for crypto-first investors who are tired of YouTube guesses and Twitter noise.

WHAT ARKLINE DOES

Portfolio Tracking
Track crypto, stocks, and custom assets in one view. Live pricing, P&L breakdowns, allocation charts, and performance against the signals the app gives you. 20,000+ assets supported.

Risk Scoring
Arkline's proprietary 8-factor risk model combines on-chain, technical, sentiment, and macro data into a single 0–1 score. Know where you are in the cycle — at a glance — and use that score to guide your DCA, your sizing, and your patience.

Market Analysis
Live sentiment gauges, altcoin season index, ETF flows, derivatives data, liquidation tracking, and a top-coin screener. The full picture, not just prices.

AI Briefings
Morning and evening summaries powered by AI — distilling overnight prices, sentiment shifts, macro moves, and your portfolio impact into a clear read. One briefing. Full clarity.

Smart DCA
Set time-based DCA reminders, or let Arkline trigger them when the risk score drops below your threshold. Buy more aggressively when conditions are favorable; hold back when the market is overheated. Discipline by design.

Macro Dashboard
VIX, DXY, WTI Crude, US Net Liquidity, Global M2, Fed Watch probabilities — with sparklines, z-scores, and regime detection. The same indicators institutional desks watch, without the Bloomberg terminal.

WHY ARKLINE

Most retail investors learn crypto from sources that profit from attention, not from being right. The people who actually build wealth in this market read risk models, track macro regimes, and watch sentiment data that retail rarely sees.

Arkline closes that gap.

ACCESS

Arkline is an invite-only application for our founding-member program. To request access, visit arkline.io.

PRIVACY & SECURITY

Built financial-app first. End-to-end encrypted credentials, Supabase backend with row-level security, Keychain storage for sensitive data, SSL certificate pinning, PBKDF2-hashed passcodes, and a 12-point internal security audit. Your portfolio data is yours.

NOT INVESTMENT ADVICE

Arkline provides analytical tools and educational content. It is not a registered investment advisor and does not provide personalized financial recommendations. Always do your own research.

—

Built by an investor who spent years looking for this tool — then built it.
```

*(approx. 2,165 chars)*

> **Note on the "ACCESS" paragraph:** This is the closest the description gets to pointing users to the website. Apple is generally fine with apps explaining how access works, as long as there's no pricing, no urgency ("limited time!"), and no language framing it as a purchase ("buy now," "subscribe today"). The phrasing above is conservative and review-safe.

---

## Keywords (100 char max, comma-separated, no spaces after commas)

Apple still indexes keywords for unlisted apps even though they don't appear in search results — they may matter if your direct link is shared and Apple shows "related apps" suggestions. More importantly, reviewers see them.

**Recommended (98 chars):**

```
bitcoin,btc,portfolio,tracker,defi,altcoin,trading,investor,dca,sentiment,fear,greed,fed,vix,dxy
```

---

## What's New (4000 char max — for v1.0)

```
Welcome to Arkline.

This is v1.0 — institutional-grade market intelligence built for retail investors who are over the noise.

In this release:
• Real-time portfolio tracking across 20,000+ assets
• 8-factor BTC risk score with historical trends
• Morning and evening AI briefings
• Macro dashboard with regime detection (VIX, DXY, WTI, M2)
• Smart DCA with risk-adjusted triggers
• Live sentiment gauges and altcoin season index

Found a bug or want a feature? Tap your profile → Send Feedback. We read everything.

— The Arkline team
```

---

## Support URL

Required. Recommended: `https://arkline.io/support` — make sure this page exists, has a contact form or email, and answers the top 5 questions (account access, data accuracy, privacy, account deletion per Apple 5.1.1(v), and supported devices).

---

## Marketing URL (optional but recommended)

`https://arkline.io`

---

## Privacy Policy URL

Required. Recommended: `https://arkline.io/privacy`. Must be a stable URL — not a Notion doc, not Google Docs.

---

## Category

- **Primary: Finance** — correct, that's where reviewers expect this app
- **Secondary: News** — recommended over Productivity. The AI Briefings + Market Analysis features map directly to News.

---

## Age Rating

Run the questionnaire honestly. Likely outcome: **17+**.

- "Unrestricted Web Access" — likely No (the app does not embed a browser or open arbitrary web content)
- "Gambling and Contests" — **No.** Apple sometimes flags crypto apps here, so be ready: clarify in App Review notes that the app does not facilitate transactions, trades, or gambling — it's analytical only.
- All others — likely No

---

## Pricing

**Set to "Free"** in App Store Connect. The app does not use IAP. All payment happens on arkline.io via Stripe, outside the App Store.

---

## Copyright

`© 2026 [Your LLC's legal name]` — fill in once the LLC is registered.

---

## App Review Notes (free text, only Apple sees) — CRITICAL FOR INVITE-ONLY

This is the most important text in your submission. Reviewers will see only a login screen unless they can use the demo account. The notes also need to head off the "we see subscription code but no IAP" question.

```
Hi review team — thanks for reviewing Arkline.

DISTRIBUTION MODEL
Arkline is an invite-only application designed for our founding-member program. Membership is sold exclusively through our website at https://arkline.io using Stripe for payment processing. The iOS app does not include any in-app purchases, subscriptions, signup flows, pricing, or upgrade prompts. There is no path inside the app to purchase, subscribe, or upgrade — those are all handled outside iOS.

Existing members sign in to access the app's analytical features. There is no free tier inside the iOS app; every authenticated user is a paid member.

NOTE ON DISTRIBUTION METHOD
This build is being submitted with "Public" selected as the App Distribution Method following a complete back-and-forth with Apple on the Unlisted distribution path:

1. The original submission (Submission ID 131e04ee-d57a-45a5-85f8-e4315183968c) was rejected on 2026-05-28 under Guideline 3.2.0 with the reviewer recommending we pursue Unlisted App Distribution.

2. We filed the per-app Unlisted App Distribution request on 2026-06-02 via developer.apple.com/contact/request/unlisted-app/.

3. On 2026-06-04, Apple App Review confirmed the path: "If you've already submitted your request for unlisted app distribution, then you should resubmit the app for review in App Store Connect if your request is approved. If you are not approved for unlisted app distribution, it would be appropriate to consider the other app distribution options described on Apple Developer."

4. On 2026-06-10, Apple Developer Support (Iskandar, case 102906056224) denied the Unlisted request. The denial email suggested either revising the concept and listing publicly, or using Custom App distribution via Apple Business / School Manager. Custom App distribution does not fit our consumer founding-member model.

Per Apple's June 4 guidance to "consider the other app distribution options" if Unlisted is denied, this build is therefore being submitted as Public. The invite-only nature of Arkline remains enforced inside the iOS app itself: there is no signup flow inside the app, so any user who acquires the app without invite-issued credentials reaches only the sign-in screen and cannot proceed to use the product.

DEMO ACCOUNT FOR REVIEW
We've created a permanent reviewer account with full member access:
  Email: reviewer@arkline.io
  Password: Reviewer2026!

The account is flagged in our backend as a permanently active member, so review will not be interrupted by trial expirations or payment issues.

SIGN-IN STEPS
  1. Launch the app. You will see a Welcome carousel.
  2. Tap "I already have an account" at the bottom of the Welcome screen.
  3. On the "Welcome back" screen, enter the email and password above.
  4. Tap "Sign In". You will be taken directly to the Home tab.

  Note: The app supports both password sign-in (recommended for review) and a passwordless email-code option. Please use the password method — the email-code path requires retrieving a verification code from the reviewer@arkline.io inbox, which is not provisioned for external access.

WALKTHROUGH ONCE SIGNED IN
  1. Home tab — current market overview, AI briefing card, BTC risk score widget, and macro dashboard
  2. Portfolio tab — demo holdings; tap any asset for risk breakdown
  3. Macro tab — VIX, DXY, WTI, US Net Liquidity, M2 with z-scores and regime detection
  4. DCA tab — configured reminders. Tap + to set up a new one.
  5. Dictionary — built-in glossary of financial and crypto terms used throughout the app
  6. Settings → no upgrade or subscription prompts; member status is read-only

ABOUT THE APP
  • AI briefings are generated using Anthropic's Claude API
  • Market data is sourced from CoinGecko, Alpha Vantage, FRED, FMP, Taapi.io, and Coinglass
  • The app is for informational and educational purposes only — it is not a registered investment advisor and does not provide personalized financial recommendations
  • Disclaimers are visible on AI briefings, the risk score, and onboarding screens
  • The app does not facilitate any cryptocurrency transactions, exchanges, or trades — it is analytical only

THIRD-PARTY SDKS
All third-party SDKs (Supabase, Kingfisher) include their own privacy manifests.

If anything is unclear, please reach us at support@arkline.io. Thank you!
```

---

## Cheat sheet: counts at a glance

| Field | Limit | Use |
| --- | --- | --- |
| Name | 30 | 28 |
| Subtitle | 30 | 29 |
| Promo text | 170 | 141 |
| Description | 4000 | ~2165 |
| Keywords | 100 | 98 |
| What's New | 4000 | ~430 |

---

## What changed vs. the previous version of this doc

The earlier draft assumed Apple IAP at $39.99/mo and $399.99/yr. Under the invite-only Stripe model, that pricing language is removed everywhere in the App Store listing. All revenue is collected outside iOS, so:

- No "Founding pricing" or "$39.99/mo" copy in promo text or description
- "ACCESS" paragraph replaces what would have been a "PRICING" paragraph
- App Review notes explicitly explain the model so reviewers don't reject for missing IAP
- App Store Connect pricing is set to "Free"
- No Paid Apps Agreement needed

## App Review Information

### Demo Account Credentials
- Email: reviewer@arkline.io
- Password: Reviewer2026!
- Full functionality enabled — permanent active member, no trial expiration.

### Review Notes for Apple
[the text we'll draft when filing for App Review]
