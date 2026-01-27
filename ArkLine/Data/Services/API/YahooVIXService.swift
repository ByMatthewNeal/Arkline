import Foundation

// MARK: - Yahoo VIX Service
/// VIX service implementation using Yahoo Finance
final class YahooVIXService: VIXServiceProtocol {
    private let yahooService = YahooFinanceService.shared

    func fetchLatestVIX() async throws -> VIXData? {
        do {
            let vix = try await yahooService.fetchVIX()
            logInfo("Yahoo VIX fetched: \(vix?.value ?? 0)", category: .network)
            return vix
        } catch {
            logError("Yahoo VIX fetch failed: \(error)", category: .network)
            throw error
        }
    }

    func fetchVIXHistory(days: Int) async throws -> [VIXData] {
        do {
            let history = try await yahooService.fetchVIXHistory(days: days)
            logInfo("Yahoo VIX history fetched: \(history.count) days", category: .network)
            return history
        } catch {
            logError("Yahoo VIX history fetch failed: \(error)", category: .network)
            throw error
        }
    }
}
