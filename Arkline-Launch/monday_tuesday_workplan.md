# Arkline — Monday/Tuesday Work Plan

> **Goal:** Maximize progress on Arkline launch infrastructure across two working days.
> **Created:** 2026-05-11

---

## Strategic Frame

Two main outcomes by EOD Tuesday:

1. **Welcome emails firing automatically on every signup** (requires Stable mailbox first)
2. **Meta tracking infrastructure live + first ad creative drafted** (sets up Phase 1 of the ads strategy)

The plan below sequences work so you can keep moving while waiting on async items (Stable mailbox approval, DNS propagation).

---

## MONDAY

### 🚨 P0 — Do these no matter what

#### 1. Set up Stable virtual mailbox *(60–90 min)*
**Why P0:** Unblocks workflow activation, privacy policy, ToS, App Store contact, and ad legal compliance. Has the longest async wait (24–48 hours), so kick it off first thing.

- [ ] Sign up at **stable.com** — pick Wyoming address
- [ ] Fill out **Form 1583** in your Stable dashboard
- [ ] **Online notary via Notarize.com** (~$25, 15-min video call)
  - ⚠️ Put BOTH "Matthew Neal" and "Arkline Technologies LLC" on the same Form 1583 — single notarization covers both
- [ ] Submit to Stable; wait for activation email (24–48 hours)

#### 2. Twitter / X cleanup *(30–45 min)*
**Why P0:** Quick, gets the public-facing brand consistent. No dependencies.

- [ ] Update arkline.io footer to link to `@Arklineio` (NOT `@arkaboreal`)
- [ ] On `@Arklineio` profile:
  - [ ] Profile picture (Arkline logo, square version)
  - [ ] Header image (can use the OG image from arkline.io as a placeholder)
  - [ ] Bio: something like *"Institutional-grade market intelligence for retail investors. iOS app launching Spring 2026. The market rewards the informed."*
  - [ ] Pinned tweet announcing waitlist with arkline.io link
