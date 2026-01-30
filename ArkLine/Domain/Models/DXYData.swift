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

    /// Signal based on DXY absolute level (matches Historical Ranges)
    /// Below 90: Weak dollar - Risk-on (bullish for crypto)
    /// 90-100: Normal range
    /// 100-105: Strong dollar
    /// Above 105: Very strong - Risk-off (bearish for crypto)
    var signal: MarketSignal {
        if value < 90 { return .bullish }
        else if value < 100 { return .neutral }
        else { return .bearish }
    }

    var signalDescription: String {
        if value < 90 { return "Weak Dollar" }
        else if value < 100 { return "Normal" }
        else if value < 105 { return "Strong Dollar" }
        else { return "Very Strong" }
    }
}
