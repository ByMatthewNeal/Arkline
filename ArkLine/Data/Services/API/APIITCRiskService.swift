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

    // MARK: - Current Risk Cache (refreshes at 7am EST and 5pm EST)
    private var currentRiskCache: [String: (risk: RiskHistoryPoint, calculatedAt: Date)] = [:]
    private let cacheQueue = DispatchQueue(label: "com.arkline.riskCache")

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

        // Use embedded + incremental historical data
        let fullPriceHistory = await getEmbeddedPriceHistory(for: coin)

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

    /// Get price history from embedded data + incrementally fetched recent data.
    private func getEmbeddedPriceHistory(for coin: String) async -> [(date: Date, price: Double)] {
        return await IncrementalPriceStore.shared.fullPriceHistory(for: coin)
    }

    func calculateCurrentRisk(coin: String) async throws -> RiskHistoryPoint {
        let coinKey = coin.uppercased()

        // Check cache - only recalculate at 7am EST and 5pm EST
        if let cached = cacheQueue.sync(execute: { currentRiskCache[coinKey] }) {
            if !shouldRefreshRisk(lastCalculation: cached.calculatedAt) {
                logDebug("Using cached risk for \(coin) (calculated at \(cached.calculatedAt))", category: .network)
                return cached.risk
            }
        }

        logDebug("Calculating fresh risk for \(coin)...", category: .network)

        // Get asset config
        guard let config = AssetRiskConfig.forCoin(coin) else {
            throw RiskCalculationError.unsupportedAsset(coin)
        }

        // Fetch historical data for regression fitting
        let priceHistory = await getEmbeddedPriceHistory(for: coin)

        guard !priceHistory.isEmpty else {
            throw RiskCalculationError.insufficientData(coin)
        }

        // Fetch current price from Binance for today's calculation
        let currentPrice = try await fetchCurrentPrice(coin: coin)

        // Calculate risk for today using live price (with regression for confidence tracking)
        guard let result = riskCalculator.calculateRiskWithRegression(
            price: currentPrice,
            date: Date(),
            config: config,
            priceHistory: priceHistory
        ) else {
            throw RiskCalculationError.noDataAvailable(coin)
        }

        let riskPoint = result.risk

        // Track regression quality and prediction accuracy for adaptive confidence
        Task {
            await ConfidenceTracker.shared.recordCalculation(
                assetId: coinKey,
                rSquared: result.regression.rSquared,
                dataPointCount: priceHistory.count,
                riskLevel: riskPoint.riskLevel,
                price: currentPrice
            )
        }

        // Cache the result
        cacheQueue.sync {
            currentRiskCache[coinKey] = (risk: riskPoint, calculatedAt: Date())
        }

        return riskPoint
    }

    /// Check if risk should be refreshed based on 7am EST and 5pm EST schedule
    private func shouldRefreshRisk(lastCalculation: Date) -> Bool {
        let now = Date()

        // Get EST timezone
        guard let est = TimeZone(identifier: "America/New_York") else {
            return true // Fallback: refresh if timezone unavailable
        }

        var calendar = Calendar.current
        calendar.timeZone = est

        // Get today's 7am and 5pm EST
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)

        var sevenAMComponents = todayComponents
        sevenAMComponents.hour = 7
        sevenAMComponents.minute = 0
        sevenAMComponents.second = 0

        var fivePMComponents = todayComponents
        fivePMComponents.hour = 17
        fivePMComponents.minute = 0
        fivePMComponents.second = 0

        guard let todaySevenAM = calendar.date(from: sevenAMComponents),
              let todayFivePM = calendar.date(from: fivePMComponents) else {
            return true
        }

        // Find the most recent refresh time (7am or 5pm)
        let lastRefreshTime: Date
        if now >= todayFivePM {
            lastRefreshTime = todayFivePM
        } else if now >= todaySevenAM {
            lastRefreshTime = todaySevenAM
        } else {
            // Before 7am today, use yesterday's 5pm
            lastRefreshTime = calendar.date(byAdding: .day, value: -1, to: todayFivePM) ?? todayFivePM
        }

        // Refresh if last calculation was before the most recent refresh time
        return lastCalculation < lastRefreshTime
    }

    /// Fetch current price: tries Binance first, falls back to CoinGecko
    private func fetchCurrentPrice(coin: String) async throws -> Double {
        let config = AssetRiskConfig.forCoin(coin)

        // Try Binance first (fast, no rate limit)
        if let binanceSymbol = config?.binanceSymbol {
            do {
                let endpoint = BinanceEndpoint.tickerPrice(symbol: binanceSymbol)
                let data = try await NetworkManager.shared.requestData(endpoint: endpoint)

                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let priceString = json["price"] as? String,
                   let price = Double(priceString) {
                    return price
                }
            } catch {
                logDebug("Binance price fetch failed for \(coin), falling back to CoinGecko", category: .network)
            }
        }

        // Fallback to CoinGecko
        guard let geckoId = config?.geckoId else {
            throw RiskCalculationError.unsupportedAsset(coin)
        }

        let endpoint = CoinGeckoEndpoint.simplePrice(ids: [geckoId], currencies: ["usd"])
        let data = try await NetworkManager.shared.requestData(endpoint: endpoint)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let coinData = json?[geckoId] as? [String: Any],
              let price = coinData["usd"] as? Double else {
            throw RiskCalculationError.networkError(AppError.invalidResponse)
        }

        return price
    }

    // MARK: - Multi-Factor Risk Methods

    /// Calculate multi-factor risk combining 7 data sources.
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

        // Fetch price history, live price, and factor data in parallel
        async let historyTask = fetchPriceHistory(config: config)
        async let livePriceTask = fetchCurrentPrice(coin: coin)
        async let factorTask = factorFetcher.fetchFactors(for: coin)

        let (priceHistory, livePrice, factorData) = try await (historyTask, livePriceTask, factorTask)

        // Calculate multi-factor risk using live price and today's date
        guard let multiFactorRisk = riskCalculator.calculateMultiFactorRisk(
            price: livePrice,
            date: Date(),
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
        async let livePriceTask = fetchCurrentPrice(coin: coin)
        async let factorTask = factorFetcher.fetchFactors(for: coin)

        let (priceHistory, livePrice, factorData) = try await (historyTask, livePriceTask, factorTask)

        guard let config = AssetRiskConfig.forCoin(coin) else {
            throw RiskCalculationError.unsupportedAsset(coin)
        }

        guard let multiFactorRisk = riskCalculator.calculateMultiFactorRisk(
            price: livePrice,
            date: Date(),
            config: config,
            factorData: factorData,
            priceHistory: priceHistory
        ) else {
            throw RiskCalculationError.insufficientData(coin)
        }

        return (multiFactorRisk, factorData)
    }

    // MARK: - Private Helpers

    /// Get price history using embedded + incremental data.
    private func fetchPriceHistory(config: AssetRiskConfig) async throws -> [(date: Date, price: Double)] {
        let priceData = await IncrementalPriceStore.shared.fullPriceHistory(for: config.assetId)

        guard !priceData.isEmpty else {
            throw RiskCalculationError.insufficientData(config.assetId)
        }

        return priceData
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
