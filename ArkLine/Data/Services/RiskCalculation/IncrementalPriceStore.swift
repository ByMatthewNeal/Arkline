import Foundation

// MARK: - Incremental Price Store
/// Fetches and persists daily close prices from Binance to fill the gap
/// between the frozen embedded data (HistoricalPriceData.swift) and today.
/// Thread-safe via actor isolation. Disk-persisted via JSON in ~/Library/Caches/PriceHistory/.
actor IncrementalPriceStore {

    // MARK: - Singleton
    static let shared = IncrementalPriceStore()

    // MARK: - Types

    struct PersistedPricePoint: Codable {
        let date: String   // "yyyy-MM-dd"
        let close: Double
    }

    struct CoinPriceFile: Codable {
        var prices: [PersistedPricePoint]
        var lastUpdated: Date
    }

    // MARK: - Coin-to-Binance Symbol Mapping

    private static let binanceSymbols: [String: String] = [
        "BTC": "BTCUSDT",
        "ETH": "ETHUSDT",
        "SOL": "SOLUSDT"
    ]

    // MARK: - State

    /// Merged result cache: embedded + incremental, keyed by coin symbol.
    private var mergedCache: [String: [(date: Date, price: Double)]] = [:]

    /// Raw incremental data loaded from disk, keyed by coin symbol.
    private var incrementalData: [String: CoinPriceFile] = [:]

    /// Track fetch attempts to enforce cooldown.
    private var fetchAttempted: [String: Date] = [:]

    /// Minimum interval between fetch attempts (15 minutes).
    private let fetchCooldown: TimeInterval = 900

    // MARK: - Date Formatter

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Init

    private init() {
        for coin in Self.binanceSymbols.keys {
            if let loaded = loadFromDisk(coin: coin) {
                incrementalData[coin] = loaded
            }
        }
    }

    // MARK: - Public API

    /// Returns the full price history for a coin: embedded baseline + incremental days.
    /// Fetches missing days from Binance if needed (respects cooldown).
    func fullPriceHistory(for coin: String) async -> [(date: Date, price: Double)] {
        let symbol = coin.uppercased()

        // Return merged cache if still valid (updated today)
        if let cached = mergedCache[symbol], isCacheValidForToday(coin: symbol) {
            return cached
        }

        // Try to fetch missing days
        await fetchMissingDaysIfNeeded(coin: symbol)

        // Build and cache merged result
        let merged = buildMergedHistory(coin: symbol)
        mergedCache[symbol] = merged
        return merged
    }

    // MARK: - Disk Persistence

    private var cacheDirectory: URL {
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = cachePath.appendingPathComponent("PriceHistory", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func fileURL(for coin: String) -> URL {
        cacheDirectory.appendingPathComponent("\(coin.uppercased())_incremental.json")
    }

    private nonisolated func loadFromDisk(coin: String) -> CoinPriceFile? {
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = cachePath.appendingPathComponent("PriceHistory", isDirectory: true)
        let url = dir.appendingPathComponent("\(coin.uppercased())_incremental.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(CoinPriceFile.self, from: data)
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    private func saveToDisk(coin: String, file: CoinPriceFile) {
        let url = fileURL(for: coin)
        do {
            let data = try JSONEncoder().encode(file)
            try data.write(to: url, options: .atomic)
        } catch {
            logDebug("IncrementalPriceStore: Failed to save \(coin): \(error)", category: .data)
        }
    }

    // MARK: - Gap Detection

    private func embeddedEndDate(for coin: String) -> Date? {
        guard let range = HistoricalPriceData.dateRange(for: coin),
              let endDate = dateFormatter.date(from: range.end) else {
            return nil
        }
        return endDate
    }

    private func nextMissingDate(for coin: String) -> Date? {
        let calendar = Calendar.current
        guard let embeddedEnd = embeddedEndDate(for: coin) else { return nil }
        var lastKnown = embeddedEnd

        if let incremental = incrementalData[coin],
           let lastInc = incremental.prices.last,
           let lastIncDate = dateFormatter.date(from: lastInc.date),
           lastIncDate > lastKnown {
            lastKnown = lastIncDate
        }

        return calendar.date(byAdding: .day, value: 1, to: lastKnown)
    }

    private func daysMissing(from startDate: Date) -> Int {
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: yesterday))
        return max(0, (components.day ?? 0) + 1)
    }

    private func isCacheValidForToday(coin: String) -> Bool {
        guard let incremental = incrementalData[coin] else {
            return isEmbeddedDataCurrent(coin: coin)
        }
        let calendar = Calendar.current
        return calendar.isDateInToday(incremental.lastUpdated)
    }

    private func isEmbeddedDataCurrent(coin: String) -> Bool {
        guard let range = HistoricalPriceData.dateRange(for: coin),
              let endDate = dateFormatter.date(from: range.end) else { return false }
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return endDate >= calendar.startOfDay(for: yesterday)
    }

    // MARK: - Fetching

    private func fetchMissingDaysIfNeeded(coin: String) async {
        // Check cooldown
        if let lastAttempt = fetchAttempted[coin],
           Date().timeIntervalSince(lastAttempt) < fetchCooldown {
            return
        }

        guard let startDate = nextMissingDate(for: coin) else { return }
        let count = daysMissing(from: startDate)
        guard count > 0 else { return }

        fetchAttempted[coin] = Date()

        guard let binanceSymbol = Self.binanceSymbols[coin] else { return }

        logDebug("IncrementalPriceStore: Fetching \(count) missing days for \(coin) from \(dateFormatter.string(from: startDate))", category: .network)

        do {
            let startMs = Int64(startDate.timeIntervalSince1970 * 1000)
            let endpoint = BinanceEndpoint.klinesWithTime(
                symbol: binanceSymbol,
                interval: "1d",
                startTime: startMs,
                limit: min(count + 1, 1000)
            )

            let data = try await NetworkManager.shared.requestData(endpoint: endpoint)
            guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
                logDebug("IncrementalPriceStore: Invalid JSON for \(coin)", category: .network)
                return
            }

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let embeddedEnd = embeddedEndDate(for: coin)

            var newPoints: [PersistedPricePoint] = []
            for element in jsonArray {
                guard let kline = BinanceKline(from: element) else { continue }

                let openDate = Date(timeIntervalSince1970: Double(kline.openTime) / 1000.0)
                let candleDay = calendar.startOfDay(for: openDate)

                // Skip today's incomplete candle
                guard candleDay < todayStart else { continue }

                // Skip dates covered by embedded data
                if let end = embeddedEnd, candleDay <= end { continue }

                let dateStr = dateFormatter.string(from: candleDay)

                // Skip if already in incremental data
                if let existing = incrementalData[coin],
                   existing.prices.contains(where: { $0.date == dateStr }) {
                    continue
                }

                newPoints.append(PersistedPricePoint(date: dateStr, close: kline.close))
            }

            guard !newPoints.isEmpty else {
                logDebug("IncrementalPriceStore: No new points for \(coin)", category: .network)
                return
            }

            // Merge with existing incremental data
            var existing = incrementalData[coin] ?? CoinPriceFile(prices: [], lastUpdated: Date())
            existing.prices.append(contentsOf: newPoints)
            existing.prices.sort { $0.date < $1.date }

            // Deduplicate by date
            var seen = Set<String>()
            existing.prices = existing.prices.filter { seen.insert($0.date).inserted }
            existing.lastUpdated = Date()

            // Persist
            incrementalData[coin] = existing
            saveToDisk(coin: coin, file: existing)
            mergedCache.removeValue(forKey: coin)

            // Invalidate downstream risk cache
            await RiskDataCache.shared.clear(for: coin)

            logDebug("IncrementalPriceStore: Added \(newPoints.count) price points for \(coin) (total incremental: \(existing.prices.count))", category: .network)

        } catch {
            logDebug("IncrementalPriceStore: Fetch failed for \(coin): \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Merging

    private func buildMergedHistory(coin: String) -> [(date: Date, price: Double)] {
        var result = HistoricalPriceData.pricesAsTuples(for: coin)
        let embeddedEnd = embeddedEndDate(for: coin)

        if let incremental = incrementalData[coin] {
            for point in incremental.prices {
                if let date = dateFormatter.date(from: point.date) {
                    // Skip dates already covered by embedded data
                    if let end = embeddedEnd, date <= end { continue }
                    result.append((date: date, price: point.close))
                }
            }
        }

        result.sort { $0.date < $1.date }
        return result
    }
}
