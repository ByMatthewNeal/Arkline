import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

/**
 * generate-research-note Edge Function
 *
 * Ticker in → independently sourced research note DRAFT out.
 *
 * Data gathering is deterministic (FMP: profile, quote, estimates, ratios,
 * earnings-call transcript, news) — all numbers in the note come from data,
 * never from the model. Claude writes the prose (thesis, bull/bear,
 * invalidation criteria, KPIs) using the Arkline equity framework.
 *
 * The note lands in research_notes with status='draft'. A human reviews and
 * publishes — drafts are never user-visible (RLS only exposes 'published').
 *
 * POST body: { "ticker": "AVGO", "classification": "thematic"?, "target_weight": 0.05?, "slot": "..."? }
 * Auth: x-cron-secret, service-role bearer, or an authenticated admin JWT.
 */

const CRON_SECRET = Deno.env.get("CRON_SECRET") ?? ""

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

function extractText(data: any): string | undefined {
  return data?.content?.find((b: { type?: string }) => b?.type === "text")?.text
}

// ─── FMP data gathering (deterministic) ─────────────────────────────────────

async function fmp(path: string, fmpKey: string): Promise<any | null> {
  try {
    const sep = path.includes("?") ? "&" : "?"
    const resp = await fetch(`https://financialmodelingprep.com/stable/${path}${sep}apikey=${fmpKey}`)
    if (!resp.ok) {
      console.warn(`  [fmp] ${path} → ${resp.status}`)
      return null
    }
    return await resp.json()
  } catch (err) {
    console.warn(`  [fmp] ${path} failed: ${err}`)
    return null
  }
}

interface GatheredData {
  profile: any
  quote: any
  ratios: any
  estimates: any[]
  transcriptExcerpt: string | null
  news: string[]
  valuation: Record<string, unknown>
}

// ─── Crypto data gathering (from Arkline's own computed data) ───────────────

interface CryptoData {
  price: number | null
  risk: any | null          // model_portfolio_risk_history latest row
  signal: any | null        // positioning_signals latest row
  fearGreed: any | null
  news: string[]
  valuation: Record<string, unknown>
}

async function gatherCryptoData(
  supabase: ReturnType<typeof createClient>,
  asset: string,
): Promise<CryptoData> {
  // Live price from Coinbase (same source as the portfolio pipeline)
  let price: number | null = null
  try {
    const resp = await fetch(`https://api.exchange.coinbase.com/products/${asset}-USD/ticker`)
    if (resp.ok) price = parseFloat((await resp.json()).price)
  } catch { /* skip */ }

  const [{ data: riskRows }, { data: sigRows }, { data: fgRows }, { data: newsRows }] = await Promise.all([
    supabase.from("model_portfolio_risk_history")
      .select("risk_level, price, fair_value, deviation, risk_date")
      .eq("asset", asset).order("risk_date", { ascending: false }).limit(1),
    supabase.from("positioning_signals")
      .select("signal, trend_score, category, signal_date")
      .eq("asset", asset).order("signal_date", { ascending: false }).limit(1),
    supabase.from("fear_greed_history")
      .select("value, classification, date").order("date", { ascending: false }).limit(1),
    supabase.from("curated_news")
      .select("curated_title, published_at")
      .order("published_at", { ascending: false }).limit(10),
  ])

  const risk = riskRows?.[0] ?? null
  const signal = sigRows?.[0] ?? null
  const fearGreed = fgRows?.[0] ?? null
  const news = (newsRows ?? []).map((n: any) => `${n.published_at ?? ""} — ${n.curated_title}`)

  const riskCategory = risk
    ? (risk.risk_level < 0.20 ? "Very Low Risk" : risk.risk_level < 0.40 ? "Low Risk"
      : risk.risk_level < 0.55 ? "Neutral" : risk.risk_level < 0.70 ? "Elevated Risk"
      : risk.risk_level < 0.90 ? "High Risk" : "Extreme Risk")
    : null

  const valuation = {
    price: price ? Math.round(price * 100) / 100 : (risk?.price ?? null),
    market_cap: null,
    pe: null, forward_pe: null, peg: null, ev_fwd_revenue: null,
    risk_level: risk?.risk_level ?? null,
    risk_category: riskCategory,
    fair_value: risk?.fair_value ?? null,
    as_of: new Date().toISOString().split("T")[0],
  }

  return { price, risk, signal, fearGreed, news, valuation }
}

