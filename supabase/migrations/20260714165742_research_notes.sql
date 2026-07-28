-- Research notes: per-ticker investment theses backing model portfolio positions.
-- Versioned (never silently rewritten), with the valuation frozen at publish time
-- and explicit invalidation criteria that can be marked triggered over time.
-- Applied to production 2026-07-14.

create table if not exists research_notes (
  id uuid primary key default gen_random_uuid(),
  ticker text not null,
  asset_class text not null default 'stock' check (asset_class in ('crypto','stock')),
  title text not null,
  -- One-paragraph thesis shown at the top ("why we own it")
  thesis text not null,
  -- Positioning block
  classification text,            -- 'core' | 'thematic'
  slot text,                      -- e.g. "Thematic — Supporting"
  target_weight numeric,          -- 0.05 = 5%
  stage text,                     -- e.g. "Stage 2 Enabler"
  -- The debate
  bull_case text,
  bear_case text,
  upside_driver text,
  downside_risk text,
  -- Accountability
  invalidation jsonb default '[]'::jsonb,  -- [{"criterion": "...", "triggered": false, "triggered_at": null}]
  kpis text[] default '{}',
  valuation_at_publish jsonb,     -- {"price": 58.9, "market_cap": "10.5B", "pe": null, "forward_pe": 45.2, "peg": null, "ev_fwd_revenue": 22.0, "as_of": "2026-07-14"}
  -- Full report body (markdown), optional
  body_markdown text,
  -- Versioning: a new version inserts a new row pointing at its predecessor
  version int not null default 1,
  supersedes uuid references research_notes(id),
  status text not null default 'published' check (status in ('draft','published','archived')),
  published_at timestamptz default now(),
  created_at timestamptz default now()
);

create index if not exists research_notes_ticker_idx on research_notes (ticker, published_at desc);

alter table research_notes enable row level security;

do $$ begin
  create policy research_notes_read on research_notes
    for select to authenticated using (status = 'published');
exception when duplicate_object then null; end $$;

do $$ begin
  create policy research_notes_insert_admin on research_notes
    for insert to authenticated
    with check (exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    ));
exception when duplicate_object then null; end $$;

do $$ begin
  create policy research_notes_update_admin on research_notes
    for update to authenticated
    using (exists (
      select 1 from profiles
      where profiles.id = auth.uid() and profiles.role = 'admin'
    ));
exception when duplicate_object then null; end $$;
