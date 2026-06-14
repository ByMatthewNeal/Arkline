# Arkline — API & Infrastructure Overview

**Prepared: May 22, 2026**

---

## External APIs (Market Data)

| API | What It Provides | Frequency |
|-----|-----------------|-----------|
| CoinGecko | Top 100 crypto prices, sparklines, global market cap, trending coins, coin charts | Every 5 min (server-side cache) |
| FMP (Financial Modeling Prep) | Stock/crypto quotes, historical prices, economic calendar, gainers/losers, sector performance | Every 30 min (events) + on demand |
| FRED (Federal Reserve) | US M2 money supply, interest rates, DXY index, economic indicators | Daily |
| Yahoo Finance | VIX, DXY, crude oil (WTI), gold, stock/ETF prices | On demand |
| Binance Data API | Historical daily candles for crypto (baseline price history for risk model) | On demand |
| Binance Futures API | Funding rates, premium index, perpetual contract data | On demand |
| Coinbase API | Daily OHLC candles for crypto (incremental price history) | Daily |
| Coinglass | Open interest, liquidations, funding rates, long/short ratios | On demand |
| Santiment (GraphQL) | BTC supply in profit (on-chain) | On demand |
| TAAPI | Technical indicators (RSI, SMA, Bull Market Support Bands) | On demand |
| Metals API | Gold, silver, platinum, palladium prices | On demand |
| Finnhub | Economic calendar events | Every 30 min |

---

## Scrapers & RSS Feeds

| Source | What It Provides | Method |
|--------|-----------------|--------|
| Google News RSS | Crypto news, market news, geopolitical news | RSS feed parsing |
| Bloomberg RSS | Markets, economics, technology, politics news | RSS feed parsing |
| Wikipedia Pageviews API | Bitcoin search interest (normalized 0-100) | Public API (Google Trends proxy) |
| Investing.com | Economic calendar events | Web scraping |
| Farside Investors | Bitcoin ETF flow data | Web scraping |

---

## AI / LLM APIs

| API | What It Powers |
|-----|---------------|
| Claude (Anthropic) | Article summaries, economic event analysis, trade signal briefings, weekly market deck generation, reel scripts, news curation, in-app AI chat |
| OpenAI (TTS) | Text-to-speech audio for daily market briefings |
| Tavily Search | Web search for market deck research context |

---

## Payment & Infrastructure

| Service | Purpose |
|---------|---------|
| Stripe | Subscription payments (web checkout, webhooks, billing portal) |
| Supabase | Auth, PostgreSQL database, Edge Functions, Storage, Realtime |
| Vercel | Website hosting (Next.js) |
| Apple Push Notifications | Signal alerts, broadcast notifications |

---

## Edge Functions (Scheduled Cron Jobs)

| Function | Schedule | What It Does |
|----------|----------|-------------|
| sync-crypto-prices | Every 5 min | CoinGecko top 100 to cache |
| sync-economic-events | Every 30 min | FMP economic calendar to DB |
| compute-positioning-signals | Daily 00:15 UTC | SMA/RSI/trend score for 54 assets |
| compute-model-portfolios | Daily 00:30 UTC | Core & Edge portfolio allocation |
| compute-rotation-signals | Daily 01:00 UTC | Crypto vs equities sector rotation |
| compute-market-breadth | Daily 01:30 UTC | % of tokens in uptrend + EMA trend |
| fibonacci-pipeline | Every 30 min | Swing trade signal generation |
| signal-monitor | Periodic | Monitors active signals for SL/TP hits |
| curate-news | Every 30 min | AI-curated news from RSS feeds |
| publish-scheduled | Periodic | Auto-publishes scheduled broadcasts |
| collect-trends | Daily | Wikipedia pageviews to search interest |
| generate-market-deck | Saturday 10am ET | Weekly market update slide deck |

---

## Data Points (45+ Supabase Tables)

**User:** profiles, user_devices, invite_codes, subscriptions, early_access_signups

**Portfolio:** portfolios, holdings, transactions, portfolio_history, dca_plans, dca_entries, dca_reminders

**Market Data:** market_data_cache, market_snapshots, indicator_snapshots, economic_events, ohlc_candles

**Signals:** positioning_signals, trade_signals, fib_confluence_zones, rotation_signals, sector_performance, market_breadth

**Model Portfolios:** model_portfolios, model_portfolio_nav, model_portfolio_trades, model_portfolio_risk_history, benchmark_nav

**Sentiment:** supply_in_profit, sentiment_history, google_trends_history, risk_snapshots, regime_snapshots, technicals_snapshots

**Content:** curated_news, market_update_decks, reel_scripts, broadcasts, broadcast_reads, broadcast_reactions, broadcast_bookmarks

**Social:** community_posts, comments, chat_sessions, chat_messages, chat_rooms, chat_room_messages

**Analytics:** analytics_events, daily_active_users, app_store_rankings, operating_costs, feature_requests, dictionary

---

## Summary

- **16** external APIs
- **5** scrapers / RSS feeds
- **3** AI services
- **12** scheduled cron jobs
- **45+** database tables
- **206,000+** lines of code (iOS + Edge Functions + Website)

---

*Arkline Technologies LLC*
