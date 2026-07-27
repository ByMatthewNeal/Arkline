import Foundation
import Observation

// MARK: - Dictionary Store

/// In-memory cache of the full `dictionary` table powering inline DefineTerm lookups.
/// Loads once per launch (disk-cached for offline), refreshes daily. Lookups resolve
/// slug -> term (case-insensitive) -> alias (case-insensitive) with zero network calls.
@Observable
@MainActor
final class DictionaryStore {

    static let shared = DictionaryStore()

    // MARK: - State

    private(set) var terms: [DictionaryTerm] = []

    private var bySlug: [String: DictionaryTerm] = [:]
    /// Lowercased term or alias -> slug
    private var labelToSlug: [String: String] = [:]
    private var loadTask: Task<Void, Never>?
    private var lastRefresh: Date?

    private let refreshInterval: TimeInterval = 24 * 60 * 60

    private init() {}

    // MARK: - Lookup

    /// Resolution order: slug -> exact term (ci) -> alias (ci). Nil on miss —
    /// callers render no trigger for unknown keys.
    func lookup(_ key: String) -> DictionaryTerm? {
        let lowered = key.lowercased()
        if let entry = bySlug[lowered] { return entry }
        if let slug = labelToSlug[lowered], let entry = bySlug[slug] { return entry }
        return nil
    }

    // MARK: - Loading

    /// Idempotent: loads disk cache immediately, then refreshes from Supabase
    /// if the cache is older than a day. Safe to call from multiple views.
    func loadIfNeeded() {
        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < refreshInterval, !terms.isEmpty {
            return
        }
        guard loadTask == nil else { return }
        loadTask = Task { [weak self] in
            await self?.load()
            self?.loadTask = nil
        }
    }

    private func load() async {
        if terms.isEmpty, let cached = Self.readDiskCache() {
            index(cached.terms)
            lastRefresh = cached.savedAt
        }

        if let lastRefresh, Date().timeIntervalSince(lastRefresh) < refreshInterval, !terms.isEmpty {
            return
        }

        do {
            let fetched = try await ServiceContainer.shared.dictionaryService.fetchAll()
            guard !fetched.isEmpty else { return }
            index(fetched)
            lastRefresh = Date()
            Self.writeDiskCache(DiskCache(savedAt: Date(), terms: fetched))
        } catch {
            logWarning("DictionaryStore refresh failed: \(error.localizedDescription)", category: .network)
        }
    }

    private func index(_ fetched: [DictionaryTerm]) {
        terms = fetched
        var slugMap: [String: DictionaryTerm] = [:]
        var labelMap: [String: String] = [:]
        for entry in fetched {
            let slug = entry.slug ?? Self.slugify(entry.term)
            slugMap[slug] = entry
            labelMap[entry.term.lowercased()] = slug
            for alias in entry.aliases ?? [] {
                labelMap[alias.lowercased()] = slug
            }
        }
        bySlug = slugMap
        labelToSlug = labelMap
    }

    /// Mirrors the DB slug rule: strip parens, non-alphanumerics -> "-", trim "-".
    static func slugify(_ term: String) -> String {
        let stripped = term.replacingOccurrences(of: "[()]", with: "", options: .regularExpression)
        let dashed = stripped.lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        return dashed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    // MARK: - Disk Cache

    private struct DiskCache: Codable {
        let savedAt: Date
        let terms: [DictionaryTerm]
    }

    private nonisolated static var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("dictionary_terms.json")
    }

    private nonisolated static func readDiskCache() -> DiskCache? {
        guard let url = cacheURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DiskCache.self, from: data)
    }

    private nonisolated static func writeDiskCache(_ cache: DiskCache) {
        guard let url = cacheURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(cache) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
