import Foundation

// MARK: - GEI Service Protocol

/// Protocol for fetching the Global Economy Index (GEI) composite indicator.
protocol GEIServiceProtocol {
    /// Fetches the current GEI composite score from 6 leading economic indicators.
    func fetchGEI() async throws -> GEIData

    /// Fetches historical daily GEI scores computed from ~90 days of component data.
    func fetchGEIHistory() async throws -> [MacroChartPoint]
}
