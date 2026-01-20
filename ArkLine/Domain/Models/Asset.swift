import Foundation

// MARK: - Base Asset Protocol
protocol Asset: Identifiable, Codable, Equatable {
    var id: String { get }
    var symbol: String { get }
    var name: String { get }
    var currentPrice: Double { get }
    var priceChange24h: Double { get }
    var priceChangePercentage24h: Double { get }
    var iconUrl: String? { get }
}

// MARK: - Asset Type Enum
enum AssetCategory: String, Codable, CaseIterable {
    case crypto
    case stock
    case metal

    var displayName: String {
        switch self {
        case .crypto: return "Crypto"
        case .stock: return "Stocks"
        case .metal: return "Metals"
        }
    }

    var icon: String {
        switch self {
        case .crypto: return "bitcoinsign.circle.fill"
        case .stock: return "chart.line.uptrend.xyaxis"
        case .metal: return "cube.fill"
        }
    }
}

// MARK: - Generic Asset
struct GenericAsset: Asset {
    let id: String
    let symbol: String
    let name: String
    var currentPrice: Double
    var priceChange24h: Double
    var priceChangePercentage24h: Double
    var iconUrl: String?
    let category: AssetCategory

    var isPositive: Bool {
        priceChangePercentage24h >= 0
    }
}

// MARK: - Asset Search Result
struct AssetSearchResult: Codable, Identifiable, Equatable {
    var id: String { symbol }
    let symbol: String
    let name: String
    let category: String
    var iconUrl: String?
    var marketCap: Double?
    var rank: Int?
}
