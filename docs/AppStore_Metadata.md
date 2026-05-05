# App Store Connect Metadata — Arkline

**Status:** Draft, ready to paste into App Store Connect once Apple Developer Program approval lands.
**Last updated:** May 4, 2026
**Strategy:** Conservative (no pricing, no external CTAs in app or metadata) — Apple's reader-app model. Lead with multi-factor risk scoring as the primary differentiator.

---

## App Information

| Field | Value | Char count |
|---|---|---|
| **App Name** (max 30) | `Arkline: Portfolio Risk Score` | 28 |
| **Subtitle** (max 30) | `Crypto, stocks & risk scoring` | 29 |
| **Bundle ID** | (whatever's already in Xcode — typically `io.arkline.app` or similar) | — |
| **SKU** | `ARKLINE-IOS-001` (your own internal ID, never shown to users) | — |
| **Primary Language** | English (U.S.) | — |
| **Primary Category** | Finance | — |
| **Secondary Category** | Productivity (or leave blank — secondary is optional) | — |
| **Copyright** | `© 2026 Arkline Technologies LLC` | — |

### Alternate App Name candidates (if first one is unavailable)

1. `Arkline: Portfolio Risk Score` (28) — recommended
2. `Arkline: Risk-Scored Investing` (30)
3. `Arkline: Smart Portfolio Risk` (29)
4. `Arkline – Portfolio Analytics` (29)

### Alternate Subtitle candidates

1. `Crypto, stocks & risk scoring` (29) — recommended
2. `Risk-scored portfolio insights` (30)
3. `Quantify risk. Invest smart.` (28)
4. `Track. Score. Invest smarter.` (29)

---

## Keywords (max 100 chars, comma-separated, NO spaces)

```
crypto,bitcoin,ethereum,investing,stocks,trading,wealth,assets,markets,DCA,rebalance,finance,risk
```

**Char count:** 99 / 100

**Keyword strategy notes:**
- Don't repeat words from the App Name or Subtitle — Apple already indexes those.
- Comma-separate, no spaces (Apple counts spaces against the limit).
- Singular forms preferred (`stock` not `stocks`) but mix where natural.
- Avoid trademarked terms (`Robinhood`, `Coinbase`, `Bloomberg`) — Apple will reject.
- Re-evaluate keywords every 4–6 weeks based on App Store Connect search analytics.

---

## Promotional Text (max 170 chars — can be updated without resubmitting the app)

```
New: Multi-factor risk scoring across crypto and stocks. See how concentrated and volatile your portfolio really is — before the market shows you.
```

**Char count:** 152 / 170

**Notes:**
- Promotional Text is shown above the description and updates without an app review. Use it for short-term news, launches, or seasonal hooks.
- Update this when you ship a notable feature or hit a milestone (e.g., "Now supporting [X]" or "v1.2 ships [Y]").

---

## Description (max 4,000 chars)

```
Arkline gives you professional-grade portfolio analytics for crypto and traditional markets — built for investors who want a data-driven edge, not gut feelings.

PORTFOLIO RISK SCORE
A single, multi-factor risk score that combines concentration, volatility, correlation, and macro exposure. Know at a glance whether your portfolio is over-extended — before the market tells you.

UNIFIED PORTFOLIO TRACKING
Track crypto, stocks, ETFs, and cash side-by-side in one clean view. Asset allocation, performance, and risk in real time. No more spreadsheets and no more juggling tabs.

AI MARKET BRIEFINGS
Personalized briefings that synthesize macro data, sentiment, and breaking news into 60-second reads. Catch up on what's moving your holdings without doom-scrolling.

DCA REMINDERS
Set dollar-cost-averaging schedules and get nudged on time, every time. Stay disciplined through volatility instead of reacting to it.

LIVE MARKET DATA
Real-time prices, charts, and indicators across crypto and traditional markets. Key macro indicators — CPI, rates, dollar index, yields — alongside your holdings, so you can read the market without leaving the app.

WHO IT'S FOR
Arkline is for investors who want institutional-quality analytics on their own portfolio. It's not a brokerage, an exchange, or a trading app. Arkline does not connect to your accounts and does not execute trades. You enter your holdings; Arkline turns them into actionable risk insight.

PRIVACY-FIRST
Your portfolio data stays yours. We don't connect to your brokerage, exchange, or bank. We don't sell your information. We don't share it for advertising.

MEMBERSHIP
Arkline is an invite-only membership platform.

—

Arkline is for informational and analytical purposes only. Nothing in this app is financial, investment, tax, or legal advice. Past performance is not indicative of future results. Investing involves risk including potential loss of principal. Always consult a licensed financial advisor before making investment decisions.

Privacy Policy: arkline.io/privacy
Terms of Service: arkline.io/terms
Support: arkline.io/contact
```

**Char count:** ~1,950 / 4,000

**Notes:**
- The triple-line break "—" is a typographic separator before the disclaimer.
- The disclaimer is mandatory for finance-vertical apps; Apple App Review specifically looks for it.
- "MEMBERSHIP — Arkline is an invite-only membership platform." is the conservative phrasing. It tells Apple this is a paid service without violating anti-steering by quoting prices or directing users to a website to subscribe. (This is the same pattern Spotify, Notion, and 1Password use.)

---

## What's New (max 4,000 chars) — for v1.0 launch

```
Welcome to Arkline.

The first release brings multi-factor portfolio risk scoring, AI market briefings, unified crypto + stocks tracking, DCA reminders, and live macro indicators to your iPhone.

Built for our Founding Member community.
```

**Char count:** ~250 / 4,000

**Notes:**
- Keep the v1.0 release notes short and warm. Save the detailed feature lists for the description.
- For subsequent versions, switch to a "what changed in this build" format: `Improved: ...`, `Fixed: ...`, `New: ...`.

---

## URLs

| Field | URL | Required? |
|---|---|---|
| **Privacy Policy URL** | `https://arkline.io/privacy` | Yes |
| **Marketing URL** | `https://arkline.io` | Optional |
| **Support URL** | `https://arkline.io/contact` | Yes |

---

## Age Rating Questionnaire

For a finance/analytics app like Arkline, the answers are typically:

| Category | Answer |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content / Nudity | None |
| Profanity / Crude Humor | None |
| Alcohol, Tobacco, or Drug Use | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Simulated Gambling | **None** (investing is NOT gambling under Apple's definition; do not check this) |
| Unrestricted Web Access | None (the app does not include an embedded browser) |
| User-Generated Content | None (Arkline does not host user-generated public content) |

**Expected rating:** 4+

---

## App Privacy ("Privacy Nutrition Label")

App Store Connect will walk you through a questionnaire about what data you collect. Below is what to declare for Arkline based on the Privacy Policy:

### Data Linked to User

These are tied to a user account / identity:

- **Contact Info → Email Address**
  Used for: App Functionality, Account Management
- **Identifiers → User ID**
  Used for: App Functionality, Account Management
- **Usage Data → Product Interaction**
  Used for: App Functionality, Analytics
- **Other Data → Other User Content** (portfolio entries, watchlists, DCA schedules)
  Used for: App Functionality
- **Purchases → Purchase History**
  Used for: App Functionality, Account Management

### Data Not Linked to User

These are anonymous / aggregate:

- **Diagnostics → Crash Data**
  Used for: App Functionality
- **Diagnostics → Performance Data**
  Used for: App Functionality, Analytics

### Data NOT Collected (do not check these)

- Financial Info (Apple's definition: payment card numbers, bank account numbers — Stripe handles these, not us)
- Health & Fitness
- Sensitive Info (race, religion, sexual orientation, etc.)
- Contacts
- Location (we use IP for security but not precise GPS)
- Biometric Identifiers
- Browsing History
- Search History
- Audio Data
- Photos or Videos (unless we add avatar uploads — TBD)
- Other Sensitive Data

### Tracking declaration

Apple will also ask: **"Does this app use third-party SDKs that track users across apps and websites owned by other companies?"**

**Answer:** No. Arkline does not include third-party tracking SDKs (e.g., Meta SDK, Google Analytics with cross-app identifiers, AdMob).

If you ever add Mixpanel, Amplitude, Sentry, or similar — re-evaluate. Most analytics SDKs do NOT trigger the "tracking" disclosure as long as data isn't linked to third-party identifiers like IDFA.

---

## Screenshots & App Preview

App Store Connect requires screenshots in specific device sizes. As of iOS 17+, only the **6.7" iPhone** size is mandatory; older sizes are auto-scaled.

| Device | Resolution (px) | Required? |
|---|---|---|
| 6.9" iPhone (16 Pro Max) | 1320 × 2868 | Recommended (newest) |
| 6.7" iPhone (15 Pro Max / 14 Pro Max) | 1290 × 2796 | **Required** |
| 6.5" iPhone (11 Pro Max / XS Max) | 1284 × 2778 | Optional (auto-scaled) |
| iPad Pro 13" (M4) | 2064 × 2752 | Required only if app supports iPad |

**Recommended count:** 5 screenshots minimum, up to 10. The first 3 show in search results — make those count.

### Suggested screenshot story (5–6 frames)

1. **Hero / Risk Score** — Show your headline feature: portfolio risk score with a clear number and breakdown. Headline overlay: "Know your real risk."
2. **Unified Portfolio View** — Crypto + stocks + cash in one screen. Headline: "All your holdings, one view."
3. **AI Briefing** — A clean briefing card. Headline: "60-second market briefings, personalized."
4. **DCA Reminder** — DCA schedule UI. Headline: "Discipline through volatility."
5. **Macro Dashboard** — Macro indicators alongside holdings. Headline: "Read the market without leaving the app."
6. *(Optional)* **Privacy** — Headline: "Your data, your device. We don't connect to your accounts."

**Screenshot tips:**
- Use overlay text for the headline so the screen contents don't have to do all the work.
- Avoid showing real personal portfolio data — use dummy data with realistic numbers.
- Match your dark mode (the website is dark) for brand consistency.

### App Preview video (optional, 15–30 seconds)

Skip for v1.0. Worth adding for a v1.1 or v1.2 once you have user testimonials and want to put effort into a polished video. Conversion lift from app preview videos is real but production cost is also real.

---

## App Review Notes (private notes for Apple reviewer)

This is a private text field App Reviewers see when reviewing your submission. Use it to head off common rejection reasons.

```
Hello App Review team,

Arkline is an informational and analytical platform for crypto and traditional-market portfolio tracking. The iOS app is a client to a paid service operated by Arkline Technologies LLC.

PURCHASE / SUBSCRIPTION MODEL
- The app does not contain any in-app purchases or subscription UI.
- The app does not include a sign-up flow; only sign-in for existing customers.
- Membership is invite-only and is provisioned outside the app. The app does not direct users to an external website to subscribe.
- This follows the same model as Spotify, Notion, and 1Password.

DEMO ACCOUNT FOR REVIEW
Username: [create a real demo account]
Password: [provide]
Invite code (if needed for first-run): [provide]

The demo account has populated portfolio data and access to all features.

NOT FINANCIAL ADVICE
Arkline is for informational purposes only. The app contains a clear "not financial advice" disclaimer in the Terms of Service (linked from the app), and the same disclosure is reinforced in the App Store description.

Thanks!
```

**Notes:**
- Always provide a working demo account. Without one, App Review almost always rejects on the first round.
- The demo account should have pre-populated data so the reviewer can see all features without setting up a portfolio.
- If you change the demo account password before each submission, note it here every time.

---

## Submission Checklist (do not submit until all checked)

### Before clicking "Submit for Review"

- [ ] Apple Developer Program enrollment is approved (needs DUNS — pending)
- [ ] App icon: 1024×1024 PNG with no transparency, no rounded corners (Apple rounds them)
- [ ] All build settings in Xcode point to release configuration
- [ ] Bundle ID matches what's set up in App Store Connect
- [ ] Version number (e.g., `1.0.0`) and Build number (e.g., `1`) set
- [ ] All metadata fields above filled in
- [ ] Screenshots uploaded (5+ for 6.7")
- [ ] Privacy Policy URL responds with 200 OK (verify on production: arkline.io/privacy)
- [ ] Terms of Service URL responds with 200 OK (verify on production: arkline.io/terms)
- [ ] Support URL responds with 200 OK
- [ ] Age rating questionnaire submitted
- [ ] App Privacy questionnaire submitted (the data nutrition label)
- [ ] Demo account created with realistic portfolio data
- [ ] App Review Notes filled in with demo creds
- [ ] Crash-tested on at least one physical iPhone
- [ ] TestFlight beta with at least 1–2 testers, no critical bugs reported
- [ ] No StoreKit / IAP code anywhere in the codebase (Apple will reject if found)
- [ ] No "Subscribe at our website" or external CTAs in the UI
- [ ] No anti-steering language (e.g., "iOS doesn't allow us to offer the best price here") — Apple bans this

### Reasonable expectations

- **Review time:** 24–48 hours for first-time submissions, sometimes faster.
- **Rejection rate:** First-time apps are rejected ~40% of the time. Don't take it personally — it's almost always a metadata or demo-account issue, not a fundamental product problem.
- **Common first-rejection reasons for finance apps:**
  - Missing or unclear "not financial advice" disclaimer
  - Demo account missing or non-functional
  - Privacy Policy doesn't match what the app actually collects
  - Inconsistent age rating
  - References to external pricing in the app or screenshots

---

## Things to do later (post-launch / v1.x)

- Localize metadata into Spanish (LATAM market for crypto is huge), German (EU regulated finance audience), and Japanese (early-adopter heavy market).
- Add an App Preview video once you have a polished v1.1 build and screenshot library.
- Add competitor keyword targeting via Apple Search Ads (paid) — works alongside organic ASO.
- Set up App Store Connect API key for automated metadata + screenshot uploads (saves time when you ship updates frequently).
