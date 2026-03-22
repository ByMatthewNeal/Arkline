import Foundation

@MainActor
@Observable
class SwingSetupsViewModel {
    private let service = SwingSetupService()

    var activeSignals: [TradeSignal] = []
    var recentSignals: [TradeSignal] = []
    var stats: SignalStats?
    var marketConditions: SignalMarketConditions?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Load

    func loadActiveSignals() async {
        isLoading = true
        defer { isLoading = false }

        do {
            activeSignals = try await service.fetchActiveSignals()
        } catch {
            logWarning("Failed to fetch active signals: \(error)", category: .network)
        }
    }

    func loadAllData() async {
        isLoading = true
        defer { isLoading = false }

        async let active = service.fetchActiveSignals()
        async let recent = service.fetchRecentSignals()
        async let signalStats = service.fetchSignalStats()
        async let conditions = service.fetchMarketConditions()

        do {
            activeSignals = try await active
        } catch {
            logWarning("Failed to fetch active signals: \(error)", category: .network)
        }

        do {
            recentSignals = try await recent
        } catch {
            logWarning("Failed to fetch recent signals: \(error)", category: .network)
        }

        do {
            stats = try await signalStats
        } catch {
            logWarning("Failed to fetch signal stats: \(error)", category: .network)
        }

        do {
            marketConditions = try await conditions
        } catch {
            logWarning("Failed to fetch market conditions: \(error)", category: .network)
        }
    }

    func fetchConfluenceZone(for signal: TradeSignal) async -> FibConfluenceZone? {
        guard let zoneId = signal.confluenceZoneId else { return nil }
        do {
            return try await service.fetchConfluenceZone(id: zoneId)
        } catch {
            return nil
        }
    }
}
