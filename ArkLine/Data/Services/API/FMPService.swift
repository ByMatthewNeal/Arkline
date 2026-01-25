import Foundation

// MARK: - FMP Service
/// Financial Modeling Prep API Service
/// Free tier: 250 calls/day
/// Provides stock quotes, crypto quotes, historical data, gainers/losers
/// Docs: https://site.financialmodelingprep.com/developer/docs
final class FMPService {

    // MARK: - Singleton
    static let shared = FMPService()

    // MARK: - Properties
    private let baseURL = "https://financialmodelingprep.com/stable"

    private var apiKey: String {
        Constants.API.fmpAPIKey
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    private init() {}

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
        guard isConfigured else {
            throw FMPError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)/historical-price-eod/full?symbol=\(symbol)&apikey=\(apiKey)") else {
            throw FMPError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        try validateResponse(response, data: data)

        let prices = try JSONDecoder().decode([FMPHistoricalPrice].self, from: data)
        return Array(prices.prefix(limit))
    }

    // MARK: - Market Movers

    /// Fetch today's biggest gainers
    func fetchBiggestGainers(limit: Int = 10) async throws -> [FMPMover] {
        guard isConfigured else {
            throw FMPError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)/biggest-gainers?apikey=\(apiKey)") else {
            throw FMPError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        try validateResponse(response, data: data)

        let movers = try JSONDecoder().decode([FMPMover].self, from: data)
        print("📈 FMP: Fetched \(movers.count) gainers")
        return Array(movers.prefix(limit))
    }

    /// Fetch today's biggest losers
    func fetchBiggestLosers(limit: Int = 10) async throws -> [FMPMover] {
        guard isConfigured else {
            throw FMPError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)/biggest-losers?apikey=\(apiKey)") else {
            throw FMPError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        try validateResponse(response, data: data)

        let movers = try JSONDecoder().decode([FMPMover].self, from: data)
        print("📉 FMP: Fetched \(movers.count) losers")
        return Array(movers.prefix(limit))
    }

    // MARK: - Company Profile

    /// Fetch company profile/info
    func fetchCompanyProfile(symbol: String) async throws -> FMPCompanyProfile {
        guard isConfigured else {
            throw FMPError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)/profile?symbol=\(symbol)&apikey=\(apiKey)") else {
            throw FMPError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        try validateResponse(response, data: data)

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
            guard let url = URL(string: "\(baseURL)/quote?symbol=\(symbol)&apikey=\(apiKey)") else {
                continue
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                try validateResponse(response, data: data)

                let quoteArray = try JSONDecoder().decode([FMPQuote].self, from: data)
                if let quote = quoteArray.first {
                    quotes.append(quote)
                }
            } catch FMPError.premiumRequired {
                print("⚠️ FMP: \(symbol) requires premium subscription")
                continue
            } catch {
                print("⚠️ FMP: Failed to fetch \(symbol): \(error.localizedDescription)")
                continue
            }
        }

        print("💹 FMP: Fetched \(quotes.count)/\(symbols.count) quotes")
        return quotes
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FMPError.invalidResponse
        }

        // Check for error messages in response
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

        guard httpResponse.statusCode == 200 else {
            throw FMPError.httpError(statusCode: httpResponse.statusCode)
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
