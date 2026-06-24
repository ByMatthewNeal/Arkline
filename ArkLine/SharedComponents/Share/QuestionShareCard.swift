import SwiftUI

// MARK: - Q&A Share Sheet (admin export for marketing)
/// Preview + export of a branded question/answer card for Instagram, X, etc.
struct QuestionShareSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    let question: MemberQuestion
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    QuestionShareCard(question: question)
                        .frame(width: 300, height: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .padding(.top, 16)

                    Button { export() } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(isRendering ? "Preparing…" : "Export & Share")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(AppColors.accent))
                    }
                    .disabled(isRendering)
                    .padding(.horizontal)

                    Text("Exports a branded card of this question and answer for Instagram, X, and other channels.")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.bottom, 28)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Share Q&A")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func export() {
        isRendering = true
        defer { isRendering = false }
        let card = QuestionShareCard(question: question)
        if let image = ShareCardRenderer.renderImage(content: card, width: 390, height: 520) {
            ShareCardRenderer.presentShareSheet(image: image)
        }
    }
}

// MARK: - Branded Card
struct QuestionShareCard: View {
    let question: MemberQuestion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image("ArkLineAppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("Arkline")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("MEMBER Q&A")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(20)

            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Q")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(Color(hex: "3B82F6"))
                    Text(question.question)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let answer = question.answer, !answer.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(Color(hex: "10B981"))
                        Text(answer)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(20)

            HStack {
                Text("Market intelligence, answered.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("arkline.io")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(20)
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "0B1220"), Color(hex: "131A2E")],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}
