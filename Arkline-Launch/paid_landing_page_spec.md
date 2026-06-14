# Arkline — Paid Landing Page Spec (`/early-access`)

> **Purpose:** Dedicated landing page for cold paid ad traffic. Single-CTA, single-page, conversion-optimized. Replaces the homepage as the destination URL for all Meta ads.
>
> **Voice rules (carry through everywhere):**
> - No emojis. No exclamation points. No "Don't miss out!" fluff.
> - Adults talking to adults. Reading level: The Information / Stratechery.
> - Position against the alternative (YouTube takes, Twitter noise, gut feel).
> - Specifics and numbers > vague claims.

---

## Page-level decisions

| Decision | Rule |
|---|---|
| **URL** | `arkline.io/early-access` |
| **Nav** | None. Logo top-left only (links to `/`, but nothing else clickable in header). |
| **Footer** | Minimal — only legal links (Privacy, Terms). No social, no contact, no FAQ. |
| **Theme** | Same dark mode as homepage. Don't reinvent the design system. |
| **Mobile** | Mobile-first. ~70% of Meta traffic is mobile. Test mobile experience first. |
| **Form** | Reuses existing `email-capture.tsx` component (already wired to `/api/early-access`). |
| **Tracking** | Fire Meta pixel `ViewContent` on page load. Lead event already fires via CAPI on form submit. |
| **UTM** | Capture UTM parameters and store with the Supabase signup (column already exists or add one). |

---

## Section 1 — Hero (above the fold)

This is the entire ad's job. If they don't get the email form in their viewport in <2 seconds, you lose them.

### Headline

**Primary:**
```
The market rewards the informed.
```

**A/B variants to test (after launch):**
- B: `Stop investing on influencer takes.`
- C: `Institutional intelligence. For retail.`
- D: `Built for investors who are tired of takes.`

### Subhead (one sentence directly below headline)

```
Multi-factor risk scoring, macro intelligence, and AI briefings — for retail investors who want signal, not screaming.
```

### Email capture form

Reuses your existing component. Single email field, submit button.

**Button text:**
- Primary: `Get Early Access`
- Secondary option: `Reserve My Spot`

### Trust line directly below the form

Small, gray, single line:
```
150 founding spots · Launching Spring 2026 · No card required
```

### Hero visual

A clean, dark-mode product screenshot. Recommendations in priority order:
1. **Best: the BTC Risk Score dashboard** — most distinctive, hardest for competitors to match, signals "this is different"
2. Macro dashboard with VIX/DXY/WTI
3. AI briefing screenshot (less visual but very on-brand)

Place on the right side on desktop, below the form on mobile.

### What to NOT include in the hero

