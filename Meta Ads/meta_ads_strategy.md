# Arkline — Meta Ads Strategy & Implementation Plan

> **Owner:** Matt
> **Created:** 2026-05-08
> **Phase:** Pre-launch (waitlist building)
> **Decision:** In-house execution, not outsourced. ~$30–50/day test budget to start.

---

## 1. Strategic Frame

### Why Meta first, not Axon / Apple Search Ads / X
- **Apple Search Ads:** doesn't work — Arkline is on Unlisted Distribution, not searchable.
- **Axon (AppLovin):** built for app installs from mobile gaming inventory; wrong funnel and wrong audience for a $400/yr serious investor product.
- **X Ads:** worth Phase 2 once @Arklineio profile is populated and there's a customer list for lookalikes.
- **Google Search:** great Phase 2 channel for high-intent capture, but won't drive volume yet.
- **Meta:** highest fit for our funnel (web → email → trial), most mature pixel + CAPI infrastructure, best lookalike modeling, cheapest Lead event learning data.

### The funnel as it actually exists today
```
Cold ad audience (Meta)
  → arkline.io (or /early-access landing page)
    → "Get Early Access" form
      → Supabase backend (custom)
        → Matt's admin app (visible)
        → Email service (Loops/Resend) — TO BE SET UP
          → Welcome + nurture sequence
            → Launch announcement
              → Stripe trial signup
                → iOS app invite
                  → Subscription
```

### Phase plan

| Phase | Time | Goal | Optimization event | Daily spend |
|---|---|---|---|---|
| **0 — Now** | Today → next 7 days | Plumbing: pixel, CAPI, email service, landing page | None (no ads yet) | $0 |
| **1 — Pre-launch** | ~7 days from now → iOS launch | Build waitlist | Lead | $30–50 |
| **2 — Launch** | iOS launch → +30 days | Convert waitlist + new leads to trial | StartTrial | $50–100 |
| **3 — Scale** | +30 days onward | Optimize CPA, fill 150 cap | Subscribe | Scale based on CPA |

### Key gap: no email nurture today
22 signups exist with no sequence after them. Any paid traffic before nurture is set up = leaky bucket. **Fix this first.**

---

## 2. Plumbing (Phase 0 — must complete before ads run)

### A. Email service
Recommended: **Loops** ($49/mo, Supabase-friendly, great drip tooling).
Alternative: **Resend + simple custom triggers** if you want to keep it engineering-heavy.

Build:
1. **Welcome email** (instant on signup): confirms signup, sets expectation of when launch is, links to follow on X, asks them to share what they're hoping Arkline solves.
2. **Drip emails** (every 7-10 days during pre-launch):
   - "How the BTC Risk Score works" — explain the 8 factors, show a chart
   - "Sample AI Briefing" — actual sample output to demonstrate value
   - "What you'll see on the macro dashboard" — VIX / DXY / WTI / US Net Liquidity teaser
   - Founder's note from Matt — why he built it
3. **Launch announcement** (when iOS is live): "It's here. Founding pricing locked for first 150."
4. **Trial conversion sequence** (3-email): scarcity nudges as the 150 cap fills.

### B. Meta Business Manager
- Open under **Arkline Technologies LLC** (not personal account)
- Add: business page, ad account, payment method (LLC business account), arkline.io domain verification
- Enable two-factor auth
- Don't run any test ads until D-U-N-S + Apple Dev are squared away (avoid attention to brand new account from Meta's risk team)

### C. Meta Pixel + Conversions API
Pixel (client-side):
- `PageView` on every page
- `ViewContent` on /pricing, /features
- `Lead` on early access form submit (success state only)

Conversions API (server-side, via Supabase):
- Server-side `Lead` event fired from Supabase function on email insert
- Use `event_id` for deduplication with the client-side Lead
- Better post-iOS14 attribution accuracy (10-30% lift over pixel-only)

Verify: Use Meta Events Manager → Test Events → live verify before going to production.

### D. Twitter handle reconciliation
- Pick canonical handle: **@Arklineio** (recommended)
- Update arkline.io footer link
- Populate profile: bio, header, 8-12 quality posts before any traffic flows there

---

## 3. Landing Page Strategy

### Today's site
arkline.io is a brand homepage — features, pricing, hero, FAQ. Great for organic traffic. **Suboptimal for paid cold traffic** because of nav distractions, multiple CTAs, and too much info before the ask.

### Build /early-access dedicated paid LP
- Single CTA, repeated 2–3x down the page
- No top nav (or compressed nav with only "Features" → opens modal, not new page)
- Tighter narrative arc:
  1. Hook (first 5 seconds): "The market rewards the informed."
  2. Problem (10 seconds): "Most retail investors are losing to YouTube takes and Twitter noise."
  3. Solution (20 seconds): "Arkline gives you the same data institutions use — risk scoring, macro intelligence, AI briefings."
  4. Social proof: TestFlight users / founding member count / endorsements (when they exist)
  5. Scarcity: "Only 150 founding spots."
  6. CTA: "Get early access — no card required."

### A/B variants to test
- **A — Data-driven**: hero shows risk-score chart with annotation
- **B — FOMO/scarcity**: countdown to launch + spots remaining
- **C — Anti-influencer**: bold "Stop trading on YouTube takes" hook, contrast position

---

## 4. Audience Strategy

### Cold targeting (start here)
Stack interest + behavior at the ad set level:

**Interest:**
- Bitcoin, Ethereum, Cryptocurrency, Coinbase, Kraken, Binance
- Bloomberg, Wall Street Journal, Financial Times
- Trading (financial), Investment management, Stock trader
- TradingView, MetaTrader

