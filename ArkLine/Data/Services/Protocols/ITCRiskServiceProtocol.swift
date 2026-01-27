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

    // MARK: - Multi-Factor Risk Methods

    /// Calculate multi-factor risk combining 6 data sources.
    /// Formula: 40% Log Regression + 15% RSI + 15% SMA + 10% Funding + 10% F&G + 10% Macro
    /// - Parameters:
    ///   - coin: Coin symbol (BTC, ETH)
    ///   - weights: Weight configuration (defaults to standard weights)
    /// - Returns: Multi-factor risk point with full breakdown
    func calculateMultiFactorRisk(
        coin: String,
        weights: RiskFactorWeights
    ) async throws -> MultiFactorRiskPoint

    /// Calculate enhanced current risk using multi-factor model.
    /// Returns backward-compatible RiskHistoryPoint.
    /// - Parameter coin: Coin symbol (BTC, ETH)
    /// - Returns: Risk history point with enhanced calculation
    func calculateEnhancedCurrentRisk(coin: String) async throws -> RiskHistoryPoint
}

// MARK: - Protocol Extensions (Default Implementations)
extension ITCRiskServiceProtocol {
    /// Default weights convenience method
    func calculateMultiFactorRisk(coin: String) async throws -> MultiFactorRiskPoint {
        try await calculateMultiFactorRisk(coin: coin, weights: .default)
    }
}
