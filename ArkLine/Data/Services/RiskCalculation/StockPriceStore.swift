import Foundation

// MARK: - Stock Price Store
/// Fetches and caches daily close prices from FMP for stock risk calculations.
/// Thread-safe via actor isolation. Disk-persisted via JSON in ~/Library/Caches/StockPriceHistory/.
actor StockPriceStore {

    // MARK: - Singleton
    static let shared = StockPriceStore()

    // MARK: - Types

    struct PricePoint: Codable {
        let date: String   // "yyyy-MM-dd"
        let close: Double
    }

    struct PriceFile: Codable {
        var prices: [PricePoint]
        var lastUpdated: Date
    }

    // MARK: - State

    private var cache: [String: [(date: Date, price: Double)]] = [:]
    private var diskData: [String: PriceFile] = [:]
    private var fetchAttempted: [String: Date] = [:]
    private let fetchCooldown: TimeInterval = 3600 // 1 hour between refreshes

    // MARK: - Date Formatter

    private let dateFmt: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "America/New_York")
        return fmt
    }()

    // MARK: - Public API

    /// Get full price history for a stock symbol.
    func fullPriceHistory(for symbol: String) async -> [(date: Date, price: Double)] {
        let symbol = symbol.uppercased()

        // Return cached if available and fresh
        if let cached = cache[symbol], isFresh(symbol) {
            return cached
        }

        // Load from disk if not in memory
        if diskData[symbol] == nil {
            loadFromDisk(symbol: symbol)
        }

        // Fetch from FMP if needed
        await fetchIfNeeded(symbol: symbol)

        // Build and cache the result
        let result = buildHistory(symbol: symbol)
        cache[symbol] = result
        return result
    }

    // MARK: - Fetch Logic

    private func isFresh(_ symbol: String) -> Bool {
        guard let lastFetch = fetchAttempted[symbol] else { return false }
        return Date().timeIntervalSince(lastFetch) < fetchCooldown
    }

    private func fetchIfNeeded(symbol: String) async {
        // Respect cooldown
        if isFresh(symbol) && diskData[symbol] != nil { return }

        // Check if disk data is from today (no need to refetch)
        if let file = diskData[symbol] {
            let calendar = Calendar.current
            if calendar.isDateInToday(file.lastUpdated) {
                fetchAttempted[symbol] = Date()
                return
            }
        }

        logDebug("StockPriceStore: Fetching history for \(symbol)...", category: .network)

        do {
            let fmpService = FMPService.shared
            // If we have disk data, only fetch recent prices to update. Otherwise fetch full history.
            let limit = diskData[symbol] != nil ? 30 : 5000
            let fmpPrices = try await fmpService.fetchHistoricalPrices(symbol: symbol, limit: limit)

            var points: [PricePoint] = []
            for fmpPrice in fmpPrices {
                guard fmpPrice.close > 0 else { continue }
                points.append(PricePoint(date: fmpPrice.date, close: fmpPrice.close))
            }

            guard !points.isEmpty else {
                logWarning("StockPriceStore: No prices returned for \(symbol)", category: .network)
                fetchAttempted[symbol] = Date()
                return
            }

            // Sort oldest first
            points.sort { $0.date < $1.date }

            // Merge with existing disk data if available (incremental update)
            if let existing = diskData[symbol] {
                let existingDates = Set(existing.prices.map(\.date))
                let newPoints = points.filter { !existingDates.contains($0.date) }
                points = (existing.prices + newPoints).sorted { $0.date < $1.date }
            }

            let file = PriceFile(prices: points, lastUpdated: Date())
            diskData[symbol] = file
            cache.removeValue(forKey: symbol) // Invalidate merged cache
            saveToDisk(symbol: symbol, file: file)
            fetchAttempted[symbol] = Date()

            logDebug("StockPriceStore: Loaded \(points.count) prices for \(symbol)", category: .network)
        } catch {
            logWarning("StockPriceStore: Fetch failed for \(symbol): \(error.localizedDescription)", category: .network)
            fetchAttempted[symbol] = Date()
        }
    }

    // MARK: - Build History

    private func buildHistory(symbol: String) -> [(date: Date, price: Double)] {
        guard let file = diskData[symbol] else { return [] }

        return file.prices.compactMap { point -> (date: Date, price: Double)? in
            guard let date = dateFmt.date(from: point.date), point.close > 0 else { return nil }
            return (date: date, price: point.close)
        }
    }

    // MARK: - Disk Persistence

    private var cacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let dir = caches.appendingPathComponent("StockPriceHistory", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(for symbol: String) -> URL {
        cacheDirectory.appendingPathComponent("\(symbol).json")
    }

    private func loadFromDisk(symbol: String) {
        let url = fileURL(for: symbol)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(PriceFile.self, from: data)
            diskData[symbol] = file
            logDebug("StockPriceStore: Loaded \(file.prices.count) cached prices for \(symbol)", category: .network)
        } catch {
            logWarning("StockPriceStore: Failed to load cache for \(symbol): \(error.localizedDescription)", category: .network)
        }
    }

    private func saveToDisk(symbol: String, file: PriceFile) {
        let url = fileURL(for: symbol)
        do {
            let data = try JSONEncoder().encode(file)
            try data.write(to: url, options: .atomic)
        } catch {
            logWarning("StockPriceStore: Failed to save cache for \(symbol): \(error.localizedDescription)", category: .network)
        }
    }
}
