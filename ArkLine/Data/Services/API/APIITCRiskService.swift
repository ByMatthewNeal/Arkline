import Foundation

// MARK: - API ITC Risk Service
/// Real implementation of ITCRiskServiceProtocol.
/// Uses client-side logarithmic regression with embedded historical price data.
/// Enhanced with multi-factor risk model combining 6 data sources.
///
/// Data Strategy:
/// - Historical data (pre-embedded): Uses HistoricalPriceData.swift for full price history
/// - Recent data: Fetches last few days from CoinGecko to stay current
/// - This eliminates dependency on external APIs for historical data
final class APIITCRiskService: ITCRiskServiceProtocol {
    // MARK: - Dependencies
    private let marketService: MarketServiceProtocol
    private let riskCalculator: RiskCalculator
    private let cache: RiskDataCache
    private let factorFetcher: RiskFactorFetcher

    // MARK: - Initialization
    init(
        marketService: MarketServiceProtocol = ServiceContainer.shared.marketService,
        riskCalculator: RiskCalculator = .shared,
        cache: RiskDataCache = .shared,
        factorFetcher: RiskFactorFetcher = .shared
    ) {
        self.marketService = marketService
        self.riskCalculator = riskCalculator
        self.cache = cache
        self.factorFetcher = factorFetcher
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

        // Use embedded historical data (no API dependency)
        let fullPriceHistory = getEmbeddedPriceHistory(for: coin)

        guard !fullPriceHistory.isEmpty else {
            throw RiskCalculationError.insufficientData(coin)
        }

        // Calculate risk history from embedded data
        let fullRiskHistory = riskCalculator.calculateRiskHistory(prices: fullPriceHistory, config: config)

        guard !fullRiskHistory.isEmpty else {
            throw RiskCalculationError.insufficientData(coin)
        }

        // Filter by days if specified
        let riskHistory: [RiskHistoryPoint]
        if let days = days {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            riskHistory = fullRiskHistory.filter { $0.date >= cutoffDate }
        } else {
            riskHistory = fullRiskHistory
        }

        // Cache the results
        await cache.store(riskHistory, for: coin, days: days)

        return riskHistory
    }

    // MARK: - Embedded Data Access

    /// Get price history from embedded data (no API call needed)
    private func getEmbeddedPriceHistory(for coin: String) -> [(date: Date, price: Double)] {
        return HistoricalPriceData.pricesAsTuples(for: coin)
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

    // MARK: - Multi-Factor Risk Methods

    /// Calculate multi-factor risk combining 6 data sources.
    /// - Parameters:
    ///   - coin: Coin symbol (BTC, ETH)
    ///   - weights: Weight configuration (defaults to standard weights)
    /// - Returns: Multi-factor risk point with full breakdown
    func calculateMultiFactorRisk(
        coin: String,
        weights: RiskFactorWeights = .default
    ) async throws -> MultiFactorRiskPoint {
        // Get asset config
        guard let config = AssetRiskConfig.forCoin(coin) else {
            throw RiskCalculationError.unsupportedAsset(coin)
        }

        // Fetch price history and factor data in parallel
        async let historyTask = fetchPriceHistory(config: config)
        async let factorTask = factorFetcher.fetchFactors(for: coin)

        let (priceHistory, factorData) = try await (historyTask, factorTask)

        guard let latestPrice = priceHistory.last else {
            throw RiskCalculationError.noDataAvailable(coin)
        }

        // Calculate multi-factor risk
        guard let multiFactorRisk = riskCalculator.calculateMultiFactorRisk(
            price: latestPrice.price,
            date: latestPrice.date,
            config: config,
            factorData: factorData,
            weights: weights,
            priceHistory: priceHistory
        ) else {
            throw RiskCalculationError.insufficientData(coin)
        }

        return multiFactorRisk
    }

    /// Calculate enhanced current risk using multi-factor model.
    /// Returns backward-compatible RiskHistoryPoint.
    /// - Parameter coin: Coin symbol (BTC, ETH)
    /// - Returns: Risk history point with enhanced calculation
    func calculateEnhancedCurrentRisk(coin: String) async throws -> RiskHistoryPoint {
        let multiFactorRisk = try await calculateMultiFactorRisk(coin: coin)
        return multiFactorRisk.toRiskHistoryPoint()
    }

    /// Get detailed risk breakdown for UI display.
    /// - Parameter coin: Coin symbol (BTC, ETH)
    /// - Returns: Tuple of multi-factor risk point and factor data
    func getRiskBreakdown(coin: String) async throws -> (risk: MultiFactorRiskPoint, factors: RiskFactorData) {
        guard let config = AssetRiskConfig.forCoin(coin) else {
            throw RiskCalculationError.unsupportedAsset(coin)
        }

        async let historyTask = fetchPriceHistory(config: config)
        async let factorTask = factorFetcher.fetchFactors(for: coin)

        let (priceHistory, factorData) = try await (historyTask, factorTask)

        guard let latestPrice = priceHistory.last else {
            throw RiskCalculationError.noDataAvailable(coin)
        }

        guard let multiFactorRisk = riskCalculator.calculateMultiFactorRisk(
            price: latestPrice.price,
            date: latestPrice.date,
            config: AssetRiskConfig.forCoin(coin)!,
            factorData: factorData,
            priceHistory: priceHistory
        ) else {
            throw RiskCalculationError.insufficientData(coin)
        }

        return (multiFactorRisk, factorData)
    }

    // MARK: - Private Helpers

    /// Get price history using embedded data (no API dependency)
    private func fetchPriceHistory(config: AssetRiskConfig) async throws -> [(date: Date, price: Double)] {
        // Use embedded historical data - no API call needed
        let embeddedData = HistoricalPriceData.pricesAsTuples(for: config.assetId)

        guard !embeddedData.isEmpty else {
            throw RiskCalculationError.insufficientData(config.assetId)
        }

        return embeddedData
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
