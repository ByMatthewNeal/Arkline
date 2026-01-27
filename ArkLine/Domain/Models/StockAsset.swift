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

// MARK: - Stock Search Result
/// Generic stock search result (provider-agnostic)
struct StockSearchResult: Codable, Identifiable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let exchange: String?
    let type: String?
    let currency: String?
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
