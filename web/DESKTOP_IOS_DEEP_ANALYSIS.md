# Arkline — Desktop vs. iOS Deep Analysis

> **Date:** July 7, 2026 · **Scope:** full product (all tabs/routes, data layer, design system, UX texture)
> **Goal:** the user should feel no difference between platforms; desktop should feel like an *enhanced* version of the iOS app with smooth, flawless UI/UX.
> **Supersedes** `web/DESKTOP_PARITY_AUDIT.md` (stale — it only covered Home, and most of its "missing" widgets have since been built).

---

## 1. Executive summary

The desktop app has quietly caught up much further than the old audit suggests: all 25 home widgets exist, customize/presets/resize exist, the design tokens mirror iOS almost value-for-value, and the invite-code flow deliberately replicates iOS logic. **Structural parity is roughly 80%. Perceived parity is much lower — maybe 55–60% —** because the gaps are concentrated in exactly the things users *feel*: data freshness, error handling, micro-interactions, native browser dialogs, and several correctness bugs where desktop shows different numbers than iOS. A user who opens both side-by-side today will see different portfolio values, a home hero widget drawer that charts *Bitcoin* instead of their portfolio, and settings toggles that do nothing.

The good news: desktop's bones are strong (React Query + design tokens + a consistent GlassCard/drawer system), and it's already *ahead* of iOS in a few places (⌘K global search, briefing text-to-speech, freely resizable grid). Closing the "feel" gap is mostly a set of surgical fixes plus one infrastructure decision (web push), not a rebuild.

**Top 5 highest-impact deltas** (details in §5–§6):

1. **The "Portfolio" widget drawer charts BTC, not the user's portfolio** — `components/dashboard/home/portfolio-hero.tsx` pulls `useRiskHistory` (BTC price from `model_portfolio_risk_history`). The pinned hero (`bento-grid.tsx:1761`) is correct; the drawer component is a stale duplicate.
2. **Portfolio pricing is wrong outside the top-100.** Desktop prices holdings only from the cached `crypto_assets_1_100` blob; stocks, metals, and long-tail coins get no live price. The live-refresh function `refreshHoldingPrices()` (`lib/api/portfolio.ts:68`) is dead code and passes symbols where CoinGecko expects ids.
3. **No delivery mechanism for anything.** iOS has APNs push with 12 granular categories plus locally-scheduled DCA reminders. Desktop's bell is synthesized client-side at query time; nothing arrives when the tab is closed. DCA — the core habit loop — silently doesn't remind on web.
4. **Desktop data is systematically staler.** iOS: 5-min home timer, 60-s portfolio prices, 15-s live signal polling, and live CoinGecko/FMP fallback when cache is stale. Web: one polling query (crypto assets, 60 s); everything else waits for tab refocus, and stale cache degrades to *demo data* rather than live fetch.
5. **Broken/no-op surfaces users will hit:** Settings "Upgrade to Premium" does nothing; "Delete account" only signs out; currency preference is stored but never applied to formatting; `prompt()`/`confirm()` native dialogs for portfolio create/deletes; avatar upload triggers a full page reload; zero error states anywhere (failures render zeros or demo data silently).

---

## 2. Method

Three parallel code surveys, then manual verification of conflicting or high-stakes claims against source:

- iOS inventory: every module under `ArkLine/Features/`, root tab structure, `Domain/Models/HomeWidget.swift`, `Core/` (haptics, notifications, security), `SharedComponents/`.
- Desktop inventory: every route under `web/src/app/`, all 40+ hooks in `web/src/lib/hooks`, shared primitives, theme.
- Cross-cutting: data sources table-by-table, refresh/TTL policy, auth/session, design tokens hex-by-hex, notifications.

Claims below marked *(verified)* were re-checked directly in source after the surveys.

---

## 3. Where parity is already good

Worth stating so effort goes to real gaps, not re-plumbing:

