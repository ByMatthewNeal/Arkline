import Foundation

// MARK: - Crude Oil Service Protocol
/// Protocol defining WTI Crude Oil data operations.
protocol CrudeOilServiceProtocol {
    /// Fetches the latest WTI Crude Oil data
    /// - Returns: Optional CrudeOilData with current price
    func fetchLatestCrudeOil() async throws -> CrudeOilData?

    /// Fetches historical WTI Crude Oil data
    /// - Parameter days: Number of days of history to fetch
    /// - Returns: Array of CrudeOilData sorted by date (newest first)
    func fetchCrudeOilHistory(days: Int) async throws -> [CrudeOilData]
}
