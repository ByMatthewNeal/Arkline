# Arkline — Desktop (Web) vs iOS Parity Audit — August 2026

Supersedes `DESKTOP_PARITY_AUDIT.md` (Jun 14, home-widgets only) and `DESKTOP_IOS_DEEP_ANALYSIS.md` (Jul 7). Both are now stale — the web app and the iOS app have both moved a lot since.

**One-line status:** The desktop app has closed most of the June gaps and is now at or near parity on the *core dashboard* (Home, Market, Portfolio, DCA, Broadcasts, Q&A, Dictionary, Profile, Settings, Onboarding, auth, marketing). The remaining divergence is concentrated in a few areas the iOS app has kept extending — above all the **Education / Learning system**, which does not exist on web at all.

---

## 1. Where desktop is AT PARITY (built & wired to live Supabase data)

- **Home dashboard** — `home/bento-grid.tsx`. ~25 widget tiles, pinned Portfolio + Briefing heroes, drag-and-drop `react-grid-layout`, **Customize panel, visibility toggles, and layout persistence/presets**. This closes the big June gaps (the old audit listed 13 missing widgets + "no customize/presets"; those are largely done: US Futures, Signal Changes, Market Breadth, Rotation, VIX/DXY/M2, Stock Risk, Trade Signals, Model Portfolio, Perp Premium, Fed Watch tiles all exist now).
- **Market** — `market/market-bento-grid.tsx` (13 tiles) + per-asset detail page `/dashboard/market/[coin]`.
- **Portfolio** — multi-portfolio switcher, live crypto/stock/**metal** pricing via `api-proxy`, add/sell holdings, allocation donut w/ target %, 365-day history, transactions + CSV, embedded Model Portfolio card.
- **DCA** — full CRUD on `dca_reminders`, stats, Plan Wizard, log-investment.
- **Broadcasts / Insights** — feed, markdown, image gallery, audio, pinned, search/filters, view/like/bookmark, Ask-a-Question.
- **Member Q&A** — ask/like/delete, plus **admin answer composer** (role-gated).
- **Dictionary** — DB-driven search + categories.
- **Profile / Settings** — profile edit + avatar upload; theme, currency, notification prefs, delete-account.
- **Onboarding** — multi-step wizard with self-serve **Stripe** step.
- **Auth** (login/signup w/ invite code, reset, renew, payment-success) and **marketing** pages.

---

## 2. The REAL gaps vs the CURRENT iOS app (prioritized)

### 🔴 P0 — Education / Learning system (entirely absent on web)
This is the single largest divergence, and iOS keeps widening it.

iOS has, with **no web counterpart:**
- A **Resources/Learn hub** with guided **trails** (Foundations, Behavioral, Scams, Crypto, Traditional Markets, Trading, Macro, Hedging, Fees & Taxes, How-Much-to-Own/sizing, Before-You-Invest), served from `trail_lessons`.
- A **Curriculum "guided path"** engine: Continue card, progress tracking, "Your Path" map, onboarding routing.
- **Explainers** (the "?" inline lessons on widget headers) and a **StartHere intro**.
- An illustration library for lessons and an **admin lesson editor**.

Web's only "education surface" today is Dictionary + a static FAQ + Q&A + tiny inline `DefineTerm` popovers on a couple of tiles. **Recommend building a `/dashboard/learn` section that reads `trail_lessons` (same tables/RLS as iOS).**

### 🟠 P1 — Metals is pricing-only on web
iOS now ships a full **Metals model portfolio** (systematic gold book: 40–60% core, valuation-driven) plus metals as an asset class. Web supports metals **only as portfolio pricing** (`fetchMetalPrices`). There is no metals model-portfolio UI, no metals detail surface. Since web reads `model_portfolios`/`model_portfolio_nav` generically, the Metals book may already appear in the model-portfolio list, **but its detail rendering won't match iOS** (see next).

### 🟠 P1 — Model-portfolio detail parity
iOS added this cycle: **Position History timeline** (open/closed positions, entered→exited, rationale, P&L), blended cost basis for metals, consistency "stance" chips, extended equity backtests, and the Alpha book retired. Web fetches model portfolios generically but has **none of these detail views** and predates the Alpha retirement (a comment still references "Core / Edge / Alpha"). Web will need: metals-aware detail, the Position History view, and to drop Alpha.

### 🟡 P2 — Risk Levels search + asset coverage
- iOS just added a **search bar** to Crypto and Stock Risk Levels (filter by name/ticker) — web risk-level lists have no search yet, and the lists are growing.
- **Data-source nuance:** iOS computes risk **client-side** from `AssetRiskConfig`; web reads a **server cache**. So newly added tickers (e.g. ETN, OKLO, AMD, WYFI) appear on iOS immediately but on web only if the server risk pipeline includes them. Worth verifying the two lists actually match.

### 🟡 P2 — Polish / stubs
- Several Home widget **detail drawers** fall back to "Detailed view coming soon."
- **Browser push notifications** are stubbed ("coming soon", preference saved only).
- **FAQ is hard-coded** static content (iOS/DB may differ).
- Marketing social-proof still says "coming soon"; `constants.ts` has a `TODO: App Store URL`.

---

## 3. iOS-only — does NOT apply to web
- **In-app update prompt** (App Store "update available" banner + hard gate) — iOS-specific; web auto-updates on deploy. No action.
- App Store metadata / screenshots / ASO — iOS distribution only.

---

## 4. Recommended build order for desktop
1. **Education / Learning** (`/dashboard/learn`) — trails + lessons from `trail_lessons`, a Learn widget on Home, and the "?" explainers. Biggest parity + product value. (Start with trail list + lesson reader; add the guided-path/Continue card second.)
2. **Model-portfolio detail parity** — metals-aware detail, Position History, drop Alpha. (Unblocks the Metals story too.)
3. **Risk Levels search** + verify ETN/OKLO/AMD/WYFI show on web (align server cache with iOS `AssetRiskConfig`).
4. **Polish**: fill the "coming soon" widget drawers, enable browser push, make FAQ DB-driven.

---

## 5. How to verify (quick checks before building)
- Web education: confirm there is truly no `trail_lessons` fetch (`grep -ri trail web/src`).
- Metals model portfolio on web: load `/dashboard/portfolio` model card and check whether the Metals book renders and how.
- Risk-level asset lists: compare web risk-levels list vs iOS `AssetRiskConfig.stockConfigs` / `cryptoConfigs`.
