import Foundation

// MARK: - Sentiment Service Protocol
/// Protocol defining sentiment and market indicator operations.
protocol SentimentServiceProtocol {
    /// Fetches the current Fear & Greed Index
    /// - Returns: Current FearGreedIndex
    func fetchFearGreedIndex() async throws -> FearGreedIndex

    /// Fetches historical Fear & Greed data
    /// - Parameter days: Number of days of history
    /// - Returns: Array of FearGreedIndex
    func fetchFearGreedHistory(days: Int) async throws -> [FearGreedIndex]

    /// Fetches current Bitcoin dominance
    /// - Returns: BTCDominance data
    func fetchBTCDominance() async throws -> BTCDominance

    /// Fetches ETF net flow data
    /// - Returns: ETFNetFlow data
    func fetchETFNetFlow() async throws -> ETFNetFlow

    /// Fetches average funding rate across exchanges
    /// - Returns: FundingRate data
    func fetchFundingRate() async throws -> FundingRate

    /// Fetches 24h liquidation data
    /// - Returns: LiquidationData
    func fetchLiquidations() async throws -> LiquidationData

    /// Fetches Altcoin Season Index
    /// - Returns: AltcoinSeasonIndex
    func fetchAltcoinSeason() async throws -> AltcoinSeasonIndex

    /// Fetches composite risk level
    /// - Returns: RiskLevel with indicators
    func fetchRiskLevel() async throws -> RiskLevel

    /// Fetches global liquidity data
    /// - Returns: GlobalLiquidity data
    func fetchGlobalLiquidity() async throws -> GlobalLiquidity

    /// Fetches App Store ranking data for a single crypto app (legacy)
    /// - Returns: AppStoreRanking
    func fetchAppStoreRanking() async throws -> AppStoreRanking

    /// Fetches App Store rankings for multiple crypto apps
    /// - Returns: Array of AppStoreRanking for Coinbase, Binance, Kraken, etc.
    func fetchAppStoreRankings() async throws -> [AppStoreRanking]

    /// Fetches the proprietary ArkLine Risk Score (0-100)
    /// - Returns: ArkLineRiskScore combining all sentiment indicators
    func fetchArkLineRiskScore() async throws -> ArkLineRiskScore

    /// Fetches Google Trends data for Bitcoin search interest
    /// - Returns: GoogleTrendsData with search volume index
    func fetchGoogleTrends() async throws -> GoogleTrendsData

    /// Fetches all sentiment data in one call
    /// - Returns: MarketOverview containing all indicators
    func fetchMarketOverview() async throws -> MarketOverview
}

// MARK: - ArkLine Risk Score (Proprietary 0-100 Composite)
/// ArkLine's proprietary risk score combining multiple sentiment indicators
struct ArkLineRiskScore: Equatable {
    let score: Int // 0-100 (0 = Extreme Fear/Low Risk to Buy, 100 = Extreme Greed/High Risk)
    let tier: SentimentTier
    let components: [RiskScoreComponent]
    let recommendation: String
    let timestamp: Date

    var displayScore: String {
        "\(score)"
    }
}

struct RiskScoreComponent: Equatable {
    let name: String
    let value: Double // Normalized 0-1
    let weight: Double
    let signal: SentimentTier
}

// MARK: - Sentiment Tier (Bullish/Neutral/Bearish)
enum SentimentTier: String, CaseIterable {
    case extremelyBullish = "Extremely Bullish"
    case bullish = "Bullish"
    case neutral = "Neutral"
    case bearish = "Bearish"
    case extremelyBearish = "Extremely Bearish"

    var color: String {
        switch self {
        case .extremelyBullish: return "#22C55E"
        case .bullish: return "#84CC16"
        case .neutral: return "#EAB308"
        case .bearish: return "#F97316"
        case .extremelyBearish: return "#EF4444"
        }
    }

    var icon: String {
        switch self {
        case .extremelyBullish: return "arrow.up.circle.fill"
        case .bullish: return "arrow.up.right.circle.fill"
        case .neutral: return "minus.circle.fill"
        case .bearish: return "arrow.down.right.circle.fill"
        case .extremelyBearish: return "arrow.down.circle.fill"
        }
    }

    static func from(score: Int) -> SentimentTier {
        switch score {
        case 0...20: return .extremelyBearish
        case 21...40: return .bearish
        case 41...60: return .neutral
        case 61...80: return .bullish
        default: return .extremelyBullish
        }
    }
}

// MARK: - Google Trends Data
struct GoogleTrendsData: Equatable {
    let keyword: String
    let currentIndex: Int // 0-100 relative search interest
    let weekAgoIndex: Int
    let monthAgoIndex: Int
    let trend: TrendDirection
    let timestamp: Date

    var changeFromLastWeek: Int {
        currentIndex - weekAgoIndex
    }

    var displayIndex: String {
        "\(currentIndex)"
    }
}

enum TrendDirection: String {
    case rising = "Rising"
    case stable = "Stable"
    case falling = "Falling"

    var icon: String {
        switch self {
        case .rising: return "arrow.up"
        case .stable: return "minus"
        case .falling: return "arrow.down"
        }
    }

    var color: String {
        switch self {
        case .rising: return "#22C55E"
        case .stable: return "#EAB308"
        case .falling: return "#EF4444"
        }
    }
}
