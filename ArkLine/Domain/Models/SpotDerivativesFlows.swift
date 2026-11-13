import Foundation

// MARK: - Spot vs Derivatives Flows Models
/// Daily BTC spot flow (cumulative taker buy/sell delta across major spot venues)
/// compared against perp open interest and funding rate. Computed daily by the
/// compute-spot-derivatives-flows edge function and stored in Supabase.
/// Source: Coinalyze. Guides, not guarantees.

struct SpotDerivativesFlowsData: Codable {
    let asset: String
    let currentPrice: Double
    let days: [Double]          // unix seconds (x axis)
    let closes: [Double]        // daily BTC close (len = days)
    let spotCvd: [Double]       // cumulative spot taker delta, $M (len = days)
    let oiUsd: [Double]         // perp open interest, $B (len = days)
    let fundingPct: [Double]    // daily funding rate, percent (len = days)
    let cvd7d: Double?          // 7d change in spot CVD, $M
    let oi7dPct: Double?        // 7d change in OI, percent
    let fundingNow: Double?     // latest funding, percent
    let regime: String?
    let regimeNote: String?
    let asOf: String?

    enum CodingKeys: String, CodingKey {
        case asset
        case currentPrice = "current_price"
        case days
        case closes
        case spotCvd = "spot_cvd"
        case oiUsd = "oi_usd"
        case fundingPct = "funding_pct"
        case cvd7d = "cvd_7d"
        case oi7dPct = "oi_7d_pct"
        case fundingNow = "funding_now"
        case regime
        case regimeNote = "regime_note"
        case asOf = "as_of"
    }
}
