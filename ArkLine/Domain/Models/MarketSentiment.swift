import Foundation

// MARK: - Fear & Greed Index
struct FearGreedIndex: Codable, Equatable {
    let value: Int
    let classification: String
    let timestamp: Date
    let previousClose: Int?
    let weekAgo: Int?
    let monthAgo: Int?

    init(value: Int, classification: String, timestamp: Date, previousClose: Int? = nil, weekAgo: Int? = nil, monthAgo: Int? = nil) {
        self.value = value
        self.classification = classification
        self.timestamp = timestamp
        self.previousClose = previousClose
        self.weekAgo = weekAgo
        self.monthAgo = monthAgo
    }

    var level: FearGreedLevel {
        FearGreedLevel.from(value: value)
    }

    var displayValue: String {
        "\(value)"
    }
}

enum FearGreedLevel: String {
    case extremeFear = "Extreme Fear"
    case fear = "Fear"
    case neutral = "Neutral"
    case greed = "Greed"
    case extremeGreed = "Extreme Greed"

    var color: String {
        switch self {
        case .extremeFear: return "#EF4444"
        case .fear: return "#F97316"
        case .neutral: return "#EAB308"
        case .greed: return "#84CC16"
        case .extremeGreed: return "#22C55E"
        }
    }

    static func from(value: Int) -> FearGreedLevel {
        switch value {
        case 0...24: return .extremeFear
        case 25...44: return .fear
        case 45...55: return .neutral
        case 56...75: return .greed
        default: return .extremeGreed
        }
    }
}

// MARK: - BTC Dominance
struct BTCDominance: Codable, Equatable {
    let value: Double
    let change24h: Double
    let timestamp: Date

    var displayValue: String {
        value.asPercentageNoSign
    }

    var changeFormatted: String {
        change24h.asPercentage
    }
}

// MARK: - Altcoin Season Index
struct AltcoinSeasonIndex: Codable, Equatable {
    let value: Int
    let isBitcoinSeason: Bool
    let timestamp: Date

    var season: String {
        isBitcoinSeason ? "Bitcoin Season" : "Altcoin Season"
    }

    var displayValue: String {
        "\(value)"
    }
}

// MARK: - ETF Net Flow
struct ETFNetFlow: Codable, Equatable {
    let totalNetFlow: Double
    let dailyNetFlow: Double
    let etfData: [ETFData]
    let timestamp: Date

    var isPositive: Bool {
        dailyNetFlow >= 0
    }

    var totalFormatted: String {
        totalNetFlow.formattedCompact
    }

    var dailyFormatted: String {
        dailyNetFlow.withSignCurrency
    }
}

struct ETFData: Codable, Identifiable, Equatable {
    var id: String { ticker }
    let ticker: String
    let name: String
    let netFlow: Double
    let aum: Double

    var netFlowFormatted: String {
        netFlow.withSignCurrency
    }
}

// MARK: - Funding Rate
struct FundingRate: Codable, Equatable {
    let averageRate: Double
    let exchanges: [ExchangeFundingRate]
    let timestamp: Date

    var displayRate: String {
        (averageRate * 100).formattedWithDecimals + "%"
    }

    var sentiment: String {
        if averageRate > 0.01 { return "Bullish" }
        if averageRate < -0.01 { return "Bearish" }
        return "Neutral"
    }
}

struct ExchangeFundingRate: Codable, Identifiable, Equatable {
    var id: String { exchange }
    let exchange: String
    let rate: Double
    let nextFundingTime: Date?
}

// MARK: - Liquidation Data
struct LiquidationData: Codable, Equatable {
    let total24h: Double
    let longLiquidations: Double
    let shortLiquidations: Double
    let largestSingleLiquidation: Double?
    let timestamp: Date

    var totalFormatted: String {
        total24h.formattedCompact
    }

    var longsFormatted: String {
        longLiquidations.formattedCompact
    }

    var shortsFormatted: String {
        shortLiquidations.formattedCompact
    }

    var dominantSide: String {
        longLiquidations > shortLiquidations ? "Longs" : "Shorts"
    }
}

// MARK: - App Store Ranking
struct AppStoreRanking: Codable, Identifiable, Equatable {
    let id: UUID
    let appName: String
    let ranking: Int
    let change: Int
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case appName = "app_name"
        case ranking
        case change
        case recordedAt = "recorded_at"
    }

    var rankFormatted: String {
        "#\(ranking)"
    }

    var changeFormatted: String {
        if change > 0 { return "+\(change)" }
        if change < 0 { return "\(change)" }
        return "—"
    }

    var isImproving: Bool {
        change < 0 // Lower rank is better
    }
}

// MARK: - Global Liquidity
struct GlobalLiquidity: Codable, Equatable {
    let totalLiquidity: Double
    let weeklyChange: Double
    let monthlyChange: Double
    let yearlyChange: Double
    let components: [LiquidityComponent]
    let timestamp: Date

    var totalFormatted: String {
        totalLiquidity.formattedCompact
    }

    var weeklyChangeFormatted: String {
        weeklyChange.asPercentage
    }
}

struct LiquidityComponent: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let value: Double
    let change: Double
}

// MARK: - Sentiment History
struct SentimentHistory: Codable, Identifiable {
    let id: UUID
    let metricType: String
    let value: Double
    let recordedAt: Date
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case metricType = "metric_type"
        case value
        case recordedAt = "recorded_at"
        case metadata
    }
}

// MARK: - Composite Risk Level
struct RiskLevel: Equatable {
    let level: Int // 1-10
    let indicators: [RiskIndicator]
    let recommendation: String
    let timestamp: Date

    var levelText: String {
        switch level {
        case 1...3: return "Low Risk"
        case 4...6: return "Moderate Risk"
        case 7...8: return "High Risk"
        default: return "Extreme Risk"
        }
    }

    var color: String {
        switch level {
        case 1...3: return "#22C55E"
        case 4...6: return "#EAB308"
        case 7...8: return "#F97316"
        default: return "#EF4444"
        }
    }
}

struct RiskIndicator: Equatable {
    let name: String
    let value: Double
    let weight: Double
    let contribution: Double
}

// MARK: - Market Overview
struct MarketOverview: Equatable {
    let fearGreed: FearGreedIndex
    let btcDominance: BTCDominance
    let altcoinSeason: AltcoinSeasonIndex?
    let totalMarketCap: Double
    let marketCapChange24h: Double
    let totalVolume24h: Double
    let btcPrice: Double
    let ethPrice: Double
    let timestamp: Date

    var marketCapFormatted: String {
        totalMarketCap.formattedCompact
    }

    var volumeFormatted: String {
        totalVolume24h.formattedCompact
    }
}
