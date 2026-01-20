import Foundation

// MARK: - Metal Asset
struct MetalAsset: Asset {
    let id: String
    let symbol: String
    let name: String
    var currentPrice: Double
    var priceChange24h: Double
    var priceChangePercentage24h: Double
    var iconUrl: String?

    // Metal-specific properties
    var unit: String // e.g., "oz" for ounce
    var currency: String
    var timestamp: Date?
}

// MARK: - Metal Extensions
extension MetalAsset {
    var isPositive: Bool {
        priceChangePercentage24h >= 0
    }

    var priceFormatted: String {
        "\(currentPrice.formatAsCurrency(currencyCode: currency))/\(unit)"
    }

    var changeFormatted: String {
        priceChangePercentage24h.asPercentage
    }
}

// MARK: - Common Metals
enum PreciousMetal: String, CaseIterable {
    case gold = "XAU"
    case silver = "XAG"
    case platinum = "XPT"
    case palladium = "XPD"

    var name: String {
        switch self {
        case .gold: return "Gold"
        case .silver: return "Silver"
        case .platinum: return "Platinum"
        case .palladium: return "Palladium"
        }
    }

    var icon: String {
        switch self {
        case .gold: return "🥇"
        case .silver: return "🥈"
        case .platinum: return "⬜"
        case .palladium: return "🔘"
        }
    }
}

// MARK: - Metals API Response
struct MetalsAPIResponse: Codable {
    let success: Bool
    let timestamp: Int
    let date: String
    let base: String
    let rates: [String: Double]
}

// MARK: - Metal Price History
struct MetalPriceHistory: Codable {
    let success: Bool
    let historical: Bool
    let date: String
    let base: String
    let rates: [String: Double]
}
