import Foundation

// MARK: - Santiment Service Protocol
/// Protocol defining on-chain data operations via Santiment API.
protocol SantimentServiceProtocol {
    /// Fetches the latest Supply in Profit percentage for Bitcoin
    /// - Returns: Optional SupplyProfitData with current percentage
    func fetchLatestSupplyInProfit() async throws -> SupplyProfitData?

    /// Fetches historical Supply in Profit data
    /// - Parameter days: Number of days of history to fetch (max ~330 for free tier)
    /// - Returns: Array of SupplyProfitData sorted by date (newest first)
    func fetchSupplyInProfitHistory(days: Int) async throws -> [SupplyProfitData]
}
