# derived_signals & asset_risk_factors — populate spec

These two tables (see `migrations/20260614000000_derived_signals.sql`) let the web
dashboard show two things that are currently computed on-device and never
persisted: the **macro regime** and the **per-asset 7-factor risk breakdown**.

The web data layer already reads them with safe fallbacks, so you can ship the
tables empty and backfill later with zero app changes:

- `fetchRegimeData` (`src/lib/api/macro.ts`) prefers `derived_signals.macro_regime`;
  until a row exists it falls back to the sign of the live `gei_composite` indicator.
- `fetchAssetRiskLevels` attaches `asset_risk_factors` rows when present; until then
  the Asset Risk card simply renders without the factor bars.
- `fetchCryptoPositioning` (`src/lib/api/market.ts`) derives growth/inflation/regime
  from live `positioning_signals` today. Once `derived_signals.growth_score` /
  `inflation_score` / `macro_regime` are written, switch that function to prefer them.

## How to populate (recommended: a daily Vercel cron)

Port the on-device regime classifier and per-asset factor computation into a
scheduled job (Vercel Cron at ~06:00 ET, or a Supabase Edge Function on a schedule)
that writes one `derived_signals` row per day and seven `asset_risk_factors` rows
per asset per day, using the **service-role key** (bypasses RLS).

### `derived_signals` — one row/day
| column | source |
| --- | --- |
| `as_of` | today (date) |
| `macro_regime` | regime classifier output, e.g. `risk-off-disinflation` |
| `regime_changed_today` | true if today's regime differs from yesterday's |
| `regime_days_in_state` | consecutive days in the current regime |
| `growth_score`, `inflation_score` | 0-100 regime model scores |
| `net_liquidity_trn` | US net liquidity in $T (already in `indicator_snapshots.net_liquidity`, /1e12) |
| `nl_chg_1w` | % change vs 7-day-old net liquidity |

### `asset_risk_factors` — 7 rows/asset/day
For each of BTC / ETH / SOL, one row per factor: `Log Regression`, `RSI`,
`SMA Position`, `Bull Market Bands`, `Funding Rate`, `Fear & Greed`, `Macro Risk`.
Set `normalized_value` in 0.000–1.000 (drives the bar widths in the UI) and `weight`
in 0.000–1.000. Many inputs already exist server-side (`technicals_snapshots`,
`fear_greed_history`, `funding_rate` indicator, the macro indicators), so most of
this is normalization logic rather than new data collection.

## Apply the migration
```bash
# via Supabase CLI
supabase db push
# or paste migrations/20260614000000_derived_signals.sql into the SQL editor
```