- ❌ Multiple bullet points (clutters)
- ❌ Pricing details
- ❌ Long paragraph of features
- ❌ "Watch this video" element (kills conversion)
- ❌ Logos of other companies / "as seen in" (you don't have them)

---

## Section 2 — Problem statement (~ one screen below hero)

Sets the identity hook before pitching features. Lets the reader self-select. This is the most important non-hero section — it's where they decide if you're "their kind" of product.

### Heading

```
Most retail investors are guessing.
```

### Body (3 short paragraphs)

```
Crypto Twitter at 3am. YouTube thumbnails. Discord pumps. Influencers who profit from
your attention, not your performance.

The people who actually build wealth in this market aren't watching that. They're
reading risk models, tracking macro regimes, watching sentiment data that most
retail investors don't even know exists.

Arkline closes the gap.
```

### Visual

Optional. If included, a single contrast image — Twitter noise vs. Arkline dashboard. Otherwise text-only is fine, lets the writing breathe.

---

## Section 3 — What you get (six pillars, condensed)

Compressed version of the homepage bento section. Cold traffic doesn't read; they scan. Each pillar is one line + one icon, not a paragraph.

### Heading

```
Six tools. One platform. No noise.
```

### Pillar grid (2×3 on desktop, 1-column on mobile)

Each pillar = icon + one-line title + one-line description. NO additional paragraphs.

| Icon | Title | Description |
|---|---|---|
| ⊞ (dashboard) | **Portfolio Tracking** | Crypto, stocks, and custom assets in one view. Live P&L. 20,000+ instruments. |
| ⊙ (target / score) | **Risk Scoring** | 8-factor BTC risk model. 0–1 score, updates in real time. |
| ⊝ (chart) | **Market Analysis** | Sentiment, altcoin season, ETF flows, derivatives. The picture behind the price. |
| ⊛ (sparkle / AI) | **AI Briefings** | Morning and evening summaries. Personalized to your holdings. |
| ⊕ (calendar / cycle) | **Smart DCA** | Risk-adjusted dollar-cost averaging. Buy more when conditions favor it. |
| ⊟ (globe / macro) | **Macro Dashboard** | VIX, DXY, WTI, US Net Liquidity. Z-scores. Regime detection. |

(Substitute the icon labels above with whatever lucide-react icons match your design system.)

---

## Section 4 — How it works

Three steps. Numbered. Each one line.

### Heading

```
How it works
```

### Steps

```
1. Join the early access list
   Email gets you the launch invite. No card required.

2. Build your portfolio at launch
   Add what you hold. We track the rest.

3. Invest with conviction
   Daily briefings, real-time risk scores, macro context.
```

### Visual

Numbered cards horizontally on desktop. Stack on mobile.

---

## Section 5 — Founder note + scarcity

Personal, authentic, position-defining. This is where you (Matt) appear by name. It's the "why should I trust this" section that's hard to fake.

### Heading

```
Why I built this
```

### Body

```
I spent two years looking for a tool that gave retail investors the same kind of
intelligence institutions have. Risk models. Macro context. AI briefings.

I couldn't find one. So I built it.

Arkline launches in Spring 2026 with 150 founding members. They lock in $39.99/month
— forever — as long as they stay subscribed. After that, standard pricing applies.

If you're tired of investing on takes, get on the list.

— Matt
   Founder, Arkline
```

### Visual

Optional. Small photo of you (head/shoulder, plain background) on the right side of the text. If you don't have a good photo, skip it entirely — the text is strong enough.

### Scarcity element

Above or below the body, a small accent block:

```
■ 150 founding spots · $39.99/month locked forever · Spring 2026 launch
```

(Bonus if you want to get fancier later: a live counter showing "X / 150 founding spots taken" pulled from Supabase. Not required for v1.)

---

## Section 6 — Final CTA

Last chance to convert. Repeat the email form with a punchy closer.

### Heading

```
Get the institutional toolkit.
```

### Subhead

```
150 founding members. Founding pricing locked forever. Spring 2026.
```

### Form

Identical to hero form. Same component, same endpoint.

### Trust line

```
Free to join · No spam · You'll be the first to know
```

---

## Footer

Minimal. Three lines:

```
© 2026 Arkline Technologies LLC          Privacy   Terms
```

That's it. No social icons. No nav. No newsletter signup (the whole page IS the newsletter signup).

---

## Technical / production notes for Claude Code

### File location

```
web/src/app/early-access/page.tsx
```

### Existing components to reuse

- The email capture form/component from `web/src/components/marketing/email-capture.tsx` — DON'T rebuild
- Existing typography utilities (Inter / Urbanist via the layout fonts)
- Existing dark-mode color tokens
- Existing button component if one exists

### New ViewContent event

On page load, fire a Meta pixel ViewContent event with a `content_name` param so we can build a custom audience of LP visitors:

```typescript
useEffect(() => {
  if (typeof window !== 'undefined' && typeof window.fbq === 'function') {
    window.fbq('track', 'ViewContent', { content_name: 'early_access_landing' })
  }
}, [])
```

### UTM parameter capture

When form is submitted, parse `utm_source`, `utm_medium`, `utm_campaign`, `utm_content`, `utm_term` from the URL and POST them along with the email to `/api/early-access`. Then in the API route, store them on the Supabase row.

**Required:** Add nullable columns to `early_access_signups` table:
- `utm_source TEXT`
- `utm_medium TEXT`
- `utm_campaign TEXT`
- `utm_content TEXT`
- `utm_term TEXT`

This lets you measure which ad creative / campaign converts best after launch.

### Page metadata (SEO + OG)

```typescript
export const metadata: Metadata = {
  title: 'Arkline — Early Access',
  description: 'Multi-factor risk scoring, macro intelligence, and AI briefings for retail investors. 150 founding spots. Spring 2026.',
  robots: { index: false, follow: false }, // Don't index — this is for paid traffic only, not SEO
  openGraph: {
    title: 'Arkline — Early Access',
    description: 'Institutional intelligence for retail investors. 150 founding spots locked in.',
    images: [{ url: '/og-image.png' }],
  },
}
```

The `robots: { index: false }` is important — you don't want this page in Google search results. It's for paid ads only.

### Mobile-first checklist

- [ ] Hero form is visible without scrolling on iPhone SE width (375px)
- [ ] Headline fits 2 lines maximum on mobile
- [ ] Email input is at least 44px tall (Apple HIG minimum touch target)
- [ ] Submit button is full-width on mobile, auto-width on desktop
- [ ] All sections stack to single column on mobile
- [ ] No horizontal scroll anywhere

### Performance

- Use Next.js Image component for the hero screenshot
- Preload the hero image (LCP optimization — Meta's algorithm penalizes slow-loading landing pages with higher CPMs)
- Avoid heavy animations that block render

---

## Claude Code prompt to build this

Once you're happy with the copy above, paste this prompt into Claude Code:

```
Please build a new landing page for Arkline at web/src/app/early-access/page.tsx based on
the spec at ~/Documents/Claude/Projects/Arkline/paid_landing_page_spec.md.

Key requirements:
- Use the exact copy from the spec (Hero, Problem, Pillars, How It Works, Founder Note, Final CTA)
- Reuse the existing email capture component from web/src/components/marketing/email-capture.tsx
- Match the existing dark-mode design system (do NOT reinvent typography or colors)
- Mobile-first: hero form must be visible above the fold on iPhone SE width
- Add a Meta pixel ViewContent event firing on mount with content_name "early_access_landing"
- Capture UTM parameters from the URL on form submit and POST them to /api/early-access
- Add nullable utm_source/medium/campaign/content/term TEXT columns to early_access_signups
  (write a Supabase migration file in supabase/migrations/ if that's where migrations live)
- Update /api/early-access route to accept and persist UTM params
- Add page metadata with robots: { index: false } (this page should NOT be indexed)
- No top nav, no full footer — minimal header (just logo) and minimal footer (just legal links)

After building:
- Run npm run lint, npm run typecheck, npm run build
- Commit with message: feat: add /early-access landing page for paid ad traffic
- Push to main

Tell me what you built, what files you touched, and any decisions you made.
```

---

## Post-build verification checklist

After Claude Code pushes and Vercel deploys:

- [ ] Page loads at `arkline.io/early-access` with no console errors
- [ ] Hero form submits successfully — row appears in Supabase
- [ ] Loops contact created (check Audience tab)
- [ ] CAPI Lead event fires (check Vercel logs for `/api/early-access` POST)
- [ ] Pixel Helper shows PageView + ViewContent on the page
- [ ] Mobile rendering works on iPhone (use Chrome DevTools mobile emulator)
- [ ] UTM params get captured — test with `arkline.io/early-access?utm_source=test&utm_campaign=test1`
- [ ] Page is excluded from Google indexing (view-source: robots meta tag)
- [ ] No nav links other than logo→home and footer→privacy/terms

---

## What to do next, after this is live

1. **Use this URL as the destination for all Meta ads** — never send paid traffic to the homepage
2. **A/B test hooks** — start with the primary headline, then test B/C/D variants once you have enough traffic to declare significance (typically 500+ visitors per variant)
3. **Build retargeting audience** — once 1,000+ visitors hit this page, you'll have a meaningful "people who saw the LP but didn't convert" pool for retargeting ads
4. **Track UTM-level conversion rates** — once UTM data is flowing, you can see which ad campaign / creative / placement converts best at the landing page level
