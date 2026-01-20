import Foundation

// MARK: - Sentiment Service Protocol
/// Protocol defining sentiment and market indicator operations.
protocol SentimentServiceProtocol {
    /// Fetches the current Fear & Greed Index
    /// - Returns: Current FearGreedIndex
    func fetchFearGreedIndex() async throws -> FearGreedIndex

    /// Fetches historical Fear & Greed data
    /// - Parameter days: Number of days of history
    /// - Returns: Array of FearGreedIndex
    func fetchFearGreedHistory(days: Int) async throws -> [FearGreedIndex]

    /// Fetches current Bitcoin dominance
    /// - Returns: BTCDominance data
    func fetchBTCDominance() async throws -> BTCDominance

    /// Fetches ETF net flow data
    /// - Returns: ETFNetFlow data
    func fetchETFNetFlow() async throws -> ETFNetFlow

    /// Fetches average funding rate across exchanges
    /// - Returns: FundingRate data
    func fetchFundingRate() async throws -> FundingRate

    /// Fetches 24h liquidation data
    /// - Returns: LiquidationData
    func fetchLiquidations() async throws -> LiquidationData

    /// Fetches Altcoin Season Index
    /// - Returns: AltcoinSeasonIndex
    func fetchAltcoinSeason() async throws -> AltcoinSeasonIndex

    /// Fetches composite risk level
    /// - Returns: RiskLevel with indicators
    func fetchRiskLevel() async throws -> RiskLevel

    /// Fetches global liquidity data
    /// - Returns: GlobalLiquidity data
    func fetchGlobalLiquidity() async throws -> GlobalLiquidity

    /// Fetches App Store ranking data for crypto apps
    /// - Returns: AppStoreRanking
    func fetchAppStoreRanking() async throws -> AppStoreRanking

    /// Fetches all sentiment data in one call
    /// - Returns: MarketOverview containing all indicators
    func fetchMarketOverview() async throws -> MarketOverview
}
