import Foundation

// MARK: - Asset Risk Configuration
/// Per-asset configuration for risk level calculation.
/// Each asset has unique parameters based on its history and volatility.
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

    // MARK: - Pre-configured Assets

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

    /// Solana - newer asset
    static let sol = AssetRiskConfig(
        assetId: "SOL",
        geckoId: "solana",
        originDate: DateComponents(calendar: .current, year: 2020, month: 4, day: 10).date!,
        deviationBounds: (low: -0.6, high: 0.6),
        confidenceLevel: 6,
        displayName: "Solana"
    )

    /// Cardano
    static let ada = AssetRiskConfig(
        assetId: "ADA",
        geckoId: "cardano",
        originDate: DateComponents(calendar: .current, year: 2017, month: 10, day: 1).date!,
        deviationBounds: (low: -0.6, high: 0.6),
        confidenceLevel: 7,
        displayName: "Cardano"
    )

    /// Chainlink
    static let link = AssetRiskConfig(
        assetId: "LINK",
        geckoId: "chainlink",
        originDate: DateComponents(calendar: .current, year: 2017, month: 9, day: 20).date!,
        deviationBounds: (low: -0.6, high: 0.6),
        confidenceLevel: 7,
        displayName: "Chainlink"
    )

    /// Polkadot
    static let dot = AssetRiskConfig(
        assetId: "DOT",
        geckoId: "polkadot",
        originDate: DateComponents(calendar: .current, year: 2020, month: 8, day: 22).date!,
        deviationBounds: (low: -0.5, high: 0.5),
        confidenceLevel: 5,
        displayName: "Polkadot"
    )

    /// Polygon (MATIC)
    static let matic = AssetRiskConfig(
        assetId: "MATIC",
        geckoId: "matic-network",
        originDate: DateComponents(calendar: .current, year: 2019, month: 4, day: 29).date!,
        deviationBounds: (low: -0.5, high: 0.5),
        confidenceLevel: 6,
        displayName: "Polygon"
    )

    /// XRP
    static let xrp = AssetRiskConfig(
        assetId: "XRP",
        geckoId: "ripple",
        originDate: DateComponents(calendar: .current, year: 2013, month: 8, day: 4).date!,
        deviationBounds: (low: -0.7, high: 0.7),
        confidenceLevel: 8,
        displayName: "XRP"
    )

    /// Dogecoin
    static let doge = AssetRiskConfig(
        assetId: "DOGE",
        geckoId: "dogecoin",
        originDate: DateComponents(calendar: .current, year: 2013, month: 12, day: 15).date!,
        deviationBounds: (low: -0.7, high: 0.7),
        confidenceLevel: 7,
        displayName: "Dogecoin"
    )

    /// Avalanche
    static let avax = AssetRiskConfig(
        assetId: "AVAX",
        geckoId: "avalanche-2",
        originDate: DateComponents(calendar: .current, year: 2020, month: 9, day: 22).date!,
        deviationBounds: (low: -0.5, high: 0.5),
        confidenceLevel: 5,
        displayName: "Avalanche"
    )

    /// Render Network
    static let render = AssetRiskConfig(
        assetId: "RENDER",
        geckoId: "render-token",
        originDate: DateComponents(calendar: .current, year: 2020, month: 4, day: 27).date!,
        deviationBounds: (low: -0.6, high: 0.6),
        confidenceLevel: 6,
        displayName: "Render"
    )

    /// Ondo Finance
    static let ondo = AssetRiskConfig(
        assetId: "ONDO",
        geckoId: "ondo-finance",
        originDate: DateComponents(calendar: .current, year: 2024, month: 1, day: 18).date!,
        deviationBounds: (low: -0.4, high: 0.4),
        confidenceLevel: 3,
        displayName: "Ondo"
    )

    // MARK: - All Configs

    /// All pre-configured assets
    static let allConfigs: [AssetRiskConfig] = [
        .btc, .eth, .sol, .ada, .link, .dot, .matic, .xrp, .doge, .avax, .render, .ondo
    ]

    /// Dictionary for quick lookup by symbol
    static let bySymbol: [String: AssetRiskConfig] = {
        Dictionary(uniqueKeysWithValues: allConfigs.map { ($0.assetId, $0) })
    }()

    /// Dictionary for quick lookup by CoinGecko ID
    static let byGeckoId: [String: AssetRiskConfig] = {
        Dictionary(uniqueKeysWithValues: allConfigs.map { ($0.geckoId, $0) })
    }()

    // MARK: - Lookup Methods

    /// Get config for a coin symbol (BTC, ETH, etc.)
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
}

// MARK: - CoinGecko ID Mapping (for backward compatibility)
extension AssetRiskConfig {
    /// Static mapping from symbol to CoinGecko ID
    static let coinGeckoIds: [String: String] = [
        "BTC": "bitcoin",
        "ETH": "ethereum",
        "SOL": "solana",
        "ADA": "cardano",
        "LINK": "chainlink",
        "DOT": "polkadot",
        "MATIC": "matic-network",
        "XRP": "ripple",
        "DOGE": "dogecoin",
        "AVAX": "avalanche-2",
        "RENDER": "render-token",
        "ONDO": "ondo-finance"
    ]
}
