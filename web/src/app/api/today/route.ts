import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

export const runtime = "edge";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function GET(req: Request) {
  // Auth
  const auth = req.headers.get("authorization") ?? "";
  if (auth !== `Bearer ${process.env.ARKLINE_READ_TOKEN}`) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  try {
    // 1. Latest risk snapshot (Arkline Score + prices)
    const { data: snapshot } = await supabase
      .from("risk_snapshots")
      .select("*")
      .order("recorded_date", { ascending: false })
      .limit(1)
      .single();

    // 2. Yesterday's snapshot for delta
    const { data: yesterday } = await supabase
      .from("risk_snapshots")
      .select("composite_score, recorded_date")
      .order("recorded_date", { ascending: false })
      .range(1, 1)
      .single();

    // 3. Today's indicators (VIX, DXY, fear_greed)
    const today = new Date().toISOString().split("T")[0];
    const sevenDaysAgo = new Date(Date.now() - 7 * 86400000)
      .toISOString()
      .split("T")[0];

    const { data: indicators } = await supabase
      .from("indicator_snapshots")
      .select("indicator, value, metadata, recorded_date")
      .in("indicator", ["vix", "dxy", "fear_greed"])
      .gte("recorded_date", sevenDaysAgo)
      .order("recorded_date", { ascending: false });

    // 4. Fear & Greed with classification
    const { data: fng } = await supabase
      .from("fear_greed_history")
      .select("value, classification")
      .order("date", { ascending: false })
      .limit(2);

    // 5. Curated news (last 24h, top 5 by relevance)
    const { data: news } = await supabase
      .from("curated_news")
      .select(
        "curated_title, source, source_url, category, relevance_score, published_at"
      )
      .gte(
        "published_at",
        new Date(Date.now() - 24 * 3600000).toISOString()
      )
      .order("relevance_score", { ascending: false })
      .limit(5);

    // 6. Waitlist count
    const { count: waitlistCount } = await supabase
      .from("early_access_signups")
      .select("*", { count: "exact", head: true });

    // 7. Waitlist 7-day delta
    const { count: waitlist7dAgo } = await supabase
      .from("early_access_signups")
      .select("*", { count: "exact", head: true })
      .lte("created_at", new Date(Date.now() - 7 * 86400000).toISOString());

    // --- Shape the response ---

    // Extract latest + week-ago values for indicators
    const latestIndicator = (name: string) =>
      indicators?.find((i) => i.indicator === name);
    const weekAgoIndicator = (name: string) => {
      const all =
        indicators?.filter((i) => i.indicator === name) ?? [];
      return all.length > 1 ? all[all.length - 1] : null;
    };

    const vixNow = latestIndicator("vix");
    const vixWeekAgo = weekAgoIndicator("vix");
    const dxyNow = latestIndicator("dxy");
    const dxyWeekAgo = weekAgoIndicator("dxy");

    const fngToday = fng?.[0];
    const fngYesterday = fng?.[1];

    // Risk score
    const riskScore = snapshot?.composite_score
      ? snapshot.composite_score / 100
      : null;
    const riskScoreYesterday = yesterday?.composite_score
      ? yesterday.composite_score / 100
      : null;

    // Risk zone mapping
    const riskZone = (score: number | null): string => {
      if (score === null) return "unknown";
      if (score < 0.3) return "low";
      if (score < 0.5) return "moderate";
      if (score < 0.7) return "elevated";
      return "high";
    };

    // Pct change helper
    const pctChange = (
      now: number | null | undefined,
      then: number | null | undefined
    ): number | null => {
      if (!now || !then || then === 0) return null;
      return Math.round(((now - then) / then) * 1000) / 10;
    };

    const body = {
      as_of: new Date().toISOString(),
      version: "1",

      btc: {
        price_usd: snapshot?.btc_price ?? null,
        risk_score: riskScore,
        risk_score_change_1d:
          riskScore !== null && riskScoreYesterday !== null
            ? Math.round((riskScore - riskScoreYesterday) * 1000) / 1000
            : null,
        risk_zone: riskZone(riskScore),
        factors: snapshot?.components ?? [],
      },

      macro: {
        regime: null, // Computed on-device, not yet stored server-side
        regime_changed_today: null,
        regime_days_in_state: null,
        vix: {
          value: vixNow?.value ?? null,
          change_pct_1w: pctChange(vixNow?.value, vixWeekAgo?.value),
        },
        dxy: {
          value: dxyNow?.value ?? null,
          change_pct_1w: pctChange(dxyNow?.value, dxyWeekAgo?.value),
        },
        net_liquidity: {
          value_trn: null, // Computed on-device via FRED API
          change_pct_1w: null,
        },
      },

      sentiment: {
        fear_and_greed: {
          value: fngToday?.value ?? null,
          label: fngToday?.classification ?? null,
          change_1d:
            fngToday && fngYesterday
              ? fngToday.value - fngYesterday.value
              : null,
        },
      },

      market_prices: {
        sp500: snapshot?.sp500_price ?? null,
        nasdaq: snapshot?.nasdaq_price ?? null,
      },

      headlines: (news ?? []).map((n) => ({
        title: n.curated_title,
        source: n.source,
        url: n.source_url,
        tags: [n.category].filter(Boolean),
      })),

      model_notes: [],

      waitlist: {
        count: (waitlistCount ?? 0),
        delta_7d:
          waitlistCount !== null && waitlist7dAgo !== null
            ? waitlistCount - waitlist7dAgo
            : null,
      },
    };

    return NextResponse.json(body, {
      headers: {
        "Cache-Control": "s-maxage=300, stale-while-revalidate=60",
      },
    });
  } catch (err) {
    console.error("today.json error:", err);
    return NextResponse.json(
      { error: "internal_error" },
      { status: 500 }
    );
  }
}
