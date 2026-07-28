-- Exported from the live database on 2026-07-27.
-- Originally applied directly (not via `supabase db push`), so no repo file
-- existed and the migrations could not reproduce production.
-- Filename version matches the applied migration version exactly.

-- Anticipatory signal support.
--
-- zone_entered_at: stamped by signal-monitor the first time price trades into
-- a watching signal's entry zone. Entry is NOT granted at touch — a 1h candle
-- must close back outside the zone in the trade direction first ("confirmed
-- rejection"). This column is the boundary between the two stages.
--
-- entered_price: the confirming candle's close — the realistic fill a member
-- could get. When present, all P&L math uses it instead of entry_price_mid,
-- so recorded outcomes reflect entries members could actually take.

alter table public.trade_signals
  add column if not exists zone_entered_at timestamptz,
  add column if not exists entered_price numeric;

comment on column public.trade_signals.zone_entered_at is
  'First time price traded into the entry zone (stage 1 of 2). Entry requires a subsequent 1h close back outside the zone in trade direction.';
comment on column public.trade_signals.entered_price is
  'Confirming candle close used as the P&L basis. Null for signals filled before the anticipatory redesign (those use entry_price_mid).';
