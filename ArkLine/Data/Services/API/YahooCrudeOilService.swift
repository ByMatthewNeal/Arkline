import Foundation

// MARK: - Yahoo Crude Oil Service
/// WTI Crude Oil service implementation using Yahoo Finance
final class YahooCrudeOilService: CrudeOilServiceProtocol {
    private let yahooService = YahooFinanceService.shared

    func fetchLatestCrudeOil() async throws -> CrudeOilData? {
        do {
            let oil = try await yahooService.fetchCrudeOil()
            logInfo("Yahoo Crude Oil fetched: \(oil?.value ?? 0)", category: .network)
            return oil
        } catch {
            logError("Yahoo Crude Oil fetch failed: \(error)", category: .network)
            throw error
        }
    }

    func fetchCrudeOilHistory(days: Int) async throws -> [CrudeOilData] {
        do {
            let history = try await yahooService.fetchCrudeOilHistory(days: days)
            logInfo("Yahoo Crude Oil history fetched: \(history.count) days", category: .network)
            return history
        } catch {
            logError("Yahoo Crude Oil history fetch failed: \(error)", category: .network)
            throw error
        }
    }
}
