import SwiftUI

// MARK: - AI Refine Sheet
/// Takes raw spoken/typed input and produces a polished, first-person insight in
/// the admin's own voice (via `BroadcastRefineService`). The admin can switch
/// tone, regenerate, edit the result inline, then apply it to the editor.
struct AIRefineSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    /// The raw text to refine (transcript or current draft).
    let input: String
    /// Optional working title, used as extra context for the model.
    var title: String = ""
    /// Called with the chosen text when the admin taps "Use This Draft".
    let onApply: (String) -> Void

    @State private var style: BroadcastRefineService.Style = .polished
    @State private var refined: String = ""
    @State private var isRefining = false
    @State private var errorMessage: String?
    @State private var showOriginal = false
    @State private var hasRefinedOnce = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.lg) {
                    intro
                    toneSelector
                    originalDisclosure
                    resultSection
                }
                .padding(ArkSpacing.md)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Refine with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use This Draft") {
                        onApply(refined)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(refined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRefining)
                }
            }
            .task {
                // Auto-run the first refinement on the default tone.
                if !hasRefinedOnce { await runRefine() }
            }
        }
    }

    // MARK: - Sections

    private var intro: some View {
        HStack(spacing: ArkSpacing.sm) {
            Image(systemName: "wand.and.stars")
                .font(.title3)
                .foregroundColor(AppColors.accent)
            Text("Your words, cleaned up in your voice. Pick a tone, tweak the result, then drop it into your post.")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(ArkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accent.opacity(0.08))
        .cornerRadius(ArkSpacing.sm)
    }

    private var toneSelector: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text("Tone")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            Picker("Tone", selection: $style) {
                Text(BroadcastRefineService.Style.polished.displayName).tag(BroadcastRefineService.Style.polished)
                Text(BroadcastRefineService.Style.brief.displayName).tag(BroadcastRefineService.Style.brief)
                Text(BroadcastRefineService.Style.takeaways.displayName).tag(BroadcastRefineService.Style.takeaways)
            }
            .pickerStyle(.segmented)
            .disabled(isRefining)
            .onChange(of: style) { _, _ in
                Task { await runRefine() }
            }
        }
    }

    private var originalDisclosure: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showOriginal.toggle() }
            } label: {
                HStack(spacing: ArkSpacing.xxs) {
                    Image(systemName: showOriginal ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                    Text("What you said")
                        .font(ArkFonts.caption)
                }
                .foregroundColor(AppColors.textTertiary)
            }
            .buttonStyle(.plain)

            if showOriginal {
                Text(input)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(ArkSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text("Refined draft")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Button {
                    Task { await runRefine() }
                } label: {
                    HStack(spacing: ArkSpacing.xxs) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text("Regenerate")
                            .font(ArkFonts.caption)
                    }
                    .foregroundColor(AppColors.accent)
                }
                .buttonStyle(.plain)
                .disabled(isRefining)
            }

            if isRefining {
                refiningPlaceholder
            } else if let errorMessage {
                errorView(errorMessage)
            } else {
                TextEditor(text: $refined)
                    .font(ArkFonts.body)
                    .frame(minHeight: 260)
                    .scrollContentBackground(.hidden)
                    .padding(ArkSpacing.sm)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)

                Text("You can edit this directly before using it.")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }

    private var refiningPlaceholder: some View {
        VStack(spacing: ArkSpacing.md) {
            ProgressView()
            Text("Refining in your voice…")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: ArkSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(AppColors.warning)
            Text(message)
                .font(ArkFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await runRefine() }
            } label: {
                Text("Try Again")
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(AppColors.accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }

    // MARK: - Actions

    @MainActor
    private func runRefine() async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = RefineError.emptyInput.errorDescription
            return
        }
        isRefining = true
        errorMessage = nil
        defer { isRefining = false }
        do {
            let result = try await BroadcastRefineService.shared.refine(
                transcript: trimmed,
                style: style,
                title: title
            )
            refined = result
            hasRefinedOnce = true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    AIRefineSheet(
        input: "Okay so uh, I think BTC is, you know, kind of at a key level here around 60k, and like if it breaks down I think we could see, um, a flush to 55. But honestly I'm still bullish into the back half of the year.",
        title: "BTC at a key level"
    ) { _ in }
}
