import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * sync-global-liquidity Edge Function
 *
 * Fetches central bank balance sheet data from BIS + FRED to build
 * a composite Global Liquidity Index.
 *
 * Data sources:
 * - BIS CBTA API: Central bank total assets for ECB, BOJ, PBOC, BOE,
 *   SNB, RBA, BOC, RBI, BOK, and 40+ others (monthly, in USD billions)
 * - FRED: Fed balance sheet (WALCL), TGA (WTREGEN), RRP (RRPONTSYD)
 *   for US Net Liquidity (weekly)
 *
 * Stores results in `global_liquidity_data` table.
 * Runs daily via cron (BIS data is monthly; FRED is weekly).
 */

// BIS country codes for major central banks
const BIS_COUNTRIES = [
  "XM", // Euro Area (ECB)
  "CN", // China (PBOC)
  "JP", // Japan (BOJ)
  "GB", // UK (BOE)
  "CH", // Switzerland (SNB)
  "AU", // Australia (RBA)
  "CA", // Canada (BOC)
  "IN", // India (RBI)
  "KR", // South Korea (BOK)
  "BR", // Brazil (BCB)
]

const BIS_COUNTRY_NAMES: Record<string, string> = {
  XM: "ECB (Euro Area)",
  CN: "PBOC (China)",
  JP: "BOJ (Japan)",
  GB: "BOE (UK)",
  CH: "SNB (Switzerland)",
  AU: "RBA (Australia)",
  CA: "BOC (Canada)",
  IN: "RBI (India)",
  KR: "BOK (South Korea)",
  BR: "BCB (Brazil)",
}

const FRED_SERIES = {
  fedAssets: "WALCL",    // Fed total assets (millions, weekly)
  tga: "WTREGEN",        // Treasury General Account (millions, weekly)
  rrp: "RRPONTSYD",      // Reverse Repo (billions, daily)
}

// Yield curve series for cycle phase confirmation
const YIELD_CURVE_SERIES = {
  t10y2y: "T10Y2Y",     // 10-Year minus 2-Year Treasury spread (daily)
  t10y3m: "T10Y3M",     // 10-Year minus 3-Month Treasury spread (daily)
}

