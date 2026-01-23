import Foundation

/// DXY (US Dollar Index) data with signal interpretation
struct DXYData: Codable, Identifiable {
    let date: String
    let value: Double
    let open: Double?
    let high: Double?
    let low: Double?
    let close: Double?
    let previousClose: Double?

    var id: String { date }

    /// Calculate percentage change from previous close
    var changePercent: Double? {
        guard let prev = previousClose, prev > 0 else { return nil }
        return ((value - prev) / prev) * 100
    }

    /// Signal based on DXY trend
    /// Rising DXY (strong dollar): Bearish for crypto/risk assets
    /// Falling DXY (weak dollar): Bullish for crypto/risk assets
    /// Flat: Neutral
    var signal: MarketSignal {
        guard let change = changePercent else { return .neutral }
        if change > 0.3 { return .bearish }  // Strong dollar = bearish for crypto
        else if change < -0.3 { return .bullish }  // Weak dollar = bullish for crypto
        else { return .neutral }
    }

    var signalDescription: String {
        switch signal {
        case .bullish: return "Dollar Weak"
        case .neutral: return "Dollar Stable"
        case .bearish: return "Dollar Strong"
        }
    }
}
