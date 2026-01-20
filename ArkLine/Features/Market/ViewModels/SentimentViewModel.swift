import SwiftUI

// MARK: - Sentiment View Model
@Observable
class SentimentViewModel {
    // MARK: - Dependencies
    private let sentimentService: SentimentServiceProtocol

    // MARK: - Properties
    var isLoading = false
    var errorMessage: String?

    // Sentiment Indicators
    var fearGreedIndex: FearGreedIndex?
    var btcDominance: BTCDominance?
    var etfNetFlow: ETFNetFlow?
    var fundingRate: FundingRate?
    var liquidations: LiquidationData?
    var altcoinSeason: AltcoinSeasonIndex?
    var globalLiquidity: GlobalLiquidity?

    // New Properties for Market Overview Redesign
    var riskLevel: RiskLevel?
    var appStoreRanking: AppStoreRanking?
    var bitcoinSearchIndex: Int = 66
    var totalMarketCap: Double = 3_320_000_000_000
    var marketCapChange24h: Double = 2.29
    var marketCapHistory: [Double] = []

    // Historical Data
    var fearGreedHistory: [FearGreedIndex] = []

    // MARK: - Computed Properties
    var overallSentiment: SentimentLevel {
        guard let fg = fearGreedIndex else { return .neutral }

        switch fg.value {
        case 0..<25: return .extremeFear
        case 25..<45: return .fear
        case 45..<55: return .neutral
        case 55..<75: return .greed
        default: return .extremeGreed
        }
    }

    var sentimentCards: [SentimentCardData] {
        var cards: [SentimentCardData] = []

        if let fg = fearGreedIndex {
            cards.append(SentimentCardData(
                id: "fear_greed",
                title: "Fear & Greed",
                value: "\(fg.value)",
                subtitle: fg.classification,
                change: nil,
                icon: "gauge.with.needle.fill",
                color: Color(hex: fg.level.color.replacingOccurrences(of: "#", with: ""))
            ))
        }

        if let btc = btcDominance {
            cards.append(SentimentCardData(
                id: "btc_dominance",
                title: "BTC Dominance",
                value: btc.displayValue,
                subtitle: btc.change24h >= 0 ? "Increasing" : "Decreasing",
                change: btc.change24h,
                icon: "bitcoinsign.circle.fill",
                color: Color(hex: "F7931A")
            ))
        }

        if let etf = etfNetFlow {
            cards.append(SentimentCardData(
                id: "etf_flow",
                title: "ETF Net Flow",
                value: etf.dailyFormatted,
                subtitle: etf.isPositive ? "Inflow" : "Outflow",
                change: nil,
                icon: "arrow.left.arrow.right.circle.fill",
                color: etf.isPositive ? Color(hex: "22C55E") : Color(hex: "EF4444")
            ))
        }

        if let funding = fundingRate {
            cards.append(SentimentCardData(
                id: "funding_rate",
                title: "Funding Rate",
                value: funding.displayRate,
                subtitle: funding.sentiment,
                change: nil,
                icon: "percent",
                color: funding.averageRate >= 0 ? Color(hex: "22C55E") : Color(hex: "EF4444")
            ))
        }

        if let liq = liquidations {
            let longPercent = (liq.longLiquidations / liq.total24h) * 100
            cards.append(SentimentCardData(
                id: "liquidations",
                title: "24h Liquidations",
                value: liq.totalFormatted,
                subtitle: String(format: "%.0f%% Long", longPercent),
                change: nil,
                icon: "flame.fill",
                color: Color(hex: "F97316")
            ))
        }

        if let alt = altcoinSeason {
            cards.append(SentimentCardData(
                id: "altcoin_season",
                title: "Altcoin Season",
                value: "\(alt.value)",
                subtitle: alt.season,
                change: nil,
                icon: "sparkles",
                color: alt.isBitcoinSeason ? Color(hex: "F7931A") : Color(hex: "8B5CF6")
            ))
        }

        return cards
    }

    // MARK: - Initialization
    init(sentimentService: SentimentServiceProtocol = ServiceContainer.shared.sentimentService) {
        self.sentimentService = sentimentService
        Task { await loadInitialData() }
    }

    // MARK: - Public Methods
    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            async let fgTask = sentimentService.fetchFearGreedIndex()
            async let btcTask = sentimentService.fetchBTCDominance()
            async let etfTask = fetchETFSafe()
            async let fundingTask = fetchFundingSafe()
            async let liqTask = fetchLiquidationsSafe()
            async let altTask = fetchAltcoinSeasonSafe()
            async let riskTask = fetchRiskLevelSafe()

            let (fg, btc, etf, funding, liq, alt, risk) = try await (fgTask, btcTask, etfTask, fundingTask, liqTask, altTask, riskTask)

            await MainActor.run {
                self.fearGreedIndex = fg
                self.btcDominance = btc
                self.etfNetFlow = etf
                self.fundingRate = funding
                self.liquidations = liq
                self.altcoinSeason = alt
                self.riskLevel = risk
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func fetchFearGreedHistory(days: Int = 30) async {
        do {
            let history = try await sentimentService.fetchFearGreedHistory(days: days)
            await MainActor.run {
                self.fearGreedHistory = history
            }
        } catch {
            // Silently fail for history - not critical
        }
    }

    // MARK: - Private Methods
    private func loadInitialData() async {
        await refresh()
        await fetchFearGreedHistory()
    }

    // Safe fetch methods that return nil on error (for non-critical data)
    private func fetchETFSafe() async -> ETFNetFlow? {
        try? await sentimentService.fetchETFNetFlow()
    }

    private func fetchFundingSafe() async -> FundingRate? {
        try? await sentimentService.fetchFundingRate()
    }

    private func fetchLiquidationsSafe() async -> LiquidationData? {
        try? await sentimentService.fetchLiquidations()
    }

    private func fetchAltcoinSeasonSafe() async -> AltcoinSeasonIndex? {
        try? await sentimentService.fetchAltcoinSeason()
    }

    private func fetchRiskLevelSafe() async -> RiskLevel? {
        try? await sentimentService.fetchRiskLevel()
    }
}

// MARK: - Sentiment Level
enum SentimentLevel {
    case extremeFear
    case fear
    case neutral
    case greed
    case extremeGreed

    var displayName: String {
        switch self {
        case .extremeFear: return "Extreme Fear"
        case .fear: return "Fear"
        case .neutral: return "Neutral"
        case .greed: return "Greed"
        case .extremeGreed: return "Extreme Greed"
        }
    }

    var color: Color {
        switch self {
        case .extremeFear: return Color(hex: "EF4444")
        case .fear: return Color(hex: "F97316")
        case .neutral: return Color(hex: "EAB308")
        case .greed: return Color(hex: "84CC16")
        case .extremeGreed: return Color(hex: "22C55E")
        }
    }
}

// MARK: - Sentiment Card Data
struct SentimentCardData: Identifiable {
    let id: String
    let title: String
    let value: String
    let subtitle: String
    let change: Double?
    let icon: String
    let color: Color
}
