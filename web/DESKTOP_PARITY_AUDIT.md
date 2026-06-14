# Arkline — iOS Home vs. Desktop Home Parity Audit

> Goal: the web dashboard home should be a 1:1 match of the iOS app home.
> Source of truth: `ArkLine/Domain/Models/HomeWidget.swift` (24-widget catalog) and
> `ArkLine/Features/Home/Views/HomeView.swift`. Desktop: `web/src/components/dashboard/home/bento-grid.tsx`.

## How the iOS home is structured

1. **Portfolio hero card** — always visible, with portfolio picker + time-period selector + "add position."
2. **AI Daily Briefing** — fixed position under the hero.
3. **Reorderable widget stack** — user-chosen widgets from a 24-item catalog.
4. **Customize sheet** — enable/disable widgets, set size (compact/standard/expanded), save up to 2 **presets**.
5. Supporting: notifications sheet, stale-data banner, subscription/trial banner, financial disclaimer, premium (Pro) gating per widget.

Desktop today: Portfolio hero tile + 12 fixed widgets in a draggable grid (reorder + reset only). No customize, no presets, no sizes, no premium gating.

## Widget-by-widget comparison

### Matched (12)
| iOS widget | Desktop tile |
| --- | --- |
| Portfolio (hero) | `portfolio` ✓ |
| Daily Briefing (`aiMarketSummary`) | `briefing` ✓ |
| ArkLine Risk Score (`riskScore`) | `arklineScore` (+ `riskChart`) ✓ |
| Fear & Greed (`fearGreedIndex`) | `fearGreed` ✓ |
| Core / Market Movers (`marketMovers`) | `marketMovers` ✓ |
| Macro Dashboard (`macroDashboard`) | `macro` ✓ |
| BTC Supply in Profit (`supplyInProfit`) | `supply` ✓ |
| Crypto Risk Levels (`assetRiskLevel`) | `assetRisk` ✓ |
| Upcoming Events (`upcomingEvents`) | `events` ✓ |
| Favorites (`favorites`) | `favorites` ✓ |
| DCA Reminders (`dcaReminders`) | `dca` ✓ |
| Daily News (`dailyNews`) | `news` ✓ |

### Missing on desktop (13)
| iOS widget | What it shows | Live data source | Buildable |
| --- | --- | --- | --- |
| **Trade Signals** (`flashIntel`) | Fibonacci trade signals across timeframes | `trade_signals` (150 rows) | ✅ |
| **Signal Changes** (`qpsSignals`) | Daily positioning signal changes, 8 assets | `positioning_signals` | ✅ |
| **Crypto/Equities Rotation** (`rotationGauge`) | When to favor crypto vs equities + sector ranks | `rotation_signals`, `sector_performance` | ✅ |
| **Market Breadth** (`marketBreadth`) | % tokens in uptrend, EMA crossover | `market_breadth` (96 rows) | ✅ |
| **Model Portfolio Updates** (`modelPortfolioUpdate`) | Latest rebalance of followed strategy | `model_portfolio_trades` (2,686) | ✅ |
| **Weekly Update** (`marketDeck`) | Weekly market slide deck | `market_update_decks` (13) | ✅ |
| **Perp Premium** (`perpPremium`) | Directional bias in perp futures | `daily_derivatives_snapshots` (78) | ✅ |
| **Stock Risk Levels** (`stockRiskLevel`) | Regression risk for select stocks | `indicator_snapshots` (`stock_risk_*`) | ✅ |
| **VIX** (`vixIndicator`) | Standalone VIX widget | `indicator_snapshots` (`vix`) | ✅ |
| **DXY** (`dxyIndicator`) | Standalone Dollar Index widget | `indicator_snapshots` (`dxy`) | ✅ |
| **Global M2** (`globalLiquidity`) | Standalone M2 liquidity widget | `indicator_snapshots` (`global_m2`) | ✅ |
| **US Futures** (`usFutures`) | S&P/Dow/Nasdaq futures + session | `benchmark_nav` / `risk_snapshots` (needs confirm) | ⚠️ likely |
| **Fed Watch** (`fedWatch`) | CME rate-cut probabilities | no cache key found yet | ⚠️ source TBD |

> Note: VIX/DXY/M2 exist *inside* the combined Macro tile on desktop, but iOS also
> offers them as separate, individually-addable widgets.

### Feature / UX gaps (beyond individual widgets)
- **Customize Home**: enable/disable any widget. Desktop has a fixed set of 12.
- **Widget sizes**: compact / standard / expanded. Desktop sizes are fixed.
- **Dashboard presets**: save & switch up to 2 layouts. Desktop has one layout + Reset.
- **Portfolio picker**: iOS supports multiple portfolios; desktop uses the first only.
- **Add position** from the home hero — missing on desktop.
- **Premium (Pro) gating** per widget (`isPremium`) — not enforced on desktop.
- Minor: notifications sheet, stale-data banner, subscription/trial banner, financial disclaimer.

## Recommended build order
1. **Quick wins (same data already wired):** VIX, DXY, Global M2 standalone, Market Breadth, Signal Changes, Stock Risk Levels.
2. **New data wiring:** Trade Signals, Rotation Gauge, Perp Premium, Model Portfolio Updates, Weekly Update deck.
3. **Confirm source then build:** US Futures, Fed Watch.
4. **Customize system:** enable/disable + sizes + presets (brings the "same experience" to parity, not just the widgets).
5. Polish: portfolio picker, add-position, banners, premium gating.
