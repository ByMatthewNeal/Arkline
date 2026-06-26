import Foundation

// MARK: - Voice Library Service
/// Reads/writes the voice_notes library — the founder's private corpus of
/// spoken thoughts. RLS restricts every row to its author.
final class VoiceLibraryService {
    static let shared = VoiceLibraryService()
    private init() {}

    private let supabase = SupabaseManager.shared

    // MARK: - Save

    /// Persist a transcript to the library. Returns the saved note.
    @discardableResult
    func save(transcript: String, title: String?, source: String = "voice", authorId: UUID) async throws -> VoiceNote {
        guard supabase.isConfigured else { throw AppError.supabaseNotConfigured }
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RefineError.emptyInput }

        let words = trimmed.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        let payload = NewVoiceNote(
            authorId: authorId,
            transcript: trimmed,
            title: title?.isEmpty == false ? title : nil,
            wordCount: words,
            source: source
        )

        let saved: VoiceNote = try await supabase.database
            .from(SupabaseTable.voiceNotes.rawValue)
            .insert(payload)
            .select()
            .single()
            .execute()
            .value
        return saved
    }

    // MARK: - Read

    /// Fetch the library, newest first.
    func fetch(authorId: UUID, limit: Int = 200) async throws -> [VoiceNote] {
        guard supabase.isConfigured else { return [] }
        let notes: [VoiceNote] = try await supabase.database
            .from(SupabaseTable.voiceNotes.rawValue)
            .select()
            .eq("author_id", value: authorId.uuidString)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return notes
    }

    // MARK: - Update / Delete

    /// Rename a note's title.
    func rename(id: UUID, title: String) async throws {
        guard supabase.isConfigured else { return }
        try await supabase.database
            .from(SupabaseTable.voiceNotes.rawValue)
            .update(TitleUpdate(title: title))
            .eq("id", value: id.uuidString)
            .execute()
    }

    /// Delete a note from the library.
    func delete(id: UUID) async throws {
        guard supabase.isConfigured else { return }
        try await supabase.database
            .from(SupabaseTable.voiceNotes.rawValue)
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// MARK: - Payloads

private struct NewVoiceNote: Encodable {
    let authorId: UUID
    let transcript: String
    let title: String?
    let wordCount: Int
    let source: String
    enum CodingKeys: String, CodingKey {
        case authorId = "author_id"
        case transcript
        case title
        case wordCount = "word_count"
        case source
    }
}

private struct TitleUpdate: Encodable {
    let title: String
}
