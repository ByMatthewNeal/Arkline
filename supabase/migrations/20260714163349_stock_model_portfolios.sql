-- Stock model portfolios: asset classes, curated targets, signal context.
-- Additive only — no changes to existing crypto portfolio behavior.
-- Spec: docs/stock_model_portfolios_spec.md

-- 1. Asset class distinction on portfolios
alter table model_portfolios
  add column if not exists asset_class text not null default 'crypto',
  add column if not exists benchmark text not null default 'SPY',
  add column if not exists display_order int;

do $$ begin
  alter table model_portfolios
    add constraint model_portfolios_asset_class_check check (asset_class in ('crypto','stock'));
exception when duplicate_object then null; end $$;

update model_portfolios set display_order = 1 where strategy = 'core';
update model_portfolios set display_order = 2 where strategy = 'edge';
update model_portfolios set display_order = 3 where strategy = 'alpha';

-- 2. Curated target allocations ("position change instructions")
create table if not exists model_portfolio_targets (
  id uuid primary key default gen_random_uuid(),
  portfolio_id uuid not null references model_portfolios(id),
  effective_date date not null,
  allocations jsonb not null,
  rationale text,
  applied_at timestamptz,
  created_at timestamptz default now(),
  unique (portfolio_id, effective_date)
);

alter table model_portfolio_targets enable row level security;

do $$ begin
  create policy model_portfolio_targets_read on model_portfolio_targets
    for select to authenticated using (true);
exception when duplicate_object then null; end $$;

-- 3. Generic signal context for stock NAV rows
alter table model_portfolio_nav
  add column if not exists signal_context jsonb;

-- 4. Follow one portfolio per asset class
alter table profiles
  add column if not exists followed_stock_portfolio text;

-- 5. Seed the two stock portfolios
insert into model_portfolios (name, strategy, description, universe, starting_nav, asset_class, benchmark, display_order)
values
  (
    'Arkline Equity Core', 'stock_core',
    'Conservative equity investment portfolio. 8 quality AI-era compounders held for years, with a cash reserve that scales with the macro regime.',
    array['MSFT','AMZN','LLY','TSM','GOOGL','ASML','META','NVDA','CASH'],
    50000, 'stock', 'SPY', 4
  ),
  (
    'Arkline Equity Edge', 'stock_edge',
    'Aggressive equity investment portfolio. Core compounders plus a thematic sleeve of 6-12 month catalyst positions across power, rare earths, AI software, and compute.',
    array['MSFT','AMZN','TSM','META','NVDA','LLY','GOOGL','ASML','CEG','VST','PLTR','MP','VRT','CIFR','CASH'],
    50000, 'stock', 'SPY', 5
  )
on conflict do nothing;

-- 6. Initial targets effective 2026-01-01 (signed-off holdings proposal v2)
insert into model_portfolio_targets (portfolio_id, effective_date, allocations, rationale)
select id, date '2026-01-01',
  '{"MSFT":0.11,"AMZN":0.11,"LLY":0.09,"TSM":0.09,"GOOGL":0.08,"ASML":0.08,"META":0.07,"NVDA":0.07,"CASH":0.30}'::jsonb,
  'Initial allocation: 8 AI-era compounders spanning builders (TSM, ASML, NVDA), enablers/distribution (MSFT, GOOGL), and adopters (AMZN, META, LLY), with a 30% cash reserve for drawdown adds.'
from model_portfolios where strategy = 'stock_core'
on conflict do nothing;

insert into model_portfolio_targets (portfolio_id, effective_date, allocations, rationale)
select id, date '2026-01-01',
  '{"MSFT":0.08,"AMZN":0.08,"TSM":0.07,"META":0.07,"NVDA":0.07,"LLY":0.06,"GOOGL":0.06,"ASML":0.06,"CEG":0.07,"VST":0.06,"PLTR":0.06,"MP":0.05,"VRT":0.03,"CIFR":0.03,"CASH":0.15}'::jsonb,
  'Initial allocation: 55% core compounder sleeve plus 30% thematic sleeve (nuclear/power via CEG and VST, rare earths via MP, AI software via PLTR, cooling via VRT, HPC compute via CIFR), 15% cash.'
from model_portfolios where strategy = 'stock_edge'
on conflict do nothing;