async function gatherData(ticker: string, fmpKey: string): Promise<GatheredData> {
  const [profileArr, quoteArr, ratiosArr, estimatesArr, transcriptArr, newsArr] = await Promise.all([
    fmp(`profile?symbol=${ticker}`, fmpKey),
    fmp(`quote?symbol=${ticker}`, fmpKey),
    fmp(`ratios-ttm?symbol=${ticker}`, fmpKey),
    fmp(`analyst-estimates?symbol=${ticker}&period=annual&limit=4`, fmpKey),
    fmp(`earning-call-transcript-latest?symbol=${ticker}`, fmpKey),
    fmp(`news/stock?symbols=${ticker}&limit=12`, fmpKey),
  ])

  const profile = Array.isArray(profileArr) ? profileArr[0] : profileArr
  const quote = Array.isArray(quoteArr) ? quoteArr[0] : quoteArr
  const ratios = Array.isArray(ratiosArr) ? ratiosArr[0] : ratiosArr
  const estimates: any[] = Array.isArray(estimatesArr) ? estimatesArr : []

  // Transcript: keep a bounded excerpt (management commentary carries the thesis signal)
  let transcriptExcerpt: string | null = null
  const transcript = Array.isArray(transcriptArr) ? transcriptArr[0] : transcriptArr
  if (transcript?.content && typeof transcript.content === "string") {
    transcriptExcerpt = transcript.content.slice(0, 12000)
  }

  const news: string[] = []
  if (Array.isArray(newsArr)) {
    for (const n of newsArr) {
      if (n?.title) news.push(`${n.publishedDate ?? ""} — ${n.title}`)
    }
  }

  // ── Deterministic valuation snapshot (numbers come from here, not the model)
  const price = quote?.price ?? null
  const trailingPe = quote?.pe ?? null

  // Forward PE / PEG from analyst EPS estimates
  let forwardPe: number | null = null
  let peg: number | null = null
  const currentYear = new Date().getUTCFullYear()
  const thisYearEst = estimates.find((e) => String(e?.date ?? "").startsWith(String(currentYear)))
  const nextYearEst = estimates.find((e) => String(e?.date ?? "").startsWith(String(currentYear + 1)))
  const epsThis = thisYearEst?.epsAvg ?? thisYearEst?.estimatedEpsAvg ?? null
  const epsNext = nextYearEst?.epsAvg ?? nextYearEst?.estimatedEpsAvg ?? null
  if (price && epsNext > 0) forwardPe = price / epsNext
  if (forwardPe && epsThis > 0 && epsNext > 0) {
    const growthPct = ((epsNext - epsThis) / Math.abs(epsThis)) * 100
    if (growthPct > 0) peg = forwardPe / growthPct
  }

  const mcapNum = profile?.marketCap ?? quote?.marketCap ?? null
  const marketCap = mcapNum
    ? (mcapNum >= 1e12 ? `$${(mcapNum / 1e12).toFixed(2)}T` : `$${(mcapNum / 1e9).toFixed(1)}B`)
    : null

  const valuation = {
    price: price ? Math.round(price * 100) / 100 : null,
    market_cap: marketCap,
    pe: trailingPe ? Math.round(trailingPe * 10) / 10 : null,
    forward_pe: forwardPe ? Math.round(forwardPe * 10) / 10 : null,
    peg: peg ? Math.round(peg * 100) / 100 : null,
    ev_fwd_revenue: null,
    as_of: new Date().toISOString().split("T")[0],
  }

  return { profile, quote, ratios, estimates, transcriptExcerpt, news, valuation }
}

// ─── Claude drafting (prose only) ───────────────────────────────────────────

