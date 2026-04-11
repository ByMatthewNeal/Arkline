import Foundation

@MainActor
@Observable
class SwingSetupsViewModel {
    private let service = SwingSetupService()

    var activeSignals: [TradeSignal] = []
    var recentSignals: [TradeSignal] = []
    var stats: SignalStats?
    var marketConditions: SignalMarketConditions?
    var analytics: SignalAnalytics?
    var livePrices: [String: Double] = [:]
    var isLoading = false
    var loadFailed = false
    var historyLoadFailed = false
    var statsLoadFailed = false

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
        historyLoadFailed = false
        statsLoadFailed = false
        defer { isLoading = false }

        // Fire all requests concurrently with individual 15s timeouts
        async let active: [TradeSignal]? = fetchWithTimeout(seconds: 15) { [service] in
            try await service.fetchActiveSignals(forceRefresh: true)
        }
        async let recent: [TradeSignal]? = fetchWithTimeout(seconds: 15) { [service] in
            try await service.fetchRecentSignals(limit: 50)
        }
        async let signalStats: SignalStats? = fetchWithTimeout(seconds: 15) { [service] in
            try await service.fetchSignalStats()
        }
        async let conditions: SignalMarketConditions?? = fetchWithTimeout(seconds: 15) { [service] in
            try await service.fetchMarketConditions()
        }
        async let signalAnalytics: SignalAnalytics?? = fetchWithTimeout(seconds: 15) { [service] in
            try await service.fetchSignalAnalytics()
        }

        // Await all results
        let (activeResult, recentResult, statsResult, conditionsResult, analyticsResult) =
            await (active, recent, signalStats, conditions, signalAnalytics)

        if let signals = activeResult {
            activeSignals = signals
        } else {
            logWarning("Failed or timed out fetching active signals", category: .network)
        }

        if let signals = recentResult {
            recentSignals = signals
            historyLoadFailed = false
        } else {
            logError("Failed or timed out fetching recent signals", category: .network)
            // Retry once — this is the most common failure point
            if recentSignals.isEmpty {
                if let retry: [TradeSignal] = await fetchWithTimeout(seconds: 15, operation: { [service] in
                    try await service.fetchRecentSignals(limit: 50)
                }) {
                    recentSignals = retry
                    historyLoadFailed = false
                } else {
                    historyLoadFailed = true
                }
            }
        }

        if let s = statsResult {
            stats = s
            statsLoadFailed = false
        } else {
            logError("Failed or timed out fetching signal stats", category: .network)
            statsLoadFailed = stats == nil
        }

        if let c = conditionsResult {
            marketConditions = c
        }
        if let a = analyticsResult {
            analytics = a
        }

        loadFailed = activeSignals.isEmpty && recentSignals.isEmpty

        // Fetch live prices for unrealized P&L display
        await fetchLivePrices()
    }

    /// Fetch live prices for all active (triggered) signals from Coinbase
    func fetchLivePrices() async {
        let liveSignals = activeSignals.filter { $0.status == .triggered }
        let assets = Set(liveSignals.map { $0.asset })
        guard !assets.isEmpty else { return }

        for asset in assets {
            let pair = "\(asset)-USD"
            guard let url = URL(string: "https://api.coinbase.com/api/v3/brokerage/market/products/\(pair)/candles?granularity=ONE_HOUR&limit=1") else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candles = json["candles"] as? [[String: Any]],
                   let latest = candles.first,
                   let closeStr = latest["close"] as? String,
                   let price = Double(closeStr) {
                    livePrices[asset] = price
                }
            } catch {
                logDebug("Failed to fetch price for \(asset): \(error)", category: .network)
            }
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

    // MARK: - Historical Performance Data

    var historicalSignals: [TradeSignal] = []
    var historicalEvents: [EconomicEvent] = []
    var isLoadingHistory = false
    /// The number of days successfully loaded (-1 = none yet, 0 = all time)
    var loadedHistoryDays: Int = -1

    func loadHistoricalData(days: Int? = 30) async {
        if isLoadingHistory { return }

        let requestedDays = days ?? 0 // 0 = all time

        // Skip if we already have data for this range or wider
        if loadedHistoryDays >= 0 {
            if loadedHistoryDays == 0 {
                // Already loaded all-time, covers everything
                return
            }
            if requestedDays > 0 && loadedHistoryDays >= requestedDays {
                // Already loaded a wider range
                return
            }
        }

        isLoadingHistory = true
        defer { isLoadingHistory = false }

        let sinceDate: Date
        if let days {
            sinceDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        } else {
            sinceDate = Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date()
        }

        async let signals: [TradeSignal]? = fetchWithTimeout(seconds: 20) { [service] in
            try await service.fetchClosedSignals(since: sinceDate)
        }
        async let events: [EconomicEvent] = EconomicEventsService.shared.fetchEvents(
            from: sinceDate,
            to: Date(),
            impactFilter: [.high, .medium]
        )

        let (signalsResult, eventsResult) = await (signals, events)

        if let s = signalsResult {
            historicalSignals = s
            historicalEvents = eventsResult
            loadedHistoryDays = requestedDays
        }
        // If signals fetch failed, don't update loadedHistoryDays — allows retry
    }
}

// MARK: - Timeout Helper

/// Runs an async operation with a timeout, returning nil on failure or timeout.
private func fetchWithTimeout<T: Sendable>(seconds: TimeInterval = 15, operation: @escaping @Sendable () async throws -> T) async -> T? {
    do {
        return try await withTimeout(seconds: seconds, operation: operation)
    } catch {
        logError("fetchWithTimeout failed: \(error)", category: .network)
        return nil
    }
}
