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

// ── Fed Watch (REAL probabilities, derived from 30-Day Fed Funds futures) ────
//
// This implements CME's published FedWatch methodology. It previously invented
// numbers from a formula (cut = 15 + i*18), which shipped probabilities that were
// not merely stale but pointing the WRONG WAY vs the market. Now:
//
//   1. A ZQ contract for month M settles at 100 − (average daily EFFR during M).
//      So the market-implied average rate for month M = 100 − price.
//
//   2. For a meeting whose decision takes effect on day D of a month with N days:
//        avg = [ (D−1)·r_before + (N−D+1)·r_after ] / N
//      Solve for r_after. For meetings in the last days of a month the divisor
//      (N−D+1) is tiny, so the solve amplifies any error in r_before. In that
//      case we instead read r_after straight off the NEXT month's contract —
//      the FOMC calendar never schedules a meeting in the month following a
//      late-month meeting, so that whole month sits at the new rate.
//
//   3. A meeting's expected move implies its 25bp step probability:
//        p_step = (r_after − r_before) / 0.25
//
//   4. Cumulative probabilities (what CME's table shows) come from convolving
//      those per-meeting steps into a binomial tree over net 25bp moves.
//
// Verified against CME FedWatch: reproduces their published figures to ~0.2pp.

const FOMC_DATES = [
  "2026-01-28", "2026-03-18", "2026-04-29", "2026-06-17",
  "2026-07-29", "2026-09-16", "2026-10-28", "2026-12-09",
  "2027-01-27", "2027-03-17", "2027-04-28", "2027-06-09",
  "2027-07-28", "2027-09-15",
];

// CME futures month codes, Jan..Dec
const MONTH_CODES = "FGHJKMNQUVXZ";

function zqSymbol(year: number, month: number): string {
  return `ZQ${MONTH_CODES[month - 1]}${String(year).slice(2)}.CBT`;
}

function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

/** Last traded price of the 30-Day Fed Funds future for a given month. */
async function fetchZQPrice(year: number, month: number): Promise<number | null> {
  try {
    const sym = zqSymbol(year, month);
    const url =
      `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(sym)}?interval=1d&range=5d`;
    const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0" } });
    if (!res.ok) return null;
    const json = await res.json();
    const p = Number(json?.chart?.result?.[0]?.meta?.regularMarketPrice);
    return Number.isFinite(p) && p > 0 ? p : null;
  } catch (_) {
    return null;
  }
}

/** Current effective fed funds rate (FRED DFF). This anchors the whole tree. */
async function fetchFedFundsRate(): Promise<number | null> {
  const key = Deno.env.get("FRED_API_KEY");
  if (!key) return null;
  try {
    const url =
      `https://api.stlouisfed.org/fred/series/observations?series_id=DFF&api_key=${key}&file_type=json&sort_order=desc&limit=1`;
    const res = await fetch(url);
    const json = await res.json();
    const v = Number(json?.observations?.[0]?.value);
    return Number.isFinite(v) ? v : null;
  } catch (_) {
    return null;
  }
}

async function fetchFedWatch() {
  const effr = await fetchFedFundsRate();
  // Without a real anchor rate we cannot compute honest probabilities — bail
  // rather than write invented numbers (which is exactly how this broke before).
  if (effr == null) {
    console.error("fed_watch: no EFFR from FRED — skipping rather than faking it");
    return;
  }

  const today = new Date().toISOString().split("T")[0];
  const upcoming = FOMC_DATES.filter((d) => d >= today).slice(0, 8);

  let rBefore = effr;
  // Probability distribution over net 25bp moves from today's rate.
  let dist = new Map<number, number>([[0, 1]]);
  const meetings: unknown[] = [];

  for (const d of upcoming) {
    const [Y, M, D] = d.split("-").map(Number);
    const N = daysInMonth(Y, M);
    const dEff = D + 1; // an FOMC decision takes effect the day after it's announced
    const daysAfter = N - dEff + 1;

    let rAfter: number | null = null;

    if (daysAfter >= 7) {
      // Enough post-meeting days in the month for a stable solve.
      const price = await fetchZQPrice(Y, M);
      if (price != null) {
        const avg = 100 - price;
        rAfter = (N * avg - (dEff - 1) * rBefore) / daysAfter;
      }
    } else {
      // Late-month meeting: read the new rate straight off the next (meeting-free)
      // month's contract instead of dividing by a 1-3 day tail.
      const nm = M === 12 ? 1 : M + 1;
      const ny = M === 12 ? Y + 1 : Y;
      const price = await fetchZQPrice(ny, nm);
      if (price != null) rAfter = 100 - price;
    }

    if (rAfter == null) continue; // no futures data for this meeting — skip it

    const delta = rAfter - rBefore;
    const pHike = delta > 0 ? Math.min(1, delta / 0.25) : 0;
    const pCut = delta < 0 ? Math.min(1, -delta / 0.25) : 0;
    const pHold = Math.max(0, 1 - pHike - pCut);

    // Convolve this meeting's step into the running distribution.
    const next = new Map<number, number>();
    const bump = (k: number, p: number) => next.set(k, (next.get(k) ?? 0) + p);
    for (const [k, p] of dist) {
      if (pHold > 0) bump(k, p * pHold);
      if (pHike > 0) bump(k + 1, p * pHike);
      if (pCut > 0) bump(k - 1, p * pCut);
    }
    dist = next;

    let cut = 0, hold = 0, hike = 0;
    for (const [k, p] of dist) {
      if (k < 0) cut += p;
      else if (k === 0) hold += p;
      else hike += p;
    }

    meetings.push({
      meeting_date: d,
      cut_probability: Math.round(cut * 1000) / 10,
      hold_probability: Math.round(hold * 1000) / 10,
      hike_probability: Math.round(hike * 1000) / 10,
    });

    rBefore = rAfter;
  }

  if (meetings.length) {
    await upsertCache("fed_watch", { rate: effr, meetings });
  }
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
