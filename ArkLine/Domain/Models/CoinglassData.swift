import Foundation

// MARK: - Open Interest Data
struct OpenInterestData: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let openInterest: Double          // Total OI in USD
    let openInterestChange24h: Double // 24h change in USD
    let openInterestChangePercent24h: Double
    let timestamp: Date

    // Exchange breakdown
    let exchangeBreakdown: [ExchangeOI]?

    var formattedOI: String {
        formatLargeNumber(openInterest)
    }

    var formattedChange: String {
        let sign = openInterestChange24h >= 0 ? "+" : ""
        return "\(sign)\(formatLargeNumber(openInterestChange24h))"
    }

    var isPositiveChange: Bool {
        openInterestChange24h >= 0
    }

    private func formatLargeNumber(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if absValue >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        } else if absValue >= 1_000 {
            return String(format: "$%.1fK", value / 1_000)
        }
        return String(format: "$%.0f", value)
    }
}

struct ExchangeOI: Codable, Identifiable {
    var id: String { exchange }
    let exchange: String
    let openInterest: Double
    let percentage: Double
}

// MARK: - Coinglass Liquidation Data
struct CoinglassLiquidationData: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let longLiquidations24h: Double   // Long liquidations in USD
    let shortLiquidations24h: Double  // Short liquidations in USD
    let totalLiquidations24h: Double
    let largestLiquidation: LiquidationEvent?
    let timestamp: Date

    var formattedTotal: String {
        formatLargeNumber(totalLiquidations24h)
    }

    var formattedLongs: String {
        formatLargeNumber(longLiquidations24h)
    }

    var formattedShorts: String {
        formatLargeNumber(shortLiquidations24h)
    }

    var longPercentage: Double {
        guard totalLiquidations24h > 0 else { return 50 }
        return (longLiquidations24h / totalLiquidations24h) * 100
    }

    var shortPercentage: Double {
        guard totalLiquidations24h > 0 else { return 50 }
        return (shortLiquidations24h / totalLiquidations24h) * 100
    }

    private func formatLargeNumber(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1_000_000_000 {
            return String(format: "$%.2fB", value / 1_000_000_000)
        } else if absValue >= 1_000_000 {
            return String(format: "$%.2fM", value / 1_000_000)
        } else if absValue >= 1_000 {
            return String(format: "$%.1fK", value / 1_000)
        }
        return String(format: "$%.0f", value)
    }
}

struct LiquidationEvent: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let exchange: String
    let side: LiquidationSide
    let amount: Double
    let price: Double
    let timestamp: Date

    var formattedAmount: String {
        if amount >= 1_000_000 {
            return String(format: "$%.2fM", amount / 1_000_000)
        } else if amount >= 1_000 {
            return String(format: "$%.1fK", amount / 1_000)
        }
        return String(format: "$%.0f", amount)
    }
}

enum LiquidationSide: String, Codable {
    case long = "LONG"
    case short = "SHORT"

    var displayName: String {
        switch self {
        case .long: return "Long"
        case .short: return "Short"
        }
    }

    var color: String {
        switch self {
        case .long: return "#22C55E"  // Green
        case .short: return "#EF4444" // Red
        }
    }
}

// MARK: - Funding Rate Data
struct CoinglassFundingRateData: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let fundingRate: Double           // Current funding rate (e.g., 0.01 = 0.01%)
    let predictedRate: Double?        // Next predicted rate
    let nextFundingTime: Date?
    let annualizedRate: Double        // Annualized funding rate
    let timestamp: Date

    // Exchange breakdown
    let exchangeRates: [CoinglassExchangeFundingRate]?

    var formattedRate: String {
        String(format: "%.4f%%", fundingRate * 100)
    }

    var formattedAnnualized: String {
        String(format: "%.2f%%", annualizedRate)
    }

    var sentiment: FundingRateSentiment {
        if fundingRate > 0.01 {
            return .veryBullish
        } else if fundingRate > 0.005 {
            return .bullish
        } else if fundingRate > -0.005 {
            return .neutral
        } else if fundingRate > -0.01 {
            return .bearish
        } else {
            return .veryBearish
        }
    }
}

struct CoinglassExchangeFundingRate: Codable, Identifiable {
    var id: String { exchange }
    let exchange: String
    let fundingRate: Double
    let nextFundingTime: Date?

    var formattedRate: String {
        String(format: "%.4f%%", fundingRate * 100)
    }
}

enum FundingRateSentiment: String {
    case veryBullish = "Very Bullish"
    case bullish = "Bullish"
    case neutral = "Neutral"
    case bearish = "Bearish"
    case veryBearish = "Very Bearish"

    var color: String {
        switch self {
        case .veryBullish: return "#22C55E"
        case .bullish: return "#4ADE80"
        case .neutral: return "#A1A1AA"
        case .bearish: return "#F87171"
        case .veryBearish: return "#EF4444"
        }
    }

    var icon: String {
        switch self {
        case .veryBullish: return "arrow.up.circle.fill"
        case .bullish: return "arrow.up.right.circle"
        case .neutral: return "minus.circle"
        case .bearish: return "arrow.down.right.circle"
        case .veryBearish: return "arrow.down.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .veryBullish: return "Longs paying high premium - potential local top"
        case .bullish: return "Longs paying premium - bullish sentiment"
        case .neutral: return "Balanced market - no strong directional bias"
        case .bearish: return "Shorts paying premium - bearish sentiment"
        case .veryBearish: return "Shorts paying high premium - potential local bottom"
        }
    }
}

