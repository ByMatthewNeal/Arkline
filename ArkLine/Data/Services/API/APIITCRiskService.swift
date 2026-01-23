import Foundation

// MARK: - API ITC Risk Service
/// Real implementation of ITCRiskServiceProtocol.
/// Uses client-side logarithmic regression with CoinGecko price data.
final class APIITCRiskService: ITCRiskServiceProtocol {
    // MARK: - Dependencies
    private let marketService: MarketServiceProtocol
    private let riskCalculator: RiskCalculator
    private let cache: RiskDataCache

    // MARK: - Initialization
    init(
        marketService: MarketServiceProtocol = ServiceContainer.shared.marketService,
        riskCalculator: RiskCalculator = .shared,
        cache: RiskDataCache = .shared
    ) {
        self.marketService = marketService
        self.riskCalculator = riskCalculator
        self.cache = cache
    }

    // MARK: - ITCRiskServiceProtocol (Legacy)

    func fetchRiskLevel(coin: String) async throws -> [ITCRiskLevel] {
        // Use enhanced method and convert to legacy format
        let history = try await fetchRiskHistory(coin: coin, days: 365)
        return history.map { ITCRiskLevel(from: $0) }
    }

    func fetchLatestRiskLevel(coin: String) async throws -> ITCRiskLevel? {
        let current = try await calculateCurrentRisk(coin: coin)
        return ITCRiskLevel(from: current)
    }

    // MARK: - Enhanced Methods

    func fetchRiskHistory(coin: String, days: Int?) async throws -> [RiskHistoryPoint] {
        // Check cache first
        if let cached = await cache.get(coin: coin, days: days) {
            return cached
        }

        // Get asset config
        guard let config = AssetRiskConfig.forCoin(coin) else {
            throw RiskCalculationError.unsupportedAsset(coin)
        }

        // Fetch price history from CoinGecko
        let effectiveDays = days ?? 365 // CoinGecko free tier max is 365 days
        let marketChart = try await marketService.fetchCoinMarketChart(
            id: config.geckoId,
            currency: "usd",
            days: effectiveDays
        )

        // Calculate risk history
        let riskHistory = riskCalculator.calculateRiskHistory(from: marketChart, config: config)

        guard !riskHistory.isEmpty else {
            throw RiskCalculationError.insufficientData(coin)
        }

        // Cache the results
        await cache.store(riskHistory, for: coin, days: days)

        return riskHistory
    }

    func calculateCurrentRisk(coin: String) async throws -> RiskHistoryPoint {
        // For current risk, we need a reasonable amount of history to fit regression
        // Use 365 days of data for accurate regression
        let history = try await fetchRiskHistory(coin: coin, days: 365)

        guard let latest = history.last else {
            throw RiskCalculationError.noDataAvailable(coin)
        }

        return latest
    }
}

// MARK: - Risk Calculation Errors
enum RiskCalculationError: LocalizedError {
    case unsupportedAsset(String)
    case insufficientData(String)
    case noDataAvailable(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedAsset(let coin):
            return "Risk calculation is not supported for \(coin)"
        case .insufficientData(let coin):
            return "Insufficient price history to calculate risk for \(coin)"
        case .noDataAvailable(let coin):
            return "No risk data available for \(coin)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
