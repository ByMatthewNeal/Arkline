import Foundation

protocol ITCRiskServiceProtocol {
    /// Fetch risk level history for a specific coin (legacy method)
    func fetchRiskLevel(coin: String) async throws -> [ITCRiskLevel]

    /// Fetch the latest risk level for a coin (legacy method)
    func fetchLatestRiskLevel(coin: String) async throws -> ITCRiskLevel?

    // MARK: - Enhanced Methods

    /// Fetch enhanced risk history with price and fair value data
    /// - Parameters:
    ///   - coin: Coin symbol (BTC, ETH, etc.)
    ///   - days: Number of days of history (nil for maximum available)
    /// - Returns: Array of enhanced risk history points
    func fetchRiskHistory(coin: String, days: Int?) async throws -> [RiskHistoryPoint]

    /// Calculate current risk level for a coin using real-time data
    /// - Parameter coin: Coin symbol (BTC, ETH, etc.)
    /// - Returns: Current risk point with price context
    func calculateCurrentRisk(coin: String) async throws -> RiskHistoryPoint
}
