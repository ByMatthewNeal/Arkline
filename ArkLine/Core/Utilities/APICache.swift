import Foundation

// MARK: - API Cache
/// Simple in-memory cache for API responses to reduce rate limiting issues
final class APICache {
    static let shared = APICache()

    // MARK: - Cache Entry
    private struct CacheEntry<T> {
        let value: T
        let timestamp: Date
        let ttl: TimeInterval

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }

    // MARK: - Storage
    private var cache: [String: Any] = [:]
    private var insertionOrder: [String] = []
    private let maxEntries = 100
    private let queue = DispatchQueue(label: "com.arkline.cache", attributes: .concurrent)

    // MARK: - Default TTLs (in seconds)
    struct TTL {
        static let short: TimeInterval = 30      // 30 seconds - for rapidly changing data
        static let medium: TimeInterval = 300    // 5 minutes - for market prices (investing app, cache-friendly)
        static let long: TimeInterval = 300      // 5 minutes - for slower changing data
        static let veryLong: TimeInterval = 900  // 15 minutes - for relatively static data
    }

    private init() {}

    // MARK: - Public Methods

    /// Get cached value if not expired
    func get<T>(_ key: String) -> T? {
        queue.sync {
            guard let entry = cache[key] as? CacheEntry<T> else { return nil }
            if entry.isExpired {
                return nil
            }
            return entry.value
        }
    }

    /// Store value in cache with TTL
    func set<T>(_ key: String, value: T, ttl: TimeInterval = TTL.medium) {
        queue.async(flags: .barrier) {
            // Evict oldest entries if over limit
            if self.cache.count >= self.maxEntries {
                // Remove expired entries first
                var expiredKeys: [String] = []
                for (k, v) in self.cache {
                    if let entry = v as? CacheEntry<Any>, entry.isExpired {
                        expiredKeys.append(k)
                    }
                }
                for k in expiredKeys {
                    self.cache.removeValue(forKey: k)
                    self.insertionOrder.removeAll { $0 == k }
                }
                // If still over limit, remove oldest by insertion order
                while self.cache.count >= self.maxEntries, let oldest = self.insertionOrder.first {
                    self.cache.removeValue(forKey: oldest)
                    self.insertionOrder.removeFirst()
                }
            }
            self.cache[key] = CacheEntry(value: value, timestamp: Date(), ttl: ttl)
            self.insertionOrder.removeAll { $0 == key }
            self.insertionOrder.append(key)
        }
    }

    /// Remove specific key from cache
    func remove(_ key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }

    /// Clear all cached data
    func clearAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }

    /// Clear expired entries
    func clearExpired() {
        queue.async(flags: .barrier) {
            self.cache = self.cache.filter { _, value in
                if let entry = value as? CacheEntry<Any> {
                    return !entry.isExpired
                }
                return false
            }
        }
    }

    // MARK: - Convenience Methods

    /// Get or fetch: returns cached value if available, otherwise executes fetch closure
    func getOrFetch<T>(_ key: String, ttl: TimeInterval = TTL.medium, fetch: () async throws -> T) async throws -> T {
        // Check cache first
        if let cached: T = get(key) {
            logDebug("Cache HIT: \(key)", category: .network)
            return cached
        }

        logDebug("Cache MISS: \(key)", category: .network)

        // Fetch and cache
        let value = try await fetch()
        set(key, value: value, ttl: ttl)
        return value
    }
}

// MARK: - Cache Keys
/// Centralized cache key definitions for consistency
enum CacheKey {
    static func cryptoAssets(page: Int, perPage: Int) -> String {
        "crypto_assets_\(page)_\(perPage)"
    }

    static func cryptoAsset(id: String) -> String {
        "crypto_asset_\(id)"
    }

    static let globalMarketData = "global_market_data"
    static let trendingCoins = "trending_coins"
    static let fearGreedIndex = "fear_greed_index"
    static let btcDominance = "btc_dominance"
    static let altcoinSeason = "altcoin_season"

    static func stockAssets(symbols: [String]) -> String {
        "stock_assets_\(symbols.sorted().joined(separator: "_"))"
    }

    static func metalAssets(symbols: [String]) -> String {
        "metal_assets_\(symbols.sorted().joined(separator: "_"))"
    }

    static let vixData = "vix_data"
    static let dxyData = "dxy_data"
    static let fedWatchMeetings = "fed_watch_meetings"
}