**Behavior:**
- Engaged shoppers, Financial decision-makers
- Frequent travelers (proxy for affluence) — test only

**Demographics:**
- 25–55, all genders, US first (broaden later)
- Education: College+ (Meta accepts as soft signal)

### Custom audiences (post pixel install)
- Website visitors (last 30 days, excluding form converters)
- Engagement on FB/IG account (last 90 days)
- Email list (existing 22 → upload as custom audience for retargeting + lookalike seed)

### Lookalikes (Phase 2+)
- 1–3% LAL of paid Stripe customers (need ~100 customers as seed)
- 1–3% LAL of trial starters
- 1% LAL of email list (low quality due to small seed but better than nothing pre-launch)

### Exclusions
- Existing waitlist (uploaded as custom audience, exclude)
- Existing Stripe customers (post-launch)

---

## 5. Creative Direction

### Voice anchors (from your brand)
- **Data-driven, not hype** — show charts, scores, numbers, not lifestyle
- **Anti-influencer** — explicitly position against the YouTube/Twitter shill culture
- **Serious tone** — adults talking to adults
- **Conviction language** — "Invest with conviction," "The market rewards the informed"
- **No emojis, no GIFs, no meme energy**

### Concept slate (5–10 to test)

1. **"Risk Score Today" static** — Big number (0.42), one-line context, screenshot of the dashboard. Hook: "Today's BTC risk score: 0.42. Historically favorable accumulation."

2. **"What you don't see on Twitter" static** — Side-by-side: Twitter take vs. Arkline data. Hook: "While crypto Twitter argues, Arkline shows you the actual data."

3. **6-pillar carousel** — One slide per pillar, clean dark-mode product screenshots.

4. **"Built for investors who are tired of the noise" video (15s)** — Quick montage of YouTube thumbnails / Twitter threads → cuts to Arkline dashboard. Wordless until end card: "Arkline. Invest with conviction."

5. **Founder's note video (30s)** — Matt to camera, low-fi, plain background. "I spent two years looking for this tool. Then I built it."

6. **AI briefing teaser carousel** — Screenshots of an actual morning AI briefing (sanitized). One slide = one insight.

7. **Macro regime moment** — When a regime shift detection fires, capture and run as a real-time ad.

8. **TestFlight quote** — Pull a 1–2 sentence quote from a TestFlight user (with permission), pair with Arkline visual. Builds social proof.

9. **"Stop trading on takes" provocative static** — Bold text-only ad, anti-influencer hook.

10. **"You wouldn't trade without this in TradFi" parallel** — Bloomberg terminal comparison, position Arkline as the retail equivalent.

### Production notes
- Matt produces; Claude drafts copy + storyboards each concept
- Static ads first (cheaper to iterate), video by week 2
- Square 1:1 (feed) and vertical 9:16 (stories/reels) for each concept
- Refresh creative every 7–14 days to avoid fatigue

---

## 6. Campaign Architecture

### Account structure
**1 Campaign:** Lead generation
**2–3 Ad sets:** segmented by audience type
- Ad set 1: Cold interest stack (largest)
- Ad set 2: Custom audience retargeting (small, high-intent)
- Ad set 3 (later): Lookalike

**5+ Ads per ad set:** rotating creative concepts

### Budget
- Start: $30–50/day total ($1,000–1,500/mo as planned)
- 70% to cold, 30% to retargeting
- Use Advantage+ campaign budget optimization at the campaign level

### Bid strategy
- **Lowest cost** (default) for first 7 days while learning
- After learning phase, evaluate switching to **Cost cap** with target ~$10 CPL

### Decision rules
- **Kill ad** if CPL > $25 after 50+ impressions and 3+ days
- **Pause ad set** if no conversions after 100 leads target volume not met after 5 days
- **Scale ad** by 20% if CPL < $10 and ROAS positive (post-launch)
- **Refresh creative** when frequency > 3.0

---

## 7. Measurement & Review

### Metrics to track weekly
- **CPL (Cost per Lead)** — primary metric
- **CTR** — secondary, leading indicator of creative health
- **Frequency** — leading indicator of fatigue
- **Lead quality** — % of waitlist that converts to trial post-launch (will only know later)

### Friday review cadence
Replaces the agency's "weekly check-in":
1. CPL by campaign / ad set / creative
2. Top 3 winners, bottom 3 losers
3. Frequency check on each ad
4. New creative shipping next week
5. Any decisions to scale, kill, refresh

---

## 8. Pre-Flight Checklist

Before turning on ads:

- [ ] LLC formed (✅ done — Arkline Technologies LLC)
- [ ] D-U-N-S issued (in progress)
- [ ] Apple Dev enrollment (pending D-U-N-S)
- [ ] Email service connected + welcome email live
- [ ] At least one nurture email scheduled
- [ ] Meta Business Manager set up under LLC
- [ ] Meta Pixel installed + tested
- [ ] Conversions API live + dedup verified
- [ ] arkline.io domain verified on Meta
- [ ] /early-access dedicated landing page live
- [ ] @Arklineio profile populated; site footer updated
- [ ] First 5 ad concepts drafted + assets produced
- [ ] Audience plan finalized
- [ ] Campaign + ad sets built but paused
- [ ] $30–50/day budget approved + payment method on Meta Ad Account

---

## 9. What's Out of Scope For Now

- Apple Search Ads (won't work for Unlisted)
- Axon / AppLovin (wrong fit)
- X Ads (Phase 2 — needs profile populated + lookalike seed)
- TikTok (wrong audience for serious tone, expensive to test)
- YouTube pre-roll (Phase 2 — better once there's a video creative library)
- Influencer partnerships (contradicts brand positioning)
- SEO / content marketing (parallel workstream, separate doc)
