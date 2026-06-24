import SwiftUI

// MARK: - Member Q&A Board
/// Public board: every member sees all questions and admin answers, and can like
/// both. Only admins can answer, dismiss, or export a question for marketing.
struct MemberQAView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = MemberQAViewModel()
    @State private var showAsk = false
    @State private var answering: MemberQuestion?
    @State private var sharing: MemberQuestion?

    private var isAdmin: Bool { appState.currentUser?.isAdmin == true }
    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    headerCard

                    if viewModel.isLoading && viewModel.questions.isEmpty {
                        ProgressView().padding(.top, 60)
                    } else if viewModel.questions.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.questions) { question in
                            QuestionCardView(
                                question: question,
                                isAdmin: isAdmin,
                                colorScheme: colorScheme,
                                onLikeQuestion: { Task { await like(question, .question) } },
                                onLikeAnswer: { Task { await like(question, .answer) } },
                                onAnswer: { answering = question },
                                onDismiss: { Task { await viewModel.dismiss(question) } },
                                onShare: { sharing = question }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Member Q&A")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAsk = true } label: {
                        Image(systemName: "plus.bubble.fill")
                    }
                }
            }
            .sheet(isPresented: $showAsk) {
                AskQuestionSheet(viewModel: viewModel).environmentObject(appState)
            }
            .sheet(item: $answering) { question in
                AnswerQuestionSheet(question: question, viewModel: viewModel).environmentObject(appState)
            }
            .sheet(item: $sharing) { question in
                QuestionShareSheetView(question: question)
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ask the market questions")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(textPrimary)
            Text("Submit a question and we'll answer it here for the community. Like the questions and answers you find most useful.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
            Button { showAsk = true } label: {
                HStack {
                    Image(systemName: "plus.bubble.fill")
                    Text("Ask a question")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(AppColors.accent))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground(colorScheme)))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 30))
                .foregroundColor(AppColors.textTertiary)
            Text("No questions yet — be the first to ask.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    private func reload() async {
        guard let uid = appState.currentUser?.id else { return }
        await viewModel.load(userId: uid)
    }

    private func like(_ question: MemberQuestion, _ target: QuestionLikeTarget) async {
        guard let uid = appState.currentUser?.id else { return }
        await viewModel.toggleLike(question, userId: uid, target: target)
    }
}

// MARK: - Question Card

private struct QuestionCardView: View {
    let question: MemberQuestion
    let isAdmin: Bool
    let colorScheme: ColorScheme
    let onLikeQuestion: () -> Void
    let onLikeAnswer: () -> Void
    let onAnswer: () -> Void
    let onDismiss: () -> Void
    let onShare: () -> Void

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Asker + status
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textTertiary)
                Text(question.displayedAsker)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textPrimary)
                Spacer()
                if question.isPending {
                    Text("Awaiting answer")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.warning)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.warning.opacity(0.12)))
                }
            }

            // Question
            Text(question.question)
                .font(.system(size: 15))
                .foregroundColor(textPrimary)

            likeButton(count: question.questionLikeCount, liked: question.likedQuestion, action: onLikeQuestion)

            // Answer
            if question.isAnswered, let answer = question.answer {
                Divider().background(textPrimary.opacity(0.08))
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.accent)
                        Text("Arkline")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                    Text(answer)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                    likeButton(count: question.answerLikeCount, liked: question.likedAnswer, action: onLikeAnswer)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.accent.opacity(0.06)))
            }

            // Admin controls
            if isAdmin {
                HStack(spacing: 12) {
                    Button(action: onAnswer) {
                        Label(question.isAnswered ? "Edit answer" : "Answer", systemImage: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    Spacer()
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Menu {
                        Button(role: .destructive, action: onDismiss) {
                            Label("Dismiss (hide)", systemImage: "eye.slash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground(colorScheme)))
    }

    private func likeButton(count: Int, liked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.system(size: 12))
                Text("\(count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundColor(liked ? AppColors.error : AppColors.textTertiary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ask Sheet

private struct AskQuestionSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: MemberQAViewModel

    @State private var text = ""
    @State private var postAnonymously = false

    private var firstName: String { appState.currentUser?.firstName ?? "you" }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your question") {
                    TextField("What's on your mind about the market?", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section {
                    Toggle("Post anonymously", isOn: $postAnonymously)
                    if !postAnonymously {
                        Text("Posting as \(firstName)")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                } footer: {
                    Text("Your question is visible to all members. You choose whether your name is shown.")
                }
            }
            .navigationTitle("Ask a question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            guard let uid = appState.currentUser?.id else { return }
                            let name = postAnonymously ? nil : firstName
                            let ok = await viewModel.submit(text: text, userId: uid, displayName: name)
                            if ok { dismiss() }
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting)
                }
            }
        }
    }
}

// MARK: - Answer Sheet (admin)

private struct AnswerQuestionSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let question: MemberQuestion
    @Bindable var viewModel: MemberQAViewModel

    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Question") {
                    Text(question.question).font(.system(size: 14))
                }
                Section("Your answer") {
                    TextField("Write your answer…", text: $text, axis: .vertical)
                        .lineLimit(4...12)
                }
            }
            .navigationTitle("Answer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post answer") {
                        Task {
                            guard let admin = appState.currentUser else { return }
                            let ok = await viewModel.answer(question, text: text, admin: admin)
                            if ok { dismiss() }
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { text = question.answer ?? "" }
        }
    }
}
