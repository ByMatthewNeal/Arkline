# Arkline — Screenshots & Assets Plan (Unlisted, Invite-Only)

**Last updated:** 2026-04-30

The website already has six clean app screenshots (`~/Arkline/web/public/screenshot-*.webp`): home, market, macro, portfolio, risk, analysis. These map almost 1:1 to the App Store's 10-screenshot limit.

For an unlisted, invite-only app, screenshots have a slightly different job than for a public consumer app: they're not trying to convert browsers into installers (no one is browsing — the only people seeing them got the link directly). Instead, they need to:

1. **Pass review.** Reviewers look at screenshots for misleading claims, pricing, or "subscribe" CTAs that don't match the app.
2. **Reassure invited members.** Someone who clicked your invite link wants confirmation they're getting what was promised.
3. **Look credible to anyone with the link.** Even though the app isn't searchable, prospective members will be sent the App Store URL and may judge before clicking through.

Apple still requires the same screenshot sizes for unlisted apps as listed ones.

---

## What Apple actually requires

| Asset | Size (px, portrait) | Required? |
| --- | --- | --- |
| **iPhone 6.9" display** (iPhone 17 Pro Max class) | 1290 × 2796 | ✅ Required — canonical iPhone size in 2026 |
| iPhone 6.5" display (legacy) | 1242 × 2688 or 1284 × 2778 | Optional — Apple auto-scales |
| iPad 13" display | 2064 × 2752 | Required if iPad supported. Skip if iPhone-only. |
| **App Icon** | 1024 × 1024 PNG, no alpha, no rounded corners | ✅ Required |
| **App Preview video** (optional) | 1080 × 1920 portrait, 15–30 seconds | Recommended |

Maximum 10 screenshots per device size. Apple shows the first 3 prominently.

> **Action:** Confirm whether Arkline ships universal (iPhone + iPad) at 1.0 or iPhone-only. If iPhone-only, drop the iPad row and ship in a 1.1.

---

## Recommended 10-screenshot sequence (iPhone 6.9")

The order is the trust-building flow. The first three carry the most weight even for invited members. The rest reinforce.

| # | Screen source | Caption headline | Caption sub | Notes |
| --- | --- | --- | --- | --- |
| 1 | `screenshot-home.webp` | **The market, in one view** | Briefings, risk, macro — all on one home screen. | Anchors the whole product. |
| 2 | `screenshot-risk.webp` | **Know where you are in the cycle** | 8-factor BTC risk score, on-chain to macro. | The single most distinctive feature. |
| 3 | `screenshot-overview.webp` (or briefings) | **Your morning briefing, before coffee** | AI-distilled. Prices, sentiment, your portfolio. | Swap in a dedicated briefings shot if you have one. |
| 4 | `screenshot-portfolio.webp` | **Track 20,000+ assets** | Crypto, stocks, custom. P&L. Allocation. | |
| 5 | `screenshot-market.webp` | **Sentiment, flows, and signals** | Altcoin season, ETF flows, derivatives, liquidations. | |
| 6 | `screenshot-macro.webp` | **Macro indicators, with z-scores** | VIX, DXY, WTI, M2, Fed Watch. Regime detection. | |
| 7 | (DCA screen — render fresh) | **Smart DCA, on autopilot** | Time-based or risk-adjusted reminders. | Render from demo data. |
| 8 | (AI Chat — render fresh) | **An on-demand analyst** | Ask anything. Get context, not hype. | Show an explanatory exchange, not a "buy/sell" recommendation. |
| 9 | (Briefings detail — render fresh) | **Two briefings a day. One read.** | Morning + evening. AI-written. | Or swap in a community broadcast / sentiment-detail screen. |
| 10 | (Member home — render fresh) | **Built for the long view** | Risk-aware. Macro-aware. Yours, with one tap. | **Replaces the founding-pricing screenshot from the previous plan.** Closer screen reinforcing the value, no pricing/CTA. |

**What changed from the previous plan:** Screenshot #10 was originally a "Founding pricing — locked forever" closer screen. That is now removed because pricing copy and "subscribe" CTAs in App Store screenshots will get the listing rejected under 3.1.3. The replacement is a value-summary closer that emphasizes the long-view positioning without referencing money.

**Caption format:** Headline 5–7 words, sub 8–12 words. Don't include "$" or any pricing in any caption. Don't include "Subscribe", "Start free trial", "Upgrade", or similar CTAs.

