import Foundation

// MARK: - Market Breadth Data Point
/// Represents a single day's market breadth reading with EMA trend analysis.
/// Tracks % of tokens in uptrend + EMA 12/21 crossover state.
struct MarketBreadthPoint: Codable, Identifiable, Hashable {
    let id: UUID
    let signalDate: String
    let totalTokens: Int
    let trendingTokens: Int
    let breadthPct: Double
    let ema12: Double?
    let ema21: Double?
    let trend: String
    let prevTrend: String?
    let crossover: String?
    let btcPrice: Double?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case signalDate = "signal_date"
        case totalTokens = "total_tokens"
        case trendingTokens = "trending_tokens"
        case breadthPct = "breadth_pct"
        case ema12 = "ema_12"
        case ema21 = "ema_21"
        case trend
        case prevTrend = "prev_trend"
        case crossover
        case btcPrice = "btc_price"
        case createdAt = "created_at"
    }

    // MARK: - Computed Properties

    var date: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: signalDate) ?? Date()
    }

    var isBullish: Bool { trend == "bullish" }
    var isBearish: Bool { trend == "bearish" }

    var trendDisplayText: String {
        switch trend {
        case "bullish": return "Bullish"
        case "bearish": return "Bearish"
        default: return "Neutral"
        }
    }

    var isCrossover: Bool { crossover != nil }

    var isBullishCrossover: Bool { crossover == "bullish_crossover" }
    var isBearishCrossover: Bool { crossover == "bearish_crossover" }

    var breadthFormatted: String {
        String(format: "%.1f%%", breadthPct)
    }

    var ema12Formatted: String {
        guard let ema = ema12 else { return "--" }
        return String(format: "%.1f%%", ema)
    }

    var ema21Formatted: String {
        guard let ema = ema21 else { return "--" }
        return String(format: "%.1f%%", ema)
    }

    var btcPriceFormatted: String {
        guard let price = btcPrice else { return "--" }
        return "$\(Int(price).formatted())"
    }

    var shortDateDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: signalDate) else { return signalDate }
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d"
        return displayFormatter.string(from: date)
    }

    /// Breadth zone description
    var zoneDescription: String {
        if breadthPct >= 70 {
            return "Strong"
        } else if breadthPct >= 30 {
            return "Mixed"
        } else {
            return "Weak"
        }
    }
}
