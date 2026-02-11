import Foundation

// MARK: - API Coinglass Service
/// Real API implementation of CoinglassServiceProtocol.
/// Uses Coinglass API v4 for derivatives data.
final class APICoinglassService: CoinglassServiceProtocol {

    // MARK: - Configuration
    // API key injected server-side by api-proxy Edge Function

    // MARK: - Open Interest

    func fetchOpenInterest(symbol: String) async throws -> OpenInterestData {
        // Use coin-list endpoint which is available on free tier
        let endpoint = "/futures/open-interest/coin-list"
        let params: [String: String] = [:]

        let response: CoinglassAPIResponse<[CoinglassOICoinResponse]> = try await request(endpoint: endpoint, params: params)

        // Find the requested symbol in the list
        guard let data = response.data.first(where: { $0.symbol.uppercased() == symbol.uppercased() }) else {
            throw AppError.dataNotFound
        }

        return OpenInterestData(
            id: UUID(),
            symbol: data.symbol,
            openInterest: data.openInterest,
            openInterestChange24h: data.h24Change ?? 0,
            openInterestChangePercent24h: data.h24ChangePercent ?? 0,
            timestamp: Date(),
            exchangeBreakdown: nil
        )
    }

    func fetchOpenInterestMultiple(symbols: [String]) async throws -> [OpenInterestData] {
        try await withThrowingTaskGroup(of: OpenInterestData.self) { group in
            for symbol in symbols {
                group.addTask {
                    try await self.fetchOpenInterest(symbol: symbol)
                }
            }

            var results: [OpenInterestData] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }

    func fetchTotalMarketOI() async throws -> Double {
        // Try to get BTC open interest as a proxy for total market
        // Full implementation would aggregate across all coins
        do {
            let btcOI = try await fetchOpenInterest(symbol: "BTC")
            return btcOI.openInterest
        } catch {
            logWarning("Could not fetch total market OI: \(error)", category: .network)
            return 0
        }
    }

    // MARK: - Liquidations

    func fetchLiquidations(symbol: String) async throws -> CoinglassLiquidationData {
        let endpoint = "/futures/liquidation/aggregated-history"
        let params = ["symbol": symbol.uppercased(), "interval": "1h", "limit": "24"]

        let response: CoinglassAPIResponse<[CoinglassLiquidationResponse]> = try await request(endpoint: endpoint, params: params)

        // Aggregate 24h liquidations
        var totalLong: Double = 0
        var totalShort: Double = 0

        for item in response.data {
            totalLong += item.longLiquidationUsd
            totalShort += item.shortLiquidationUsd
        }

        return CoinglassLiquidationData(
            id: UUID(),
            symbol: symbol.uppercased(),
            longLiquidations24h: totalLong,
            shortLiquidations24h: totalShort,
            totalLiquidations24h: totalLong + totalShort,
            largestLiquidation: nil, // Would need separate endpoint
            timestamp: Date()
        )
    }

    func fetchTotalLiquidations() async throws -> CoinglassLiquidationData {
        let endpoint = "/futures/liquidation/coin-list"

        let response: CoinglassAPIResponse<[CoinglassLiquidationResponse]> = try await request(endpoint: endpoint, params: [:])

        var totalLong: Double = 0
        var totalShort: Double = 0

        for item in response.data {
            totalLong += item.longLiquidationUsd
            totalShort += item.shortLiquidationUsd
        }

        return CoinglassLiquidationData(
            id: UUID(),
            symbol: "ALL",
            longLiquidations24h: totalLong,
            shortLiquidations24h: totalShort,
            totalLiquidations24h: totalLong + totalShort,
            largestLiquidation: nil,
            timestamp: Date()
        )
    }

    func fetchRecentLiquidations(symbol: String?, limit: Int) async throws -> [LiquidationEvent] {
        // Recent liquidation orders endpoint requires paid tier
        // Return empty array for graceful degradation
        logInfo("Recent liquidations requires Coinglass paid tier", category: .network)
        return []
    }

    // MARK: - Funding Rates

    func fetchFundingRate(symbol: String) async throws -> CoinglassFundingRateData {
        // Try the coin-list endpoint which is available on free tier
        let endpoint = "/futures/funding-rate/coin-list"
        let params: [String: String] = [:]

        let response: CoinglassAPIResponse<[CoinglassFundingCoinResponse]> = try await request(endpoint: endpoint, params: params)

        // Find the requested symbol in the list
        guard let coinData = response.data.first(where: { $0.symbol.uppercased() == symbol.uppercased() }) else {
            throw AppError.dataNotFound
        }

        return CoinglassFundingRateData(
            id: UUID(),
            symbol: coinData.symbol,
            fundingRate: coinData.rate,
            predictedRate: nil,
            nextFundingTime: nil,
            annualizedRate: coinData.rate * 3 * 365 * 100,
            timestamp: Date(),
            exchangeRates: nil
        )
    }

    func fetchFundingRatesMultiple(symbols: [String]) async throws -> [CoinglassFundingRateData] {
        try await withThrowingTaskGroup(of: CoinglassFundingRateData.self) { group in
            for symbol in symbols {
                group.addTask {
                    try await self.fetchFundingRate(symbol: symbol)
                }
            }

            var results: [CoinglassFundingRateData] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }

    func fetchWeightedFundingRate(symbol: String) async throws -> Double {
        // Use regular funding rate as approximation
        // Weighted rate requires aggregating across exchanges
        do {
            let fundingData = try await fetchFundingRate(symbol: symbol)
            return fundingData.fundingRate
        } catch {
            logWarning("Could not fetch weighted funding rate: \(error)", category: .network)
            return 0
        }
    }

    // MARK: - Long/Short Ratios

    func fetchLongShortRatio(symbol: String) async throws -> LongShortRatioData {
        let endpoint = "/futures/global-long-short-account-ratio/history"
        let params = ["symbol": symbol.uppercased(), "interval": "1h", "limit": "1"]

        let response: CoinglassAPIResponse<[CoinglassLongShortResponse]> = try await request(endpoint: endpoint, params: params)

        guard let data = response.data.first else {
            throw AppError.dataNotFound
        }

        return LongShortRatioData(
            id: UUID(),
            symbol: data.symbol,
            longRatio: data.longRate,
            shortRatio: data.shortRate,
            longShortRatio: data.longShortRatio,
            topTraderLongRatio: nil,
            topTraderShortRatio: nil,
            timestamp: Date(),
            exchangeRatios: nil
        )
    }

    func fetchTopTraderRatio(symbol: String) async throws -> LongShortRatioData {
        let endpoint = "/futures/top-long-short-account-ratio/history"
        let params = ["symbol": symbol.uppercased(), "interval": "1h", "limit": "1"]

        let response: CoinglassAPIResponse<[CoinglassLongShortResponse]> = try await request(endpoint: endpoint, params: params)

        guard let data = response.data.first else {
            throw AppError.dataNotFound
        }

        return LongShortRatioData(
            id: UUID(),
            symbol: data.symbol,
            longRatio: data.longRate,
            shortRatio: data.shortRate,
            longShortRatio: data.longShortRatio,
            topTraderLongRatio: data.longRate,
            topTraderShortRatio: data.shortRate,
            timestamp: Date(),
            exchangeRatios: nil
        )
    }

    // MARK: - Aggregated Overview

    func fetchDerivativesOverview() async throws -> DerivativesOverview {
        // Fetch all data with graceful failure handling
        // Some endpoints may not be available on all tiers

        // Required data - these must succeed
        async let btcOI = fetchOpenInterestSafe(symbol: "BTC")
        async let ethOI = fetchOpenInterestSafe(symbol: "ETH")
        async let btcFunding = fetchFundingRateSafe(symbol: "BTC")
        async let ethFunding = fetchFundingRateSafe(symbol: "ETH")
        async let btcLS = fetchLongShortRatioSafe(symbol: "BTC")
        async let ethLS = fetchLongShortRatioSafe(symbol: "ETH")

        // Optional data - may fail on lower tiers
        async let totalLiqs = fetchTotalLiquidationsSafe()

        let (btcOpenInterest, ethOpenInterest, btcFundingRate, ethFundingRate, btcLongShort, ethLongShort, liquidations) = await (btcOI, ethOI, btcFunding, ethFunding, btcLS, ethLS, totalLiqs)

        // Check if we have any usable data
        let hasOI = btcOpenInterest != nil || ethOpenInterest != nil
        let hasFunding = btcFundingRate != nil || ethFundingRate != nil
        let hasLS = btcLongShort != nil || ethLongShort != nil

        guard hasOI || hasFunding || hasLS else {
            logError("Coinglass: No derivatives data available from any endpoint", category: .network)
            throw AppError.dataNotFound
        }

        if !hasOI {
            logWarning("Coinglass: OI endpoints failed, using defaults", category: .network)
        }

        let totalOI = (btcOpenInterest?.openInterest ?? 0) + (ethOpenInterest?.openInterest ?? 0)

        // Create default values for missing data
        let defaultOI = OpenInterestData(
            id: UUID(),
            symbol: "N/A",
            openInterest: 0,
            openInterestChange24h: 0,
            openInterestChangePercent24h: 0,
            timestamp: Date(),
            exchangeBreakdown: nil
        )

        let defaultFunding = CoinglassFundingRateData(
            id: UUID(),
            symbol: "N/A",
            fundingRate: 0,
            predictedRate: nil,
            nextFundingTime: nil,
            annualizedRate: 0,
            timestamp: Date(),
            exchangeRates: nil
        )

        let defaultLS = LongShortRatioData(
            id: UUID(),
            symbol: "N/A",
            longRatio: 0.5,
            shortRatio: 0.5,
            longShortRatio: 1.0,
            topTraderLongRatio: nil,
            topTraderShortRatio: nil,
            timestamp: Date(),
            exchangeRatios: nil
        )

        let defaultLiquidations = CoinglassLiquidationData(
            id: UUID(),
            symbol: "ALL",
            longLiquidations24h: 0,
            shortLiquidations24h: 0,
            totalLiquidations24h: 0,
            largestLiquidation: nil,
            timestamp: Date()
        )

        return DerivativesOverview(
            btcOpenInterest: btcOpenInterest ?? defaultOI,
            ethOpenInterest: ethOpenInterest ?? defaultOI,
            totalMarketOI: totalOI,
            totalLiquidations24h: liquidations ?? defaultLiquidations,
            btcFundingRate: btcFundingRate ?? defaultFunding,
            ethFundingRate: ethFundingRate ?? defaultFunding,
            btcLongShortRatio: btcLongShort ?? defaultLS,
            ethLongShortRatio: ethLongShort ?? defaultLS,
            lastUpdated: Date()
        )
    }

    // MARK: - Safe Fetch Helpers (return nil on error)

    private func fetchOpenInterestSafe(symbol: String) async -> OpenInterestData? {
        do {
            return try await fetchOpenInterest(symbol: symbol)
        } catch {
            logWarning("Coinglass OI fetch failed for \(symbol): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchFundingRateSafe(symbol: String) async -> CoinglassFundingRateData? {
        do {
            return try await fetchFundingRate(symbol: symbol)
        } catch {
            logWarning("Coinglass Funding fetch failed for \(symbol): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchLongShortRatioSafe(symbol: String) async -> LongShortRatioData? {
        do {
            return try await fetchLongShortRatio(symbol: symbol)
        } catch {
            logWarning("Coinglass L/S ratio fetch failed for \(symbol): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    private func fetchTotalLiquidationsSafe() async -> CoinglassLiquidationData? {
        do {
            return try await fetchTotalLiquidations()
        } catch {
            logWarning("Coinglass Liquidations fetch failed (may require higher tier): \(error.localizedDescription)", category: .network)
            return nil
        }
    }

    // MARK: - Private Networking

    private func request<T: Codable>(endpoint: String, params: [String: String]) async throws -> T {
        // CG-API-KEY header injected server-side by api-proxy Edge Function
        let data = try await APIProxy.shared.request(
            service: .coinglass,
            path: endpoint,
            queryItems: params.isEmpty ? nil : params
        )

        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logError("Coinglass decode error for \(endpoint)", category: .network)
            throw error
        }
    }
}

// MARK: - App Errors Extension
extension AppError {
    static let unauthorized = AppError.custom(message: "Invalid API key")
    static let rateLimited = AppError.custom(message: "Rate limit exceeded")

    static func serverError(statusCode: Int) -> AppError {
        .custom(message: "Server error: \(statusCode)")
    }
}
