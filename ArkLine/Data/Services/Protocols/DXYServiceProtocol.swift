import Foundation

// MARK: - DXY Service Protocol
/// Protocol defining DXY (US Dollar Index) data operations.
protocol DXYServiceProtocol {
    /// Fetches the latest DXY data
    /// - Returns: Optional DXYData with current DXY value
    func fetchLatestDXY() async throws -> DXYData?

    /// Fetches historical DXY data
    /// - Parameter days: Number of days of history to fetch
    /// - Returns: Array of DXYData sorted by date (newest first)
    func fetchDXYHistory(days: Int) async throws -> [DXYData]
}