- **Design tokens** match value-for-value on brand colors (`#3B82F6/#2563EB/#60A5FA`), success/warning/info, backgrounds (`#0F0F0F`/`#F8F8F8`), card `#1F1F1F`, spacing scale (2→48), radii (card 16 / button 8 / input 8), card shadow, and fonts (Inter + Urbanist both sides). `src/theme/tokens.ts` is an explicit mirror of `Colors.swift`.
- **Home widget catalog**: all 24 iOS widget types exist as desktop tiles (25 keys incl. hero variants), with the same default ordering, click-to-open detail drawers with lazy-loaded detail views, shaped skeletons per tile type, drag/reorder/resize with cloud-synced layout (`profiles.dashboard_layouts`), a customize panel, and 2 savable presets.
- **Supabase schema parity**: portfolios/holdings/transactions/history, broadcasts + reactions + bookmarks, member Q&A, DCA reminders, dictionary — same tables, compatible reads/writes.
- **Invite-code validation** on web deliberately mirrors iOS including payment_status/revoked/expired checks (`web/src/lib/api/onboarding.ts`).
- **Broadcasts (Insights) feed**: search, date filters, saved/bookmarks, pinned section, optimistic likes — close to iOS structure.
- **Dictionary and member Q&A** exist on both with near-equivalent capability.
- **Route protection + onboarding gating** via middleware is solid and mirrors the iOS coordinator logic.

---

## 4. Feature-by-feature parity matrix

Legend: ✅ parity · 🟡 partial · ❌ missing on desktop · ⬆️ desktop ahead

### Home

| Capability | iOS | Desktop | Status |
|---|---|---|---|
| 24-widget catalog + detail views | ✔ | ✔ (all built) | ✅ |
| Portfolio hero = user's actual portfolio | ✔ | Pinned hero ✔ / widget-drawer version charts **BTC** *(verified)* | 🟡 bug |
| Portfolio picker on hero | ✔ multi-portfolio | ✖ hardcoded `portfolios[0]` | ❌ |
| Add position from hero | ✔ | ✖ | ❌ |
| Widget sizes | compact/standard/expanded presets | free grid resize (min/max constraints) | 🟡 different model, arguably ⬆️ |
| Presets | up to named presets, cloud-synced, rename/delete | max 2, **localStorage only**, apply = full `window.location.reload` | 🟡 |
| Widget visibility | cloud-synced | localStorage only (no cross-device) | 🟡 |
| Stale-data banner + retry | ✔ | ✖ (silent zeros/demo data) | ❌ |
| Subscription/trial banner | ✔ | ✖ | ❌ |
| AI briefing | expand, sentiment pill, past-briefings archive, admin feedback, morning/evening/weekend slots | expand, regime badge, **TTS play button** ⬆️; no archive, no feedback | 🟡 |
| Notifications inbox | typed, deep-link routed, push-backed | synthesized 3-source feed, localStorage read-state | 🟡 |
| Financial disclaimer footer | ✔ | ✖ | ❌ |
| Refresh cadence | 5-min timer + 60-s prices + foreground refresh | refocus-based only (except crypto assets 60 s) | ❌ feel gap |

### Market

| Capability | iOS | Desktop | Status |
|---|---|---|---|
| Widget stack | 13 widgets, reorder via Edit mode | 13 widgets, drag/resize | ✅ |
| Customize / reset / visibility | ✔ (shared dashboard prefs) | **✖ — Home only**; Market has no Customize or Reset UI | ❌ |
| Coin detail | Swift Charts, 1H–ALL, stats grid, favorite, **branded share card** | chart 7D–ALL w/ tooltip, stats, watchlist star | 🟡 (no 1H/1D, no share card) |
| Coin search | live CoinGecko search (any coin) | top-100 cache slice only | ❌ |
| News | live RSS + curated, read/unread, topics incl. custom keywords, AI quick summary, paged reader | curated table only, plain cards | 🟡 |
| Altcoin screener | multi-line chart, scrub, tap-to-isolate, **landscape fullscreen** | drawer detail view | 🟡 |
| Trend channel / stock detail | synced dual-chart scrubbing, regression gauge, fullscreen | drawer views, no scrubbing | 🟡 |
| Signal detail | live P&L (15-s poll), trade structure chart, leverage calculator, adjust-entry | drawer summary | 🟡 deep gap |
| Swing performance | win-rate gauge, equity curve, **P&L calendar heatmap**, filters | ✖ | ❌ |
| Sentiment regime detail | quadrant chart, per-user notification toggle | shared sentiment drawer | 🟡 |

### Portfolio

