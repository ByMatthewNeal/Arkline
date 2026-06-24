import Foundation

// MARK: - Member Question Service
/// Reads/writes the member Q&A board. RLS enforces that only admins can answer
/// or dismiss; members can insert their own questions and like questions/answers.
final class MemberQuestionService {
    private let supabase = SupabaseManager.shared

    // MARK: - Member actions

    /// Submit a new market question. Pass `displayName` to post under a name, or
    /// nil to post anonymously.
    func submitQuestion(_ text: String, userId: UUID, displayName: String?) async throws -> MemberQuestion {
        guard supabase.isConfigured else { throw AppError.supabaseNotConfigured }
        let created: MemberQuestion = try await supabase.database
            .from(SupabaseTable.memberQuestions.rawValue)
            .insert(NewQuestionRequest(userId: userId, question: text, askerDisplayName: displayName))
            .select()
            .single()
            .execute()
            .value
        return created
    }

    /// Fetch the public board (newest first) and hydrate which entries the caller liked.
    func fetchQuestions(userId: UUID, limit: Int = 100) async throws -> [MemberQuestion] {
        guard supabase.isConfigured else { return [] }

        var questions: [MemberQuestion] = try await supabase.database
            .from(SupabaseTable.memberQuestions.rawValue)
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        let likes: [QuestionLikeRow] = try await supabase.database
            .from(SupabaseTable.memberQuestionLikes.rawValue)
            .select("question_id, target")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let likedQuestions = Set(likes.filter { $0.target == "question" }.map { $0.questionId })
        let likedAnswers = Set(likes.filter { $0.target == "answer" }.map { $0.questionId })
        for i in questions.indices {
            questions[i].likedQuestion = likedQuestions.contains(questions[i].id)
            questions[i].likedAnswer = likedAnswers.contains(questions[i].id)
        }
        return questions
    }

    /// Like or unlike a question or its answer.
    func setLike(questionId: UUID, userId: UUID, target: QuestionLikeTarget, liked: Bool) async throws {
        guard supabase.isConfigured else { return }
        if liked {
            try await supabase.database
                .from(SupabaseTable.memberQuestionLikes.rawValue)
                .insert(LikeRequest(questionId: questionId, userId: userId, target: target.rawValue))
                .execute()
        } else {
            try await supabase.database
                .from(SupabaseTable.memberQuestionLikes.rawValue)
                .delete()
                .eq("question_id", value: questionId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .eq("target", value: target.rawValue)
                .execute()
        }
    }

    // MARK: - Admin actions (RLS restricts these to admins)

    /// Answer a question. Returns the updated row.
    @discardableResult
    func answerQuestion(id: UUID, answer: String, adminId: UUID) async throws -> MemberQuestion {
        guard supabase.isConfigured else { throw AppError.supabaseNotConfigured }
        let updated: MemberQuestion = try await supabase.database
            .from(SupabaseTable.memberQuestions.rawValue)
            .update(AnswerUpdate(answer: answer, status: "answered", answeredBy: adminId, answeredAt: Date()))
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
        return updated
    }

    /// Hide a question from the public board (spam/moderation).
    func dismissQuestion(id: UUID) async throws {
        guard supabase.isConfigured else { return }
        try await supabase.database
            .from(SupabaseTable.memberQuestions.rawValue)
            .update(StatusUpdate(status: "dismissed"))
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// MARK: - Request / Response Payloads

private struct NewQuestionRequest: Encodable {
    let userId: UUID
    let question: String
    let askerDisplayName: String?
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case question
        case askerDisplayName = "asker_display_name"
    }
}

private struct LikeRequest: Encodable {
    let questionId: UUID
    let userId: UUID
    let target: String
    enum CodingKeys: String, CodingKey { case questionId = "question_id"; case userId = "user_id"; case target }
}

private struct AnswerUpdate: Encodable {
    let answer: String
    let status: String
    let answeredBy: UUID
    let answeredAt: Date
    enum CodingKeys: String, CodingKey {
        case answer, status
        case answeredBy = "answered_by"
        case answeredAt = "answered_at"
    }
}

private struct StatusUpdate: Encodable {
    let status: String
}

private struct QuestionLikeRow: Decodable {
    let questionId: UUID
    let target: String
    enum CodingKeys: String, CodingKey { case questionId = "question_id"; case target }
}