// 65-month cycle anchor: October 2022 trough (crypto bottom, global liquidity trough)
// Howell: "upswing began late 2022, crested H2 2025" → 32.5 month half-cycle matches
const CYCLE_ANCHOR_TROUGH = new Date(2022, 9, 1) // Oct 2022
const CYCLE_LENGTH_MONTHS = 65

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405)
  }

  // Auth: cron secret
  const cronSecret = Deno.env.get("CRON_SECRET") ?? ""
  const secret = req.headers.get("x-cron-secret") ?? ""
  if (!cronSecret || secret !== cronSecret) {
    return json({ error: "Unauthorized" }, 401)
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  const fredKey = Deno.env.get("FRED_API_KEY") ?? ""
  const supabase = createClient(supabaseUrl, supabaseKey)

  const stats = {
    bis: { success: false, countries: 0, latestPeriod: "" },
    fred: { success: false, netLiquidity: 0 },
    composite: { success: false, totalLiquidity: 0 },
    cycle: { success: false, phase: "", momentumIndex: 0 },
    errors: [] as string[],
  }

  // ─── 1. Fetch BIS Central Bank Total Assets ─────────────────────────────────

  let bisData: Array<{ country: string; name: string; period: string; value: number }> = []

  try {
    const countries = BIS_COUNTRIES.join("+")
    // Fetch last 24 months for history
    const startPeriod = getDateMonthsAgo(24)
    const bisUrl = `https://stats.bis.org/api/v2/data/dataflow/BIS/WS_CBTA/1.0/M.${countries}.B.USD._Z.B?startPeriod=${startPeriod}&format=csv`

    console.log(`Fetching BIS CBTA: ${bisUrl}`)
    const resp = await fetch(bisUrl)
    if (!resp.ok) {
      throw new Error(`BIS API ${resp.status}: ${await resp.text()}`)
    }

    const csvText = await resp.text()
    bisData = parseBisCSV(csvText)
    stats.bis.countries = new Set(bisData.map((d) => d.country)).size
    stats.bis.latestPeriod = bisData.length > 0
      ? bisData.reduce((a, b) => (a.period > b.period ? a : b)).period
      : ""
    stats.bis.success = true
    console.log(`BIS: ${bisData.length} observations from ${stats.bis.countries} central banks`)
  } catch (err) {
    const msg = `BIS: ${err}`
    console.error(msg)
    stats.errors.push(msg)
  }

  // ─── 2. Fetch FRED Net Liquidity Components ─────────────────────────────────

  let fredNetLiquidity: Array<{ date: string; fedAssets: number; tga: number; rrp: number; netLiquidity: number }> = []

  if (fredKey) {
    try {
      const startDate = getDateMonthsAgo(24, true)

      // Fetch all 3 FRED series in parallel
      const [fedResp, tgaResp, rrpResp] = await Promise.all([
        fetchFredSeries(fredKey, FRED_SERIES.fedAssets, startDate),
        fetchFredSeries(fredKey, FRED_SERIES.tga, startDate),
        fetchFredSeries(fredKey, FRED_SERIES.rrp, startDate),
      ])

      // Align by date - use weekly Fed data as the base
      const tgaMap = new Map(tgaResp.map((d) => [d.date, d.value]))
      const rrpMap = new Map(rrpResp.map((d) => [d.date, d.value]))

      // For RRP (daily) and TGA (weekly), find closest date
      for (const fed of fedResp) {
        const tga = tgaMap.get(fed.date) ?? findClosest(tgaResp, fed.date)
        // WALCL is in millions, TGA is in millions, RRP is in billions
        const rrpBillions = rrpMap.get(fed.date) ?? findClosest(rrpResp, fed.date)
        const rrpMillions = rrpBillions * 1000

        const netLiq = (fed.value - tga - rrpMillions) / 1e6 // Convert to trillions
        fredNetLiquidity.push({
          date: fed.date,
          fedAssets: fed.value / 1e6, // trillions
          tga: tga / 1e6,
          rrp: rrpMillions / 1e6,
          netLiquidity: netLiq,
        })
      }

      stats.fred.success = true
      stats.fred.netLiquidity = fredNetLiquidity.length > 0
        ? fredNetLiquidity[fredNetLiquidity.length - 1].netLiquidity
        : 0
      console.log(`FRED: ${fredNetLiquidity.length} net liquidity observations, latest: $${stats.fred.netLiquidity.toFixed(3)}T`)
    } catch (err) {
      const msg = `FRED: ${err}`
      console.error(msg)
      stats.errors.push(msg)
    }
  } else {
    stats.errors.push("FRED: No API key configured")
  }

  // ─── 3. Compute Composite Global Liquidity ──────────────────────────────────

  try {
    // Build per-country latest values (each country may have a different latest period)
    const countryLatest = new Map<string, { name: string; value_b: number; period: string }>()
    for (const d of bisData) {
      const existing = countryLatest.get(d.country)
      if (!existing || d.period > existing.period) {
        countryLatest.set(d.country, { name: d.name, value_b: d.value, period: d.period })
      }
    }

    // Sum latest values across all countries for the headline number
    let latestBisTotal = 0
    for (const [, info] of countryLatest) {
      latestBisTotal += info.value_b
    }

    // Group BIS data by period — only include periods where we have a minimum
    // number of countries (at least 80% of the max observed) to avoid partial sums
    const bisByPeriodDetail = new Map<string, Map<string, number>>()
    for (const d of bisData) {
      if (!bisByPeriodDetail.has(d.period)) {
        bisByPeriodDetail.set(d.period, new Map())
      }
      bisByPeriodDetail.get(d.period)!.set(d.country, d.value)
    }

    const maxCountries = Math.max(...[...bisByPeriodDetail.values()].map((m) => m.size))
    const minCountries = Math.ceil(maxCountries * 0.8)

    // For periods with fewer countries, carry forward the last known value
    const lastKnown = new Map<string, number>()
    const sortedPeriods = [...bisByPeriodDetail.keys()].sort()

    const bisByPeriod = new Map<string, number>()
    for (const period of sortedPeriods) {
      const countries = bisByPeriodDetail.get(period)!
      // Update last known values
      for (const [code, value] of countries) {
        lastKnown.set(code, value)
      }
      // Sum using last known for all countries
      let total = 0
      for (const [, value] of lastKnown) {
        total += value
      }
      // Only include periods with enough data
      if (lastKnown.size >= minCountries) {
        bisByPeriod.set(period, total)
      }
    }

    // Get latest Fed net liquidity
    const latestFred = fredNetLiquidity.length > 0
      ? fredNetLiquidity[fredNetLiquidity.length - 1]
      : null

    // Composite = US Net Liquidity (trillions) + BIS total (billions → trillions)
    const latestComposite = (latestFred?.netLiquidity ?? 0) + (latestBisTotal / 1000)

    // Build monthly composite history
    const validPeriods = [...bisByPeriod.keys()].sort()
    const compositeHistory: Array<{
      period: string
      us_net_liquidity_t: number
      bis_total_t: number
      composite_t: number
      breakdown: Record<string, number>
    }> = []

    for (const period of validPeriods) {
      const bisTotal = bisByPeriod.get(period) ?? 0
      // Find closest FRED observation to this month
      const monthStart = `${period}-01`
      const fredMatch = findClosestFred(fredNetLiquidity, monthStart)
      const usNetLiq = fredMatch?.netLiquidity ?? 0

      // Build per-country breakdown for this period (using last known values)
      const breakdown: Record<string, number> = {}
      const periodCountries = bisByPeriodDetail.get(period)
      if (periodCountries) {
        for (const [code, value] of periodCountries) {
          breakdown[code] = value
        }
      }
      if (fredMatch) {
        breakdown["US"] = fredMatch.fedAssets * 1000 // back to billions for consistency
      }

      compositeHistory.push({
        period,
        us_net_liquidity_t: usNetLiq,
        bis_total_t: bisTotal / 1000,
        composite_t: usNetLiq + bisTotal / 1000,
        breakdown,
      })
    }

    // Calculate changes
    const latest = compositeHistory[compositeHistory.length - 1]
    const oneMonthAgo = compositeHistory[compositeHistory.length - 2]
    const threeMonthsAgo = compositeHistory[compositeHistory.length - 4]
    const sixMonthsAgo = compositeHistory[compositeHistory.length - 7]
    const oneYearAgo = compositeHistory[compositeHistory.length - 13]

    const changes = {
      monthly: oneMonthAgo ? ((latest.composite_t - oneMonthAgo.composite_t) / oneMonthAgo.composite_t) * 100 : null,
      quarterly: threeMonthsAgo ? ((latest.composite_t - threeMonthsAgo.composite_t) / threeMonthsAgo.composite_t) * 100 : null,
      semiannual: sixMonthsAgo ? ((latest.composite_t - sixMonthsAgo.composite_t) / sixMonthsAgo.composite_t) * 100 : null,
      annual: oneYearAgo ? ((latest.composite_t - oneYearAgo.composite_t) / oneYearAgo.composite_t) * 100 : null,
    }

    // Determine signal based on rate of change (Howell's key insight)
    let signal: "expanding" | "contracting" | "neutral" = "neutral"
    if (changes.monthly !== null) {
      if (changes.monthly > 0.3) signal = "expanding"
      else if (changes.monthly < -0.3) signal = "contracting"
    }

    // ─── 4. Compute Liquidity Cycle ───────────────────────────────────────────

    // Momentum: 3-month and 6-month rate of change of composite
    const momentumHistory: Array<{ period: string; roc3m: number | null; roc6m: number | null }> = []
    for (let i = 0; i < compositeHistory.length; i++) {
      const current = compositeHistory[i].composite_t
      const threeBack = i >= 3 ? compositeHistory[i - 3].composite_t : null
      const sixBack = i >= 6 ? compositeHistory[i - 6].composite_t : null

      momentumHistory.push({
        period: compositeHistory[i].period,
        roc3m: threeBack ? ((current - threeBack) / threeBack) * 100 : null,
        roc6m: sixBack ? ((current - sixBack) / sixBack) * 100 : null,
      })
    }

    // Current momentum values
    const latestMomentum = momentumHistory[momentumHistory.length - 1]
    const prevMomentum = momentumHistory.length >= 2 ? momentumHistory[momentumHistory.length - 2] : null

    // Percentile rank of 3M momentum (0-100)
    const roc3mValues = momentumHistory.map((m) => m.roc3m).filter((v): v is number => v !== null)
    let momentumIndex = 50 // default neutral
    if (latestMomentum?.roc3m !== null && roc3mValues.length > 2) {
      const below = roc3mValues.filter((v) => v < latestMomentum.roc3m!).length
      momentumIndex = Math.round((below / roc3mValues.length) * 100)
    }

    // Momentum acceleration (second derivative: current 3M RoC - previous 3M RoC)
    const acceleration = (latestMomentum?.roc3m !== null && prevMomentum?.roc3m !== null)
      ? latestMomentum.roc3m! - prevMomentum.roc3m!
      : 0

    // 65-month theoretical cycle wave
    const now = new Date()
    const monthsSinceTrough = (now.getFullYear() - CYCLE_ANCHOR_TROUGH.getFullYear()) * 12
      + (now.getMonth() - CYCLE_ANCHOR_TROUGH.getMonth())
    const cyclePhaseAngle = (2 * Math.PI * monthsSinceTrough) / CYCLE_LENGTH_MONTHS
    // -cos gives: trough at 0, peak at half cycle
    const theoreticalWave = (-Math.cos(cyclePhaseAngle) + 1) / 2 * 100

    // Determine cycle phase from angle (4 quadrants)
    const normalizedAngle = ((cyclePhaseAngle % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI)
    let cyclePhase: string
    let cryptoGuidance: string
    let equityGuidance: string
    let traditionalFavored: string

    if (normalizedAngle < Math.PI / 2) {
      cyclePhase = "early_expansion"
      cryptoGuidance = "BTC accumulation zone. Liquidity momentum turning positive — historically BTC leads risk assets here."
      equityGuidance = "Favor cyclical growth — tech, discretionary, financials. Earnings growth accelerating as liquidity expands. Small-caps tend to outperform."
      traditionalFavored = "Bonds → Equities transition"
    } else if (normalizedAngle < Math.PI) {
      cyclePhase = "late_expansion"
      cryptoGuidance = "Alt season conditions. Peak speculation phase — consider taking profits on leveraged positions."
      equityGuidance = "Rotate from growth to value — energy, materials, industrials. Valuations stretched on growth names. Commodities-linked equities benefit most near the peak."
      traditionalFavored = "Equities → Commodities"
    } else if (normalizedAngle < 3 * Math.PI / 2) {
      cyclePhase = "early_contraction"
      cryptoGuidance = "Rotate to stables. Liquidity momentum fading — reduce altcoin exposure, favor BTC or stablecoins."
      equityGuidance = "Defensive sectors — utilities, healthcare, consumer staples. Trim broad equity exposure, raise cash. Quality and low-volatility factors outperform in this phase."
      traditionalFavored = "Cash & Defensive"
    } else {
      cyclePhase = "late_contraction"
      cryptoGuidance = "DCA opportunity approaching. Maximum pessimism — start building positions for the next cycle."
      equityGuidance = "Quality dividends and long-duration bonds. Equity valuations resetting — begin building watchlists. Look for companies with strong balance sheets trading below fair value."
      traditionalFavored = "Long-duration Bonds"
    }

    // Fetch yield curve data
    let yieldCurve: {
      t10y2y: number | null
      t10y2y_1m_ago: number | null
      t10y3m: number | null
      regime: string
    } = { t10y2y: null, t10y2y_1m_ago: null, t10y3m: null, regime: "unknown" }

    if (fredKey) {
      try {
        const ycStart = getDateMonthsAgo(3, true)
        const [t10y2yResp, t10y3mResp] = await Promise.all([
          fetchFredSeries(fredKey, YIELD_CURVE_SERIES.t10y2y, ycStart),
          fetchFredSeries(fredKey, YIELD_CURVE_SERIES.t10y3m, ycStart),
        ])

        if (t10y2yResp.length > 0) {
          yieldCurve.t10y2y = t10y2yResp[t10y2yResp.length - 1].value
          // Value from ~1 month ago for direction
          const oneMonthIdx = Math.max(0, t10y2yResp.length - 22) // ~22 trading days
          yieldCurve.t10y2y_1m_ago = t10y2yResp[oneMonthIdx].value
        }
        if (t10y3mResp.length > 0) {
          yieldCurve.t10y3m = t10y3mResp[t10y3mResp.length - 1].value
        }

        // Classify yield curve regime
        if (yieldCurve.t10y2y !== null && yieldCurve.t10y2y_1m_ago !== null) {
          const spread = yieldCurve.t10y2y
          const direction = spread - yieldCurve.t10y2y_1m_ago // positive = steepening

          if (spread < -0.2) {
            yieldCurve.regime = "inverted" // Strong recession signal
          } else if (spread < 0) {
            yieldCurve.regime = direction > 0 ? "uninverting" : "deeply_inverted"
          } else if (direction > 0.1) {
            yieldCurve.regime = "steepening" // Early cycle / risk-on
          } else if (direction < -0.1) {
            yieldCurve.regime = "flattening" // Late cycle / tightening
          } else {
            yieldCurve.regime = "stable"
          }
        }

        console.log(`Yield curve: T10Y2Y=${yieldCurve.t10y2y?.toFixed(2)}, regime=${yieldCurve.regime}`)
      } catch (err) {
        console.error(`Yield curve fetch failed: ${err}`)
        stats.errors.push(`Yield curve: ${err}`)
      }
    }

    const liquidityCycle = {
      momentum_index: momentumIndex,
      momentum_3m: latestMomentum?.roc3m ?? null,
      momentum_6m: latestMomentum?.roc6m ?? null,
      acceleration,
      theoretical_wave: Math.round(theoreticalWave * 10) / 10,
      cycle_phase: cyclePhase,
      cycle_angle_degrees: Math.round((normalizedAngle * 180 / Math.PI) * 10) / 10,
      months_since_trough: monthsSinceTrough,
      crypto_guidance: cryptoGuidance,
      equity_guidance: equityGuidance,
      traditional_favored: traditionalFavored,
      yield_curve: yieldCurve,
    }

    stats.cycle.success = true
    stats.cycle.phase = cyclePhase
    stats.cycle.momentumIndex = momentumIndex
    console.log(`Cycle: phase=${cyclePhase}, momentum=${momentumIndex}/100, wave=${theoreticalWave.toFixed(1)}, angle=${(normalizedAngle * 180 / Math.PI).toFixed(1)}°`)

    // Store everything
    const payload = {
      period: latest?.period ?? validPeriods[validPeriods.length - 1] ?? "",
      composite_liquidity_t: latestComposite,
      us_net_liquidity_t: latestFred?.netLiquidity ?? 0,
      fed_assets_t: latestFred?.fedAssets ?? 0,
      tga_t: latestFred?.tga ?? 0,
      rrp_t: latestFred?.rrp ?? 0,
      bis_total_b: latestBisTotal,
      signal,
      changes,
      liquidity_cycle: liquidityCycle,
      history: compositeHistory,
      country_latest: Object.fromEntries(
        [...countryLatest.entries()].map(([code, info]) => [code, { name: info.name, value_b: info.value_b }])
      ),
    }

    // Write to market_data_cache (same pattern as sync-crypto-prices)
    await writeCache(supabase, "global_liquidity_index", payload, 86400) // 24hr TTL

    stats.composite.success = true
    stats.composite.totalLiquidity = latestComposite
    console.log(`Composite: $${latestComposite.toFixed(2)}T (signal: ${signal})`)
    console.log(`Changes: monthly=${changes.monthly?.toFixed(2)}%, quarterly=${changes.quarterly?.toFixed(2)}%, annual=${changes.annual?.toFixed(2)}%`)
  } catch (err) {
    const msg = `Composite: ${err}`
    console.error(msg)
    stats.errors.push(msg)
  }

  console.log(`Global liquidity sync complete: ${JSON.stringify(stats)}`)
  return json(stats)
})

