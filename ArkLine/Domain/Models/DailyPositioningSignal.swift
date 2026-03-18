import Foundation

// MARK: - Asset Category

enum QPSAssetCategory: String, Codable, CaseIterable, Hashable {
    case crypto
    case index
    case macro
    case commodity
    case stock

    var displayName: String {
        switch self {
        case .crypto: return "Crypto"
        case .index: return "Indices"
        case .macro: return "Macro"
        case .commodity: return "Commodities"
        case .stock: return "Stocks"
        }
    }

    var icon: String {
        switch self {
        case .crypto: return "bitcoinsign.circle"
        case .index: return "chart.line.uptrend.xyaxis"
        case .macro: return "building.columns"
        case .commodity: return "cube.fill"
        case .stock: return "chart.bar.fill"
        }
    }

    /// Display order for the grid
    var sortOrder: Int {
        switch self {
        case .index: return 0
        case .macro: return 1
        case .commodity: return 2
        case .stock: return 3
        case .crypto: return 4
        }
    }
}

// MARK: - Daily Positioning Signal

/// Server-computed daily positioning signal for an asset
struct DailyPositioningSignal: Codable, Identifiable, Hashable {
    let id: UUID
    let asset: String
    let signalDate: Date
    let signal: String
    let prevSignal: String?
    let trendScore: Double
    let rsi: Double?
    let price: Double
    let above200Sma: Bool
    let riskLevel: Double?
    let category: String?
    let createdAt: Date?

    var positioningSignal: PositioningSignal {
        switch signal.lowercased() {
        case "bullish": return .bullish
        case "bearish": return .bearish
        default: return .neutral
        }
    }

    var prevPositioningSignal: PositioningSignal? {
        guard let prev = prevSignal else { return nil }
        switch prev.lowercased() {
        case "bullish": return .bullish
        case "bearish": return .bearish
        default: return .neutral
        }
    }

    var assetCategory: QPSAssetCategory {
        if let cat = category, let parsed = QPSAssetCategory(rawValue: cat) {
            return parsed
        }
        // Fallback: derive from ticker
        return Self.inferCategory(for: asset)
    }

    var displayName: String {
        Self.assetDisplayNames[asset] ?? asset
    }

    var hasChanged: Bool {
        guard let prev = prevSignal else { return false }
        return signal != prev
    }

    var changeDescription: String? {
        guard hasChanged, let prev = prevPositioningSignal else { return nil }
        return "\(prev.label) → \(positioningSignal.label)"
    }

    enum CodingKeys: String, CodingKey {
        case id, asset, signal, price, rsi, category
        case signalDate = "signal_date"
        case prevSignal = "prev_signal"
        case trendScore = "trend_score"
        case above200Sma = "above_200_sma"
        case riskLevel = "risk_level"
        case createdAt = "created_at"
    }

    // MARK: - Static Lookups

    private static let assetDisplayNames: [String: String] = [
        // Crypto
        "BTC": "Bitcoin", "ETH": "Ethereum", "SOL": "Solana",
        "BNB": "BNB", "SUI": "Sui", "UNI": "Uniswap",
        "ONDO": "Ondo", "RENDER": "Render", "XRP": "XRP",
        "LINK": "Chainlink", "TAO": "Bittensor", "HYPE": "Hyperliquid",
        "ZEC": "Zcash",
        // Indices
        "SPY": "S&P 500", "QQQ": "Nasdaq 100", "DIA": "Dow Jones",
        "IWM": "Russell 2000",
        // Macro
        "VIX": "Volatility Index", "DXY": "US Dollar Index",
        "TLT": "20Y Treasuries",
        // Commodities
        "GOLD": "Gold", "SILVER": "Silver", "OIL": "Oil",
        "COPPER": "Copper", "URA": "Uranium", "DBA": "Agriculture",
        "DBB": "Industrial Metals", "REMX": "Rare Earth Metals",
        // Stocks
        "AAPL": "Apple", "NVDA": "NVIDIA", "GOOGL": "Google",
        "COIN": "Coinbase", "MSTR": "MicroStrategy",
        "MARA": "Marathon Digital", "RIOT": "Riot Platforms",
        "GLXY": "Galaxy Digital",
    ]

    private static func inferCategory(for ticker: String) -> QPSAssetCategory {
        switch ticker {
        case "SPY", "QQQ", "DIA", "IWM": return .index
        case "VIX", "DXY", "TLT": return .macro
        case "GOLD", "SILVER", "OIL", "COPPER", "URA", "DBA", "DBB", "REMX": return .commodity
        case "AAPL", "NVDA", "GOOGL", "COIN", "MSTR", "MARA", "RIOT", "GLXY": return .stock
        default: return .crypto
        }
    }
}
