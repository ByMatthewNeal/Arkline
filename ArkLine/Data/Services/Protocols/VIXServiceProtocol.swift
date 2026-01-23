import Foundation

// MARK: - VIX Service Protocol
/// Protocol defining VIX (Volatility Index) data operations.
protocol VIXServiceProtocol {
    /// Fetches the latest VIX data
    /// - Returns: Optional VIXData with current VIX value
    func fetchLatestVIX() async throws -> VIXData?

    /// Fetches historical VIX data
    /// - Parameter days: Number of days of history to fetch
    /// - Returns: Array of VIXData sorted by date (newest first)
    func fetchVIXHistory(days: Int) async throws -> [VIXData]
}
