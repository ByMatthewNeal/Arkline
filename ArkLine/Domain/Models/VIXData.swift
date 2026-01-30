import Foundation

/// VIX (Volatility Index) data with signal interpretation
struct VIXData: Codable, Identifiable {
    let date: String
    let value: Double
    let open: Double?
    let high: Double?
    let low: Double?
    let close: Double?

    var id: String { date }

    /// Signal based on VIX levels (matches UI interpretation)
    /// Below 15: Complacent (very low volatility)
    /// 15-20: Normal market conditions
    /// 20-25: Elevated uncertainty
    /// 25-30: High fear
    /// Above 30: Extreme fear
    var signal: MarketSignal {
        if value < 15 { return .bullish }
        else if value < 20 { return .neutral }
        else { return .bearish }
    }

    var signalDescription: String {
        if value < 15 { return "Complacent" }
        else if value < 20 { return "Normal" }
        else if value < 25 { return "Elevated" }
        else if value < 30 { return "High Fear" }
        else { return "Extreme Fear" }
    }
}

/// Market signal enum for VIX/DXY
enum MarketSignal: String, Codable {
    case bullish = "bullish"
    case neutral = "neutral"
    case bearish = "bearish"

    var displayName: String {
        rawValue.capitalized
    }
}
