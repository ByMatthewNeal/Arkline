import Foundation

// MARK: - GEI Service Protocol

/// Protocol for fetching the Global Economy Index (GEI) composite indicator.
protocol GEIServiceProtocol {
    /// Fetches the current GEI composite score from 6 leading economic indicators.
    func fetchGEI() async throws -> GEIData
}
