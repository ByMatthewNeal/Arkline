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

    /// Signal based on VIX levels for spot investing
    /// Below 20: Low volatility = Bullish for risk assets
    /// 20-25: Neutral
    /// Above 25: Bearish
    var signal: MarketSignal {
        if value < 20 { return .bullish }
        else if value < 25 { return .neutral }
        else { return .bearish }
    }

    var signalDescription: String {
        if value < 20 { return "Bullish" }
        else if value < 25 { return "Neutral" }
        else { return "Bearish" }
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
