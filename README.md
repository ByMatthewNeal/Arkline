# ArkLine

**Crypto & macro intelligence for investors who want clarity, not noise.**

ArkLine is an iOS app that tracks cryptocurrency and traditional markets through the lens of risk, sentiment, and positioning — not just price. It combines proprietary risk models, macro regime analysis, AI-generated daily briefings, and systematic trade signals into a single surface designed for investors who think in terms of cycles, not candles.

## What it does

- **Regression Risk Scores** — logarithmic regression from genesis for 41 crypto assets, bucketed by risk band (Low / Neutral / Elevated / High / Extreme) with a 7-factor composite cross-check
- **ArkLine Score** — daily 0-100 composite of 11 macro and sentiment indicators (Fear & Greed, BTC cycle risk, VIX, DXY, net liquidity, funding rates, crude oil, app store FOMO, capital flow, altcoin season)
- **Daily Briefings** — AI-generated morning and evening market summaries with macro, technical, and positioning context. TTS audio available.
- **Trade Signals** — Fibonacci confluence-based swing (4H) and scalp (1H) signals with automated entry, stop loss, and target levels
- **Daily Positioning (QPS)** — 54-asset daily bullish/neutral/bearish positioning signals across crypto, indices, commodities, and stocks
- **Model Portfolios** — Arkline Core (conservative) and Edge (aggressive) systematic crypto portfolios with daily rebalancing
- **Portfolio Tracking** — multi-portfolio support for crypto, stocks, commodities, and real estate with P&L, allocation charts, and DCA tracking
- **Macro Dashboard** — VIX, DXY, global M2 liquidity, yield curve regime, economic calendar with real-time event analysis
- **Curated News** — AI-filtered Bloomberg + Google News RSS with relevance scoring and 3-bullet takeaways

## Tech stack

| Layer | Technology |
|-------|-----------|
| iOS app | SwiftUI, Swift 5.9, @Observable, MVVM |
| Backend | Supabase (Auth, PostgreSQL, Edge Functions, Storage) |
| APIs | CoinGecko, FMP, FRED, Taapi.io, Coinbase, Claude AI |
| Website | Next.js (App Router), Vercel, Tailwind CSS |
| Payments | Stripe (web-only checkout, no in-app purchase) |
| Crash reporting | Apple MetricKit |
| Image loading | Kingfisher |

## Architecture

```
ArkLine/
├── App/                    # Entry point, ContentView routing, AppState
├── Core/
│   ├── Extensions/         # Swift extensions
│   ├── Theme/              # Design tokens (Colors, Typography, Spacing)
│   └── Utilities/          # Constants, Logger, Cache, Keychain, Passcode
├── Data/
│   ├── Network/            # NetworkManager, APIProxy (SSL pinning), APIEndpoint
│   ├── Services/
│   │   ├── API/            # Real service implementations
│   │   ├── Mock/           # Mock services for development
│   │   ├── Protocols/      # Service protocol definitions
│   │   └── Diagnostics/    # MetricKit crash reporting
│   └── Supabase/           # Client config, Auth, Database DTOs
├── Domain/Models/          # Data models (User, Portfolio, Risk, Signals, etc.)
├── Features/
│   ├── Authentication/     # Login, passcode, biometrics, password sign-in
│   ├── Home/               # Dashboard, risk cards, briefings, widgets
│   ├── Market/             # Sentiment, QPS positioning, signal detail
│   ├── Portfolio/          # Multi-portfolio management, DCA tracking
│   ├── Onboarding/         # Invite code, email verification, profile setup
│   ├── Settings/           # Preferences, FAQ, About, feature requests
│   ├── Admin/              # Invite management, Stripe integration
│   └── ...
└── SharedComponents/       # Reusable UI (inputs, cards, charts, share kit)
```

### Server-side

- **7 cron jobs** running on Supabase Edge Functions (crypto price sync, economic events, news curation, positioning signals, model portfolios, signal pipeline, signal monitor)
- **API proxy** Edge Function routes sensitive API calls through Supabase to avoid exposing keys in the iOS binary
- **3-tier caching** — L1 (in-memory), L2 (Supabase `market_data_cache` table), L3 (external APIs)

## Business model

Invite-only, single subscription tier. All payments processed via Stripe on the web — the iOS app contains zero StoreKit code. Architecture follows the SaaS client / reader-app model (Spotify, Notion, 1Password).

## Security

- API keys loaded from `Secrets.plist` (stripped from release builds) + XOR-obfuscated `ObfuscatedSecrets.swift` for on-device keys
- SSL certificate pinning via `PinnedURLSession` (all network calls routed through pinned session)
- Direct API fallback gated to `#if DEBUG` — release builds route exclusively through the Edge Function proxy
- PBKDF2 passcode hashing with Keychain storage
- RLS policies on all Supabase tables
- Privacy overlay on app switcher

## Development

**Requirements:** Xcode 16+, iOS 17+, Node.js 24+ (for Supabase CLI and web)

```bash
# iOS
open ArkLine/ArkLine.xcodeproj

# Supabase Edge Functions
npx supabase functions serve

# Website
cd web && npm run dev

# Deploy edge function
npx supabase functions deploy <function-name> --project-ref mprbbjgrshfbupheuscn --no-verify-jwt

# Push database migrations
npx supabase db push

# Deploy website
cd web && npx vercel --prod
```

## License

Proprietary. All rights reserved. Arkline Technologies LLC.
