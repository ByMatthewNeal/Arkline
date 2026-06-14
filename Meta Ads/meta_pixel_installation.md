# Arkline — Meta Pixel Installation Guide

> **Goal:** Install Meta Pixel on arkline.io to track PageView and ViewContent events for ad audience building and optimization.
> **Note:** CAPI (Conversions API, server-side complement) is a separate task we'll do once the Pixel is live and verified.

---

## Why we're doing this now

The pixel needs at least 7–14 days of data before Meta's algorithm can effectively optimize ad delivery. Installing today means it's "warmed up" by the time you launch your first ad campaigns. Even with zero ad spend in between, the pixel is silently collecting visitor signals that compound into better targeting data.

---

## Architecture overview

**What we're installing:**
1. **Meta Pixel base code** — Next.js Script component in root layout, fires `fbq('track', 'PageView')` automatically on every page navigation
2. **ViewContent events** on key pages (`/features`, `/pricing`) — fires `fbq('track', 'ViewContent')` so we can build custom audiences of high-intent visitors
3. **Environment variable** — `NEXT_PUBLIC_META_PIXEL_ID` (public because it gets embedded in HTML)

**What's NOT in this installation (separate future tasks):**
- **Conversions API (CAPI)** — server-side complement, lives in `/api/early-access` route. Adds ~20–30% conversion accuracy post-iOS14.
- **Lead event firing** — happens after CAPI is set up.
- **Custom audience pixel events** — created later when ads are running.

---

## Pre-flight checklist

Before running the Claude Code prompt below, confirm:

- [ ] You have your **Meta Pixel ID** copied from Events Manager (16-digit number)
- [ ] Add `NEXT_PUBLIC_META_PIXEL_ID=<your_pixel_id>` to **both**:
  - Your local `web/.env.local` file
  - **Vercel project → Settings → Environment Variables** (Production + Preview + Development)
- [ ] Install the **Meta Pixel Helper Chrome extension** for testing: https://chrome.google.com/webstore (search "Meta Pixel Helper")

---

## Claude Code prompt

Paste this into Claude Code from the `~/Arkline` directory:

```
I need to install Meta Pixel on the arkline.io website (Next.js 14+ App Router project at web/).

PIXEL ID: Stored in env var NEXT_PUBLIC_META_PIXEL_ID (already added to .env.local and Vercel).

Tasks:

1. Create a new client component at web/src/components/analytics/MetaPixel.tsx that:
   - Uses the next/script component with strategy="afterInteractive"
   - Initializes the Meta Pixel using the standard fbq snippet
   - Reads the Pixel ID from process.env.NEXT_PUBLIC_META_PIXEL_ID
   - Returns null if the env var is missing (so dev environments don't error)
   - Includes the <noscript> fallback img tag

2. Create a small hook at web/src/components/analytics/use-pixel-page-view.ts that:
   - Is a client-side hook
   - Listens to route changes via usePathname() and useSearchParams()
   - Fires fbq('track', 'PageView') on each route change
   - Handles the first PageView call (initial mount)

3. Wire both into web/src/app/layout.tsx:
   - Add the MetaPixel component inside the <body>, BEFORE the children
   - Use the use-pixel-page-view hook in a small wrapper client component if needed (since layout.tsx is a server component)

4. Add a ViewContent event on the following pages:
   - web/src/app/features/page.tsx (or wherever the features page lives)
   - web/src/app/pricing/page.tsx (or wherever the pricing page lives)
   Use a small "use client" component that calls fbq('track', 'ViewContent', { content_name: 'features' }) on mount.

5. TypeScript: Add a window.fbq type declaration in a global.d.ts file (or extend an existing one) so TypeScript doesn't complain about the global fbq function.

6. Verify:
   - Run npm run typecheck (or pnpm/yarn equivalent) — fix any TypeScript errors
   - Run npm run lint — fix any lint issues
   - Run npm run build to confirm production build works
   - The fbq global is only called client-side, never during SSR

7. Commit with this message:
   feat: install Meta Pixel with PageView and ViewContent events

8. Push to main.

Important constraints:
- This is a marketing site, performance matters. Use strategy="afterInteractive" (NOT "beforeInteractive"). The pixel loads after the page is interactive, which is the Meta-recommended setup for marketing pixels.
- Do NOT install the react-facebook-pixel npm package. Use raw fbq snippet via next/script — it's lighter and more reliable.
- Do not fire any events on the early-access signup form yet. That's handled separately via Conversions API in a future task.
- Confirm at the end: which route files you added ViewContent to (in case the page structure isn't /features and /pricing as assumed).

After completion, tell me:
- The commit hash
- The file paths you created or modified
- Which pages you added ViewContent to
- Any build warnings I should know about
```

---

## How to verify after Vercel deploys

Once Vercel finishes deploying the change (1–2 min):

1. **Open Meta Pixel Helper Chrome extension** (icon in toolbar)
2. Navigate to **arkline.io** (production)
3. Click the Pixel Helper icon — you should see:
   - ✅ "1 pixel found on this page"
   - ✅ "PageView" event firing
   - ✅ Pixel ID matches the one you added to env vars

4. Navigate to **arkline.io/features** — Pixel Helper should now show:
   - ✅ "PageView" event
   - ✅ "ViewContent" event

5. Navigate to **arkline.io/pricing** — same as above

6. **Cross-check in Meta Events Manager:**
   - Go to Events Manager → your Pixel → **Test Events** tab
   - Enter `arkline.io` as the test URL
   - Navigate to a few pages on arkline.io
   - You should see events appearing in near-real-time in the Test Events panel

If any step fails, screenshot the Pixel Helper or Test Events panel and we'll debug.

---

## What this unlocks

Once the pixel is verified:

- **Custom Audience: All website visitors** — Meta auto-builds this as soon as data starts flowing. By the time you launch ads, you'll have 1,000+ visitors retargetable.
- **Custom Audience: ViewContent on /features** — high-intent visitors who deeply explored. Smaller but higher-converting retargeting pool.
- **Custom Audience: ViewContent on /pricing** — even higher intent (people who looked at price). Highest-value retargeting pool.
- **Lookalike audiences** — once you have 100+ Lead events (post-launch), you can build 1–3% LALs off these audiences. The audiences need data NOW so they're meaningful later.

---

## Next steps after this

**Same week:**
- Install Conversions API (CAPI) in `/api/early-access` route — fires server-side `Lead` event when someone signs up for early access. Adds ~20–30% conversion measurement accuracy.
- Test Lead event dedup between client-side pixel and server-side CAPI

**When you launch ads (later):**
- Add Purchase event firing on Stripe trial signups (post-app-launch)
- Add InitiateCheckout event on Stripe payment page

---

## Privacy / compliance notes

- The pixel collects visitor IP, user agent, and basic behavioral signals. Make sure your **privacy policy mentions Meta** as a third-party service for analytics/advertising.
- Your current privacy policy doesn't yet list Meta — we should add it in the next privacy policy revision before going live with ads. Not blocking pixel installation, but flag for the attorney review pass.
- Cookie consent: arkline.io doesn't currently have a cookie banner. Acceptable risk for a US-only invite-only launch; revisit if you expand to EU users.
