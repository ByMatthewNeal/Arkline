import Foundation

// MARK: - Voice Note
/// One captured thought from the voice library — the growing corpus of how the
/// founder talks. Reusable anytime to generate content in their own voice.
struct VoiceNote: Identifiable, Codable, Hashable {
    let id: UUID
    let authorId: UUID
    var transcript: String
    var title: String?
    var wordCount: Int
    var source: String          // "voice" | "typed"
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case transcript
        case title
        case wordCount = "word_count"
        case source
        case createdAt = "created_at"
    }

    /// A short, human label for the note — its title, or the first line of speech.
    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        let firstLine = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .first ?? transcript
        return String(firstLine.prefix(60))
    }

    /// A one-line preview of the spoken content.
    var preview: String {
        let cleaned = transcript
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(120))
    }
}
