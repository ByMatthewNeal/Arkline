import Foundation

// MARK: - Binance Funding Rate Service
/// Fetches funding rates from Binance Futures API (free, no API key required)
final class APIBinanceFundingService {
    private let baseURL = "https://fapi.binance.com"

    // MARK: - Public Methods

    /// Fetch current funding rate for a symbol
    func fetchFundingRate(symbol: String) async throws -> BinanceFundingRate {
        let endpoint = "/fapi/v1/fundingRate"
        let params = ["symbol": "\(symbol.uppercased())USDT", "limit": "1"]

        let rates: [BinanceFundingRateResponse] = try await request(endpoint: endpoint, params: params)

        guard let latest = rates.first else {
            throw AppError.dataNotFound
        }

        return BinanceFundingRate(
            symbol: symbol.uppercased(),
            fundingRate: Double(latest.fundingRate) ?? 0,
            fundingTime: Date(timeIntervalSince1970: TimeInterval(latest.fundingTime) / 1000),
            markPrice: Double(latest.markPrice ?? "0") ?? 0
        )
    }

    /// Fetch funding rates for multiple symbols
    func fetchFundingRates(symbols: [String]) async throws -> [BinanceFundingRate] {
        try await withThrowingTaskGroup(of: BinanceFundingRate?.self) { group in
            for symbol in symbols {
                group.addTask {
                    try? await self.fetchFundingRate(symbol: symbol)
                }
            }

            var results: [BinanceFundingRate] = []
            for try await result in group {
                if let rate = result {
                    results.append(rate)
                }
            }
            return results
        }
    }

    /// Fetch premium index (includes predicted funding rate)
    func fetchPremiumIndex(symbol: String) async throws -> BinancePremiumIndex {
        let endpoint = "/fapi/v1/premiumIndex"
        let params = ["symbol": "\(symbol.uppercased())USDT"]

        let response: BinancePremiumIndexResponse = try await request(endpoint: endpoint, params: params)

        let fundingRate = Double(response.lastFundingRate) ?? 0
        logDebug("Binance \(symbol) funding rate: \(response.lastFundingRate) -> \(fundingRate)", category: .network)

        return BinancePremiumIndex(
            symbol: symbol.uppercased(),
            markPrice: Double(response.markPrice) ?? 0,
            indexPrice: Double(response.indexPrice) ?? 0,
            lastFundingRate: fundingRate,
            nextFundingTime: Date(timeIntervalSince1970: TimeInterval(response.nextFundingTime) / 1000),
            interestRate: Double(response.interestRate) ?? 0
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await PinnedURLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let responseStr = String(data: data, encoding: .utf8) {
                logError("Binance API Error (\(httpResponse.statusCode)): \(responseStr)", category: .network)
            }
            throw AppError.serverError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Response Models
struct BinanceFundingRateResponse: Codable {
    let symbol: String
    let fundingRate: String
    let fundingTime: Int64
    let markPrice: String?
}

struct BinancePremiumIndexResponse: Codable {
    let symbol: String
    let markPrice: String
    let indexPrice: String
    let lastFundingRate: String
    let nextFundingTime: Int64
    let interestRate: String
}

// MARK: - Domain Models
struct BinanceFundingRate {
    let symbol: String
    let fundingRate: Double
    let fundingTime: Date
    let markPrice: Double

    var fundingRatePercent: Double {
        fundingRate * 100
    }

    var annualizedRate: Double {
        fundingRate * 3 * 365 * 100 // 3 funding periods per day * 365 days * 100 for percent
    }

    var displayRate: String {
        String(format: "%.4f%%", fundingRatePercent)
    }

    var sentiment: String {
        if fundingRate > 0.0005 {
            return "Bullish"
        } else if fundingRate < -0.0005 {
            return "Bearish"
        } else {
            return "Neutral"
        }
    }
}

struct BinancePremiumIndex {
    let symbol: String
    let markPrice: Double
    let indexPrice: Double
    let lastFundingRate: Double
    let nextFundingTime: Date
    let interestRate: Double
}