| Capability | iOS | Desktop | Status |
|---|---|---|---|
| Multi-portfolio create/edit/delete | ✔ (public/private) | switcher + create via **`prompt()`**; no edit/delete UI | 🟡 |
| Asset classes | crypto / stock / metal / **real estate** | crypto only (top-100 search) | ❌ |
| Transaction entry | simple/advanced modes, historical price backfill for backdated buys, emotional-state picker | buy/sell modal, live price prefill, validation | 🟡 |
| Sell flow | Max, live P/L, **transfer proceeds to another portfolio** | sell tab in modal | 🟡 |
| Holdings detail | per-symbol history, swipe-delete, edit/sell from toolbar | hover Buy/Sell/Remove (`confirm()`) | 🟡 |
| Allocation | donut + target editor sheet + drift badges | donut + inline target % edit + drift | ✅ |
| Performance | Sharpe/drawdown/volatility, contribution bars, monthly bars, **export PNG/PDF/CSV** | Sharpe/drawdown/volatility, equity curve, CSV export | 🟡 |
| History tab | type filters, transaction detail sheet w/ realized P/L, edit | last-10 list only | ❌ |
| Model portfolios (Core/Edge/Alpha) | follow/track, NAV vs SPY, trade log, rebalance push | home widget + drawer only; no follow, no detail parity | ❌ |
| DCA calculator wizard (7-step, risk-based strategies) | ✔ | ✖ (simple reminder modal only) | ❌ |
| Portfolio Showcase (privacy-masked share image) | ✔ 4 privacy levels | ✖ | ❌ |
| Live pricing of holdings | live multi-source | cached top-100 only; `refreshHoldingPrices` dead + symbol/id bug *(verified)* | ❌ bug |

### Insights / Broadcasts

| Capability | iOS | Desktop | Status |
|---|---|---|---|
| Feed: search, date filters, saved, pinned | ✔ + colored multi-select tag pills, unread dots, tab badge | ✔ (no tag pills, no unread dots) | 🟡 |
| Content rendering | full markdown, voice notes w/ player, annotated images, embedded live app widgets (24 section types), portfolio attachments, linked deck, 6-emoji reactions | **markdown stripped to plain text**, ❤ like + bookmark only | ❌ big feel gap |
| Weekly Market Deck | story-style fullscreen reader, 12 slide types, 52-week history | slide-by-slide drawer reader | 🟡 |
| Member Q&A | ask/anonymous, hearts, admin answer + share card, targeted push | ask/anonymous, likes, delete-own | ✅ core / 🟡 extras |
| Admin studio (editor, AI refine, voice transcription, analytics, deck pipeline) | ✔ | ✖ (acceptable — admin lives on iOS) | n/a by design |

### Profile / Settings / Auth

