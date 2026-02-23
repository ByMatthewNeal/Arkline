import Foundation

// MARK: - Yahoo Gold Service
/// Gold (XAU/USD) service implementation using Yahoo Finance
final class YahooGoldService: GoldServiceProtocol {
    private let yahooService = YahooFinanceService.shared

    func fetchLatestGold() async throws -> GoldData? {
        do {
            let gold = try await yahooService.fetchGold()
            logInfo("Yahoo Gold fetched: \(gold?.value ?? 0)", category: .network)
            return gold
        } catch {
            logError("Yahoo Gold fetch failed: \(error)", category: .network)
            throw error
        }
    }

    func fetchGoldHistory(days: Int) async throws -> [GoldData] {
        do {
            let history = try await yahooService.fetchGoldHistory(days: days)
            logInfo("Yahoo Gold history fetched: \(history.count) days", category: .network)
            return history
        } catch {
            logError("Yahoo Gold history fetch failed: \(error)", category: .network)
            throw error
        }
    }
}
