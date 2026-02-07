import Foundation

// MARK: - Incremental Price Store
/// Fetches and persists daily close prices to fill the gap
/// between the frozen embedded data (HistoricalPriceData.swift) and today.
/// For coins without embedded data (BNB, HYPE, SUI, UNI, ONDO, RENDER),
/// fetches full history from CoinGecko on first use and caches to disk.
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

    // MARK: - State

    /// Merged result cache: embedded + incremental, keyed by coin symbol.
    private var mergedCache: [String: [(date: Date, price: Double)]] = [:]

    /// Raw incremental data loaded from disk, keyed by coin symbol.
    private var incrementalData: [String: CoinPriceFile] = [:]

    /// Full history fetched from CoinGecko (for coins without embedded data).
    private var geckoBaselineData: [String: CoinPriceFile] = [:]

    /// Track fetch attempts to enforce cooldown.
    private var fetchAttempted: [String: Date] = [:]

    /// Track CoinGecko baseline fetch attempts to enforce cooldown.
    private var geckoFetchAttempted: [String: Date] = [:]

    /// Track failed CoinGecko fetches (shorter cooldown for retries).
    private var geckoFetchFailed: [String: Date] = [:]

    /// Minimum interval between fetch attempts (15 minutes).
    private let fetchCooldown: TimeInterval = 900

    /// Shorter cooldown after a failed CoinGecko baseline fetch (30 seconds).
    private let failedFetchCooldown: TimeInterval = 30

    // MARK: - Date Formatter

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Init

    private init() {
        for config in AssetRiskConfig.allConfigs {
            let coin = config.assetId
            if let loaded = loadFromDisk(coin: coin) {
                incrementalData[coin] = loaded
            }
            if let baseline = loadBaselineFromDisk(coin: coin) {
                geckoBaselineData[coin] = baseline
            }
        }
    }

    // MARK: - Public API

    /// Returns the full price history for a coin: embedded baseline (or CoinGecko baseline) + incremental days.
    /// Fetches missing days from Binance/CoinGecko if needed (respects cooldown).
    func fullPriceHistory(for coin: String) async -> [(date: Date, price: Double)] {
        let symbol = coin.uppercased()

        // Return merged cache if still valid (updated today)
        if let cached = mergedCache[symbol], isCacheValidForToday(coin: symbol) {
            return cached
        }

        // For coins without embedded data, fetch full history from CoinGecko if needed
        if !hasEmbeddedData(coin: symbol) && geckoBaselineData[symbol] == nil {
            await fetchFullHistoryFromCoinGecko(coin: symbol)
        }

        // Try to fetch missing days
        await fetchMissingDaysIfNeeded(coin: symbol)

        // Build and cache merged result (only cache if non-empty)
        let merged = buildMergedHistory(coin: symbol)
        if !merged.isEmpty {
            mergedCache[symbol] = merged
        }
        return merged
    }

    // MARK: - Embedded Data Check

    private func hasEmbeddedData(coin: String) -> Bool {
        !HistoricalPriceData.prices(for: coin).isEmpty
    }

    // MARK: - CoinGecko Full History Fetch

    /// Fetches the complete price history from CoinGecko for coins without embedded data.
    /// Only called once per coin; result is cached to disk.
    private func fetchFullHistoryFromCoinGecko(coin: String) async {
        // Already have baseline data - no need to refetch
        if geckoBaselineData[coin] != nil { return }

        // Check failure cooldown (short - allows quick retries)
        if let lastFailed = geckoFetchFailed[coin],
           Date().timeIntervalSince(lastFailed) < failedFetchCooldown {
            return
        }

        guard let config = AssetRiskConfig.forCoin(coin) else { return }

        // Mark attempt for failure tracking (cleared on success)
        geckoFetchFailed[coin] = Date()

        logDebug("IncrementalPriceStore: Fetching full history from CoinGecko for \(coin) (\(config.geckoId))", category: .network)

        do {
            // Rate-limit: wait 1.5s between CoinGecko baseline requests to avoid 429s
            if let lastRequest = geckoFetchAttempted.values.max(),
               Date().timeIntervalSince(lastRequest) < 1.5 {
                let delay = 1.5 - Date().timeIntervalSince(lastRequest)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            geckoFetchAttempted[coin] = Date()

            let endpoint = CoinGeckoEndpoint.coinMarketChart(
                id: config.geckoId,
                currency: "usd",
                days: 10000 // max - returns all available data
            )

            let data = try await NetworkManager.shared.requestData(endpoint: endpoint)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pricesArray = json["prices"] as? [[Double]] else {
                logDebug("IncrementalPriceStore: Invalid CoinGecko response for \(coin)", category: .network)
                return
            }

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            var seen = Set<String>()
            var points: [PersistedPricePoint] = []

            for entry in pricesArray {
                guard entry.count >= 2 else { continue }
                let timestamp = entry[0] / 1000.0
                let price = entry[1]
                let date = Date(timeIntervalSince1970: timestamp)
                let dayStart = calendar.startOfDay(for: date)

                // Skip today's incomplete data
                guard dayStart < todayStart else { continue }

                let dateStr = dateFormatter.string(from: dayStart)

                // Deduplicate by date (CoinGecko may return multiple points per day)
                guard seen.insert(dateStr).inserted else { continue }

                points.append(PersistedPricePoint(date: dateStr, close: price))
            }

            points.sort { $0.date < $1.date }

            guard !points.isEmpty else {
                logDebug("IncrementalPriceStore: No CoinGecko data for \(coin)", category: .network)
                return
            }

            let file = CoinPriceFile(prices: points, lastUpdated: Date())
            geckoBaselineData[coin] = file
            saveBaselineToDisk(coin: coin, file: file)
            mergedCache.removeValue(forKey: coin)

            // Clear failure tracker on success
            geckoFetchFailed.removeValue(forKey: coin)

            logDebug("IncrementalPriceStore: Loaded \(points.count) historical points for \(coin) from CoinGecko", category: .network)

        } catch {
            logDebug("IncrementalPriceStore: CoinGecko fetch failed for \(coin): \(error.localizedDescription)", category: .network)
        }
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

    private func baselineFileURL(for coin: String) -> URL {
        cacheDirectory.appendingPathComponent("\(coin.uppercased())_baseline.json")
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

    private nonisolated func loadBaselineFromDisk(coin: String) -> CoinPriceFile? {
        let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = cachePath.appendingPathComponent("PriceHistory", isDirectory: true)
        let url = dir.appendingPathComponent("\(coin.uppercased())_baseline.json")
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

    private func saveBaselineToDisk(coin: String, file: CoinPriceFile) {
        let url = baselineFileURL(for: coin)
        do {
            let data = try JSONEncoder().encode(file)
            try data.write(to: url, options: .atomic)
        } catch {
            logDebug("IncrementalPriceStore: Failed to save baseline \(coin): \(error)", category: .data)
        }
    }

    // MARK: - Gap Detection

    /// Returns the end date of the baseline data (embedded or CoinGecko-fetched).
    private func baselineEndDate(for coin: String) -> Date? {
        // Check embedded data first
        if let range = HistoricalPriceData.dateRange(for: coin),
           let endDate = dateFormatter.date(from: range.end) {
            return endDate
        }
        // Fall back to CoinGecko baseline
        if let baseline = geckoBaselineData[coin],
           let last = baseline.prices.last,
           let date = dateFormatter.date(from: last.date) {
            return date
        }
        return nil
    }

    private func nextMissingDate(for coin: String) -> Date? {
        let calendar = Calendar.current
        guard let baseEnd = baselineEndDate(for: coin) else { return nil }
        var lastKnown = baseEnd

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
            return isBaselineDataCurrent(coin: coin)
        }
        let calendar = Calendar.current
        return calendar.isDateInToday(incremental.lastUpdated)
    }

    private func isBaselineDataCurrent(coin: String) -> Bool {
        // Check embedded data
        if let range = HistoricalPriceData.dateRange(for: coin),
           let endDate = dateFormatter.date(from: range.end) {
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            return endDate >= calendar.startOfDay(for: yesterday)
        }
        // Check CoinGecko baseline
        if let baseline = geckoBaselineData[coin] {
            let calendar = Calendar.current
            return calendar.isDateInToday(baseline.lastUpdated)
        }
        return false
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

        // Get Binance symbol from config
        guard let config = AssetRiskConfig.forCoin(coin),
              let binanceSymbol = config.binanceSymbol else {
            // No Binance symbol - use CoinGecko for incremental updates
            await fetchIncrementalFromCoinGecko(coin: coin, days: count)
            return
        }

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
            let baseEnd = baselineEndDate(for: coin)

            var newPoints: [PersistedPricePoint] = []
            for element in jsonArray {
                guard let kline = BinanceKline(from: element) else { continue }

                let openDate = Date(timeIntervalSince1970: Double(kline.openTime) / 1000.0)
                let candleDay = calendar.startOfDay(for: openDate)

                // Skip today's incomplete candle
                guard candleDay < todayStart else { continue }

                // Skip dates covered by baseline data
                if let end = baseEnd, candleDay <= end { continue }

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

    /// Fetch incremental daily data from CoinGecko (for coins without Binance listing).
    private func fetchIncrementalFromCoinGecko(coin: String, days: Int) async {
        guard let config = AssetRiskConfig.forCoin(coin) else { return }

        logDebug("IncrementalPriceStore: Fetching \(days) days from CoinGecko for \(coin)", category: .network)

        do {
            let endpoint = CoinGeckoEndpoint.coinMarketChart(
                id: config.geckoId,
                currency: "usd",
                days: min(days + 2, 90)
            )

            let data = try await NetworkManager.shared.requestData(endpoint: endpoint)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pricesArray = json["prices"] as? [[Double]] else {
                return
            }

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let baseEnd = baselineEndDate(for: coin)

            var newPoints: [PersistedPricePoint] = []
            var seen = Set<String>()

            for entry in pricesArray {
                guard entry.count >= 2 else { continue }
                let timestamp = entry[0] / 1000.0
                let price = entry[1]
                let date = Date(timeIntervalSince1970: timestamp)
                let dayStart = calendar.startOfDay(for: date)

                guard dayStart < todayStart else { continue }
                if let end = baseEnd, dayStart <= end { continue }

                let dateStr = dateFormatter.string(from: dayStart)
                guard seen.insert(dateStr).inserted else { continue }

                if let existing = incrementalData[coin],
                   existing.prices.contains(where: { $0.date == dateStr }) {
                    continue
                }

                newPoints.append(PersistedPricePoint(date: dateStr, close: price))
            }

            guard !newPoints.isEmpty else { return }

            var existing = incrementalData[coin] ?? CoinPriceFile(prices: [], lastUpdated: Date())
            existing.prices.append(contentsOf: newPoints)
            existing.prices.sort { $0.date < $1.date }

            var seenDates = Set<String>()
            existing.prices = existing.prices.filter { seenDates.insert($0.date).inserted }
            existing.lastUpdated = Date()

            incrementalData[coin] = existing
            saveToDisk(coin: coin, file: existing)
            mergedCache.removeValue(forKey: coin)

            await RiskDataCache.shared.clear(for: coin)

            logDebug("IncrementalPriceStore: Added \(newPoints.count) CoinGecko points for \(coin)", category: .network)

        } catch {
            logDebug("IncrementalPriceStore: CoinGecko incremental fetch failed for \(coin): \(error.localizedDescription)", category: .network)
        }
    }

    // MARK: - Merging

    private func buildMergedHistory(coin: String) -> [(date: Date, price: Double)] {
        // Start with embedded data (BTC/ETH/SOL)
        var result = HistoricalPriceData.pricesAsTuples(for: coin)
        let embeddedEnd: Date? = {
            guard let range = HistoricalPriceData.dateRange(for: coin),
                  let endDate = dateFormatter.date(from: range.end) else { return nil }
            return endDate
        }()

        // Add CoinGecko baseline data (for coins without embedded data)
        if result.isEmpty, let baseline = geckoBaselineData[coin] {
            for point in baseline.prices {
                if let date = dateFormatter.date(from: point.date) {
                    result.append((date: date, price: point.close))
                }
            }
        }

        let baseEnd = baselineEndDate(for: coin)

        // Add incremental data
        if let incremental = incrementalData[coin] {
            for point in incremental.prices {
                if let date = dateFormatter.date(from: point.date) {
                    // Skip dates covered by baseline data
                    if let end = baseEnd, date <= end { continue }
                    result.append((date: date, price: point.close))
                }
            }
        }

        result.sort { $0.date < $1.date }
        return result
    }
}
