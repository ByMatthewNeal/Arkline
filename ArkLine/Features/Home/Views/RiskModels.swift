import SwiftUI

// MARK: - Risk Colors (6-Tier System)
/// Provides colors based on 6-tier risk level thresholds
struct RiskColors {
    // 6-tier color palette matching ITC app
    static let veryLowRisk = Color(hex: "3B82F6")   // Blue
    static let lowRisk = Color(hex: "22C55E")       // Green
    static let neutral = Color(hex: "EAB308")       // Yellow
    static let elevatedRisk = Color(hex: "F97316") // Orange
    static let highRisk = Color(hex: "EF4444")      // Red
    static let extremeRisk = Color(hex: "991B1B")   // Maroon

    /// Returns the appropriate color for a given risk level (0.0 - 1.0) using 6-tier system
    static func color(for level: Double) -> Color {
        switch level {
        case 0..<0.20:
            return veryLowRisk
        case 0.20..<0.40:
            return lowRisk
        case 0.40..<0.55:
            return neutral
        case 0.55..<0.70:
            return elevatedRisk
        case 0.70..<0.90:
            return highRisk
        default:
            return extremeRisk
        }
    }

    /// Returns the category name for a given risk level using 6-tier system
    static func category(for level: Double) -> String {
        switch level {
        case 0..<0.20:
            return "Very Low Risk"
        case 0.20..<0.40:
            return "Low Risk"
        case 0.40..<0.55:
            return "Neutral"
        case 0.55..<0.70:
            return "Elevated Risk"
        case 0.70..<0.90:
            return "High Risk"
        default:
            return "Extreme Risk"
        }
    }

    /// Returns description for a given risk level
    static func description(for level: Double) -> String {
        switch level {
        case 0..<0.20:
            return "Deep value range, historically excellent accumulation zone"
        case 0.20..<0.40:
            return "Still favorable accumulation, attractive for multi-year investors"
        case 0.40..<0.55:
            return "Mid-cycle territory, neither strong buy nor sell"
        case 0.55..<0.70:
            return "Late-cycle behavior, higher probability of corrections"
        case 0.70..<0.90:
            return "Historically blow-off-top region, major cycle tops occur here"
        default:
            return "Historically where macro tops happen, smart-money distribution"
        }
    }

    /// Returns a gradient for the risk gauge
    static func gradient(for level: Double, colorScheme: ColorScheme) -> LinearGradient {
        let riskColor = self.color(for: level)
        return LinearGradient(
            colors: [riskColor.opacity(0.6), riskColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Legacy method for backward compatibility
    static func color(for level: Double, colorScheme: ColorScheme) -> Color {
        return color(for: level)
    }
}

// Legacy alias for backward compatibility
typealias ITCRiskColors = RiskColors

// MARK: - Time Range for Chart
enum RiskTimeRange: String, CaseIterable {
    case all = "All"
    case oneYear = "1Y"
    case ninetyDays = "90D"
    case thirtyDays = "30D"
    case sevenDays = "7D"

    var days: Int? {
        switch self {
        case .all: return nil
        case .oneYear: return 365
        case .ninetyDays: return 90
        case .thirtyDays: return 30
        case .sevenDays: return 7
        }
    }
}

// Legacy alias
typealias ITCTimeRange = RiskTimeRange

// MARK: - Supported Coins for Risk Level
enum RiskCoin: String, CaseIterable {
    case btc = "BTC"
    case eth = "ETH"
    case sol = "SOL"
    case bnb = "BNB"
    case sui = "SUI"
    case uni = "UNI"
    case ondo = "ONDO"
    case render = "RENDER"
    case tao = "TAO"
    case zec = "ZEC"
    case xrp = "XRP"
    case ltc = "LTC"
    case aave = "AAVE"
    case ena = "ENA"
    case jup = "JUP"
    case syrup = "SYRUP"

    var displayName: String {
        AssetRiskConfig.forCoin(rawValue)?.displayName ?? rawValue
    }

    var icon: String {
        switch self {
        case .btc: return "bitcoinsign.circle.fill"
        case .eth: return "e.circle.fill"
        case .sol: return "s.circle.fill"
        case .bnb: return "b.circle.fill"
        case .sui: return "s.circle.fill"
        case .uni: return "u.circle.fill"
        case .ondo: return "o.circle.fill"
        case .render: return "r.circle.fill"
        case .tao: return "t.circle.fill"
        case .zec: return "z.circle.fill"
        case .xrp: return "x.circle.fill"
        case .ltc: return "l.circle.fill"
        case .aave: return "a.circle.fill"
        case .ena: return "e.circle.fill"
        case .jup: return "j.circle.fill"
        case .syrup: return "s.circle.fill"
        }
    }

    var coinGeckoId: String {
        AssetRiskConfig.forCoin(rawValue)?.geckoId ?? rawValue.lowercased()
    }

    /// CoinGecko thumbnail URL — these are stable CDN paths
    var iconURL: URL? {
        switch self {
        case .btc: return URL(string: "https://assets.coingecko.com/coins/images/1/small/bitcoin.png")
        case .eth: return URL(string: "https://assets.coingecko.com/coins/images/279/small/ethereum.png")
        case .sol: return URL(string: "https://assets.coingecko.com/coins/images/4128/small/solana.png")
        case .bnb: return URL(string: "https://assets.coingecko.com/coins/images/825/small/bnb-icon2_2x.png")
        case .sui: return URL(string: "https://assets.coingecko.com/coins/images/26375/small/sui-ocean-square.png")
        case .uni: return URL(string: "https://assets.coingecko.com/coins/images/12504/small/uni.jpg")
        case .ondo: return URL(string: "https://assets.coingecko.com/coins/images/26580/small/ONDO.png")
        case .render: return URL(string: "https://assets.coingecko.com/coins/images/11636/small/rndr.png")
        case .tao: return URL(string: "https://assets.coingecko.com/coins/images/28452/small/ARUsPeNQ_400x400.jpeg")
        case .zec: return URL(string: "https://assets.coingecko.com/coins/images/486/small/circle-zcash-color.png")
        case .xrp: return URL(string: "https://assets.coingecko.com/coins/images/44/small/xrp-symbol-white-128.png")
        case .ltc: return URL(string: "https://assets.coingecko.com/coins/images/2/small/litecoin.png")
        case .aave: return URL(string: "https://assets.coingecko.com/coins/images/12645/small/aave-token-round.png")
        case .ena: return URL(string: "https://assets.coingecko.com/coins/images/36530/small/ethena.png")
        case .jup: return URL(string: "https://assets.coingecko.com/coins/images/34188/small/jup.png")
        case .syrup: return URL(string: "https://assets.coingecko.com/coins/images/14097/small/photo_2021-05-03_14.20.41.jpeg")
        }
    }

    /// Short ticker symbol for display (e.g. "BTC", "ETH")
    var ticker: String { rawValue }
}

// Legacy alias
typealias ITCCoin = RiskCoin

// MARK: - Cached DateFormatters (avoid allocation per frame)
enum RiskDateFormatters {
    static let iso: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    static let display: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM d, yyyy"; return f
    }()
    static let sevenDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    static let thirtyDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    static let month: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f
    }()
    static let monthYear: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM yy"; return f
    }()
}
