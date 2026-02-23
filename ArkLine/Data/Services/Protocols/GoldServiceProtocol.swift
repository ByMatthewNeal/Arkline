import Foundation

// MARK: - Gold Service Protocol
/// Protocol defining Gold (XAU/USD) data operations.
protocol GoldServiceProtocol {
    /// Fetches the latest Gold data
    /// - Returns: Optional GoldData with current price
    func fetchLatestGold() async throws -> GoldData?

    /// Fetches historical Gold data
    /// - Parameter days: Number of days of history to fetch
    /// - Returns: Array of GoldData sorted by date (newest first)
    func fetchGoldHistory(days: Int) async throws -> [GoldData]
}
