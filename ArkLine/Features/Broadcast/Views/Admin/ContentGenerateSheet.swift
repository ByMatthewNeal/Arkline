import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Content Generate Sheet
/// Takes one captured thought and turns it into platform-ready content in the
/// founder's own voice. Switch format, edit the result, then copy or share.
struct ContentGenerateSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    let input: String
    var title: String = ""

    @State private var format: ContentStudioService.Format = .broadcast
    @State private var output: String = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var didCopy = false
    @State private var showOriginal = false
    @State private var generatedFormats: Set<ContentStudioService.Format> = []

    private var charCount: Int { output.count }
    private var isOverTwitterLimit: Bool { format == .twitterPost && charCount > 280 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.lg) {
                    intro
                    formatPicker
                    originalDisclosure
                    resultSection
                }
                .padding(ArkSpacing.md)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Create Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if !generatedFormats.contains(format) { await generate() }
            }
        }
    }

    // MARK: - Sections

    private var intro: some View {
        HStack(spacing: ArkSpacing.sm) {
            Image(systemName: "wand.and.stars")
                .font(.title3)
                .foregroundColor(AppColors.accent)
            Text("Same thought, shaped for each place you post — always in your voice. Pick a format, tweak it, then copy or share.")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(ArkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accent.opacity(0.08))
        .cornerRadius(ArkSpacing.sm)
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text("Format")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArkSpacing.sm) {
                    ForEach(ContentStudioService.Format.allCases) { f in
                        formatChip(f)
                    }
                }
            }
        }
    }

    private func formatChip(_ f: ContentStudioService.Format) -> some View {
        let selected = format == f
        return Button {
            guard f != format else { return }
            format = f
            Task { await generate() }
        } label: {
            HStack(spacing: ArkSpacing.xxs) {
                Image(systemName: f.iconName)
                    .font(.caption)
                Text(f.displayName)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(selected ? .white : AppColors.accent)
            .padding(.horizontal, ArkSpacing.md)
            .padding(.vertical, ArkSpacing.sm)
            .background(selected ? AppColors.accent : AppColors.accent.opacity(0.12))
            .cornerRadius(ArkSpacing.sm)
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
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
                Text(format.subtitle)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Button {
                    Task { await generate() }
                } label: {
                    HStack(spacing: ArkSpacing.xxs) {
                        Image(systemName: "arrow.clockwise").font(.caption)
                        Text("Regenerate").font(ArkFonts.caption)
                    }
                    .foregroundColor(AppColors.accent)
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }

            if isGenerating {
                generatingPlaceholder
            } else if let errorMessage {
                errorView(errorMessage)
            } else {
                TextEditor(text: $output)
                    .font(ArkFonts.body)
                    .frame(minHeight: 240)
                    .scrollContentBackground(.hidden)
                    .padding(ArkSpacing.sm)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)

                HStack {
                    if format == .twitterPost {
                        Text("\(charCount)/280")
                            .font(ArkFonts.caption)
                            .foregroundColor(isOverTwitterLimit ? AppColors.error : AppColors.textTertiary)
                    } else {
                        Text("Edit freely before sharing.")
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    Spacer()
                }

                actionButtons
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: ArkSpacing.sm) {
            Button {
                copyToClipboard()
            } label: {
                HStack {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    Text(didCopy ? "Copied" : "Copy")
                }
                .font(ArkFonts.bodySemibold)
                .foregroundColor(AppColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.sm)
                .background(AppColors.accent.opacity(0.12))
                .cornerRadius(ArkSpacing.sm)
            }
            .buttonStyle(.plain)

            Button {
                ShareCardRenderer.presentShareSheet(text: output)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(ArkFonts.bodySemibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.sm)
                .background(AppColors.accent)
                .cornerRadius(ArkSpacing.sm)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, ArkSpacing.xs)
        .disabled(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var generatingPlaceholder: some View {
        VStack(spacing: ArkSpacing.md) {
            ProgressView()
            Text("Writing your \(format.displayName.lowercased())…")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
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
            Button { Task { await generate() } } label: {
                Text("Try Again")
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(AppColors.accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }

    // MARK: - Actions

    @MainActor
    private func generate() async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = RefineError.emptyInput.errorDescription
            return
        }
        isGenerating = true
        errorMessage = nil
        didCopy = false
        defer { isGenerating = false }
        do {
            let result = try await ContentStudioService.shared.generate(
                transcript: trimmed,
                format: format,
                title: title
            )
            output = result
            generatedFormats.insert(format)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func copyToClipboard() {
        #if canImport(UIKit)
        UIPasteboard.general.string = output
        #endif
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            didCopy = false
        }
    }
}

// MARK: - Preview

#Preview {
    ContentGenerateSheet(
        input: "BTC is sitting right at a key level around 60k and if it loses that I think we flush to 55, but I'm still bullish into year end.",
        title: "BTC key level"
    )
}
