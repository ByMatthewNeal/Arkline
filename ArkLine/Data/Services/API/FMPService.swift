import Foundation

// MARK: - FMP Service
/// Financial Modeling Prep API Service
/// Free tier: 250 calls/day
/// Provides stock quotes, crypto quotes, historical data, gainers/losers
/// Requests are proxied through the api-proxy Supabase Edge Function to keep the API key server-side.
/// Docs: https://site.financialmodelingprep.com/developer/docs
final class FMPService {

    // MARK: - Singleton
    static let shared = FMPService()

    // MARK: - Properties

    var isConfigured: Bool {
        SupabaseManager.shared.isConfigured
    }

    private init() {}

    // MARK: - Edge Function Proxy

    /// Invoke the api-proxy Edge Function for FMP and return raw response Data
    private func invokeProxy(path: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        guard isConfigured else { throw FMPError.notConfigured }

        var queryDict: [String: String] = [:]
        for item in queryItems {
            if let value = item.value {
                queryDict[item.name] = value
            }
        }

        do {
            return try await APIProxy.shared.request(
                service: .fmp,
                path: path,
                queryItems: queryDict.isEmpty ? nil : queryDict
            )
        } catch let error as APIProxyError {
            throw mapProxyError(error)
        }
    }

    // MARK: - Stock Quotes

    /// Fetch a single stock quote
    func fetchStockQuote(symbol: String) async throws -> FMPQuote {
        let quotes = try await fetchQuotes(symbols: [symbol])
        guard let quote = quotes.first else {
            throw FMPError.symbolNotFound(symbol)
        }
        return quote
    }

    /// Fetch multiple stock quotes
    func fetchStockQuotes(symbols: [String]) async throws -> [FMPQuote] {
        return try await fetchQuotes(symbols: symbols)
    }

    // MARK: - Crypto Quotes

    /// Fetch a single crypto quote (use symbol like "BTCUSD", "ETHUSD")
    func fetchCryptoQuote(symbol: String) async throws -> FMPQuote {
        let cryptoSymbol = symbol.uppercased().hasSuffix("USD") ? symbol.uppercased() : "\(symbol.uppercased())USD"
        return try await fetchStockQuote(symbol: cryptoSymbol)
    }

    /// Fetch multiple crypto quotes
    func fetchCryptoQuotes(symbols: [String]) async throws -> [FMPQuote] {
        let cryptoSymbols = symbols.map { sym -> String in
            sym.uppercased().hasSuffix("USD") ? sym.uppercased() : "\(sym.uppercased())USD"
        }
        return try await fetchQuotes(symbols: cryptoSymbols)
    }

    // MARK: - Historical Data

    /// Fetch historical daily prices for a symbol
    func fetchHistoricalPrices(symbol: String, limit: Int = 30) async throws -> [FMPHistoricalPrice] {
        let data = try await invokeProxy(
            path: "/historical-price-eod/full",
            queryItems: [URLQueryItem(name: "symbol", value: symbol)]
        )

        try validateResponseData(data)

        let prices = try JSONDecoder().decode([FMPHistoricalPrice].self, from: data)
        return Array(prices.prefix(limit))
    }

    // MARK: - Market Movers

    /// Fetch today's biggest gainers
    func fetchBiggestGainers(limit: Int = 10) async throws -> [FMPMover] {
        let data = try await invokeProxy(path: "/biggest-gainers")

        try validateResponseData(data)

        let movers = try JSONDecoder().decode([FMPMover].self, from: data)
        logDebug("FMP: Fetched \(movers.count) gainers", category: .network)
        return Array(movers.prefix(limit))
    }

    /// Fetch today's biggest losers
    func fetchBiggestLosers(limit: Int = 10) async throws -> [FMPMover] {
        let data = try await invokeProxy(path: "/biggest-losers")

        try validateResponseData(data)

        let movers = try JSONDecoder().decode([FMPMover].self, from: data)
        logDebug("FMP: Fetched \(movers.count) losers", category: .network)
        return Array(movers.prefix(limit))
    }

    // MARK: - Stock Search