// MARK: - Long/Short Ratio Data
struct LongShortRatioData: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let longRatio: Double             // e.g., 0.52 = 52% long
    let shortRatio: Double            // e.g., 0.48 = 48% short
    let longShortRatio: Double        // e.g., 1.08 = 52/48
    let topTraderLongRatio: Double?   // Top traders long %
    let topTraderShortRatio: Double?  // Top traders short %
    let timestamp: Date

    // Exchange breakdown
    let exchangeRatios: [ExchangeLongShortRatio]?

    var formattedLongPercent: String {
        String(format: "%.1f%%", longRatio * 100)
    }

    var formattedShortPercent: String {
        String(format: "%.1f%%", shortRatio * 100)
    }

    var formattedRatio: String {
        String(format: "%.2f", longShortRatio)
    }

    var sentiment: LongShortSentiment {
        if longShortRatio > 1.5 {
            return .extremeLong
        } else if longShortRatio > 1.1 {
            return .longBias
        } else if longShortRatio > 0.9 {
            return .balanced
        } else if longShortRatio > 0.67 {
            return .shortBias
        } else {
            return .extremeShort
        }
    }
}

struct ExchangeLongShortRatio: Codable, Identifiable {
    var id: String { exchange }
    let exchange: String
    let longRatio: Double
    let shortRatio: Double
    let longShortRatio: Double
}

enum LongShortSentiment: String {
    case extremeLong = "Extreme Long"
    case longBias = "Long Bias"
    case balanced = "Balanced"
    case shortBias = "Short Bias"
    case extremeShort = "Extreme Short"

    var color: String {
        switch self {
        case .extremeLong: return "#22C55E"
        case .longBias: return "#4ADE80"
        case .balanced: return "#A1A1AA"
        case .shortBias: return "#F87171"
        case .extremeShort: return "#EF4444"
        }
    }

    var description: String {
        switch self {
        case .extremeLong: return "Crowded long - high squeeze risk"
        case .longBias: return "More traders positioned long"
        case .balanced: return "Evenly positioned market"
        case .shortBias: return "More traders positioned short"
        case .extremeShort: return "Crowded short - high squeeze risk"
        }
    }
}

// MARK: - Aggregated Derivatives Overview
struct DerivativesOverview: Codable {
    let btcOpenInterest: OpenInterestData
    let ethOpenInterest: OpenInterestData
    let totalMarketOI: Double
    let totalLiquidations24h: CoinglassLiquidationData
    let btcFundingRate: CoinglassFundingRateData
    let ethFundingRate: CoinglassFundingRateData
    let btcLongShortRatio: LongShortRatioData
    let ethLongShortRatio: LongShortRatioData
    let lastUpdated: Date

    var formattedTotalOI: String {
        if totalMarketOI >= 1_000_000_000 {
            return String(format: "$%.2fB", totalMarketOI / 1_000_000_000)
        }
        return String(format: "$%.2fM", totalMarketOI / 1_000_000)
    }
}

// MARK: - Coinglass API Response Models
struct CoinglassAPIResponse<T: Codable>: Codable {
    let code: String
    let msg: String
    let data: T
    let success: Bool

    // Handle code being either String or Int from API
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try String first, then Int
        if let codeString = try? container.decode(String.self, forKey: .code) {
            code = codeString
        } else if let codeInt = try? container.decode(Int.self, forKey: .code) {
            code = String(codeInt)
        } else {
            code = "0"
        }

        msg = try container.decode(String.self, forKey: .msg)
        data = try container.decode(T.self, forKey: .data)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? true
    }

    enum CodingKeys: String, CodingKey {
        case code, msg, data, success
    }
}

struct CoinglassOIResponse: Codable {
    let symbol: String
    let openInterest: Double
    let h24Change: Double?
    let h24ChangePercent: Double?
    let exchangeList: [CoinglassExchangeOI]?
}

struct CoinglassExchangeOI: Codable {
    let exchangeName: String
    let openInterest: Double
    let rate: Double?
}

struct CoinglassFundingRateResponse: Codable {
    let symbol: String
    let uMarginList: [CoinglassExchangeFunding]?
}

struct CoinglassExchangeFunding: Codable {
    let exchangeName: String
    let rate: Double
    let nextFundingTime: Int64?
}

struct CoinglassLiquidationResponse: Codable {
    let symbol: String?
    let longLiquidationUsd: Double
    let shortLiquidationUsd: Double
    let totalLiquidationUsd: Double?
}

struct CoinglassLongShortResponse: Codable {
    let symbol: String
    let longRate: Double
    let shortRate: Double
    let longShortRatio: Double
}

// MARK: - Coin List Response Models (Free Tier)
struct CoinglassFundingCoinResponse: Codable {
    let symbol: String
    let rate: Double
    let uRate: Double?
    let cRate: Double?

    enum CodingKeys: String, CodingKey {
        case symbol
        case rate
        case uRate = "u_rate"
        case cRate = "c_rate"
    }
}

struct CoinglassOICoinResponse: Codable {
    let symbol: String
    let openInterest: Double
    let h24Change: Double?
    let h24ChangePercent: Double?

    enum CodingKeys: String, CodingKey {
        case symbol
        case openInterest = "open_interest"
        case h24Change = "h24_change"
        case h24ChangePercent = "h24_change_percent"
    }
}
