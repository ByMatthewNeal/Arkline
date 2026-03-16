import Foundation

// MARK: - Binance Funding Rate Service
/// Fetches funding rates from Binance Futures API via server-side proxy.
/// Binance Futures (fapi.binance.com) is geo-blocked in the US, so requests
/// are routed through the api-proxy edge function which runs outside the US.
final class APIBinanceFundingService {
    private let proxy = APIProxy.shared

    // MARK: - Public Methods

    /// Fetch current funding rate for a symbol
    func fetchFundingRate(symbol: String) async throws -> BinanceFundingRate {
        let path = "/fapi/v1/fundingRate"
        let params = ["symbol": "\(symbol.uppercased())USDT", "limit": "1"]

        let data = try await proxy.request(
            service: .binanceFutures,
            path: path,
            queryItems: params
        )

        let rates = try JSONDecoder().decode([BinanceFundingRateResponse].self, from: data)

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
        let path = "/fapi/v1/premiumIndex"
        let params = ["symbol": "\(symbol.uppercased())USDT"]

        let data = try await proxy.request(
            service: .binanceFutures,
            path: path,
            queryItems: params
        )

        let response = try JSONDecoder().decode(BinancePremiumIndexResponse.self, from: data)

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
