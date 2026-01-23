import Foundation

// MARK: - Risk Data Cache
/// File-based caching for risk calculation data.
/// Reduces API calls and improves performance.
actor RiskDataCache {

    // MARK: - Singleton
    static let shared = RiskDataCache()

    // MARK: - Cache Configuration
    /// Time-to-live for current risk data (1 hour)
    private let currentTTL: TimeInterval = 3600

    /// Time-to-live for historical risk data (24 hours)
    private let historyTTL: TimeInterval = 86400

    // MARK: - Cache Storage
    private var memoryCache: [String: CacheEntry] = [:]

    // MARK: - Cache Entry
    struct CacheEntry: Codable {
        let history: [RiskHistoryPoint]
        let timestamp: Date
        let days: Int?

        var isExpired: Bool {
            let ttl: TimeInterval = days == nil ? 3600 : 86400
            return Date().timeIntervalSince(timestamp) > ttl
        }
    }

    // MARK: - Public Methods

    /// Get cached risk history for a coin
    /// - Parameters:
    ///   - coin: Coin symbol
    ///   - days: Number of days (nil for all)
    /// - Returns: Cached history if valid, nil otherwise
    func get(coin: String, days: Int?) -> [RiskHistoryPoint]? {
        let key = cacheKey(coin: coin, days: days)

        // Check memory cache
        if let entry = memoryCache[key], !entry.isExpired {
            return entry.history
        }

        // Check disk cache
        if let entry = loadFromDisk(key: key), !entry.isExpired {
            // Refresh memory cache
            memoryCache[key] = entry
            return entry.history
        }

        return nil
    }

    /// Store risk history in cache
    /// - Parameters:
    ///   - history: Risk history to cache
    ///   - coin: Coin symbol
    ///   - days: Number of days (nil for all)
    func store(_ history: [RiskHistoryPoint], for coin: String, days: Int? = nil) {
        let key = cacheKey(coin: coin, days: days)
        let entry = CacheEntry(history: history, timestamp: Date(), days: days)

        // Store in memory
        memoryCache[key] = entry

        // Store to disk
        saveToDisk(entry: entry, key: key)
    }

    /// Clear all cached data
    func clearAll() {
        memoryCache.removeAll()
        clearDiskCache()
    }

    /// Clear cached data for a specific coin
    func clear(for coin: String) {
        let prefix = coin.uppercased()
        memoryCache = memoryCache.filter { !$0.key.hasPrefix(prefix) }
        clearDiskCache(prefix: prefix)
    }

    // MARK: - Private Helpers

    private func cacheKey(coin: String, days: Int?) -> String {
        let daysStr = days.map { String($0) } ?? "all"
        return "\(coin.uppercased())_\(daysStr)"
    }

    // MARK: - Disk Cache

    private var cacheDirectory: URL {
        let fileManager = FileManager.default
        let cachePath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let riskCachePath = cachePath.appendingPathComponent("RiskCache", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: riskCachePath.path) {
            try? fileManager.createDirectory(at: riskCachePath, withIntermediateDirectories: true)
        }

        return riskCachePath
    }

    private func cacheFile(for key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).json")
    }

    private func loadFromDisk(key: String) -> CacheEntry? {
        let file = cacheFile(for: key)

        guard FileManager.default.fileExists(atPath: file.path) else { return nil }

        do {
            let data = try Data(contentsOf: file)
            return try JSONDecoder().decode(CacheEntry.self, from: data)
        } catch {
            // Invalid cache file, remove it
            try? FileManager.default.removeItem(at: file)
            return nil
        }
    }

    private func saveToDisk(entry: CacheEntry, key: String) {
        let file = cacheFile(for: key)

        do {
            let data = try JSONEncoder().encode(entry)
            try data.write(to: file)
        } catch {
            // Silently fail - cache is optional
        }
    }

    private func clearDiskCache(prefix: String? = nil) {
        let fileManager = FileManager.default

        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)

            for file in files {
                if let prefix = prefix {
                    if file.lastPathComponent.hasPrefix(prefix) {
                        try? fileManager.removeItem(at: file)
                    }
                } else {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            // Silently fail
        }
    }

    // MARK: - Private Init
    private init() {}
}
