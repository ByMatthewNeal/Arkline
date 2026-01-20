import Foundation

// MARK: - Stock Asset
struct StockAsset: Asset {
    let id: String
    let symbol: String
    let name: String
    var currentPrice: Double
    var priceChange24h: Double
    var priceChangePercentage24h: Double
    var iconUrl: String?

    // Stock-specific properties
    var open: Double?
    var high: Double?
    var low: Double?
    var previousClose: Double?
    var volume: Int?
    var latestTradingDay: Date?
    var exchange: String?
    var currency: String?
    var marketCap: Double?
    var peRatio: Double?
    var dividendYield: Double?
    var week52High: Double?
    var week52Low: Double?
}

// MARK: - Stock Extensions
extension StockAsset {
    var isPositive: Bool {
        priceChangePercentage24h >= 0
    }

    var priceFormatted: String {
        currentPrice.formatAsCurrency(currencyCode: currency ?? "USD")
    }

    var changeFormatted: String {
        priceChangePercentage24h.asPercentage
    }

    var volumeFormatted: String {
        Double(volume ?? 0).formattedCompact
    }

    var marketCapFormatted: String {
        (marketCap ?? 0).formattedCompact
    }
}

// MARK: - Alpha Vantage Response Models
struct AlphaVantageGlobalQuoteResponse: Codable {
    let globalQuote: AlphaVantageQuote

    enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }
}

struct AlphaVantageQuote: Codable {
    let symbol: String
    let open: String
    let high: String
    let low: String
    let price: String
    let volume: String
    let latestTradingDay: String
    let previousClose: String
    let change: String
    let changePercent: String

    enum CodingKeys: String, CodingKey {
        case symbol = "01. symbol"
        case open = "02. open"
        case high = "03. high"
        case low = "04. low"
        case price = "05. price"
        case volume = "06. volume"
        case latestTradingDay = "07. latest trading day"
        case previousClose = "08. previous close"
        case change = "09. change"
        case changePercent = "10. change percent"
    }

    func toStockAsset() -> StockAsset {
        StockAsset(
            id: symbol,
            symbol: symbol,
            name: symbol,
            currentPrice: Double(price) ?? 0,
            priceChange24h: Double(change) ?? 0,
            priceChangePercentage24h: Double(changePercent.replacingOccurrences(of: "%", with: "")) ?? 0,
            iconUrl: nil,
            open: Double(open),
            high: Double(high),
            low: Double(low),
            previousClose: Double(previousClose),
            volume: Int(volume),
            latestTradingDay: nil
        )
    }
}

// MARK: - Alpha Vantage Search
struct AlphaVantageSearchResponse: Codable {
    let bestMatches: [AlphaVantageSearchMatch]
}

struct AlphaVantageSearchMatch: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let type: String
    let region: String
    let marketOpen: String
    let marketClose: String
    let timezone: String
    let currency: String
    let matchScore: String

    enum CodingKeys: String, CodingKey {
        case symbol = "1. symbol"
        case name = "2. name"
        case type = "3. type"
        case region = "4. region"
        case marketOpen = "5. marketOpen"
        case marketClose = "6. marketClose"
        case timezone = "7. timezone"
        case currency = "8. currency"
        case matchScore = "9. matchScore"
    }
}

// MARK: - Alpha Vantage Time Series
struct AlphaVantageTimeSeries: Codable {
    let metaData: TimeSeriesMetaData
    let timeSeries: [String: TimeSeriesData]

    enum CodingKeys: String, CodingKey {
        case metaData = "Meta Data"
        case timeSeries = "Time Series (Daily)"
    }
}

struct TimeSeriesMetaData: Codable {
    let information: String
    let symbol: String
    let lastRefreshed: String
    let outputSize: String
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case information = "1. Information"
        case symbol = "2. Symbol"
        case lastRefreshed = "3. Last Refreshed"
        case outputSize = "4. Output Size"
        case timezone = "5. Time Zone"
    }
}

struct TimeSeriesData: Codable {
    let open: String
    let high: String
    let low: String
    let close: String
    let volume: String

    enum CodingKeys: String, CodingKey {
        case open = "1. open"
        case high = "2. high"
        case low = "3. low"
        case close = "4. close"
        case volume = "5. volume"
    }
}
