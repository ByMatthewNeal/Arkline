import Foundation

// MARK: - API Coinglass Service
/// Real API implementation of CoinglassServiceProtocol.
/// Uses Coinglass API v4 for derivatives data.
final class APICoinglassService: CoinglassServiceProtocol {

    // MARK: - Configuration
    private let baseURL = "https://open-api-v4.coinglass.com/api"
    private var apiKey: String {
        // TODO: Move to secure storage / environment variable
        Constants.coinglassAPIKey
    }

    // MARK: - Open Interest

    func fetchOpenInterest(symbol: String) async throws -> OpenInterestData {
        let endpoint = "/futures/openInterest/exchange-list"
        let params = ["symbol": symbol.uppercased()]

        let response: CoinglassAPIResponse<[CoinglassOIResponse]> = try await request(endpoint: endpoint, params: params)

        guard let data = response.data.first else {
            throw AppError.dataNotFound
        }

        return OpenInterestData(
            id: UUID(),
            symbol: data.symbol,
            openInterest: data.openInterest,
            openInterestChange24h: data.h24Change ?? 0,
            openInterestChangePercent24h: data.h24ChangePercent ?? 0,
            timestamp: Date(),
            exchangeBreakdown: data.exchangeList?.map { exchange in
                ExchangeOI(
                    exchange: exchange.exchangeName,
                    openInterest: exchange.openInterest,
                    percentage: exchange.rate ?? 0
                )
            }
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
        let endpoint = "/futures/openInterest/ohlc-aggregated-history"
        let params = ["symbol": "BTC", "interval": "1h", "limit": "1"]

        // TODO: Implement proper total market OI calculation
        // This would aggregate OI across all coins
        throw AppError.notImplemented
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
        let endpoint = "/futures/liquidation/order"
        var params: [String: String] = ["limit": String(limit)]
        if let symbol = symbol {
            params["symbol"] = symbol.uppercased()
        }

        // TODO: Parse liquidation orders into LiquidationEvent
        throw AppError.notImplemented
    }

    // MARK: - Funding Rates

    func fetchFundingRate(symbol: String) async throws -> CoinglassFundingRateData {
        let endpoint = "/futures/fundingRate/exchange-list"
        let params = ["symbol": symbol.uppercased()]

        let response: CoinglassAPIResponse<CoinglassFundingRateResponse> = try await request(endpoint: endpoint, params: params)

        let avgRate = response.data.uMarginList?.reduce(0.0) { $0 + $1.rate } ?? 0
        let count = Double(response.data.uMarginList?.count ?? 1)
        let rate = avgRate / count

        return CoinglassFundingRateData(
            id: UUID(),
            symbol: response.data.symbol,
            fundingRate: rate,
            predictedRate: nil,
            nextFundingTime: response.data.uMarginList?.first?.nextFundingTime.map { Date(timeIntervalSince1970: TimeInterval($0 / 1000)) },
            annualizedRate: rate * 3 * 365 * 100, // Convert to percentage
            timestamp: Date(),
            exchangeRates: response.data.uMarginList?.map { exchange in
                CoinglassExchangeFundingRate(
                    exchange: exchange.exchangeName,
                    fundingRate: exchange.rate,
                    nextFundingTime: exchange.nextFundingTime.map { Date(timeIntervalSince1970: TimeInterval($0 / 1000)) }
                )
            }
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
        let endpoint = "/futures/fundingRate/oi-weight-ohlc-history"
        let params = ["symbol": symbol.uppercased(), "interval": "1h", "limit": "1"]

        // TODO: Parse weighted funding rate response
        throw AppError.notImplemented
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
        async let btcOI = fetchOpenInterest(symbol: "BTC")
        async let ethOI = fetchOpenInterest(symbol: "ETH")
        async let totalLiqs = fetchTotalLiquidations()
        async let btcFunding = fetchFundingRate(symbol: "BTC")
        async let ethFunding = fetchFundingRate(symbol: "ETH")
        async let btcLS = fetchLongShortRatio(symbol: "BTC")
        async let ethLS = fetchLongShortRatio(symbol: "ETH")

        let (btcOpenInterest, ethOpenInterest, liquidations, btcFundingRate, ethFundingRate, btcLongShort, ethLongShort) = try await (btcOI, ethOI, totalLiqs, btcFunding, ethFunding, btcLS, ethLS)

        let totalOI = btcOpenInterest.openInterest + ethOpenInterest.openInterest

        return DerivativesOverview(
            btcOpenInterest: btcOpenInterest,
            ethOpenInterest: ethOpenInterest,
            totalMarketOI: totalOI,
            totalLiquidations24h: liquidations,
            btcFundingRate: btcFundingRate,
            ethFundingRate: ethFundingRate,
            btcLongShortRatio: btcLongShort,
            ethLongShortRatio: ethLongShort,
            lastUpdated: Date()
        )
    }

    // MARK: - Private Networking

    private func request<T: Codable>(endpoint: String, params: [String: String]) async throws -> T {
        var components = URLComponents(string: baseURL + endpoint)
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }

        guard let url = components?.url else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "CG-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw AppError.unauthorized
            } else if httpResponse.statusCode == 429 {
                throw AppError.rateLimited
            }
            throw AppError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
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