- [ ] Post 5–8 starter tweets — mix of market takes (using Arkline's data lens), product teasers, and the launch announcement. Match the brand voice: serious, data-driven, anti-influencer.

#### 3. Backfill 22 existing signups into Loops *(15 min)*
**Why P0:** Those folks signed up weeks ago and haven't heard from you. Once the workflow is activated, they should get the welcome email too.

- [ ] Supabase Dashboard → `early_access_signups` table → Export as CSV
- [ ] Loops → Audience → **Import** → CSV
- [ ] Map columns: email → Email, Source → "arkline.io early access (pre-API)", User Group → "Early Access"
- [ ] **Hold off on running import until Loops workflow is activated** (after Stable arrives) — otherwise they don't get the welcome email
- [ ] So really this is: prepare the CSV today, run the import on Tuesday after activation

### 🔵 P1 — Strong second priority

#### 4. Install Meta Pixel on arkline.io *(60–90 min)*
**Why P1:** Required before any ad spend. Doesn't depend on Stable, so do it now to make Tuesday's CAPI work easier.

- [ ] Get your Pixel ID from Meta Business Manager → Events Manager → Pixel (one was auto-created when you set up the ad account)
- [ ] Have Claude Code add the Meta Pixel script to `arkline.io`:
  - Install `react-facebook-pixel` or use raw `fbq(...)` script in `<head>`
  - Fire `PageView` automatically
  - Fire `ViewContent` on `/features` and `/pricing` pages
- [ ] Verify pixel fires using **Meta Pixel Helper Chrome extension**
- [ ] Verify events appear in Meta Events Manager → Test Events (live mode)
- [ ] Note: the `Lead` event will fire via Conversions API (Tuesday work), not pixel

### 🟢 P2 — If you have extra energy

#### 5. Privacy Policy & Terms of Service review *(30 min)*
**Why P2:** Need updating with Stable address anyway, so might as well audit them now.

- [ ] Open `~/Documents/Arkline-Launch/05_privacy_policy.md` and `06_terms_of_service.md`
- [ ] Identify all `[BUSINESS ADDRESS]` placeholders — flag them for Tuesday's swap
- [ ] Read through full docs — any other placeholders or outdated info?
- [ ] Tag anything that needs attorney review

---

## TUESDAY

### 🚨 P0 — Do these no matter what

#### 1. Once Stable activates → swap address everywhere *(30 min)*
**Why P0:** Unblocks workflow activation, which unblocks actual welcome emails.

When Stable confirms your address is active (check email):

- [ ] **Loops** → Settings → Domain → Company Address → swap to Stable
- [ ] **Privacy Policy** → update `[BUSINESS ADDRESS]` placeholder
- [ ] **Terms of Service** → update `[BUSINESS ADDRESS]` placeholder
- [ ] Republish these docs on arkline.io
- [ ] **App Store Connect** → contact info → update with Stable
- [ ] **Stripe** → business address → update with Stable (when you re-engage Stripe pre-launch)
- [ ] Note for future: File WY SOS amendment ($60) to move principal office from apartment → Stable. This is its own task — do it sometime in the next 2 weeks.

#### 2. Activate the Loops welcome workflow *(15 min)*
**Why P0:** This is the moment you've been building toward.

- [ ] Loops → Workflows → "Welcome - Early Access" → click **Start**
- [ ] Run final test with `mneal.jw+test4@gmail.com`
- [ ] Confirm welcome email arrives in your inbox within 1 minute
- [ ] Now run the CSV import of the 22 existing signups (from Monday's prep)
- [ ] **You're live.** Every new signup now gets the welcome email automatically.

#### 3. Install Meta Conversions API (CAPI) *(60–90 min)*
**Why P0:** Pixel alone misses 20–30% of conversions post-iOS14. CAPI is the server-side complement that fixes that.

- [ ] Get your CAPI Access Token from Meta Events Manager → your Pixel → Settings → Generate Access Token
- [ ] Have Claude Code modify `web/src/app/api/early-access/route.ts`:
  - Add a `fetch()` call to Meta's Conversions API after the Loops add
  - Fire `Lead` event with the user's hashed email
  - Use `event_id` for deduplication with the client-side pixel
- [ ] Verify dedup is working in Meta Events Manager → Test Events
- [ ] Add `META_PIXEL_ID` and `META_CAPI_TOKEN` to Vercel env vars

### 🔵 P1 — Strong second priority

#### 4. Draft ad creative concepts *(60–90 min, collaborative with me)*
**Why P1:** You'll need real creative when you launch ads in 2–3 weeks. Better to start drafting now so production has runway.

Together, we'll produce a workspace doc with:
- 5–10 ad concepts in your voice
- Each concept: hook, body copy, CTA, visual description, format (image / video / carousel)
- Static-first; video concepts noted for week 2 of production

When you're ready, just say "let's draft the ad creative" and I'll produce the doc.

#### 5. Build dedicated paid-traffic landing page *(2–3 hours)*
**Why P1:** Cold paid traffic converts much better on a focused single-CTA page than your current homepage.

- [ ] Sketch the page structure first (I can help):
  - Hook (5 seconds)
  - Problem (10 seconds)
  - Solution + 6 pillars condensed
  - Social proof / scarcity (150 spots)
  - Single CTA: "Get early access"
- [ ] Have Claude Code create `web/src/app/early-access/page.tsx`
- [ ] Reuse existing components where possible (the email-capture form especially)
- [ ] Test the same `mneal.jw+test5@gmail.com` flow on the new page

### 🟢 P2 — If you have time

#### 6. Define Meta audience strategy *(30 min)*
**Why P2:** Helpful pre-work for the actual campaign setup, but no rush.

- [ ] Review the audience plan in `meta_ads_strategy.md`
- [ ] Decide: are the interest stacks I drafted (Bitcoin, Ethereum, Bloomberg, etc.) right for your audience? Add/remove any?
- [ ] Decide on starting daily budget within the $30–50 range
- [ ] No action to take yet — just confirm the plan

---

## What to expect across the two days

| End of Monday | End of Tuesday |
|---|---|
| Stable signed up, waiting on activation | Welcome emails LIVE for new signups |
| Twitter brand consistent + active | Existing 22 signups got welcome email |
| Meta Pixel firing on arkline.io | CAPI installed (server-side tracking) |
| Privacy/ToS audited | 5–10 ad concepts drafted |
|  | Paid landing page live |

If you crush both days, the only major items left before launching ads are: campaign architecture in Meta Ads Manager, creative production (filming/designing the actual ads), and final QA.

---

## What I can do for you while you work

While you're clicking through Stable signup, Form 1583, or coding with Claude Code, I can in parallel:

- Draft the 5–10 ad creative concepts (just ask)
- Pre-write the privacy policy + ToS language for the new Stable address
- Plan the landing page structure / sketch the copy
- Pre-write the CAPI integration code so Claude Code can apply it directly
- Pre-write the Meta Pixel installation code

Just say what you want me to prep and I'll have it ready as a workspace doc when you're ready.

---

## What's NOT in scope this week

To stay focused, these wait until later:

- Drafting nurture emails 3–8 (do as launch approaches, ~2 weeks out)
- Filing the WY SOS amendment to move principal office (post-Stable, can take 1–2 weeks)
- Filming actual video ad creative
- Building lookalike audiences (need ~100 customers post-launch)
- Setting up X Ads / Google Ads (Phase 2)
- D-U-N-S Number tracking (check status; can take 1–7 days, currently in flight)
- Apple Dev enrollment (pending D-U-N-S)
- Final TestFlight → App Review submission
