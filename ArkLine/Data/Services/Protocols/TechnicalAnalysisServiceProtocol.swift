import Foundation

// MARK: - Technical Analysis Service Protocol
/// Protocol defining technical analysis operations using Taapi.io API.
protocol TechnicalAnalysisServiceProtocol {
    /// Fetches complete technical analysis for an asset
    /// - Parameters:
    ///   - symbol: Trading pair symbol (e.g., "BTC/USDT")
    ///   - exchange: Exchange name (e.g., "binance")
    /// - Returns: TechnicalAnalysis with all indicators
    func fetchTechnicalAnalysis(symbol: String, exchange: String) async throws -> TechnicalAnalysis

    /// Fetches SMA values for multiple periods
    /// - Parameters:
    ///   - symbol: Trading pair symbol
    ///   - exchange: Exchange name
    ///   - periods: Array of SMA periods (e.g., [21, 50, 200])
    ///   - interval: Time interval (e.g., "1d")
    /// - Returns: Dictionary mapping period to SMA value
    func fetchSMAValues(symbol: String, exchange: String, periods: [Int], interval: String) async throws -> [Int: Double]

    /// Fetches Bollinger Bands for a symbol
    /// - Parameters:
    ///   - symbol: Trading pair symbol
    ///   - exchange: Exchange name
    ///   - interval: Time interval (e.g., "1d", "1w")
    /// - Returns: BollingerBandData
    func fetchBollingerBands(symbol: String, exchange: String, interval: String) async throws -> BollingerBandData

    /// Fetches current price for a symbol
    /// - Parameters:
    ///   - symbol: Trading pair symbol
    ///   - exchange: Exchange name
    /// - Returns: Current price as Double
    func fetchCurrentPrice(symbol: String, exchange: String) async throws -> Double

    /// Fetches RSI value
    /// - Parameters:
    ///   - symbol: Trading pair symbol
    ///   - exchange: Exchange name
    ///   - interval: Time interval
    ///   - period: RSI period (default 14)
    /// - Returns: RSI value (0-100)
    func fetchRSI(symbol: String, exchange: String, interval: String, period: Int) async throws -> Double
}

// MARK: - Taapi Symbol Mapping
/// Maps asset IDs/symbols to Taapi.io compatible trading pairs
enum TaapiSymbolMapper {
    /// Converts a CryptoAsset to a Taapi-compatible symbol
    static func symbol(for asset: CryptoAsset) -> String {
        // Common mappings for crypto
        let symbol = asset.symbol.uppercased()
        return "\(symbol)/USDT"
    }

    /// Gets the appropriate exchange for an asset
    static func exchange(for asset: CryptoAsset) -> String {
        // Default to Binance for crypto
        return "binance"
    }

    /// Converts interval string to Taapi format
    static func interval(_ timeframe: BollingerTimeframe) -> String {
        switch timeframe {
        case .daily:
            return "1d"
        case .weekly:
            return "1w"
        case .monthly:
            return "1M"
        }
    }
}