    /// Search for stocks by query
    func searchStocks(query: String, limit: Int = 10) async throws -> [StockSearchResult] {
        let data = try await invokeProxy(
            path: "/search-symbol",
            queryItems: [URLQueryItem(name: "query", value: query)]
        )

        try validateResponseData(data)

        let results = try JSONDecoder().decode([FMPSearchResult].self, from: data)
        // Limit results and filter to primary exchanges
        let filteredResults = results
            .filter { !$0.symbol.contains(".") } // Filter out non-US exchanges (AAPL.L, AAPL.DE, etc.)
            .prefix(limit)
        return filteredResults.map { $0.toStockSearchResult() }
    }

    // MARK: - Company Profile

    /// Fetch company profile/info
    func fetchCompanyProfile(symbol: String) async throws -> FMPCompanyProfile {
        let data = try await invokeProxy(
            path: "/profile",
            queryItems: [URLQueryItem(name: "symbol", value: symbol)]
        )

        try validateResponseData(data)

        let profiles = try JSONDecoder().decode([FMPCompanyProfile].self, from: data)
        guard let profile = profiles.first else {
            throw FMPError.symbolNotFound(symbol)
        }
        return profile
    }

    // MARK: - Private Helpers

    private func fetchQuotes(symbols: [String]) async throws -> [FMPQuote] {
        guard isConfigured else {
            throw FMPError.notConfigured
        }

        var quotes: [FMPQuote] = []

        // FMP requires individual calls for each symbol on free tier
        for symbol in symbols {
            do {
                let data = try await invokeProxy(
                    path: "/quote",
                    queryItems: [URLQueryItem(name: "symbol", value: symbol)]
                )
                try validateResponseData(data)

                let quoteArray = try JSONDecoder().decode([FMPQuote].self, from: data)
                if let quote = quoteArray.first {
                    quotes.append(quote)
                }
            } catch FMPError.premiumRequired {
                logWarning("FMP: \(symbol) requires premium subscription", category: .network)
                continue
            } catch {
                logWarning("FMP: Failed to fetch \(symbol): \(error.localizedDescription)", category: .network)
                continue
            }
        }

        logDebug("FMP: Fetched \(quotes.count)/\(symbols.count) quotes", category: .network)
        return quotes
    }

    /// Validate FMP-specific error messages in the response body
    private func validateResponseData(_ data: Data) throws {
        if let responseString = String(data: data, encoding: .utf8) {
            if responseString.contains("Premium") || responseString.contains("not available under your current subscription") {
                throw FMPError.premiumRequired
            }
            if responseString.contains("Invalid API KEY") {
                throw FMPError.invalidAPIKey
            }
            if responseString.contains("Limit Reach") {
                throw FMPError.rateLimitExceeded
            }
        }
    }

    /// Map APIProxyError to FMPError
    private func mapProxyError(_ error: APIProxyError) -> FMPError {
        switch error {
        case .unauthorized:
            return .invalidAPIKey
        case .httpError(let code, _):
            return .httpError(statusCode: code)
        case .notConfigured:
            return .notConfigured
        case .relayError:
            return .invalidResponse
        }
    }
}

// MARK: - FMP Error
enum FMPError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case invalidAPIKey
    case premiumRequired
    case rateLimitExceeded
    case symbolNotFound(String)
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "FMP API key not configured"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidAPIKey:
            return "Invalid FMP API key"
        case .premiumRequired:
            return "This data requires a premium FMP subscription"
        case .rateLimitExceeded:
            return "FMP daily rate limit exceeded (250 calls/day)"
        case .symbolNotFound(let symbol):
            return "Symbol not found: \(symbol)"
        case .httpError(let code):
            return "HTTP error: \(code)"
        }
    }
}

// MARK: - FMP Models

/// Stock/Crypto Quote
struct FMPQuote: Codable, Identifiable {
    let symbol: String
    let name: String
    let price: Double
    let changePercentage: Double
    let change: Double
    let volume: Int
    let dayLow: Double
    let dayHigh: Double
    let yearHigh: Double
    let yearLow: Double
    let marketCap: Double?
    let priceAvg50: Double?
    let priceAvg200: Double?
    let exchange: String
    let open: Double
    let previousClose: Double
    let timestamp: Int

