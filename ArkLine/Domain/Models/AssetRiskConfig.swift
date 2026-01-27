import Foundation

// MARK: - Asset Risk Configuration
/// Per-asset configuration for risk level calculation.
/// Each asset has unique parameters based on its history and volatility.
///
/// Supported assets: BTC, ETH, SOL only.
struct AssetRiskConfig {
    /// Asset identifier (symbol like "BTC", "ETH")
    let assetId: String

    /// CoinGecko API ID (e.g., "bitcoin", "ethereum")
    let geckoId: String

    /// Origin date for logarithmic regression (when the asset was first tradeable)
    let originDate: Date

    /// Deviation bounds for risk normalization (log10 scale)
    /// Negative = undervalued, Positive = overvalued
    let deviationBounds: (low: Double, high: Double)

    /// Data confidence level (1-9) based on available history
    /// Higher = more historical data, more reliable regression
    let confidenceLevel: Int

    /// Display name for the asset
    let displayName: String

    // MARK: - Supported Assets (BTC, ETH, SOL only)

    /// Bitcoin - longest history, most reliable
    static let btc = AssetRiskConfig(
        assetId: "BTC",
        geckoId: "bitcoin",
        originDate: DateComponents(calendar: .current, year: 2009, month: 1, day: 3).date!,
        deviationBounds: (low: -0.8, high: 0.8),
        confidenceLevel: 9,
        displayName: "Bitcoin"
    )

    /// Ethereum - second longest, high reliability
    static let eth = AssetRiskConfig(
        assetId: "ETH",
        geckoId: "ethereum",
        originDate: DateComponents(calendar: .current, year: 2015, month: 7, day: 30).date!,
        deviationBounds: (low: -0.7, high: 0.7),
        confidenceLevel: 8,
        displayName: "Ethereum"
    )

    /// Solana
    static let sol = AssetRiskConfig(
        assetId: "SOL",
        geckoId: "solana",
        originDate: DateComponents(calendar: .current, year: 2020, month: 4, day: 10).date!,
        deviationBounds: (low: -0.6, high: 0.6),
        confidenceLevel: 6,
        displayName: "Solana"
    )

    // MARK: - All Configs

    /// All supported assets (BTC, ETH, SOL only)
    static let allConfigs: [AssetRiskConfig] = [.btc, .eth, .sol]

    /// Dictionary for quick lookup by symbol
    static let bySymbol: [String: AssetRiskConfig] = {
        Dictionary(uniqueKeysWithValues: allConfigs.map { ($0.assetId, $0) })
    }()

    /// Dictionary for quick lookup by CoinGecko ID
    static let byGeckoId: [String: AssetRiskConfig] = {
        Dictionary(uniqueKeysWithValues: allConfigs.map { ($0.geckoId, $0) })
    }()

    // MARK: - Lookup Methods

    /// Get config for a coin symbol (BTC, ETH, SOL)
    static func forCoin(_ symbol: String) -> AssetRiskConfig? {
        bySymbol[symbol.uppercased()]
    }

    /// Get config for a CoinGecko ID
    static func forGeckoId(_ id: String) -> AssetRiskConfig? {
        byGeckoId[id.lowercased()]
    }

    /// Convert symbol to CoinGecko ID
    static func geckoId(for symbol: String) -> String? {
        forCoin(symbol)?.geckoId
    }

    /// Check if a coin is supported for risk calculation
    static func isSupported(_ symbol: String) -> Bool {
        bySymbol[symbol.uppercased()] != nil
    }
}

// MARK: - CoinGecko ID Mapping
extension AssetRiskConfig {
    /// Static mapping from symbol to CoinGecko ID (BTC, ETH, SOL only)
    static let coinGeckoIds: [String: String] = [
        "BTC": "bitcoin",
        "ETH": "ethereum",
        "SOL": "solana"
    ]
}