// ─── BIS CSV Parser ──────────────────────────────────────────────────────────

function parseBisCSV(csvText: string): Array<{ country: string; name: string; period: string; value: number }> {
  const lines = csvText.split("\n")
  if (lines.length < 2) return []

  // Parse header to find column indices
  const header = parseCSVLine(lines[0])
  const refAreaIdx = header.indexOf("REF_AREA")
  const timeIdx = header.indexOf("TIME_PERIOD")
  const valueIdx = header.indexOf("OBS_VALUE")
  const titleIdx = header.indexOf("TITLE")

  if (refAreaIdx < 0 || timeIdx < 0 || valueIdx < 0) {
    throw new Error(`BIS CSV missing required columns. Header: ${header.join(",")}`)
  }

  const results: Array<{ country: string; name: string; period: string; value: number }> = []

  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue
    const cols = parseCSVLine(lines[i])
    const value = parseFloat(cols[valueIdx])
    if (isNaN(value)) continue

    results.push({
      country: cols[refAreaIdx],
      name: BIS_COUNTRY_NAMES[cols[refAreaIdx]] ?? cols[titleIdx] ?? cols[refAreaIdx],
      period: cols[timeIdx],
      value, // billions USD
    })
  }

  return results
}

/** Simple CSV line parser that handles quoted fields with commas */
function parseCSVLine(line: string): string[] {
  const result: string[] = []
  let current = ""
  let inQuotes = false

  for (let i = 0; i < line.length; i++) {
    const ch = line[i]
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        current += '"'
        i++
      } else {
        inQuotes = !inQuotes
      }
    } else if (ch === "," && !inQuotes) {
      result.push(current.trim())
      current = ""
    } else {
      current += ch
    }
  }
  result.push(current.trim())
  return result
}

