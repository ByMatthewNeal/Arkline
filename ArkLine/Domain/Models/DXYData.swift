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

    /// Signal based on DXY absolute level for spot investing
    /// Below 100: Weak dollar = Bullish for risk assets
    /// 100-105: Neutral
    /// Above 105: Bearish
    var signal: MarketSignal {
        if value < 100 { return .bullish }
        else if value < 105 { return .neutral }
        else { return .bearish }
    }

    var signalDescription: String {
        if value < 100 { return "Bullish" }
        else if value < 105 { return "Neutral" }
        else { return "Bearish" }
    }
}
