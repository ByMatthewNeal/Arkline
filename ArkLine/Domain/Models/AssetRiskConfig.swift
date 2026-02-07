import Foundation

// MARK: - Asset Risk Configuration
/// Per-asset configuration for risk level calculation.
/// Each asset has unique parameters based on its history and volatility.
struct AssetRiskConfig {
    // MARK: - Safe Date Helper

    /// Creates a date from year/month/day components safely
    /// Falls back to distant past if creation fails (should never happen for valid dates)
    private static func safeDate(year: Int, month: Int, day: Int) -> Date {
        DateComponents(calendar: .current, year: year, month: month, day: day).date
            ?? Date.distantPast
    }
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

    /// Binance trading pair symbol (nil if not listed on Binance)
    let binanceSymbol: String?

    // MARK: - Supported Assets

    /// Bitcoin - longest history, most reliable
    static let btc = AssetRiskConfig(
        assetId: "BTC",
        geckoId: "bitcoin",
        originDate: safeDate(year: 2009, month: 1, day: 3),
        deviationBounds: (low: -0.8, high: 0.8),
        confidenceLevel: 9,
        displayName: "Bitcoin",
        binanceSymbol: "BTCUSDT"
    )

    /// Ethereum - second longest, high reliability
    static let eth = AssetRiskConfig(
        assetId: "ETH",
        geckoId: "ethereum",
        originDate: safeDate(year: 2015, month: 7, day: 30),
        deviationBounds: (low: -0.7, high: 0.7),
        confidenceLevel: 8,
        displayName: "Ethereum",
        binanceSymbol: "ETHUSDT"
    )

    /// Solana
    static let sol = AssetRiskConfig(
        assetId: "SOL",
        geckoId: "solana",
        originDate: safeDate(year: 2020, month: 4, day: 10),
        deviationBounds: (low: -0.6, high: 0.6),
        confidenceLevel: 6,
        displayName: "Solana",
        binanceSymbol: "SOLUSDT"
    )

    /// BNB - Binance coin, multiple cycles of data
    static let bnb = AssetRiskConfig(
        assetId: "BNB",
        geckoId: "binancecoin",
        originDate: safeDate(year: 2017, month: 7, day: 25),
        deviationBounds: (low: -0.65, high: 0.65),
        confidenceLevel: 7,
        displayName: "BNB",
        binanceSymbol: "BNBUSDT"
    )

    /// Uniswap - DeFi governance token
    static let uni = AssetRiskConfig(
        assetId: "UNI",
        geckoId: "uniswap",
        originDate: safeDate(year: 2020, month: 9, day: 17),
        deviationBounds: (low: -0.55, high: 0.55),
        confidenceLevel: 5,
        displayName: "Uniswap",
        binanceSymbol: "UNIUSDT"
    )

    /// Render - GPU rendering network
    static let render = AssetRiskConfig(
        assetId: "RENDER",
        geckoId: "render-token",
        originDate: safeDate(year: 2020, month: 6, day: 10),
        deviationBounds: (low: -0.55, high: 0.55),
        confidenceLevel: 5,
        displayName: "Render",
        binanceSymbol: "RENDERUSDT"
    )

    /// Sui - Move-based L1
    static let sui = AssetRiskConfig(
        assetId: "SUI",
        geckoId: "sui",
        originDate: safeDate(year: 2023, month: 5, day: 3),
        deviationBounds: (low: -0.50, high: 0.50),
        confidenceLevel: 4,
        displayName: "Sui",
        binanceSymbol: "SUIUSDT"
    )

    /// Ondo - RWA tokenization
    static let ondo = AssetRiskConfig(
        assetId: "ONDO",
        geckoId: "ondo-finance",
        originDate: safeDate(year: 2024, month: 1, day: 18),
        deviationBounds: (low: -0.45, high: 0.45),
        confidenceLevel: 3,
        displayName: "Ondo",
        binanceSymbol: "ONDOUSDT"
    )

    // MARK: - All Configs

    /// All supported assets
    static let allConfigs: [AssetRiskConfig] = [
        .btc, .eth, .sol, .bnb, .sui, .uni, .ondo, .render
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

    /// Get config for a coin symbol
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
    /// Static mapping from symbol to CoinGecko ID
    static let coinGeckoIds: [String: String] = {
        Dictionary(uniqueKeysWithValues: allConfigs.map { ($0.assetId, $0.geckoId) })
    }()
}