// ─── FRED Helpers ────────────────────────────────────────────────────────────

async function fetchFredSeries(
  apiKey: string,
  seriesId: string,
  startDate: string
): Promise<Array<{ date: string; value: number }>> {
  const url = `https://api.stlouisfed.org/fred/series/observations?series_id=${seriesId}&api_key=${apiKey}&file_type=json&observation_start=${startDate}&sort_order=asc`

  const resp = await fetch(url)
  if (!resp.ok) {
    throw new Error(`FRED ${seriesId} ${resp.status}: ${await resp.text()}`)
  }

  const data = await resp.json()
  const observations = data.observations ?? []

  return observations
    .filter((o: { value: string }) => o.value !== ".")
    .map((o: { date: string; value: string }) => ({
      date: o.date,
      value: parseFloat(o.value),
    }))
}

function findClosest(series: Array<{ date: string; value: number }>, targetDate: string): number {
  if (series.length === 0) return 0
  const target = new Date(targetDate).getTime()
  let best = series[0]
  let bestDiff = Math.abs(new Date(best.date).getTime() - target)

  for (const entry of series) {
    const diff = Math.abs(new Date(entry.date).getTime() - target)
    if (diff < bestDiff) {
      best = entry
      bestDiff = diff
    }
  }
  return best.value
}

