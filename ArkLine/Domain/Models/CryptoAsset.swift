import Foundation

// MARK: - Sparkline Wrapper
struct SparklineData: Codable, Hashable {
    let price: [Double]?
}

// MARK: - Crypto Asset
struct CryptoAsset: Asset, Hashable, Codable {
    let id: String
    let symbol: String
    let name: String
    var currentPrice: Double
    var priceChange24h: Double
    var priceChangePercentage24h: Double
    var iconUrl: String?

    // Additional crypto-specific properties
    var marketCap: Double?
    var marketCapRank: Int?
    var fullyDilutedValuation: Double?
    var totalVolume: Double?
    var high24h: Double?
    var low24h: Double?
    var circulatingSupply: Double?
    var totalSupply: Double?
    var maxSupply: Double?
    var ath: Double?
    var athChangePercentage: Double?
    var athDate: Date?
    var atl: Double?
    var atlChangePercentage: Double?
    var atlDate: Date?
    var sparklineIn7d: SparklineData?
    var lastUpdated: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case currentPrice = "current_price"
        case priceChange24h = "price_change_24h"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case iconUrl = "image"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case fullyDilutedValuation = "fully_diluted_valuation"
        case totalVolume = "total_volume"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case circulatingSupply = "circulating_supply"
        case totalSupply = "total_supply"
        case maxSupply = "max_supply"
        case ath
        case athChangePercentage = "ath_change_percentage"
        case athDate = "ath_date"
        case atl
        case atlChangePercentage = "atl_change_percentage"
        case atlDate = "atl_date"
        case sparklineIn7d = "sparkline_in_7d"
        case lastUpdated = "last_updated"
    }

    // Convenience accessor for sparkline prices
    var sparklinePrices: [Double]? {
        sparklineIn7d?.price
    }
}

// MARK: - Crypto Asset Extensions
extension CryptoAsset {
    var isPositive: Bool {
        priceChangePercentage24h >= 0
    }

    var priceFormatted: String {
        currentPrice.asCryptoPrice
    }

    var changeFormatted: String {
        priceChangePercentage24h.asPercentage
    }

    var marketCapFormatted: String {
        (marketCap ?? 0).formattedCompact
    }

    var volumeFormatted: String {
        (totalVolume ?? 0).formattedCompact
    }

    var supplyFormatted: String {
        (circulatingSupply ?? 0).formattedCompact
    }

    var athFormatted: String {
        (ath ?? 0).asCryptoPrice
    }

    var atlFormatted: String {
        (atl ?? 0).asCryptoPrice
    }

    var fromATH: Double {
        guard let ath = ath, ath > 0 else { return 0 }
        return ((currentPrice - ath) / ath) * 100
    }

    var fromATL: Double {
        guard let atl = atl, atl > 0 else { return 0 }
        return ((currentPrice - atl) / atl) * 100
    }
}

// MARK: - CoinGecko Response Models
struct CoinGeckoSimplePriceResponse: Codable {
    let prices: [String: CoinGeckoPriceData]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        prices = try container.decode([String: CoinGeckoPriceData].self)
    }
}

struct CoinGeckoPriceData: Codable {
    let usd: Double?
    let usdMarketCap: Double?
    let usd24hChange: Double?

    enum CodingKeys: String, CodingKey {
        case usd
        case usdMarketCap = "usd_market_cap"
        case usd24hChange = "usd_24h_change"
    }
}

// MARK: - CoinGecko Market Chart
struct CoinGeckoMarketChart: Codable {
    let prices: [[Double]]
    let marketCaps: [[Double]]
    let totalVolumes: [[Double]]

    enum CodingKeys: String, CodingKey {
        case prices
        case marketCaps = "market_caps"
        case totalVolumes = "total_volumes"
    }

    var priceHistory: [PricePoint] {
        prices.compactMap { data -> PricePoint? in
            guard data.count >= 2 else { return nil }
            let timestamp = data[0] / 1000 // Convert milliseconds to seconds
            let price = data[1]
            return PricePoint(date: Date(timeIntervalSince1970: timestamp), price: price)
        }
    }
}

struct PricePoint: Identifiable {
    var id: Date { date }
    let date: Date
    let price: Double
}

// MARK: - CoinGecko Global Data
struct CoinGeckoGlobalData: Codable {
    let data: GlobalMarketData

    struct GlobalMarketData: Codable {
        let activeCryptocurrencies: Int
        let upcomingIcos: Int
        let ongoingIcos: Int
        let endedIcos: Int
        let markets: Int
        let totalMarketCap: [String: Double]
        let totalVolume: [String: Double]
        let marketCapPercentage: [String: Double]
        let marketCapChangePercentage24hUsd: Double
        let updatedAt: Int

        enum CodingKeys: String, CodingKey {
            case activeCryptocurrencies = "active_cryptocurrencies"
            case upcomingIcos = "upcoming_icos"
            case ongoingIcos = "ongoing_icos"
            case endedIcos = "ended_icos"
            case markets
            case totalMarketCap = "total_market_cap"
            case totalVolume = "total_volume"
            case marketCapPercentage = "market_cap_percentage"
            case marketCapChangePercentage24hUsd = "market_cap_change_percentage_24h_usd"
            case updatedAt = "updated_at"
        }
    }
}

// MARK: - CoinGecko Search
struct CoinGeckoSearchResponse: Codable {
    let coins: [CoinGeckoSearchCoin]
}

struct CoinGeckoSearchCoin: Codable, Identifiable {
    let id: String
    let name: String
    let apiSymbol: String?
    let symbol: String
    let marketCapRank: Int?
    let thumb: String?
    let large: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case apiSymbol = "api_symbol"
        case symbol
        case marketCapRank = "market_cap_rank"
        case thumb
        case large
    }
}

// MARK: - CoinGecko Trending
struct CoinGeckoTrendingResponse: Codable {
    let coins: [TrendingCoinWrapper]

    struct TrendingCoinWrapper: Codable {
        let item: TrendingCoin
    }

    struct TrendingCoin: Codable, Identifiable {
        let id: String
        let coinId: Int
        let name: String
        let symbol: String
        let marketCapRank: Int?
        let thumb: String?
        let small: String?
        let large: String?
        let score: Int

        enum CodingKeys: String, CodingKey {
            case id
            case coinId = "coin_id"
            case name
            case symbol
            case marketCapRank = "market_cap_rank"
            case thumb
            case small
            case large
            case score
        }
    }
}

// MARK: - CoinGecko Market Coin (for Altcoin Season calculation)
/// Model for coins/markets endpoint with price change percentages
struct CoinGeckoMarketCoin: Codable, Identifiable {
    let id: String
    let symbol: String
    let name: String
    let currentPrice: Double?
    let marketCap: Double?
    let marketCapRank: Int?
    let priceChangePercentage24h: Double?
    let priceChangePercentage7dInCurrency: Double?
    let priceChangePercentage30dInCurrency: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case currentPrice = "current_price"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case priceChangePercentage7dInCurrency = "price_change_percentage_7d_in_currency"
        case priceChangePercentage30dInCurrency = "price_change_percentage_30d_in_currency"
    }
}