    var id: String { symbol }

    /// Check if this is a crypto quote
    var isCrypto: Bool {
        exchange == "CRYPTO"
    }

    /// Formatted price string
    var priceFormatted: String {
        if price < 0.01 {
            return String(format: "$%.8f", price)
        } else if price < 1 {
            return String(format: "$%.4f", price)
        } else {
            return String(format: "$%.2f", price)
        }
    }

    /// Formatted change percentage
    var changePercentFormatted: String {
        let sign = changePercentage >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", changePercentage))%"
    }

    /// Formatted market cap
    var marketCapFormatted: String {
        guard let cap = marketCap else { return "N/A" }
        if cap >= 1_000_000_000_000 {
            return String(format: "$%.2fT", cap / 1_000_000_000_000)
        } else if cap >= 1_000_000_000 {
            return String(format: "$%.2fB", cap / 1_000_000_000)
        } else if cap >= 1_000_000 {
            return String(format: "$%.2fM", cap / 1_000_000)
        }
        return String(format: "$%.0f", cap)
    }

    /// Is price up or down
    var isPositive: Bool {
        changePercentage >= 0
    }

    /// Convert to StockAsset
    func toStockAsset() -> StockAsset {
        StockAsset(
            id: symbol,
            symbol: symbol,
            name: name,
            currentPrice: price,
            priceChange24h: change,
            priceChangePercentage24h: changePercentage,
            iconUrl: nil,
            open: open,
            high: dayHigh,
            low: dayLow,
            previousClose: previousClose,
            volume: volume,
            latestTradingDay: Date(timeIntervalSince1970: TimeInterval(timestamp)),
            exchange: exchange,
            currency: nil,
            marketCap: marketCap,
            peRatio: nil,
            dividendYield: nil,
            week52High: yearHigh,
            week52Low: yearLow
        )
    }
}

/// Historical Price Data
struct FMPHistoricalPrice: Codable, Identifiable {
    let symbol: String
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
    let change: Double
    let changePercent: Double
    let vwap: Double?

    var id: String { "\(symbol)-\(date)" }

    /// Parse date string to Date
    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
}

/// Market Mover (Gainer/Loser)
struct FMPMover: Codable, Identifiable {
    let symbol: String
    let price: Double
    let name: String
    let change: Double
    let changesPercentage: Double
    let exchange: String

    var id: String { symbol }

    /// Formatted price
    var priceFormatted: String {
        String(format: "$%.2f", price)
    }

    /// Formatted change percentage
    var changePercentFormatted: String {
        let sign = changesPercentage >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", changesPercentage))%"
    }
}

/// Stock Search Result from FMP
struct FMPSearchResult: Codable {
    let symbol: String
    let name: String
    let currency: String?
    let exchange: String?
    let exchangeFullName: String?

    func toStockSearchResult() -> StockSearchResult {
        StockSearchResult(
            symbol: symbol,
            name: name,
            exchange: exchange ?? exchangeFullName,
            type: "Equity",
            currency: currency
        )
    }
}

/// Company Profile
struct FMPCompanyProfile: Codable, Identifiable {
    let symbol: String
    let price: Double
    let marketCap: Double?
    let beta: Double?
    let lastDividend: Double?
    let range: String?
    let change: Double
    let changePercentage: Double
    let companyName: String
    let currency: String?
    let exchange: String
    let industry: String?
    let website: String?
    let description: String?
    let ceo: String?
    let sector: String?
    let country: String?
    let fullTimeEmployees: String?
    let image: String?
    let ipoDate: String?

    var id: String { symbol }

    /// Formatted market cap
    var marketCapFormatted: String {
        guard let cap = marketCap else { return "N/A" }
        if cap >= 1_000_000_000_000 {
            return String(format: "$%.2fT", cap / 1_000_000_000_000)
        } else if cap >= 1_000_000_000 {
            return String(format: "$%.2fB", cap / 1_000_000_000)
        } else if cap >= 1_000_000 {
            return String(format: "$%.2fM", cap / 1_000_000)
        }
        return String(format: "$%.0f", cap)
    }
}
