import Foundation

// MARK: - Shared Cache Service
/// Server-side shared cache using Supabase to reduce external API rate limiting.
/// Acts as L2 cache between local APICache (L1) and external APIs (L3).
///
/// With 300 users, this reduces external API calls from 300 per TTL period to ~1.
/// Flow: L1 (APICache in-memory) → L2 (Supabase table) → L3 (external API)
actor SharedCacheService {
    // MARK: - Singleton
    static let shared = SharedCacheService()

    // MARK: - Dependencies
    private let localCache = APICache.shared
    private let supabase = SupabaseManager.shared

    private init() {}

    // MARK: - Main Entry Point

    /// Get or fetch with three-tier caching: L1 (local) → L2 (Supabase) → L3 (API fetch)
    func getOrFetch<T: Codable>(
        _ key: String,
        ttl: TimeInterval = APICache.TTL.medium,
        fetch: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        // L1: Check local in-memory cache (fastest, ~0ms)
        if let cached: T = localCache.get(key) {
            logDebug("SharedCache L1 HIT: \(key)", category: .network)
            return cached
        }

        // L2: Check Supabase shared cache (~50ms)
        if supabase.isConfigured {
            do {
                let result = try await readFromL2(key: key, ttl: ttl, as: T.self)
                if let value = result.value {
                    localCache.set(key, value: value, ttl: ttl)
                    logDebug("SharedCache L2 HIT\(result.isStale ? " (stale-while-revalidate)" : ""): \(key)", category: .network)

                    // Stale-while-revalidate: return stale data, refresh in background
                    if result.isStale {
                        Task { [fetch] in
                            await self.backgroundRefresh(key: key, ttl: ttl, fetch: fetch)
                        }
                    }
                    return value
                }
            } catch {
                logWarning("SharedCache L2 read failed for \(key): \(error.localizedDescription)", category: .network)
                // Fall through to L3
            }
        }

        // L3: Fetch from external API
        logDebug("SharedCache L3 FETCH: \(key)", category: .network)
        let value = try await fetch()

        // Write back to L1
        localCache.set(key, value: value, ttl: ttl)

        // Write back to L2 (fire-and-forget)
        if supabase.isConfigured {
            Task {
                await self.writeToL2(key: key, value: value, ttl: ttl)
            }
        }

        return value
    }

    // MARK: - L2 Operations

    private struct L2Result<T> {
        let value: T?
        let isStale: Bool
    }

    private func readFromL2<T: Decodable>(key: String, ttl: TimeInterval, as type: T.Type) async throws -> L2Result<T> {
        let rows: [MarketCacheRow] = try await supabase.database
            .from(SupabaseTable.marketDataCache.rawValue)
            .select()
            .eq("key", value: key)
            .limit(1)
            .execute()
            .value

        guard let row = rows.first else {
            return L2Result(value: nil, isStale: false)
        }

        // Check freshness using server timestamp
        let age = Date().timeIntervalSince(row.updatedAt)
        let effectiveTTL = TimeInterval(row.ttlSeconds)
        let isExpired = age > effectiveTTL
        let isVeryStale = age > effectiveTTL * 2

        // If very stale (>2× TTL), treat as miss
        if isVeryStale {
            return L2Result(value: nil, isStale: false)
        }

        // Decode the JSON string back to the target type
        guard let jsonData = row.data.data(using: .utf8) else {
            return L2Result(value: nil, isStale: false)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try fractional seconds first (CoinGecko format)
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractionalFormatter.date(from: dateString) { return date }

            // Fall back to standard ISO 8601
            let standardFormatter = ISO8601DateFormatter()
            if let date = standardFormatter.date(from: dateString) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        let decoded = try decoder.decode(type, from: jsonData)

        return L2Result(value: decoded, isStale: isExpired)
    }

    private func writeToL2<T: Encodable>(key: String, value: T, ttl: TimeInterval) async {
        do {
            let encoder = JSONEncoder()
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            encoder.dateEncodingStrategy = .custom { date, encoder in
                var container = encoder.singleValueContainer()
                try container.encode(fractionalFormatter.string(from: date))
            }
            let jsonData = try encoder.encode(value)

            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                logWarning("SharedCache L2 WRITE failed: could not encode to string for \(key)", category: .network)
                return
            }

            let row = MarketCacheWriteRow(
                key: key,
                data: jsonString,
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                ttlSeconds: Int(ttl)
            )

            try await supabase.database
                .from(SupabaseTable.marketDataCache.rawValue)
                .upsert(row, onConflict: "key")
                .execute()

            logDebug("SharedCache L2 WRITE: \(key)", category: .network)
        } catch {
            logWarning("SharedCache L2 write failed for \(key): \(error.localizedDescription)", category: .network)
        }
    }

    private func backgroundRefresh<T: Codable>(key: String, ttl: TimeInterval, fetch: @Sendable () async throws -> T) async {
        do {
            let value = try await fetch()
            localCache.set(key, value: value, ttl: ttl)
            await writeToL2(key: key, value: value, ttl: ttl)
            logDebug("SharedCache BACKGROUND REFRESH: \(key)", category: .network)
        } catch {
            logWarning("SharedCache background refresh failed for \(key): \(error.localizedDescription)", category: .network)
        }
    }
}

// MARK: - DTOs

/// Row read from market_data_cache table
private struct MarketCacheRow: Codable {
    let key: String
    let data: String
    let updatedAt: Date
    let ttlSeconds: Int

    enum CodingKeys: String, CodingKey {
        case key, data
        case updatedAt = "updated_at"
        case ttlSeconds = "ttl_seconds"
    }
}

/// Row written to market_data_cache table (uses String for updated_at to avoid date encoding issues)
private struct MarketCacheWriteRow: Codable {
    let key: String
    let data: String
    let updatedAt: String
    let ttlSeconds: Int

    enum CodingKeys: String, CodingKey {
        case key, data
        case updatedAt = "updated_at"
        case ttlSeconds = "ttl_seconds"
    }
}
