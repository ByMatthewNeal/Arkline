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
    var loadFailed = false

    // MARK: - Init

    init() {
        // Pre-populate with cached signals so the view isn't empty
        // while waiting for a fresh fetch (home screen already loaded these)
        if let cached = SwingSetupService.cachedActiveSignals {
            activeSignals = cached
        }
    }

    // MARK: - Load

    func loadActiveSignals() async {
        isLoading = true
        defer { isLoading = false }

        do {
            activeSignals = try await service.fetchActiveSignals()
            loadFailed = false
        } catch {
            logWarning("Failed to fetch active signals: \(error)", category: .network)
            loadFailed = activeSignals.isEmpty
        }
    }

    func loadAllData() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }

        var anyFailed = false

        async let active = service.fetchActiveSignals()
        async let recent = service.fetchRecentSignals()
        async let signalStats = service.fetchSignalStats()
        async let conditions = service.fetchMarketConditions()

        do {
            activeSignals = try await active
        } catch {
            logWarning("Failed to fetch active signals: \(error)", category: .network)
            anyFailed = true
        }

        do {
            recentSignals = try await recent
        } catch {
            logWarning("Failed to fetch recent signals: \(error)", category: .network)
            anyFailed = true
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

        // Only mark as failed if we have no data to show
        loadFailed = anyFailed && activeSignals.isEmpty && recentSignals.isEmpty
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
