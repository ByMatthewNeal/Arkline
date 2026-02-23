import Foundation

/// Gold (XAU/USD) data with signal interpretation for crypto markets
struct GoldData: Codable, Identifiable {
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

    /// Signal based on gold price level (crypto impact)
    /// Below $2000: Low safe-haven demand - risk-on, bullish for crypto
    /// $2000-2400: Normal range
    /// Above $2400: Strong safe-haven demand - risk-off, bearish for crypto short-term
    var signal: MarketSignal {
        if value < 2000 { return .bullish }
        else if value < 2400 { return .neutral }
        else { return .bearish }
    }

    var signalDescription: String {
        if value < 1800 { return "Very Low" }
        else if value < 2000 { return "Low" }
        else if value < 2200 { return "Normal" }
        else if value < 2400 { return "Elevated" }
        else if value < 2600 { return "High" }
        else { return "Very High" }
    }
}
