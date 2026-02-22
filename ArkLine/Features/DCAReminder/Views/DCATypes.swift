import Foundation

// MARK: - DCA Frequency Option
enum DCAFrequencyOption: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case custom = "Custom"

    var displayName: String { rawValue }

    var toDCAFrequency: DCAFrequency {
        switch self {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .custom: return .weekly // Default for custom
        }
    }

    static func from(_ frequency: DCAFrequency) -> DCAFrequencyOption {
        switch frequency {
        case .daily: return .daily
        case .weekly, .twiceWeekly, .biweekly: return .weekly
        case .monthly: return .monthly
        }
    }
}

// MARK: - Custom Period
enum CustomPeriod: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var displayName: String { rawValue }
}

// MARK: - DCA Asset Category
enum DCAAssetCategory: String, CaseIterable {
    case crypto = "Crypto"
    case stocks = "Stocks"
    case commodities = "Commodities"

    var displayName: String { rawValue }
}

// MARK: - Coin Option
struct CoinOption: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let name: String
    let hasRiskData: Bool

    static let cryptoCoins: [CoinOption] = [
        CoinOption(symbol: "BTC", name: "Bitcoin", hasRiskData: true),
        CoinOption(symbol: "ETH", name: "Ethereum", hasRiskData: true),
        CoinOption(symbol: "SOL", name: "Solana", hasRiskData: true),
        CoinOption(symbol: "BNB", name: "BNB", hasRiskData: true),
        CoinOption(symbol: "SUI", name: "Sui", hasRiskData: true),
        CoinOption(symbol: "UNI", name: "Uniswap", hasRiskData: true),
        CoinOption(symbol: "ONDO", name: "Ondo", hasRiskData: true),
        CoinOption(symbol: "RENDER", name: "Render", hasRiskData: true),
        CoinOption(symbol: "ADA", name: "Cardano", hasRiskData: false),
        CoinOption(symbol: "DOT", name: "Polkadot", hasRiskData: false),
        CoinOption(symbol: "AVAX", name: "Avalanche", hasRiskData: false),
        CoinOption(symbol: "LINK", name: "Chainlink", hasRiskData: false),
        CoinOption(symbol: "DOGE", name: "Dogecoin", hasRiskData: false),
        CoinOption(symbol: "TRX", name: "TRON", hasRiskData: false),
        CoinOption(symbol: "SHIB", name: "Shiba Inu", hasRiskData: false),
        CoinOption(symbol: "XRP", name: "XRP", hasRiskData: false),
    ]
}

// MARK: - Risk Source Type
enum RiskSourceType: String, CaseIterable {
    case logRegression = "Log Regression"
    case composite = "7-Factor Composite"
}

// MARK: - DCA Frequency Extension
extension DCAFrequency {
    var shortDisplayName: String {
        switch self {
        case .daily: return "Daily"
        case .twiceWeekly: return "Tue, Fri"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        }
    }
}
