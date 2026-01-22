import Foundation

// MARK: - Coinglass Service Protocol
/// Protocol defining Coinglass derivatives data operations.
protocol CoinglassServiceProtocol {

    // MARK: - Open Interest

    /// Fetches open interest data for a specific symbol
    /// - Parameter symbol: Coin symbol (e.g., "BTC", "ETH")
    /// - Returns: OpenInterestData with current OI and 24h changes
    func fetchOpenInterest(symbol: String) async throws -> OpenInterestData

    /// Fetches open interest data for multiple symbols
    /// - Parameter symbols: Array of coin symbols
    /// - Returns: Array of OpenInterestData
    func fetchOpenInterestMultiple(symbols: [String]) async throws -> [OpenInterestData]

    /// Fetches total market open interest across all coins
    /// - Returns: Total OI in USD
    func fetchTotalMarketOI() async throws -> Double

    // MARK: - Liquidations

    /// Fetches 24h liquidation data for a specific symbol
    /// - Parameter symbol: Coin symbol (e.g., "BTC", "ETH")
    /// - Returns: CoinglassLiquidationData with long/short breakdown
    func fetchLiquidations(symbol: String) async throws -> CoinglassLiquidationData

    /// Fetches aggregated 24h liquidation data across all coins
    /// - Returns: CoinglassLiquidationData with total market liquidations
    func fetchTotalLiquidations() async throws -> CoinglassLiquidationData

    /// Fetches recent large liquidation events
    /// - Parameters:
    ///   - symbol: Optional symbol filter
    ///   - limit: Maximum number of events to return
    /// - Returns: Array of LiquidationEvent
    func fetchRecentLiquidations(symbol: String?, limit: Int) async throws -> [LiquidationEvent]

    // MARK: - Funding Rates

    /// Fetches current funding rate for a specific symbol
    /// - Parameter symbol: Coin symbol (e.g., "BTC", "ETH")
    /// - Returns: CoinglassFundingRateData with current and predicted rates
    func fetchFundingRate(symbol: String) async throws -> CoinglassFundingRateData

    /// Fetches funding rates for multiple symbols
    /// - Parameter symbols: Array of coin symbols
    /// - Returns: Array of CoinglassFundingRateData
    func fetchFundingRatesMultiple(symbols: [String]) async throws -> [CoinglassFundingRateData]

    /// Fetches OI-weighted average funding rate across exchanges
    /// - Parameter symbol: Coin symbol
    /// - Returns: Weighted average funding rate
    func fetchWeightedFundingRate(symbol: String) async throws -> Double

    // MARK: - Long/Short Ratios

    /// Fetches global long/short account ratio for a symbol
    /// - Parameter symbol: Coin symbol (e.g., "BTC", "ETH")
    /// - Returns: LongShortRatioData
    func fetchLongShortRatio(symbol: String) async throws -> LongShortRatioData

    /// Fetches top trader long/short ratio for a symbol
    /// - Parameter symbol: Coin symbol
    /// - Returns: LongShortRatioData with top trader data
    func fetchTopTraderRatio(symbol: String) async throws -> LongShortRatioData

    // MARK: - Aggregated Overview

    /// Fetches a complete derivatives overview with all key metrics
    /// - Returns: DerivativesOverview with OI, liquidations, funding, and L/S ratios
    func fetchDerivativesOverview() async throws -> DerivativesOverview
}
