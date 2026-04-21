import Foundation

// MARK: - Dictionary Service

/// Manages glossary terms via Supabase.
final class DictionaryService {

    // MARK: - Dependencies

    private let supabase = SupabaseManager.shared

    // MARK: - Initialization

    init() {}

    // MARK: - Fetch

    func fetchAll() async throws -> [DictionaryTerm] {
        guard supabase.isConfigured else {
            logWarning("Supabase not configured, returning empty dictionary", category: .network)
            return []
        }

        let terms: [DictionaryTerm] = try await supabase.database
            .from(SupabaseTable.dictionary.rawValue)
            .select()
            .order("term", ascending: true)
            .execute()
            .value

        return terms
    }

    // MARK: - Search

    func search(query: String) async throws -> [DictionaryTerm] {
        guard supabase.isConfigured else { return [] }

        let terms: [DictionaryTerm] = try await supabase.database
            .from(SupabaseTable.dictionary.rawValue)
            .select()
            .ilike("term", pattern: "%\(query)%")
            .order("term", ascending: true)
            .execute()
            .value

        return terms
    }

    // MARK: - Create

    func create(term: CreateTermRequest) async throws -> DictionaryTerm {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        let created: DictionaryTerm = try await supabase.database
            .from(SupabaseTable.dictionary.rawValue)
            .insert(term)
            .select()
            .single()
            .execute()
            .value

        return created
    }

    // MARK: - Update

    func update(id: UUID, term: UpdateTermRequest) async throws {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        try await supabase.database
            .from(SupabaseTable.dictionary.rawValue)
            .update(term)
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Delete

    func delete(id: UUID) async throws {
        guard supabase.isConfigured else {
            throw AppError.supabaseNotConfigured
        }

        try await supabase.database
            .from(SupabaseTable.dictionary.rawValue)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
