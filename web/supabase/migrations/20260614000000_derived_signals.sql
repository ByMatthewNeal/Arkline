-- Arkline — derived_signals + asset_risk_factors
--
-- Purpose: persist the two pieces that are currently computed on the user's
-- device (and therefore can't be served to the web dashboard):
--   1) the macro regime (+ net liquidity) — powers the "Risk On/Off" badge and
--      the Crypto Positioning regime card.
--   2) the per-asset 7-factor risk breakdown — powers the Asset Risk Level card.
--
-- Once a daily job writes to these tables, the web data layer (src/lib/api/*)
-- automatically prefers them over its live fallbacks. No app code change needed.

-- ── Macro regime / net liquidity ────────────────────────────────────────────
create table if not exists public.derived_signals (
  as_of                 date primary key,
  macro_regime          text,          -- e.g. 'risk-on-disinflation' | 'risk-off-inflation' ...
  regime_changed_today  boolean default false,
  regime_days_in_state  integer,
  growth_score          integer,       -- 0-100 (optional; powers positioning card)
  inflation_score       integer,       -- 0-100 (optional)
  net_liquidity_trn     numeric,       -- US net liquidity in $ trillions
  nl_chg_1w             numeric,       -- week-over-week % change
  created_at            timestamptz default now()
);

comment on table public.derived_signals is
  'Daily server-side macro regime + net liquidity (port of on-device classifier).';

-- ── Per-asset risk factor breakdown ─────────────────────────────────────────
create table if not exists public.asset_risk_factors (
  id                uuid primary key default gen_random_uuid(),
  asset             text not null,        -- 'BTC' | 'ETH' | 'SOL'
  recorded_date     date not null,
  factor            text not null,        -- 'Log Regression' | 'RSI' | 'SMA Position'
                                          -- | 'Bull Market Bands' | 'Funding Rate'
                                          -- | 'Fear & Greed' | 'Macro Risk'
  raw_value         numeric,              -- pre-normalization input (display only)
  normalized_value  numeric,              -- 0.000 - 1.000 (drives the bar widths)
  weight            numeric,              -- 0.000 - 1.000 contribution weight
  created_at        timestamptz default now(),
  unique (asset, recorded_date, factor)
);

comment on table public.asset_risk_factors is
  'Daily per-asset 7-factor risk breakdown (port of on-device computation).';

create index if not exists asset_risk_factors_asset_date_idx
  on public.asset_risk_factors (asset, recorded_date desc);

-- ── Row Level Security ───────────────────────────────────────────────────────
-- Read-only market data: allow anon + authenticated to SELECT, writes are
-- service-role only (the daily job uses the service key, which bypasses RLS).
-- Adjust to match the policy convention on your other market tables if it differs.
alter table public.derived_signals     enable row level security;
alter table public.asset_risk_factors  enable row level security;

create policy "derived_signals_read"
  on public.derived_signals for select
  to anon, authenticated using (true);

create policy "asset_risk_factors_read"
  on public.asset_risk_factors for select
  to anon, authenticated using (true);
