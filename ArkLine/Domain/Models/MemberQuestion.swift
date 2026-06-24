import Foundation

// MARK: - Member Question
/// A market question submitted by a member. Visible to all members on a public
/// board; only admins can answer, dismiss, or export. Members can like both the
/// question and the answer.
struct MemberQuestion: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var question: String
    /// Name to show publicly (full or first name), or nil = posted anonymously.
    var askerDisplayName: String?
    var status: String          // pending | answered | dismissed
    var answer: String?
    var answeredBy: UUID?
    var answeredAt: Date?
    var questionLikeCount: Int
    var answerLikeCount: Int
    let createdAt: Date
    var updatedAt: Date?

    // Hydrated client-side from the caller's likes (not stored on the row).
    var likedQuestion: Bool = false
    var likedAnswer: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case question
        case askerDisplayName = "asker_display_name"
        case status
        case answer
        case answeredBy = "answered_by"
        case answeredAt = "answered_at"
        case questionLikeCount = "question_like_count"
        case answerLikeCount = "answer_like_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isAnswered: Bool { status == "answered" && (answer?.isEmpty == false) }
    var isPending: Bool { status == "pending" }

    /// What to show as the asker on the public board.
    var displayedAsker: String {
        let name = askerDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty == false) ? name! : "Anonymous"
    }
}

enum MemberQuestionStatus: String {
    case pending, answered, dismissed
}

enum QuestionLikeTarget: String {
    case question, answer
}
