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

    /// Signal based on gold price level for spot investing
    /// Gold in a secular uptrend — only a collapse below $3,000
    /// (major trend break) would signal bearish
    var signal: MarketSignal {
        if value > 3000 { return .bullish }
        else if value > 2000 { return .neutral }
        else { return .bearish }
    }

    var signalDescription: String {
        if value > 3000 { return "Bullish" }
        else if value > 2000 { return "Neutral" }
        else { return "Bearish" }
    }
}
