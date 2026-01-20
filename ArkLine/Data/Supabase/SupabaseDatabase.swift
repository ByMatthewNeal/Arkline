import Foundation
import Supabase

// MARK: - Supabase Database Helper
/// Database helper for Supabase operations.
/// Note: This is a stub implementation. Full implementation requires matching
/// the current Supabase Swift SDK API version.
actor SupabaseDatabase {
    // MARK: - Singleton
    static let shared = SupabaseDatabase()

    // MARK: - Init
    private init() {}

    // MARK: - Generic Select (simplified)
    func select<T: Decodable>(
        from table: SupabaseTable,
        columns: String = "*"
    ) async throws -> [T] {
        let client = SupabaseManager.shared.client
        return try await client
            .from(table.rawValue)
            .select(columns)
            .execute()
            .value
    }

    // MARK: - Select with filter
    func selectWithFilter<T: Decodable>(
        from table: SupabaseTable,
        column: String,
        value: String,
        columns: String = "*"
    ) async throws -> [T] {
        let client = SupabaseManager.shared.client
        return try await client
            .from(table.rawValue)
            .select(columns)
            .eq(column, value: value)
            .execute()
            .value
    }

    // MARK: - Insert
    func insert<T: Encodable>(
        into table: SupabaseTable,
        values: T
    ) async throws {
        let client = SupabaseManager.shared.client
        try await client
            .from(table.rawValue)
            .insert(values)
            .execute()
    }

    // MARK: - Update
    func update<T: Encodable>(
        in table: SupabaseTable,
        values: T,
        id: String
    ) async throws {
        let client = SupabaseManager.shared.client
        try await client
            .from(table.rawValue)
            .update(values)
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Delete
    func delete(
        from table: SupabaseTable,
        id: String
    ) async throws {
        let client = SupabaseManager.shared.client
        try await client
            .from(table.rawValue)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - Convenience Extensions
extension SupabaseDatabase {
    // Profile Operations
    func getProfile(userId: UUID) async throws -> ProfileDTO? {
        let results: [ProfileDTO] = try await selectWithFilter(
            from: .profiles,
            column: "id",
            value: userId.uuidString
        )
        return results.first
    }

    // Portfolio Operations
    func getPortfolios(userId: UUID) async throws -> [PortfolioDTO] {
        try await selectWithFilter(
            from: .portfolios,
            column: "user_id",
            value: userId.uuidString
        )
    }

    // DCA Reminders
    func getDCAReminders(userId: UUID) async throws -> [DCAReminder] {
        try await selectWithFilter(
            from: .dcaReminders,
            column: "user_id",
            value: userId.uuidString
        )
    }

    // Chat Sessions
    func getChatSessions(userId: UUID) async throws -> [ChatSessionDTO] {
        try await selectWithFilter(
            from: .chatSessions,
            column: "user_id",
            value: userId.uuidString
        )
    }
}

// MARK: - DTO Types for Database
struct ProfileDTO: Codable {
    let id: UUID
    let username: String?
    let email: String?
    let fullName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }
}

struct PortfolioDTO: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case userId = "user_id"
        case isPublic = "is_public"
    }
}

struct ChatSessionDTO: Codable {
    let id: UUID
    let userId: UUID
    let title: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