| Capability | iOS | Desktop | Status |
|---|---|---|---|
| Profile edit + avatar | ✔ | ✔ but save-success = **full page reload**, silent failure | 🟡 |
| Appearance | light/dark/**automatic**, follows system by default | light/dark/system, **defaults to dark** *(verified)* | 🟡 mismatch |
| Personalization | avatar color theme, chart palette, risk display pref, news topics | ✖ | ❌ |
| Notification prefs | 12 granular toggles, wired to APNs | 6 toggles saved to profile, **wired to nothing** | ❌ |
| Currency | applied app-wide | stored; `formatCurrency` hardcodes USD | ❌ bug |
| Security | Face ID, passcode (PBKDF2-600k), lockout, privacy overlay | session cookie only | 🟡 (web norm differs; see §7) |
| Delete account | real flow w/ confirm | **signs out only** *(verified label vs behavior)* | ❌ bug |
| Subscription | manage/restore (RevenueCat or Stripe portal) | role badge + dead "Upgrade to Premium" button | ❌ bug |
| Feature request form | ✔ | ✖ | ❌ |
| Sign-in | Face ID / passcode / email+password / OTP | email+password | ✅ for web |

### Desktop is ahead (protect these)

⌘K global search with page jumps; briefing text-to-speech; freely resizable widget grid; sticky topbar with breadcrumbs; hover-reveal actions; the `/api/glance` public feed; onboarding self-serve Stripe checkout; transaction CSV export directly from portfolio page.

---

## 5. The "feel" gap — why desktop doesn't yet feel flawless

These are the differences a user perceives within minutes, independent of the feature matrix.

**Freshness.** iOS refreshes Home every 5 minutes and portfolio prices every 60 seconds, polls live signals at 15 s, and falls back to live CoinGecko/FMP when the server cache is stale. Desktop refetches almost everything only on window refocus, and when cache misses it renders *demo data* with no indication. Two devices side-by-side will routinely disagree. iOS also surfaces staleness honestly (StaleDataBanner + retry, "Updated Xm ago"); desktop never does.

**Error handling.** iOS: error banners with retry, per-card retry in sentiment, toasts. Desktop: zero error states anywhere — failed queries fall back to zeros or demo values, and failed mutations (profile save, settings save) are swallowed silently. "Flawless" requires *visible honesty* when things fail, not silence.

**Micro-interactions.** iOS uses haptics (tab switch, favorites, chips, toggles), matchedGeometry pill transitions, numeric text transitions, scroll-to-top on tab re-tap, optimistic updates with revert. Desktop has good foundations (count-ups, shine sweeps, hover scale) but breaks the spell with native `prompt()`/`confirm()` dialogs, a full `window.location.reload` on preset apply and avatar save, and no toast system at all.

**Chart interactivity.** iOS charts scrub (drag on ArkLine score history, macro indicators, synced dual-chart scrubbing on trend channel, tap-to-isolate on the screener, landscape fullscreen). Desktop tile sparklines have no tooltips and drawer charts have hover tooltips at best. On a desktop with a mouse, hover scrubbing should be the *strength* of the platform — right now it's behind the touch app.

**Content richness in Insights.** iOS renders full markdown, voice notes, annotated images, and live embedded widgets inside broadcasts. Desktop strips markdown to plain text. Same data, dramatically flatter experience — this is the single biggest "these don't feel like the same product" moment for a paying member.

**Typography discipline.** iOS has an explicit type scale (`Fonts.swift`: display numbers 64/44/36, Urbanist titles 32/30/24/20, body 16/14, captions). Desktop has **no typography tokens** — ad-hoc Tailwind `text-sm/xs` per component — which produces subtle inconsistency across pages that reads as "less polished" even when nobody can name why.

**Token drift (dark mode)** *(verified)*: `textSecondary` iOS `#475569` vs web dark `#A1A1AA`; `textTertiary` `#64748B` vs `#71717A`; `error` `#DC2626` vs web dark `#EF4444`; theme default dark on web vs follow-system on iOS. Note the web values are arguably *better* (iOS slate-600 on near-black is borderline illegible) — the right fix may be to change iOS, but pick one source of truth.

---

## 6. Bug list (correctness, not parity)

> **Update (July 7, 2026):** B1–B5 fixed, plus native `prompt()`/`confirm()` dialogs replaced with styled `ConfirmDialog`/`PromptDialog`, a toast system added (`components/ui/toast.tsx`), mutation errors surfaced on settings/profile/portfolio/DCA/Q&A, and the avatar-upload full-page reload removed. Live pricing now flows through `usePricedHoldings`/`useLivePrices` (60 s refresh; CoinGecko id resolution + FMP stocks + metals via `api-proxy`). Currency preference applies app-wide (formatting only — matches iOS, no FX conversion). Verified with tsc + eslint (0 errors); full `next build` not runnable in the analysis sandbox (macOS-native lightningcss binary).

| # | Bug | Where | Severity |
|---|---|---|---|
| B1 | Portfolio widget drawer charts BTC price as if it were the portfolio | `home/portfolio-hero.tsx` (drawer import at `bento-grid.tsx:86`) vs correct pinned hero at `bento-grid.tsx:1761` | **P0** — wrong financial data |
| B2 | Holdings priced only from top-100 cache; stocks/metals/long-tail unpriced; `refreshHoldingPrices()` never called and passes symbols as CoinGecko ids | `lib/api/portfolio.ts:68-90`, `dashboard/portfolio/page.tsx` | **P0** |
| B3 | "Delete account" signs out without deleting anything | `dashboard/settings` | **P0** — trust/compliance |
| B4 | Currency preference stored but `formatCurrency` hardcodes USD | `lib/utils/format` + settings | P1 |
| B5 | "Upgrade to Premium" button has no handler (also conflicts with anti-steering posture — should likely not exist on web either way) | settings | P1 |
| B6 | Notification toggles persist to `profiles.notifications` but no delivery infra exists | settings | P1 (or label as "applies to iOS app") |
| B7 | Theme saved to `profiles.dark_mode` but never hydrated from profile; localStorage only | `use-theme.tsx` | P2 |
| B8 | Demo-data fallback can silently show fabricated numbers in production when cache misses | `lib/api/market.ts`, `macro.ts` | P1 — worse than an error state in a finance product |
| B9 | Topbar breadcrumb map missing dictionary/faq/qa entries (shows "Dashboard") | `shared/topbar.tsx` | P3 |

**Also — documentation drift discovered during this analysis (worth fixing so agents don't act on false constraints):** `CLAUDE.md` states "zero StoreKit/IAP" and describes an AIChat feature. In reality the iOS app now ships **RevenueCat + `ArkPaywallSheet`** (in-app renewal path, restore purchases), and **no `Features/AIChat/` module exists** on either platform. `Features/Community/` on iOS is dead code (unreachable), which desktop correctly mirrors by redirecting `/dashboard/community` → broadcasts.

---

## 7. Recommended roadmap

### Phase 0 — Correctness (do first; small, surgical)
Fix B1 (point the drawer at the real hero component or delete the stale duplicate), B2 (call a fixed `refreshHoldingPrices` with proper CoinGecko ids via the existing `api-proxy` edge function; add FMP path for stocks/metals), B3, B4, B5. Replace every `prompt()`/`confirm()` with the existing DetailDrawer/modal primitives. Add a minimal toast system and surface mutation failures. Replace silent demo-data fallback with an explicit stale/error tile state ("Data unavailable — retry").

### Phase 1 — Feel parity (the "no difference" bar)
Freshness: add `refetchInterval` to portfolio/market-critical queries (60 s prices, 5 min widgets — mirror iOS numbers), refetch-on-focus everywhere, and a StaleDataBanner equivalent. Ship the iOS-style "Updated Xm ago" labels. Sync widget visibility + presets to `profiles` (layouts already sync); remove the reload-on-preset-apply. Portfolio picker + add-position on the home hero. Market page gets Customize/Reset like Home. Render broadcast markdown properly + audio player + image lightbox (data is already there). Unify dark-mode text/error tokens with iOS (decide the source of truth once). Add a typography token layer mirroring `Fonts.swift`. Theme default = system, hydrated from profile.

### Phase 2 — Enhanced desktop (justify the bigger screen)
Hover scrubbing on every chart (crosshair + synced tooltips — desktop should beat iOS here); larger multi-pane detail views instead of one-at-a-time drawers (e.g., signal detail with live P&L + trade structure + leverage calc side-by-side); transaction history tab with filters and editing; DCA calculator wizard; model-portfolio follow + full detail; portfolio showcase/share images (ImageRenderer equivalent via canvas/`html-to-image`); keyboard shortcuts beyond ⌘K (g h / g m navigation, arrow-key widget focus); Web Push (service worker + `user_devices` reuse) so DCA reminders and broadcasts actually arrive — this is the one infrastructure lift, and it unlocks the notification settings that already exist.

### Phase 3 — Long-tail polish
Read/unread news state, custom news topics, share cards, avatar/chart color personalization, feature-request form, real coin search beyond top-100, granular per-card retry like iOS sentiment.

---

## 8. What would help me help you

1. **Run both side-by-side and screenshot** the same account on iOS + desktop — I can only compare code; a visual pass would catch spacing/density issues code can't. If you enable Chrome/browser access for me with the dev server running, I can drive the desktop app myself and audit interactions live.
2. **Decide the design-token source of truth** for the dark-mode text/error colors (web's values look more legible; iOS should probably adopt them).
3. **Confirm the RevenueCat/IAP situation** so CLAUDE.md can be corrected — right now the docs prohibit what the app already ships, which will confuse every future agent session.
4. **Priority call:** if you want one thing that most changes perceived parity for paying members, it's Phase 1's broadcast rendering + freshness work; if you want the most trust-critical, it's Phase 0's pricing bugs.
