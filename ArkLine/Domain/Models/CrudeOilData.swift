import Foundation

/// WTI Crude Oil data with signal interpretation for crypto markets
struct CrudeOilData: Codable, Identifiable {
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

    /// Signal based on WTI price level for spot investing
    /// Below $80: Moderate oil = Bullish for risk assets
    /// $80-95: Neutral
    /// Above $95: Bearish
    var signal: MarketSignal {
        if value < 80 { return .bullish }
        else if value < 95 { return .neutral }
        else { return .bearish }
    }

    var signalDescription: String {
        if value < 80 { return "Bullish" }
        else if value < 95 { return "Neutral" }
        else { return "Bearish" }
    }
}