const FRAMEWORK_PROMPT = `You are the research analyst for Arkline, an investment app that publishes curated equity model portfolios with full transparency about why each position is held.

Arkline's equity framework:
- Positions are investments held for months to years, never trades.
- Every company is classified by AI-era stage: Stage 1 Builder (infrastructure/chips), Stage 2 Enabler (second-order bottlenecks: power, networking, materials, lithography), Stage 3 Adopter (uses AI to expand margins/revenue). Companies spanning multiple stages are highest conviction.
- Valuation discipline via PEG bands: below 1 undervalued, 1-2 fairly priced, above 2 a premium justified only by an exceptional durable moat.
- Classification: "core" = quality compounder, 5-10 year horizon. "thematic" = 6-12 month catalyst-driven position.
- Intellectual honesty is the product. Every note must state what would prove the thesis wrong.

Using ONLY the source data provided below (do not invent numbers — numeric claims must trace to the data; if a figure isn't in the data, describe qualitatively), write a research note as JSON with exactly these fields:

{
  "title": "one-line descriptor of the company's role, e.g. 'AI cluster networking pure-play'",
  "thesis": "one paragraph: why Arkline holds/would hold this, what the bet actually is, and how it's sized/framed. Plain language, no hype.",
  "stage": "e.g. 'Stage 2 Enabler' or 'Stage 1 Builder & Stage 3 Adopter'",
  "bull_case": "2-4 sentences, the strongest honest case for the position",
  "bear_case": "2-4 sentences, the strongest honest case against it — steelman, don't strawman",
  "upside_driver": "1-2 sentences: the primary driver that makes the position work",
  "downside_risk": "1-2 sentences: the primary risk",
  "invalidation": ["4-6 specific, observable criteria that would prove the thesis wrong — each concrete enough that a reader could verify it happened (tie to deliveries, output, margins, guidance, dilution — not vague sentiment)"],
  "kpis": ["5-8 specific metrics a follower should watch, tied to the thesis"]
}

Respond with ONLY the JSON object, no markdown fencing.`

const CRYPTO_FRAMEWORK_PROMPT = `You are the research analyst for Arkline, an investment app that publishes systematic crypto model portfolios (Core: conservative BTC/ETH/gold/stables; Edge: balanced with selective altcoin rotation; Alpha: alt-heavy aggressive) with full transparency about why each asset is held.

Arkline's crypto framework:
- These are investment allocations held through cycles, not trades. Allocation SIZE flexes daily with signals; the asset's ROLE in the strategy is what a research note explains.
- Durable assets (BTC, PAXG/gold) hold floor allocations that never go to zero — cyclical signals reduce exposure but never fully exit. Cyclical assets (ETH, SOL, alts) can be exited entirely.
- Arkline computes a proprietary risk level per asset (0-1, from log-regression fair-value deviation): below 0.40 favors accumulation, above 0.70 favors trimming. This is the crypto equivalent of valuation discipline.
- Crypto is a high-beta expression of global liquidity: it outperforms in liquidity expansions and underperforms in contractions, more than equities.
- Stablecoins (USDC) are the defensive sleeve, earning yield while waiting for risk to reprice.
- Intellectual honesty is the product. Every note must state what would prove the asset's role wrong.

Using ONLY the source data provided below (do not invent numbers — numeric claims must trace to the data; if a figure isn't in the data, describe qualitatively), write a research note as JSON with exactly these fields:

{
  "title": "one-line descriptor of the asset's role, e.g. 'The durable base layer of every Arkline portfolio'",
  "thesis": "one paragraph: why this asset has a place in Arkline's portfolios, what role it plays (durable base / cyclical beta / defensive sleeve), and how the risk model governs its sizing. Plain language, no hype.",
  "stage": "the asset's role label, e.g. 'Durable Base Asset' or 'Cyclical Beta' or 'Defensive Sleeve'",
  "bull_case": "2-4 sentences, the strongest honest case for holding it",
  "bear_case": "2-4 sentences, the strongest honest case against it — steelman, don't strawman",
  "upside_driver": "1-2 sentences: the primary driver that makes the allocation work",
  "downside_risk": "1-2 sentences: the primary risk",
  "invalidation": ["4-6 specific, observable criteria that would prove the asset's role in the portfolio wrong — tie to market structure, regulation, network fundamentals, or sustained model behavior, not short-term price"],
  "kpis": ["5-8 specific metrics a follower should watch, tied to the role"]
}

Respond with ONLY the JSON object, no markdown fencing.`

