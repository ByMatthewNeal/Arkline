import SwiftUI

// MARK: - Sentiment View Model
@Observable
class SentimentViewModel {
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
    init() {
        loadMockData()
    }

    // MARK: - Public Methods
    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            async let fg = fetchFearGreedIndex()
            async let btc = fetchBTCDominance()
            async let etf = fetchETFNetFlow()
            async let funding = fetchFundingRate()
            async let liq = fetchLiquidations()
            async let alt = fetchAltcoinSeason()

            let (fgResult, btcResult, etfResult, fundingResult, liqResult, altResult) = try await (fg, btc, etf, funding, liq, alt)

            await MainActor.run {
                self.fearGreedIndex = fgResult
                self.btcDominance = btcResult
                self.etfNetFlow = etfResult
                self.fundingRate = fundingResult
                self.liquidations = liqResult
                self.altcoinSeason = altResult
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - Private Methods
    private func fetchFearGreedIndex() async throws -> FearGreedIndex {
        try await Task.sleep(nanoseconds: 300_000_000)
        return FearGreedIndex(value: 65, classification: "Greed", timestamp: Date())
    }

    private func fetchBTCDominance() async throws -> BTCDominance {
        try await Task.sleep(nanoseconds: 200_000_000)
        return BTCDominance(value: 52.3, change24h: 0.5, timestamp: Date())
    }

    private func fetchETFNetFlow() async throws -> ETFNetFlow {
        try await Task.sleep(nanoseconds: 200_000_000)
        return ETFNetFlow(
            totalNetFlow: 58_000_000_000,
            dailyNetFlow: 245_000_000,
            etfData: [
                ETFData(ticker: "IBIT", name: "BlackRock iShares", netFlow: 125_000_000, aum: 21_000_000_000),
                ETFData(ticker: "FBTC", name: "Fidelity", netFlow: 85_000_000, aum: 12_500_000_000),
                ETFData(ticker: "GBTC", name: "Grayscale", netFlow: -45_000_000, aum: 15_000_000_000)
            ],
            timestamp: Date()
        )
    }

    private func fetchFundingRate() async throws -> FundingRate {
        try await Task.sleep(nanoseconds: 200_000_000)
        return FundingRate(averageRate: 0.0125, exchanges: [], timestamp: Date())
    }

    private func fetchLiquidations() async throws -> LiquidationData {
        try await Task.sleep(nanoseconds: 200_000_000)
        return LiquidationData(total24h: 125_000_000, longLiquidations: 85_000_000, shortLiquidations: 40_000_000, largestSingleLiquidation: 5_200_000, timestamp: Date())
    }

    private func fetchAltcoinSeason() async throws -> AltcoinSeasonIndex {
        try await Task.sleep(nanoseconds: 200_000_000)
        return AltcoinSeasonIndex(value: 42, isBitcoinSeason: true, timestamp: Date())
    }

    private func loadMockData() {
        fearGreedIndex = FearGreedIndex(value: 65, classification: "Greed", timestamp: Date())
        btcDominance = BTCDominance(value: 52.3, change24h: 0.5, timestamp: Date())
        etfNetFlow = ETFNetFlow(totalNetFlow: 58_000_000_000, dailyNetFlow: 245_000_000, etfData: [], timestamp: Date())
        fundingRate = FundingRate(averageRate: 0.0125, exchanges: [], timestamp: Date())
        liquidations = LiquidationData(total24h: 125_000_000, longLiquidations: 85_000_000, shortLiquidations: 40_000_000, largestSingleLiquidation: 5_200_000, timestamp: Date())
        altcoinSeason = AltcoinSeasonIndex(value: 42, isBitcoinSeason: true, timestamp: Date())
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
