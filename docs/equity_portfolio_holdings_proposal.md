# Equity Portfolio Holdings Proposal — for Matt's sign-off (v2)

> **Date:** 2026-07-14 · **Status:** DRAFT v2 — adapted from the reference portfolio (July 14 update) per Matt's direction: same themes, cash posture, and sizing mechanics; Arkline's own selection and weights.
> Valuations approximate from July 2026 public sources; exact PE/fPE/PEG pulled from FMP at seeding.

## Reference portfolio snapshot (July 14, 2026)

MSFT 10.5 · AMZN 10.4 · LLY 9.8 · ASML 8.8 · TSM 8.3 · META 4.0 (half-size, building) · CEG 3.5 · VST 3.2 · MP 2.8 · PLTR 2.5 (half-size, building) · CIFR 1.5 · **Cash 34.7**

Key mechanics to adopt: high cash reserve deployed gradually, half-size initiations sized up to target on technicals, and the update format (announcement → execution @ fill price → forward note) as the template for Arkline position-change broadcasts.

## How Arkline adapts (not mirrors)

- Same thematic pillars: AI compounders, nuclear/power (CEG, VST), rare earths (MP), AI software (PLTR), HPC/compute-adjacent (CIFR).
- Arkline keeps NVDA and GOOGL (reference holds neither) — our valuation framework justifies both, and it differentiates the product.
- Cash posture adopted: Core carries 30%, Edge 15% (vs my v1 draft's 20%/0%).

---

## Arkline Equity Core — conservative (`stock_core`)

8 positions + 30% cash. Compounders only, 5–10yr horizon, 12% cap.

| Ticker | Weight | Stage | Thesis (one line) |
|---|---|---|---|
| MSFT | 11% | 2–3 | AI distribution at scale: Azure + Copilot across the enterprise install base |
| AMZN | 11% | All 3 | The multi-stage template: largest AI consumer + infra builder (~$200B capex, Trainium) |
| LLY | 9% | 3 | GLP-1 dominance + NVIDIA biology supercomputer (fwd PE ~30, fair) |
| TSM | 9% | 1 | Sole scaled fab for AI silicon; cheapest growth-adjusted mega-cap in the trade |
| GOOGL | 8% | All 3 | Own silicon (TPU), own cloud, own adoption surface |
| ASML | 8% | 1 | EUV/high-NA monopoly; core-sized per reference posture despite premium PEG |
| META | 7% | 3 | AI-driven ads monetize immediately; open-model ecosystem hedge |
| NVDA | 7% | 1 | Accelerator standard; flat YTD after June reset — Arkline differentiator |
| CASH | 30% | — | Reserve for drawdown adds; scales with macro regime (~4% yield) |

## Arkline Equity Edge — aggressive (`stock_edge`)

Core sleeve 55% + thematic 30% + cash 15%. 10% cap, 14 positions.

**Core sleeve (55%):** MSFT 8 · AMZN 8 · TSM 7 · META 7 · NVDA 7 · LLY 6 · GOOGL 6 · ASML 6

**Thematic sleeve (30%)** — 6–12 month catalysts:

| Ticker | Weight | Theme / catalyst | Risk note |
|---|---|---|---|
| CEG | 7% | Nuclear baseload for data centers; PPA pipeline | ~33x PE, most reasonable of power trio |
| VST | 6% | Power generation growth leader for 2026 | Higher beta than CEG |
| PLTR | 6% | AI software adoption; software sector −20% YTD = contrarian entry | Rich multiple, sentiment-driven |
| MP | 5% | Rare earths — supply-chain onshoring catalyst | Policy-dependent, volatile |
| VRT | 3% | Cooling/power distribution | +105% YTD — parabolic flag, hence small |
| CIFR | 3% | HPC/AI compute conversion play | Speculative, smallest slot |

**Seeding mechanic:** thematic names can seed at half-size with cash correspondingly higher, then size up via new target rows — mirrors the reference workflow and generates natural broadcast content from day one.

---

## Backfill integrity flag (unchanged, now softer)

Backfilling from 2026-01-01 with today's holdings bakes in hindsight. The adopted ~30% cash posture mutes this (less flattering than a fully-deployed semis book), but pre-launch history must still be labeled *simulated/backtested* on the chart. Live tracking starts at ship.

## After sign-off

1. Seed `model_portfolios` (2 rows) + initial `model_portfolio_targets` effective 2026-01-01.
2. Backfill daily NAV from FMP historical closes.
3. Store final seeded valuations + rationale in the initial target row.

**Not investment advice — draft editorial content for ArkLine's model portfolios, subject to Matt's review and ownership.**

Sources: [Intellectia — AI semis July 2026](https://intellectia.ai/blog/ai-semiconductor-stocks-july-2026), [PNC — July 2026 market phase](https://www.pnc.com/insights/corporate-institutional/asset-management-group/addingalpha/july-2026-ai-momentum-meets-a-more-selective-market-phase.html), [Seeking Alpha — 2026 sector leaders](https://seekingalpha.com/article/4921209-my-updated-2026-market-outlook-keeping-sp500-target-but-changing-sector-leaders), [Yahoo — TSMC vs NVIDIA](https://finance.yahoo.com/markets/stocks/articles/tsmc-vs-nvidia-ai-semiconductor-190000743.html), [24/7 Wall St — Vistra/Vertiv/Constellation](https://247wallst.com/investing/2026/01/27/ai-power-needs-are-soaring-is-vistra-energy-vertiv-or-constellation-the-better-buy/), [GuruFocus — LLY forward PE](https://www.gurufocus.com/term/forward-pe-ratio/FRA:LLY)
