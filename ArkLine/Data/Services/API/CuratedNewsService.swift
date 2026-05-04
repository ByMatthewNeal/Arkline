import Foundation
import Supabase

// MARK: - Curated News Service
/// Reads AI-curated news from the `curated_news` Supabase table (synced by curate-news edge function).
/// Falls back to direct RSS fetching via APINewsService if curated data is unavailable.
final class CuratedNewsService {
    static let shared = CuratedNewsService()

    private var cache: [NewsItem] = []
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 600 // 10 minutes

    private init() {}

    // MARK: - Public API

    /// Fetch the latest curated news articles (last 24 hours).
    /// Returns curated articles if available, otherwise falls back to raw RSS.
    func fetchLatest(limit: Int = 20) async -> [NewsItem] {
        // Check in-memory cache
        if let ts = cacheTimestamp, Date().timeIntervalSince(ts) < cacheTTL, !cache.isEmpty {
            return Array(cache.prefix(limit))
        }

        // Try Supabase
        if SupabaseManager.shared.isConfigured {
            do {
                let articles = try await fetchFromSupabase(limit: limit)
                if !articles.isEmpty {
                    cache = articles
                    cacheTimestamp = Date()
                    logInfo("CuratedNewsService: Loaded \(articles.count) curated articles from Supabase", category: .network)
                    return articles
                }
            } catch {
                logWarning("CuratedNewsService: Supabase fetch failed: \(error)", category: .network)
            }
        }

        // Fallback to raw RSS via existing APINewsService
        logInfo("CuratedNewsService: Falling back to direct RSS", category: .network)
        do {
            let rssService = APINewsService()
            let news = try await rssService.fetchCombinedNewsFeed(
                limit: limit,
                includeTwitter: false,
                includeGoogleNews: true
            )
            return news
        } catch {
            logError("CuratedNewsService: RSS fallback also failed: \(error)", category: .network)
            return []
        }
    }

    /// Clear the in-memory cache (e.g., on pull-to-refresh).
    func clearCache() {
        cache = []
        cacheTimestamp = nil
    }

    // MARK: - Private

    private func fetchFromSupabase(limit: Int) async throws -> [NewsItem] {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let cutoffStr = isoFormatter.string(from: cutoff)

        let rows: [CuratedNewsDTO] = try await SupabaseManager.shared.database
            .from(SupabaseTable.curatedNews.rawValue)
            .select()
            .gte("published_at", value: cutoffStr)
            .order("published_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return rows.map { $0.toNewsItem() }
    }
}

// MARK: - Curated News DTO

private struct CuratedNewsDTO: Decodable {
    let id: UUID
    let originalTitle: String
    let curatedTitle: String
    let source: String
    let sourceUrl: String
    let publishedAt: String
    let takeaway1: String
    let takeaway2: String
    let takeaway3: String
    let relevanceScore: Int?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case id, source, category
        case originalTitle = "original_title"
        case curatedTitle = "curated_title"
        case sourceUrl = "source_url"
        case publishedAt = "published_at"
        case takeaway1 = "takeaway_1"
        case takeaway2 = "takeaway_2"
        case takeaway3 = "takeaway_3"
        case relevanceScore = "relevance_score"
    }

    func toNewsItem() -> NewsItem {
        let date = parseDate(publishedAt) ?? Date()

        return NewsItem(
            id: id,
            title: curatedTitle,
            source: source,
            publishedAt: date,
            url: sourceUrl,
            sourceType: .curated,
            takeaways: [takeaway1, takeaway2, takeaway3]
        )
    }

    private func parseDate(_ dateStr: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: dateStr) { return d }

        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: dateStr)
    }
}
