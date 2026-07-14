import Foundation
import Supabase

// MARK: - Research Note Service

/// Fetches published research notes backing model portfolio positions.
final class ResearchNoteService {

    private let supabase = SupabaseManager.shared

    init() {}

    /// Latest published note per ticker (newest version wins).
    func fetchLatestNotes(tickers: [String]) async throws -> [String: ResearchNote] {
        guard supabase.isConfigured, !tickers.isEmpty else { return [:] }

        let rows: [ResearchNote] = try await supabase.database
            .from("research_notes")
            .select()
            .in("ticker", values: tickers)
            .eq("status", value: "published")
            .order("published_at", ascending: false)
            .execute()
            .value

        var latest: [String: ResearchNote] = [:]
        for note in rows where latest[note.ticker] == nil {
            latest[note.ticker] = note
        }
        return latest
    }

    /// Full version history for a ticker, newest first.
    func fetchHistory(ticker: String) async throws -> [ResearchNote] {
        guard supabase.isConfigured else { return [] }

        return try await supabase.database
            .from("research_notes")
            .select()
            .eq("ticker", value: ticker)
            .eq("status", value: "published")
            .order("published_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Admin (drafts pipeline)

    /// Pending drafts awaiting review (admin-only via RLS).
    func fetchDrafts() async throws -> [ResearchNote] {
        guard supabase.isConfigured else { return [] }

        return try await supabase.database
            .from("research_notes")
            .select()
            .eq("status", value: "draft")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    private struct GenerateRequest: Encodable {
        let ticker: String
        let classification: String?
        let target_weight: Double?
    }

    private struct GenerateResponse: Decodable {
        struct Draft: Decodable { let id: UUID; let ticker: String; let version: Int }
        let success: Bool?
        let draft: Draft?
        let error: String?
    }

    /// Kick off the research pipeline for a ticker. Returns the created draft info.
    func generateDraft(ticker: String, classification: String?, targetWeight: Double?) async throws -> String {
        let data: Data = try await supabase.functions.invoke(
            "generate-research-note",
            options: FunctionInvokeOptions(body: GenerateRequest(
                ticker: ticker,
                classification: classification,
                target_weight: targetWeight
            )),
            decode: { data, _ in data }
        )
        let response = try JSONDecoder().decode(GenerateResponse.self, from: data)
        if let error = response.error, !error.isEmpty {
            throw NSError(domain: "ResearchNote", code: 1, userInfo: [NSLocalizedDescriptionKey: error])
        }
        guard let draft = response.draft else {
            throw NSError(domain: "ResearchNote", code: 2, userInfo: [NSLocalizedDescriptionKey: "No draft returned"])
        }
        return "\(draft.ticker) v\(draft.version)"
    }

    private struct StatusUpdate: Encodable {
        let status: String
        let published_at: String?
    }

    /// Publish a reviewed draft (makes it user-visible).
    func publish(noteId: UUID) async throws {
        try await supabase.database
            .from("research_notes")
            .update(StatusUpdate(status: "published", published_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: noteId.uuidString)
            .execute()
    }

    /// Discard a draft.
    func archive(noteId: UUID) async throws {
        try await supabase.database
            .from("research_notes")
            .update(StatusUpdate(status: "archived", published_at: nil))
            .eq("id", value: noteId.uuidString)
            .execute()
    }
}
