import Foundation

// MARK: - Market Service Protocol
/// Protocol defining market data operations for crypto, stocks, and metals.
protocol MarketServiceProtocol {
    /// Fetches cryptocurrency assets with pagination
    /// - Parameters:
    ///   - page: Page number (1-indexed)
    ///   - perPage: Number of items per page
    /// - Returns: Array of CryptoAsset
    func fetchCryptoAssets(page: Int, perPage: Int) async throws -> [CryptoAsset]

    /// Fetches stock assets for given symbols
    /// - Parameter symbols: Array of stock ticker symbols
    /// - Returns: Array of StockAsset
    func fetchStockAssets(symbols: [String]) async throws -> [StockAsset]

    /// Fetches precious metal assets for given symbols
    /// - Parameter symbols: Array of metal symbols (e.g., XAU, XAG)
    /// - Returns: Array of MetalAsset
    func fetchMetalAssets(symbols: [String]) async throws -> [MetalAsset]

    /// Fetches global market data including total market cap, volume, etc.
    /// - Returns: CoinGeckoGlobalData containing market statistics
    func fetchGlobalMarketData() async throws -> CoinGeckoGlobalData

    /// Fetches trending cryptocurrencies
    /// - Returns: Array of trending CryptoAsset
    func fetchTrendingCrypto() async throws -> [CryptoAsset]

    /// Searches for cryptocurrencies by query
    /// - Parameter query: Search query string
    /// - Returns: Array of matching CryptoAsset
    func searchCrypto(query: String) async throws -> [CryptoAsset]

    /// Searches for stocks by query
    /// - Parameter query: Search query string
    /// - Returns: Array of matching stock search results
    func searchStocks(query: String) async throws -> [StockSearchResult]

    /// Fetches price history for a cryptocurrency
    /// - Parameters:
    ///   - id: Coin ID (e.g., "bitcoin")
    ///   - currency: Target currency (e.g., "usd")
    ///   - days: Number of days of history
    /// - Returns: CoinGeckoMarketChart with price history
    func fetchCoinMarketChart(id: String, currency: String, days: Int) async throws -> CoinGeckoMarketChart
}

// MARK: - Market Stats
/// Simple struct for market statistics
struct MarketStats {
    let marketCap: Double
    let volume: Double
    let btcDominance: Double
    let change: Double
}
