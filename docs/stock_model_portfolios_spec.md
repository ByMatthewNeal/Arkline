# Stock Model Portfolios — Feature Spec

> **Status:** Draft for Matt's review · **Date:** 2026-07-14
> **Basis:** Bull Market Blueprint framework (Intelligent New World, Equity Valuation Tools, Macro Investing Foundations) mapped onto the existing crypto model portfolio system.

---

## Problem Statement

ArkLine's model portfolios are crypto-only (Core / Edge / Alpha). Users who want equity exposure — the "Businesses" leg of the Three B's framework the product's philosophy draws from — have nothing to follow. A user should be able to open ArkLine, choose to follow a **stock portfolio and/or a crypto portfolio**, and get the same transparent NAV, allocation, and trade-log experience for both.

## Goals

1. Two stock model portfolios live in the app, visually and structurally consistent with the crypto ones.
2. Users can follow one crypto **and** one stock portfolio simultaneously.
3. Daily NAV marked automatically; zero recurring manual work except when Matt changes holdings.
4. Users can compare stock vs crypto performance and regime at a glance and decide for themselves where to allocate (see Cross-Market Comparison).
5. ≥30% of users who view model portfolios follow a stock portfolio within 60 days of launch.

## Non-Goals (v1)

- **Fully systematic stock rebalancing.** The blueprint's equity process is judgment-based (PEG reads, catalysts, drawdown adds). Holdings are curated by Matt; the pipeline computes. Codifying rules is a later experiment.
- **Per-stock risk scores** (the log-regression model is crypto-specific). Valuation context (PE / forward PE / PEG) replaces it — P1.
- **User-built custom portfolios.** Separate initiative.
- **Reproducing BMB content.** The framework informs structure; names, holdings, and copy are ArkLine originals (BMB is paid membership IP — do not ship their slot tables, tickers, or text).

---

## The Two Portfolios

Mirrors the crypto Core/Edge tiering.

> **These are investment portfolios, not trading portfolios.** Positions are held for weeks, months, or years. All UI copy reflects this: "position changes" and "rebalances," never "trades" or trading language. Low turnover is a feature, not a limitation — surface it ("3 position changes this year").

### 1. "Arkline Equity Core" — conservative (`strategy: "stock_core"`)

- 8–10 positions, quality mega-cap compounders across the three AI stages (builders / enablers / adopters), 5–10 year horizon.
- Position cap 12%; cash sleeve 5–40% scaled by macro regime (risk-off ⇒ more cash).
- Turnover: rare. Adds on 20–30% drawdowns in core names; trims on parabolic overextension or extreme overvaluation (PEG > 2 without a durable moat).

### 2. "Arkline Equity Edge" — aggressive (`strategy: "stock_edge"`)

- Full 70/30 structure: ~9 core positions (70%) + ~5 thematic positions (30%, 6–12 month catalyst horizon).
- Position cap 10%; thematic slots rotate; a thematic name can graduate to core.
- Cash 0–25% by regime. Higher turnover than Core, still low in absolute terms.

Both: starting NAV **$50,000** (parity with crypto), benchmark **SPY** (reuses `benchmark_nav`), USD cash sleeve accrues a money-market-style yield (parameterized, ~4%/yr).

---

## System Design

### Curation model ("Matt curates, pipeline computes")

New table holds **target allocations**. Matt posts a new target when holdings change; the daily function applies it, logs the trade, and otherwise just marks NAV to market.

### Data model changes (Supabase migration)

```sql
-- 1. Distinguish asset classes
alter table model_portfolios
  add column asset_class text not null default 'crypto'
    check (asset_class in ('crypto','stock')),
  add column benchmark text not null default 'SPY',
  add column display_order int;

-- 2. Curated targets (the "trade instruction" mechanism)
create table model_portfolio_targets (
  id uuid primary key default gen_random_uuid(),
  portfolio_id uuid not null references model_portfolios(id),
  effective_date date not null,
  allocations jsonb not null,          -- {"NVDA": 0.10, "AMZN": 0.10, ..., "CASH": 0.15}
  rationale text,                      -- shown in trade log market_context
  created_at timestamptz default now(),
  unique (portfolio_id, effective_date)
);

-- 3. Generic signal context for stock NAV rows
alter table model_portfolio_nav
  add column signal_context jsonb;     -- {"vix": 14.2, "leading_sectors": ["Tech","Semis"], "breadth_pct": 62, ...}

-- 4. Two new portfolio rows (asset_class='stock', universe = ticker list)
-- 5. Follow one per class
alter table profiles add column followed_stock_portfolio text;
```

Existing crypto-specific NAV columns (`btc_signal`, `gold_signal`, `dominant_alt`) stay null for stock rows; `macro_regime` is shared. No changes to crypto behavior.

### New edge function: `compute-stock-portfolios`

Sibling of `compute-model-portfolios`, scheduled **weekdays ~21:05 UTC** (after US close). Per portfolio:

1. Skip non-trading days (weekend/holiday check via FMP `is-the-market-open` or calendar table).
2. Fetch prices for the union of held tickers via FMP batch quote (**FMP key already in env** — same vendor as SPY benchmark).
3. Check `model_portfolio_targets` for a target with `effective_date <= today` newer than the last applied one → rebalance, write `model_portfolio_trades` row (trigger `"target_update"`, rationale + curated headlines/events in `market_context` — reuse `fetchMarketContext`).
4. Otherwise mark-to-market (reuse `computeNav` logic; CASH accrues daily yield like USDC).
5. Compute `signal_context`: macro regime (reuse `determineMacroRegime` over positioning signals incl. VIX), leading sectors from `sector_performance`, breadth from `market_breadth`.
6. Write `model_portfolio_nav` row. SPY benchmark continues to be written by the existing crypto function (no duplication).

