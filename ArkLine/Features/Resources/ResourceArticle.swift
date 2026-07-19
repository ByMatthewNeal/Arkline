import Foundation

// MARK: - Resource Article
//
// A single entry in the in-app Resources ("Learn") hub. Content lives in Supabase
// (`resource_articles`) and renders as markdown, so guides can be added or edited
// without shipping an App Store update. Some rows are "link" rows that deep-link
// into an existing surface (the Dictionary glossary, the referral flow) instead of
// carrying their own body.

struct ResourceArticle: Codable, Identifiable, Equatable {
    let id: UUID
    let slug: String
    let title: String
    let summary: String?
    let body: String?
    let category: String        // get_started | learn | more
    let icon: String?           // SF Symbol
    let sortOrder: Int
    let linkType: String?       // "dictionary" | "referral" | nil (nil = markdown article)
    let isPublished: Bool

    enum CodingKeys: String, CodingKey {
        case id, slug, title, summary, body, category, icon
        case sortOrder = "sort_order"
        case linkType = "link_type"
        case isPublished = "is_published"
    }

    // MARK: Presentation helpers

    var resolvedIcon: String { icon ?? "doc.text" }

    /// A row that routes into an existing app surface rather than showing markdown.
    var isLink: Bool { linkType != nil }

    var section: ResourceSection { ResourceSection(rawValue: category) ?? .learn }
}

// MARK: - Sections

enum ResourceSection: String, CaseIterable {
    case getStarted = "get_started"
    case learn
    case more

    var title: String {
        switch self {
        case .getStarted: return "Get Started"
        case .learn: return "Learn"
        case .more: return "More"
        }
    }

    /// Display order of the buckets.
    var order: Int {
        switch self {
        case .getStarted: return 0
        case .learn: return 1
        case .more: return 2
        }
    }
}

// MARK: - Service

/// Reads published resources for members; upserts for admins.
final class ResourceService {
    static let shared = ResourceService()
    private init() {}

    private var db: SupabaseManager { SupabaseManager.shared }

    /// All published articles, ordered for display.
    func fetchPublished() async throws -> [ResourceArticle] {
        try await db.database
            .from(SupabaseTable.resourceArticles.rawValue)
            .select()
            .eq("is_published", value: true)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    /// Admin: every article (including drafts), for the editor list.
    func fetchAll() async throws -> [ResourceArticle] {
        try await db.database
            .from(SupabaseTable.resourceArticles.rawValue)
            .select()
            .order("category", ascending: true)
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    /// Admin: create or update an article (keyed by slug).
    func upsert(_ payload: ResourceArticleUpsert) async throws {
        try await db.database
            .from(SupabaseTable.resourceArticles.rawValue)
            .upsert(payload, onConflict: "slug")
            .execute()
    }
}

/// Write payload for the admin editor (server assigns id/created_at/updated_at).
struct ResourceArticleUpsert: Encodable {
    let slug: String
    let title: String
    let summary: String?
    let body: String?
    let category: String
    let icon: String?
    let sortOrder: Int
    let isPublished: Bool

    enum CodingKeys: String, CodingKey {
        case slug, title, summary, body, category, icon
        case sortOrder = "sort_order"
        case isPublished = "is_published"
    }
}
