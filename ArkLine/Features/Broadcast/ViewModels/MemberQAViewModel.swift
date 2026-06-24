import Foundation

// MARK: - Member Q&A View Model
@MainActor
@Observable
final class MemberQAViewModel {
    private let service = MemberQuestionService()

    var questions: [MemberQuestion] = []
    var isLoading = false
    var isSubmitting = false
    var errorMessage: String?

    func load(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            questions = try await service.fetchQuestions(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Submit a question. `displayName` nil = post anonymously.
    func submit(text: String, userId: UUID, displayName: String?) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let created = try await service.submitQuestion(trimmed, userId: userId, displayName: displayName)
            questions.insert(created, at: 0)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func toggleLike(_ question: MemberQuestion, userId: UUID, target: QuestionLikeTarget) async {
        guard let idx = questions.firstIndex(where: { $0.id == question.id }) else { return }
        let wasLiked = (target == .question) ? questions[idx].likedQuestion : questions[idx].likedAnswer
        let nowLiked = !wasLiked

        // Optimistic update
        applyLike(at: idx, target: target, liked: nowLiked)
        do {
            try await service.setLike(questionId: question.id, userId: userId, target: target, liked: nowLiked)
        } catch {
            // Revert on failure
            applyLike(at: idx, target: target, liked: wasLiked)
        }
    }

    private func applyLike(at idx: Int, target: QuestionLikeTarget, liked: Bool) {
        switch target {
        case .question:
            let delta = liked == questions[idx].likedQuestion ? 0 : (liked ? 1 : -1)
            questions[idx].likedQuestion = liked
            questions[idx].questionLikeCount = max(0, questions[idx].questionLikeCount + delta)
        case .answer:
            let delta = liked == questions[idx].likedAnswer ? 0 : (liked ? 1 : -1)
            questions[idx].likedAnswer = liked
            questions[idx].answerLikeCount = max(0, questions[idx].answerLikeCount + delta)
        }
    }

    /// Admin: answer a question, then notify the asker.
    func answer(_ question: MemberQuestion, text: String, admin: User) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            let updated = try await service.answerQuestion(id: question.id, answer: trimmed, adminId: admin.id)
            if let idx = questions.firstIndex(where: { $0.id == question.id }) {
                var merged = updated
                merged.likedQuestion = questions[idx].likedQuestion
                merged.likedAnswer = questions[idx].likedAnswer
                questions[idx] = merged
            }
            await notifyAsker(question)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Admin: hide a question from the public board.
    func dismiss(_ question: MemberQuestion) async {
        do {
            try await service.dismissQuestion(id: question.id)
            questions.removeAll { $0.id == question.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func notifyAsker(_ question: MemberQuestion) async {
        let payload: [String: Any] = [
            "broadcast_id": question.id.uuidString,
            "title": "💬 Your question was answered",
            "body": "An Arkline admin replied to your question. Tap to read the answer.",
            "event_type": "qa_answer",
            "target_audience": ["type": "specific", "user_ids": [question.userId.uuidString]],
        ]
        do {
            let _: Data = try await SupabaseManager.shared.functions.invoke(
                "send-broadcast-notification",
                options: .init(body: JSONSerialization.data(withJSONObject: payload))
            )
        } catch {
            logWarning("Q&A answer notification failed: \(error.localizedDescription)", category: .network)
        }
    }
}
