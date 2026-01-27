import Foundation

// MARK: - Yahoo DXY Service
/// DXY service implementation using Yahoo Finance
final class YahooDXYService: DXYServiceProtocol {
    private let yahooService = YahooFinanceService.shared

    func fetchLatestDXY() async throws -> DXYData? {
        do {
            let dxy = try await yahooService.fetchDXY()
            logInfo("Yahoo DXY fetched: \(dxy?.value ?? 0)", category: .network)
            return dxy
        } catch {
            logError("Yahoo DXY fetch failed: \(error)", category: .network)
            throw error
        }
    }

    func fetchDXYHistory(days: Int) async throws -> [DXYData] {
        do {
            let history = try await yahooService.fetchDXYHistory(days: days)
            logInfo("Yahoo DXY history fetched: \(history.count) days", category: .network)
            return history
        } catch {
            logError("Yahoo DXY history fetch failed: \(error)", category: .network)
            throw error
        }
    }
}