async function draftCryptoNote(
  anthropicKey: string,
  asset: string,
  data: CryptoData,
): Promise<Record<string, unknown> | null> {
  const sources: string[] = []
  sources.push(`COMPUTED VALUATION / RISK SNAPSHOT (authoritative — use these exact figures):\n${JSON.stringify(data.valuation)}`)
  if (data.risk) sources.push(`ARKLINE RISK MODEL (latest):\n${JSON.stringify(data.risk)}`)
  if (data.signal) sources.push(`POSITIONING SIGNAL (latest):\n${JSON.stringify(data.signal)}`)
  if (data.fearGreed) sources.push(`FEAR & GREED INDEX (latest):\n${JSON.stringify(data.fearGreed)}`)
  if (data.news.length > 0) sources.push(`RECENT CURATED HEADLINES (crypto/macro):\n${data.news.join("\n")}`)

  const prompt = `${CRYPTO_FRAMEWORK_PROMPT}\n\nASSET: ${asset}\n\n─── SOURCE DATA ───\n\n${sources.join("\n\n")}`

  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": anthropicKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-5",
      max_tokens: 4000,
      messages: [{ role: "user", content: prompt }],
    }),
    signal: AbortSignal.timeout(120_000),
  })

  if (!response.ok) {
    console.error("Claude crypto drafting failed:", await response.text())
    return null
  }

  const result = await response.json()
  const text = extractText(result) ?? ""
  const cleaned = text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim()
  try {
    return JSON.parse(cleaned)
  } catch {
    console.error("Failed to parse Claude crypto JSON output")
    return null
  }
}

async function draftNote(
  anthropicKey: string,
  ticker: string,
  data: GatheredData,
): Promise<Record<string, unknown> | null> {
  const sources: string[] = []
  if (data.profile) {
    sources.push(`COMPANY PROFILE:\n${JSON.stringify({
      name: data.profile.companyName,
      sector: data.profile.sector,
      industry: data.profile.industry,
      description: String(data.profile.description ?? "").slice(0, 1500),
      marketCap: data.profile.marketCap,
    })}`)
  }
  if (data.quote) {
    sources.push(`QUOTE (as of today):\n${JSON.stringify({
      price: data.quote.price, pe: data.quote.pe, yearHigh: data.quote.yearHigh,
      yearLow: data.quote.yearLow, change52wContext: undefined,
    })}`)
  }
  sources.push(`COMPUTED VALUATION (authoritative — use these exact figures):\n${JSON.stringify(data.valuation)}`)
  if (data.estimates.length > 0) {
    sources.push(`ANALYST ESTIMATES (annual):\n${JSON.stringify(data.estimates.slice(0, 4))}`)
  }
  if (data.ratios) {
    sources.push(`TTM RATIOS:\n${JSON.stringify(data.ratios)}`)
  }
  if (data.news.length > 0) {
    sources.push(`RECENT NEWS HEADLINES:\n${data.news.join("\n")}`)
  }
  if (data.transcriptExcerpt) {
    sources.push(`LATEST EARNINGS CALL TRANSCRIPT (excerpt):\n${data.transcriptExcerpt}`)
  }

  const prompt = `${FRAMEWORK_PROMPT}\n\nTICKER: ${ticker}\n\n─── SOURCE DATA ───\n\n${sources.join("\n\n")}`

  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": anthropicKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-5",
      max_tokens: 4000,
      messages: [{ role: "user", content: prompt }],
    }),
    signal: AbortSignal.timeout(120_000),
  })

  if (!response.ok) {
    console.error("Claude drafting failed:", await response.text())
    return null
  }

  const result = await response.json()
  const text = extractText(result) ?? ""
  const cleaned = text.replace(/```json\n?/g, "").replace(/```\n?/g, "").trim()
  try {
    return JSON.parse(cleaned)
  } catch {
    console.error("Failed to parse Claude JSON output")
    return null
  }
}

