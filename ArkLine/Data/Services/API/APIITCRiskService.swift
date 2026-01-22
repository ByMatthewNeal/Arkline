import Foundation

// MARK: - API ITC Risk Service
/// Real API implementation of ITCRiskServiceProtocol.
/// Uses ArkLine backend for Into The Cryptoverse risk level data.
final class APIITCRiskService: ITCRiskServiceProtocol {
    // MARK: - Dependencies
    private let networkManager = NetworkManager.shared

    // MARK: - ITCRiskServiceProtocol

    func fetchRiskLevel(coin: String) async throws -> [ITCRiskLevel] {
        let endpoint = ArklineBackendEndpoint.itcRiskLevel(coin: coin)
        let response: ITCRiskLevelResponse = try await networkManager.request(endpoint)
        return response.history
    }

    func fetchLatestRiskLevel(coin: String) async throws -> ITCRiskLevel? {
        let history = try await fetchRiskLevel(coin: coin)
        return history.last
    }
}