> **Visual style note:** All 10 screenshots should share the same gradient background (use the website's `from-ark-primary via-ark-violet to-ark-cyan` gradient), the same headline typeface (Urbanist if you can match the website), and the same device frame (use a 2026 iPhone Pro Max bezel — silver or black, pick one and stick with it).

---

## Assets you'll need to render fresh

1. **DCA screen** — grab from a real demo session with realistic-but-not-personal holdings.
2. **AI Chat** — show a Q&A exchange where the AI explains a metric (e.g. "What is the DXY signaling right now?") rather than giving advice.
3. **Briefings detail** — full briefing screen (header, summary, portfolio impact, key macro shifts).
4. **Member home / value closer** — the v1 home with all widgets configured. No pricing, no upgrade prompts.
5. **App icon** — already in `web/public/appicon.png`. Confirm it's 1024×1024, no alpha, no rounded corners before uploading.
6. **App preview video** — 15–30 seconds storyboard:
   - 0:00–0:03 — Logo intro, tagline "The market rewards the informed."
   - 0:03–0:08 — Scrolling the home dashboard
   - 0:08–0:13 — Tapping the risk score, drilling into the 8 factors
   - 0:13–0:18 — Switching to macro dashboard, hovering a z-score
   - 0:18–0:25 — Opening a morning briefing
   - 0:25–0:30 — End card: "Arkline. Available by invitation."

**Note on the end card:** The video closer should NOT say "available on the App Store" since you're unlisted and that's slightly misleading — anyone with the link can install, but it's not in the App Store in the way most users understand. "Available by invitation" or "Member access — arkline.io" is more accurate and leans into the positioning.

---

## Production workflow

The cleanest way to produce all 10 screenshots is in Figma using a single template:

1. Create a Figma file `Arkline/AppStore-Screenshots`
2. Set up 10 frames at **1290 × 2796** each
3. In each frame, layer:
   - Background gradient (match website tokens: `--ark-primary`, `--ark-violet`, `--ark-cyan`)
   - Caption headline + sub at the top (reserve top ~22% of the frame)
   - Device frame (iPhone 17 Pro Max bezel)
   - The actual app screenshot inside the device frame
4. Export at 2x or 3x as PNG
5. Verify each file is exactly 1290×2796 before uploading

If you'd rather skip Figma, Mockuuups Studio and Screenshot Studio (Mac apps) both produce App Store-ready assets in the right sizes.

---

## Checklist

- [ ] App icon is 1024×1024 PNG, no alpha, no rounded corners
- [ ] 10 iPhone 6.9" screenshots rendered at exactly 1290×2796
- [ ] Each screenshot has the same caption typography and the same device frame
- [ ] **Captions reviewed for pricing language** — no "$", no "/mo", no "Pro", no "Premium", no "Subscribe", no "Free trial"
- [ ] **Captions reviewed for "investment advice" language** — all are descriptive, not prescriptive
- [ ] No real user data in any screenshot (use demo account holdings only)
- [ ] No outdated price data — Apple checks if BTC at $30k feels stale
- [ ] App Preview video rendered at 1080×1920, 15–30 seconds, < 500MB
- [ ] Poster frame for the App Preview is a meaningful frame (not a black screen)
- [ ] If shipping iPad in 1.0: 10 iPad 13" screenshots rendered at 2064×2752
- [ ] All assets uploaded to App Store Connect → App Information → screenshots
- [ ] All assets stored in `~/Documents/Arkline-Launch/screenshots/` for backup

---

## Things to avoid (will get the listing rejected or downgraded)

- ❌ Mentioning Android, web, or other platforms in screenshot captions
- ❌ Showing pricing ($39.99, $400/yr, free trial) anywhere — invite-only apps cannot reference IAP-style pricing in App Store screenshots
- ❌ "Subscribe" / "Upgrade" / "Buy" / "Restore Purchases" UI visible in any screenshot
- ❌ "As seen on Twitter / featured in Bankless / endorsed by [influencer]" claims without proof
- ❌ Showing brokerage UIs that imply trading happens in-app
- ❌ Tagline "Get rich" / "Find alpha" / "Outperform the market" — Apple's review team will reject for 5.2.3 (investment advice)
- ❌ Real user data in any screenshot (use demo account holdings only)
- ❌ Apple logos / iOS UI chrome reproduced as decoration
