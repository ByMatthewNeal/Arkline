import Foundation

protocol ITCRiskServiceProtocol {
    /// Fetch risk level history for a specific coin
    func fetchRiskLevel(coin: String) async throws -> [ITCRiskLevel]

    /// Fetch the latest risk level for a coin
    func fetchLatestRiskLevel(coin: String) async throws -> ITCRiskLevel?
}