// ─── Main ───────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  const authHeader = req.headers.get("authorization") ?? ""
  const cronSecret = req.headers.get("x-cron-secret") ?? ""
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? ""
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? ""
  const fmpKey = Deno.env.get("FMP_API_KEY") ?? ""
  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY") ?? ""

  const supabase = createClient(supabaseUrl, serviceRoleKey)

  // Auth: cron secret, service role, or an authenticated admin user's JWT
  let authorized = cronSecret === CRON_SECRET || authHeader === `Bearer ${serviceRoleKey}`
  if (!authorized && authHeader.startsWith("Bearer ")) {
    const jwt = authHeader.slice(7)
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: userData } = await userClient.auth.getUser(jwt)
    if (userData?.user) {
      const { data: prof } = await supabase
        .from("profiles").select("role").eq("id", userData.user.id).single()
      authorized = prof?.role === "admin"
    }
  }
  if (!authorized) return jsonResponse({ error: "Unauthorized" }, 401)

  if (!anthropicKey) return jsonResponse({ error: "ANTHROPIC_API_KEY is not configured" }, 500)
  if (!fmpKey) return jsonResponse({ error: "FMP_API_KEY is not configured" }, 500)

  let ticker = ""
  let assetClass = "stock"
  let classification: string | null = null
  let slot: string | null = null
  let targetWeight: number | null = null
  try {
    const body = await req.json()
    ticker = String(body?.ticker ?? "").toUpperCase().trim()
    assetClass = body?.asset_class === "crypto" ? "crypto" : "stock"
    classification = body?.classification ?? null
    slot = body?.slot ?? null
    targetWeight = body?.target_weight ?? null
  } catch { /* no body */ }

  if (!ticker) return jsonResponse({ error: "ticker is required" }, 400)

  try {
    let draft: Record<string, unknown> | null
    let valuation: Record<string, unknown>

    if (assetClass === "crypto") {
      console.log(`[research-note] Gathering crypto data for ${ticker}`)
      const data = await gatherCryptoData(supabase, ticker)
      valuation = data.valuation
      console.log(`[research-note] Drafting crypto note for ${ticker}`)
      draft = await draftCryptoNote(anthropicKey, ticker, data)
    } else {
      console.log(`[research-note] Gathering data for ${ticker}`)
      const data = await gatherData(ticker, fmpKey)
      if (!data.profile && !data.quote) {
        return jsonResponse({ error: `No FMP data found for ${ticker}` }, 404)
      }
      valuation = data.valuation
      console.log(`[research-note] Drafting note for ${ticker}`)
      draft = await draftNote(anthropicKey, ticker, data)
    }
    if (!draft) return jsonResponse({ error: "Drafting failed" }, 502)

    // Versioning: next version number for this ticker
    const { data: prior } = await supabase
      .from("research_notes")
      .select("id, version")
      .eq("ticker", ticker)
      .order("version", { ascending: false })
      .limit(1)
    const priorNote = prior?.[0]

    const invalidation = Array.isArray(draft.invalidation)
      ? (draft.invalidation as string[]).map((c) => ({ criterion: c, triggered: false, triggered_at: null }))
      : []

    const { data: inserted, error } = await supabase
      .from("research_notes")
      .insert({
        ticker,
        asset_class: assetClass,
        title: String(draft.title ?? `${ticker} research note`),
        thesis: String(draft.thesis ?? ""),
        classification,
        slot,
        target_weight: targetWeight,
        stage: draft.stage ?? null,
        bull_case: draft.bull_case ?? null,
        bear_case: draft.bear_case ?? null,
        upside_driver: draft.upside_driver ?? null,
        downside_risk: draft.downside_risk ?? null,
        invalidation,
        kpis: Array.isArray(draft.kpis) ? draft.kpis : [],
        valuation_at_publish: valuation,
        version: (priorNote?.version ?? 0) + 1,
        supersedes: priorNote?.id ?? null,
        status: "draft",
      })
      .select("id, ticker, version")
      .single()

    if (error) throw new Error(`Insert failed: ${error.message}`)

    console.log(`[research-note] Draft created: ${inserted.ticker} v${inserted.version}`)
    return jsonResponse({ success: true, draft: inserted })
  } catch (err) {
    console.error("[research-note] Error:", err)
    return jsonResponse({ error: String(err) }, 500)
  }
})
