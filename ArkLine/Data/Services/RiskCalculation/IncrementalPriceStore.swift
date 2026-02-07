import Foundation

// MARK: - Incremental Price Store
/// Fetches and persists daily close prices to fill the gap
/// between the frozen embedded data (HistoricalPriceData.swift) and today.
/// For coins without embedded data (BNB, SUI, UNI, ONDO, RENDER),
/// fetches full history from Binance on first use and caches to disk.
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

    /// Full history fetched from Binance (for coins without embedded data).
    private var baselineData: [String: CoinPriceFile] = [:]

    /// Track fetch attempts to enforce cooldown.
    private var fetchAttempted: [String: Date] = [:]

    /// Track failed baseline fetches (shorter cooldown for retries).
    private var baselineFetchFailed: [String: Date] = [:]

    /// Minimum interval between fetch attempts (15 minutes).
    private let fetchCooldown: TimeInterval = 900

    /// Shorter cooldown after a failed baseline fetch (30 seconds).
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
                baselineData[coin] = baseline
            }
        }
    }

    // MARK: - Public API

    /// Returns the full price history for a coin: embedded baseline (or Binance baseline) + incremental days.
    /// Fetches missing days from Binance if needed (respects cooldown).
    func fullPriceHistory(for coin: String) async -> [(date: Date, price: Double)] {
        let symbol = coin.uppercased()

        // Return merged cache if still valid (updated today)
        if let cached = mergedCache[symbol], isCacheValidForToday(coin: symbol) {
            return cached
        }

        // For coins without embedded data, fetch full history from Binance if needed
        if !hasEmbeddedData(coin: symbol) && baselineData[symbol] == nil {
            await fetchFullBaselineHistory(coin: symbol)
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

    // MARK: - Full Baseline History Fetch

    /// Fetches the complete price history for coins without embedded data using Binance daily klines.
    private func fetchFullBaselineHistory(coin: String) async {
        // Already have baseline data
        if baselineData[coin] != nil { return }

        // Check failure cooldown
        if let lastFailed = baselineFetchFailed[coin],
           Date().timeIntervalSince(lastFailed) < failedFetchCooldown {
            return
        }

        guard let config = AssetRiskConfig.forCoin(coin),
              let binanceSymbol = config.binanceSymbol else { return }

        baselineFetchFailed[coin] = Date()
        await fetchFullHistoryFromBinance(coin: coin, binanceSymbol: binanceSymbol, originDate: config.originDate)
    }

    /// Fetch full history from Binance using paginated daily klines (1000 per request, no rate limits).
    private func fetchFullHistoryFromBinance(coin: String, binanceSymbol: String, originDate: Date) async {
        logDebug("IncrementalPriceStore: Fetching full history from Binance for \(coin) (\(binanceSymbol))", category: .network)

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        var allPoints: [PersistedPricePoint] = []
        var currentStartTime = Int64(originDate.timeIntervalSince1970 * 1000)
        let todayMs = Int64(todayStart.timeIntervalSince1970 * 1000)

        do {
            // Paginate through history (Binance returns max 1000 klines per request)
            while currentStartTime < todayMs {
                let endpoint = BinanceEndpoint.klinesWithTime(
                    symbol: binanceSymbol,
                    interval: "1d",
                    startTime: currentStartTime,
                    limit: 1000
                )

                let data = try await NetworkManager.shared.requestData(endpoint: endpoint)
                guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
                    break
                }

                if jsonArray.isEmpty { break }

                for element in jsonArray {
                    guard let kline = BinanceKline(from: element) else { continue }
                    let openDate = Date(timeIntervalSince1970: Double(kline.openTime) / 1000.0)
                    let candleDay = calendar.startOfDay(for: openDate)

                    // Skip today's incomplete candle
                    guard candleDay < todayStart else { continue }

                    let dateStr = dateFormatter.string(from: candleDay)
                    allPoints.append(PersistedPricePoint(date: dateStr, close: kline.close))
                }

                // Move start time past the last candle (next day)
                if let lastElement = jsonArray.last,
                   let lastKline = BinanceKline(from: lastElement) {
                    currentStartTime = lastKline.closeTime + 1
                } else {
                    break
                }
            }

            // Deduplicate by date
            var seen = Set<String>()
            allPoints = allPoints.filter { seen.insert($0.date).inserted }
            allPoints.sort { $0.date < $1.date }

            guard !allPoints.isEmpty else {
                logDebug("IncrementalPriceStore: No Binance data for \(coin)", category: .network)
                return
            }

            let file = CoinPriceFile(prices: allPoints, lastUpdated: Date())
            baselineData[coin] = file
            saveBaselineToDisk(coin: coin, file: file)
            mergedCache.removeValue(forKey: coin)
            baselineFetchFailed.removeValue(forKey: coin)

            logDebug("IncrementalPriceStore: Loaded \(allPoints.count) historical points for \(coin) from Binance", category: .network)

        } catch {
            logDebug("IncrementalPriceStore: Binance full history fetch failed for \(coin): \(error.localizedDescription)", category: .network)
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

    /// Returns the end date of the baseline data (embedded or Binance-fetched).
    private func baselineEndDate(for coin: String) -> Date? {
        // Check embedded data first
        if let range = HistoricalPriceData.dateRange(for: coin),
           let endDate = dateFormatter.date(from: range.end) {
            return endDate
        }
        // Fall back to Binance baseline
        if let baseline = baselineData[coin],
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
        // Check Binance baseline
        if let baseline = baselineData[coin] {
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
              let binanceSymbol = config.binanceSymbol else { return }

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

    // MARK: - Merging

    private func buildMergedHistory(coin: String) -> [(date: Date, price: Double)] {
        // Start with embedded data (BTC/ETH/SOL)
        var result = HistoricalPriceData.pricesAsTuples(for: coin)
        let embeddedEnd: Date? = {
            guard let range = HistoricalPriceData.dateRange(for: coin),
                  let endDate = dateFormatter.date(from: range.end) else { return nil }
            return endDate
        }()

        // Add Binance baseline data (for coins without embedded data)
        if result.isEmpty, let baseline = baselineData[coin] {
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
