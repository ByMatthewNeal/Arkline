import { createClient } from "jsr:@supabase/supabase-js@2"

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
)

const fmpKey = Deno.env.get("FMP_API_KEY") ?? ""

async function fetchHistoricalPrices(symbol: string): Promise<Map<string, number>> {
  const url = `https://financialmodelingprep.com/stable/historical-price-eod/full?symbol=${encodeURIComponent(symbol)}&apikey=${fmpKey}`
  const res = await fetch(url)
  if (!res.ok) throw new Error(`FMP ${symbol}: ${res.status}`)
  const data = await res.json()
  const map = new Map<string, number>()
  for (const row of data) {
    if (row.date && row.close) {
      map.set(row.date, row.close)
    }
  }
  return map
}

Deno.serve(async (req) => {
  // Auth: require cron secret or service role
  const cronSecret = req.headers.get("x-cron-secret")
  const authHeader = req.headers.get("authorization")
  if (cronSecret !== Deno.env.get("CRON_SECRET") && !authHeader?.includes("Bearer")) {
    return new Response("Unauthorized", { status: 401 })
  }

  try {
    // 1. Get all snapshots missing prices
    const { data: snapshots, error } = await supabase
      .from("risk_snapshots")
      .select("id, recorded_date")
      .is("btc_price", null)
      .order("recorded_date", { ascending: true })

    if (error) throw error
    if (!snapshots || snapshots.length === 0) {
      return new Response(JSON.stringify({ message: "No snapshots to backfill", count: 0 }))
    }

    console.log(`Found ${snapshots.length} snapshots to backfill`)

    // 2. Fetch historical prices for all three assets
    const [btcPrices, sp500Prices, nasdaqPrices] = await Promise.all([
      fetchHistoricalPrices("BTCUSD"),
      fetchHistoricalPrices("^GSPC"),
      fetchHistoricalPrices("^IXIC"),
    ])

    console.log(`Price data: BTC ${btcPrices.size} days, S&P ${sp500Prices.size} days, NDX ${nasdaqPrices.size} days`)

    // 3. Update each snapshot
    let updated = 0
    let skipped = 0
    for (const snap of snapshots) {
      const date = snap.recorded_date
      const btc = btcPrices.get(date)
      const sp500 = sp500Prices.get(date)
      const nasdaq = nasdaqPrices.get(date)

      if (!btc && !sp500 && !nasdaq) {
        skipped++
        continue
      }

      const { error: updateErr } = await supabase
        .from("risk_snapshots")
        .update({
          btc_price: btc ?? null,
          sp500_price: sp500 ?? null,
          nasdaq_price: nasdaq ?? null,
        })
        .eq("id", snap.id)

      if (updateErr) {
        console.error(`Failed to update ${date}: ${updateErr.message}`)
      } else {
        updated++
      }
    }

    const result = { updated, skipped, total: snapshots.length }
    console.log(`Backfill complete:`, result)
    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    })
  } catch (err) {
    console.error("Backfill error:", err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 })
  }
})
