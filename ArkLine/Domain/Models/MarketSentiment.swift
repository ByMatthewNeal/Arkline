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

    /// Display rate as percentage with 4 decimal places (e.g., "0.0058%")
    var displayRate: String {
        String(format: "%.4f%%", averageRate * 100)
    }

    /// Sentiment based on funding rate
    /// - > 0.0005 (0.05%) = Bullish (longs paying shorts)
    /// - < -0.0005 (-0.05%) = Bearish (shorts paying longs)
    /// - Otherwise = Neutral
    var sentiment: String {
        if averageRate > 0.0005 { return "Bullish" }
        if averageRate < -0.0005 { return "Bearish" }
        return "Neutral"
    }

    /// Annualized funding rate (3 funding periods per day * 365 days)
    var annualizedRate: Double {
        averageRate * 3 * 365 * 100
    }

    var annualizedDisplay: String {
        String(format: "%.1f%% APR", annualizedRate)
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
    let platform: AppPlatform
    let region: AppRegion
    let category: String // "finance", "all", etc.
    let recordedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case appName = "app_name"
        case ranking
        case change
        case platform
        case region
        case category
        case recordedAt = "recorded_at"
    }

    // Convenience initializer for backward compatibility
    init(id: UUID, appName: String, ranking: Int, change: Int, recordedAt: Date) {
        self.id = id
        self.appName = appName
        self.ranking = ranking
        self.change = change
        self.platform = .ios
        self.region = .us
        self.category = "finance"
        self.recordedAt = recordedAt
    }

    // Full initializer
    init(id: UUID, appName: String, ranking: Int, change: Int, platform: AppPlatform, region: AppRegion, category: String = "finance", recordedAt: Date) {
        self.id = id
        self.appName = appName
        self.ranking = ranking
        self.change = change
        self.platform = platform
        self.region = region
        self.category = category
        self.recordedAt = recordedAt
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
        change < 0 // Lower rank is better (moving up in charts)
    }

    var changeDescription: String {
        if change == 0 { return "No change" }
        let direction = change < 0 ? "up" : "down"
        return "\(abs(change)) positions \(direction)"
    }
}

// MARK: - App Platform
enum AppPlatform: String, Codable, CaseIterable {
    case ios = "ios"
    case android = "android"

    var displayName: String {
        switch self {
        case .ios: return "iOS"
        case .android: return "Android"
        }
    }

    var icon: String {
        switch self {
        case .ios: return "apple.logo"
        case .android: return "logo.playstation" // Using as Android placeholder
        }
    }
}

// MARK: - App Region
enum AppRegion: String, Codable, CaseIterable {
    case us = "us"
    case global = "global"

    var displayName: String {
        switch self {
        case .us: return "US"
        case .global: return "Global"
        }
    }

    var flag: String {
        switch self {
        case .us: return "🇺🇸"
        case .global: return "🌍"
        }
    }
}

// MARK: - App Store Composite Sentiment
/// Composite sentiment score from multiple exchange app rankings
struct AppStoreCompositeSentiment: Equatable {
    let score: Double // 0-100 (higher = more retail interest)
    let tier: AppStoreSentimentTier
    let historicalPercentile: Double? // Where current score ranks vs history
    let rankings: [AppStoreRanking]
    let timestamp: Date

    var scoreFormatted: String {
        String(format: "%.0f", score)
    }

    var percentileFormatted: String? {
        guard let percentile = historicalPercentile else { return nil }
        return String(format: "%.0f%%", percentile)
    }
}

// MARK: - App Store Sentiment Tier
enum AppStoreSentimentTier: String, CaseIterable {
    case extremeEuphoria = "Extreme Euphoria"
    case highInterest = "High Interest"
    case moderateInterest = "Moderate Interest"
    case lowInterest = "Low Interest"
    case apathy = "Apathy"

    var color: String {
        switch self {
        case .extremeEuphoria: return "#EF4444" // Red - danger zone
        case .highInterest: return "#F97316" // Orange
        case .moderateInterest: return "#EAB308" // Yellow
        case .lowInterest: return "#84CC16" // Light green
        case .apathy: return "#22C55E" // Green - good buying zone
        }
    }

    var icon: String {
        switch self {
        case .extremeEuphoria: return "flame.fill"
        case .highInterest: return "arrow.up.circle.fill"
        case .moderateInterest: return "minus.circle.fill"
        case .lowInterest: return "arrow.down.circle.fill"
        case .apathy: return "zzz"
        }
    }

    var description: String {
        switch self {
        case .extremeEuphoria: return "All apps top ranked - retail FOMO peak. Historically correlates with market tops."
        case .highInterest: return "Apps trending upward - retail money entering the market."
        case .moderateInterest: return "Stable mid-range rankings - healthy market participation."
        case .lowInterest: return "Apps declining in rankings - retail interest fading."
        case .apathy: return "Apps at cycle lows - retail has left. Historically good accumulation zone."
        }
    }

    static func from(score: Double) -> AppStoreSentimentTier {
        switch score {
        case 80...100: return .extremeEuphoria
        case 60..<80: return .highInterest
        case 40..<60: return .moderateInterest
        case 20..<40: return .lowInterest
        default: return .apathy
        }
    }
}

// MARK: - App Store Ranking Calculator
enum AppStoreRankingCalculator {
    /// Calculates composite sentiment score from exchange app rankings
    /// - Parameters:
    ///   - rankings: Array of app store rankings
    ///   - maxRank: Maximum rank to normalize against (default 500 for Finance category)
    /// - Returns: Composite sentiment data
    static func calculateComposite(from rankings: [AppStoreRanking], maxRank: Int = 500) -> AppStoreCompositeSentiment {
        // Weights: Coinbase 50%, Binance 30%, Kraken 20%
        let weights: [String: Double] = [
            "Coinbase": 0.50,
            "Binance": 0.30,
            "Kraken": 0.20
        ]

        var weightedSum: Double = 0
        var totalWeight: Double = 0

        for ranking in rankings {
            guard let weight = weights[ranking.appName] else { continue }

            // Normalize: lower rank = higher interest
            // Score = (maxRank - actualRank) / maxRank * 100
            let normalizedScore = max(0, min(100, Double(maxRank - ranking.ranking) / Double(maxRank) * 100))
            weightedSum += normalizedScore * weight
            totalWeight += weight
        }

        let compositeScore = totalWeight > 0 ? weightedSum / totalWeight : 0
        let tier = AppStoreSentimentTier.from(score: compositeScore)

        return AppStoreCompositeSentiment(
            score: compositeScore,
            tier: tier,
            historicalPercentile: nil, // Would need historical data to calculate
            rankings: rankings,
            timestamp: Date()
        )
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
