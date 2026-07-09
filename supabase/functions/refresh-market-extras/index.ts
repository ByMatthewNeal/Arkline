// Arkline — refresh-market-extras
//
// Scheduled Edge Function that fetches the three "live external" home widgets
// server-side (where browser CORS doesn't apply) and writes them into
// market_data_cache so the web dashboard can read them like every other widget:
//
//   key 'us_futures'   → [{ symbol, name, price, change, change_percent }]
//   key 'perp_premium' → [{ symbol, funding_rate, annualized_rate, premium_score }]
//   key 'fed_watch'    → { rate, meetings: [{ meeting_date, cut_probability, hold_probability, hike_probability }] }
//
// Deploy:   supabase functions deploy refresh-market-extras
// Schedule: see supabase/SCHEDULE_MARKET_EXTRAS.sql (pg_cron, e.g. every 15 min)
//
// Env (Project Settings → Edge Functions → Secrets):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (provided automatically)
//   FRED_API_KEY  (optional — improves Fed Watch; falls back to a default rate)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

async function upsertCache(key: string, data: unknown) {
  await supabase.from("market_data_cache").upsert(
    { key, data, updated_at: new Date().toISOString() },
    { onConflict: "key" },
  );
}

// ── US Futures (Yahoo Finance) ──────────────────────────────────────────────
const FUTURES = [
  { symbol: "ES=F", name: "S&P 500", short: "ES" },
  { symbol: "YM=F", name: "Dow", short: "YM" },
  { symbol: "NQ=F", name: "NASDAQ", short: "NQ" },
];

async function fetchFutures() {
  const out: unknown[] = [];
  for (const f of FUTURES) {
    try {
      // range=1d so meta.chartPreviousClose is YESTERDAY's close (the correct
      // daily-change reference). range=5d makes chartPreviousClose a ~6-day-old
      // close, which flips the change sign vs live sources (CNN) and the iOS app,
      // whose fetchQuote also uses range=1d.
      const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(f.symbol)}?interval=1d&range=1d`;
      const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0" } });
      if (!res.ok) continue;
      const json = await res.json();
      const meta = json?.chart?.result?.[0]?.meta;
      if (!meta) continue;
      const price = Number(meta.regularMarketPrice);
      const prev = Number(meta.chartPreviousClose ?? meta.previousClose ?? price);
      const change = price - prev;
      out.push({
        symbol: f.short,
        name: f.name,
        price,
        change,
        change_percent: prev ? (change / prev) * 100 : 0,
      });
    } catch (_) { /* skip this symbol */ }
  }
  if (out.length) await upsertCache("us_futures", out);
}

// ── Perp Premium (CoinGecko derivatives — Binance fapi is geo-blocked) ───────
// CoinGecko's funding_rate is a percentage (e.g. 0.01 = 0.01%); we store it as a
// decimal fraction to match the tile (which renders rate * 100).
async function fetchPerpPremium() {
  try {
    const key = Deno.env.get("COINGECKO_API_KEY");
    const headers: Record<string, string> = { "User-Agent": "Mozilla/5.0" };
    if (key) headers["x-cg-demo-api-key"] = key;
    const res = await fetch(
      "https://api.coingecko.com/api/v3/derivatives/exchanges/binance_futures?include_tickers=unexpired",
      { headers },
    );
    if (!res.ok) return;
    const json = await res.json();
    const tickers: any[] = json?.tickers ?? [];
    const wanted = [{ base: "BTC", sym: "BTC" }, { base: "ETH", sym: "ETH" }];
    const out: unknown[] = [];
    for (const w of wanted) {
      const t = tickers.find(
        (x) => x.base === w.base && (x.target === "USDT" || x.target === "USD") &&
          (x.contract_type ? x.contract_type === "perpetual" : true),
      );
      if (!t || t.funding_rate == null) continue;
      const rate = Number(t.funding_rate) / 100; // % → decimal
      out.push({
        symbol: w.sym,
        funding_rate: rate,
        annualized_rate: rate * 3 * 365 * 100,
        premium_score: Math.max(-100, Math.min(100, rate * 100000)),
      });
    }
    if (out.length) await upsertCache("perp_premium", out);
  } catch (_) { /* skip */ }
}

// ── Fed Watch (estimated from current rate + FOMC calendar) ─────────────────
// Mirrors the iOS CMEFedWatchScraper, which estimates probabilities rather than
// scraping CME. Known 2026 FOMC decision dates; extend as the calendar updates.
const FOMC_DATES = [
  "2026-01-28", "2026-03-18", "2026-04-29", "2026-06-17",
  "2026-07-29", "2026-09-16", "2026-10-28", "2026-12-09",
];

async function fetchFedFundsRate(): Promise<number> {
  const key = Deno.env.get("FRED_API_KEY");
  if (!key) return 4.33;
  try {
    const url = `https://api.stlouisfed.org/fred/series/observations?series_id=DFF&api_key=${key}&file_type=json&sort_order=desc&limit=1`;
    const res = await fetch(url);
    const json = await res.json();
    const v = Number(json?.observations?.[0]?.value);
    return Number.isFinite(v) ? v : 4.33;
  } catch (_) {
    return 4.33;
  }
}

async function fetchFedWatch() {
  const rate = await fetchFedFundsRate();
  const today = new Date().toISOString().split("T")[0];
  const upcoming = FOMC_DATES.filter((d) => d >= today).slice(0, 4);
  const meetings = upcoming.map((d, i) => {
    const cut = Math.min(70, 15 + i * 18);
    const hold = Math.max(20, 80 - i * 16);
    const hike = Math.max(0, 100 - cut - hold);
    const total = cut + hold + hike || 1;
    return {
      meeting_date: d,
      cut_probability: Math.round((cut / total) * 100),
      hold_probability: Math.round((hold / total) * 100),
      hike_probability: Math.round((hike / total) * 100),
    };
  });
  await upsertCache("fed_watch", { rate, meetings });
}

Deno.serve(async (req) => {
  // Optional `?jobs=us_futures,perp_premium` filter so a caller can refresh just
  // a subset. No param = refresh everything (backward compatible). This lets US
  // Futures (free Yahoo) run on a fast cron without also hammering the CoinGecko
  // (perp premium) and FRED (fed watch) quotas.
  const requested = new URL(req.url).searchParams.get("jobs");
  const wanted = requested
    ? new Set(requested.split(",").map((s) => s.trim()).filter(Boolean))
    : null;
  const shouldRun = (job: string) => !wanted || wanted.has(job);

  const tasks: Promise<unknown>[] = [];
  const jobNames: string[] = [];
  if (shouldRun("us_futures")) { tasks.push(fetchFutures()); jobNames.push("us_futures"); }
  if (shouldRun("perp_premium")) { tasks.push(fetchPerpPremium()); jobNames.push("perp_premium"); }
  if (shouldRun("fed_watch")) { tasks.push(fetchFedWatch()); jobNames.push("fed_watch"); }

  const results = await Promise.allSettled(tasks);
  const status = results.map((r, i) => ({
    job: jobNames[i],
    ok: r.status === "fulfilled",
  }));
  return new Response(JSON.stringify({ ok: true, status }), {
    headers: { "Content-Type": "application/json" },
  });
});
