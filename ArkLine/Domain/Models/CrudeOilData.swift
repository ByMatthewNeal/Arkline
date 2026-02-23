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

    /// Signal based on WTI price level (crypto impact)
    /// Below $65: Low oil - disinflationary, bullish for crypto
    /// $65-85: Normal range
    /// Above $85: High oil - inflationary pressure, bearish for crypto
    var signal: MarketSignal {
        if value < 65 { return .bullish }
        else if value < 85 { return .neutral }
        else { return .bearish }
    }

    var signalDescription: String {
        if value < 55 { return "Very Low" }
        else if value < 65 { return "Low" }
        else if value < 75 { return "Normal" }
        else if value < 85 { return "Elevated" }
        else if value < 95 { return "High" }
        else { return "Very High" }
    }
}