function findClosestFred(
  series: Array<{ date: string; netLiquidity: number; fedAssets: number }>,
  targetDate: string
): { netLiquidity: number; fedAssets: number } | null {
  if (series.length === 0) return null
  const target = new Date(targetDate).getTime()
  let best = series[0]
  let bestDiff = Math.abs(new Date(best.date).getTime() - target)

  for (const entry of series) {
    const diff = Math.abs(new Date(entry.date).getTime() - target)
    if (diff < bestDiff) {
      best = entry
      bestDiff = diff
    }
  }
  return best
}

// ─── Utility ─────────────────────────────────────────────────────────────────

/** Returns YYYY-MM (for BIS) or YYYY-MM-DD (for FRED) */
function getDateMonthsAgo(months: number, fullDate = false): string {
  const d = new Date()
  d.setMonth(d.getMonth() - months)
  const ym = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`
  return fullDate ? `${ym}-01` : ym
}

async function writeCache(
  supabase: ReturnType<typeof createClient>,
  key: string,
  data: unknown,
  ttlSeconds: number
) {
  const jsonString = JSON.stringify(data)
  const { error } = await supabase
    .from("market_data_cache")
    .upsert(
      {
        key,
        data: jsonString,
        updated_at: new Date().toISOString(),
        ttl_seconds: ttlSeconds,
      },
      { onConflict: "key" }
    )

  if (error) {
    console.error(`Cache write failed for "${key}": ${error.message}`)
    throw error
  }
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}
