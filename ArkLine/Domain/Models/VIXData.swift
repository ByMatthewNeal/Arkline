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

    /// Signal based on VIX levels
    /// VIX < 20: Low volatility (Bullish for stocks)
    /// VIX 20-30: Normal volatility (Neutral)
    /// VIX > 30: High volatility (Bearish for stocks, potentially bullish for BTC as hedge)
    var signal: MarketSignal {
        if value < 20 { return .bullish }
        else if value < 30 { return .neutral }
        else { return .bearish }
    }

    var signalDescription: String {
        switch signal {
        case .bullish: return "Low Fear"
        case .neutral: return "Normal"
        case .bearish: return "High Fear"
        }
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