Shared helpers (`computeNav`, `fetchMarketContext`, `enforceExposureCaps`, regime logic) should be extracted to `functions/_shared/portfolio.ts` rather than copy-pasted.

**P1:** nightly valuation snapshot per holding (PE, forward PE, PEG from FMP) into a `model_portfolio_valuations` table → powers the app's stock "decision logic" card using the PEG bands (<1 cheap · 1–2 fair · >2 premium).

### iOS changes

| Area | File(s) | Change |
|---|---|---|
| Model | `Domain/Models/ModelPortfolio.swift` | Add `assetClass`, `benchmark`; fix `returnPct` to use `startingNav` instead of hardcoded 50000; decode `signal_context` |
| ViewModel | `Features/Portfolio/ViewModels/ModelPortfolioViewModel.swift` | Replace hardcoded `coreNav/edgeNav/alphaNav` with storage keyed by portfolio id; `followedStrategy` → one follow per asset class (`followed_model_portfolio` + `followed_stock_portfolio`) |
| Service | `APIModelPortfolioService.swift` | No structural change; fetches are already generic |
| Overview UI | `Features/Portfolio/Views/ModelPortfolioCard.swift` + parent | **Crypto \| Stocks** segmented control (or grouped sections); user picks either or both. Entry: "Which portfolios do you want to follow — crypto, stocks, or both?" (also as an onboarding step, P1) |
| Detail UI | `ModelPortfolioDetailView.swift` | Reuse NAV header, performance chart vs SPY, allocation, trade log, stats, disclaimer. Branch by `assetClass`: crypto keeps QPS/BTC-risk sections; stocks show regime + VIX + leading sectors (P0) and valuation card (P1) |
| Home | `ModelPortfolioUpdateCard.swift` | Surface updates for followed portfolios of both classes |

### Cross-Market Comparison — "Where the returns are"

The core product goal: users should see, at a glance, which market is currently delivering returns (and which is gearing up) so they can make their own informed allocation decision. Data, not advice — ArkLine presents; the user decides.

**P0 — Comparison strip** (top of the model portfolio overview, above the Crypto | Stocks sections):

- Side-by-side returns over a selectable window (7D / 30D / 90D / YTD): best crypto portfolio · best stock portfolio · BTC · SPY.
- A regime badge per market: crypto (BTC risk category + macro regime, existing) and stocks (macro regime + VIX band, from `signal_context`).
- All data already computed — this is a read-across of `model_portfolio_nav` + `benchmark_nav`; no new backend work.

**P1 — Momentum & rotation context:**

- Relative strength: BTC/SPY ratio trend (rising = crypto leading, falling = stocks leading) — computable from existing price history.
- Global liquidity direction (the `sync-global-liquidity` function already ingests this) with the framing from the macro framework: expanding liquidity historically favors crypto/growth; contracting favors defensives/cash.
- One-line neutral summary per market, e.g. "Stocks: risk-on, tech leading, VIX 14" / "Crypto: BTC risk elevated, liquidity flat." Generated from signals, no editorializing ("buy now" language is out).

**Guardrail:** copy must stay descriptive ("crypto has outperformed stocks by X% over 30D") never prescriptive ("move money into crypto"). Keeps the compliance posture identical to the existing disclaimer stance.

### Compliance

Reuse the existing model-portfolio disclaimer verbatim pattern; add equity wording ("hypothetical model, not investment advice, past performance…"). Same placement as crypto detail view.

---

## Phasing

- **P0 (ship):** migration + 2 portfolio rows + targets table + `compute-stock-portfolios` (NAV, trades, regime context) + iOS asset-class chooser, follow-per-class, detail view with shared components + disclaimer.
- **P1:** valuation snapshots + PEG-band decision card, sector/breadth context section, onboarding step, push notification on stock trade log entries.
- **P2:** per-stock fair-value analog, drawdown-add alerts ("Core name −25% from high"), combined stocks+crypto blended view, custom portfolios.

## Acceptance Criteria (P0)

- [ ] Both stock portfolios appear alongside crypto ones with live NAV within 1 trading day of seeding
- [ ] Inserting a `model_portfolio_targets` row rebalances next run and produces a trade-log entry with rationale
- [ ] NAV unchanged on weekends/holidays; no spurious rows
- [ ] User can follow one crypto and one stock portfolio at once; both sync to `profiles`
- [ ] Crypto portfolios behave byte-for-byte as before (no regression in NAV series or UI)
- [ ] Return % correct for any starting NAV (no hardcoded 50000)

## Decisions (Matt, 2026-07-14)

1. **Names:** Arkline Equity Core / Arkline Equity Edge. ✅
2. **Initial holdings + weights:** proposal drafted for sign-off → `docs/equity_portfolio_holdings_proposal.md`. ⏳
3. **Backfill from 2026-01-01** at $50k. The edge function needs a backfill mode: historical daily closes from FMP, initial target effective 2026-01-01, held static through the backfill window (unless Matt specifies interim position changes). Backfilled NAV must be labeled "simulated/backtested" in the app per compliance norms — the disclaimer must distinguish backfilled history from live tracking.
4. Cash yield: default 4.0% (unconfirmed, non-blocking).
5. **Position changes fire a broadcast + push notification** like crypto updates. ✅
6. **Framing:** investment portfolios, not trading — reflected in all copy (see The Two Portfolios).
