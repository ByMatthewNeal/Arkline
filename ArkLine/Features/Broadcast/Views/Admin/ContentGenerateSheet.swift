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
    var noteId: UUID? = nil
    var onTitleSaved: ((String) -> Void)? = nil

    init(input: String, title: String = "", noteId: UUID? = nil, onTitleSaved: ((String) -> Void)? = nil) {
        self.input = input
        self.title = title
        self.noteId = noteId
        self.onTitleSaved = onTitleSaved
        _titleText = State(initialValue: title)
        _lastSavedTitle = State(initialValue: title)
    }

    @State private var format: ContentStudioService.Format = .broadcast
    @State private var output: String = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var didCopy = false
    @State private var showOriginal = false
    @State private var generatedFormats: Set<ContentStudioService.Format> = []

    // Title / subject
    @State private var titleText: String
    @State private var titleIdeas: ContentStudioService.TitleIdeas?
    @State private var isLoadingTitles = false
    @State private var titlesError: String?
    @State private var didSaveTitle = false
    @State private var lastSavedTitle: String

    private var charCount: Int { output.count }
    private var isOverTwitterLimit: Bool { format == .twitterPost && charCount > 280 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.lg) {
                    intro
                    titleSection
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
            .task { await loadTitlesIfNeeded() }
            .onDisappear { saveTitleToNote() }
        }
    }

    // MARK: - Sections

    private var intro: some View {
        HStack(spacing: ArkSpacing.sm) {
            Image(systemName: "wand.and.stars")
                .font(.title3)
                .foregroundColor(AppColors.accent)
            Text("Same thought, shaped for each place you post, always in your voice. Pick a format, tweak it, then copy or share.")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(ArkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.accent.opacity(0.08))
        .cornerRadius(ArkSpacing.sm)
    }

    // MARK: - Title / Subject

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text("Title / Subject")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                if didSaveTitle {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.success)
                }
            }

            HStack(spacing: ArkSpacing.sm) {
                TextField("Give it a title", text: $titleText)
                    .font(ArkFonts.body)
                    .submitLabel(.done)
                    .onSubmit { saveTitleToNote() }
                    .padding(ArkSpacing.sm)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)

                if noteId != nil && !titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button { saveTitleToNote() } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.body)
                            .foregroundColor(AppColors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            titleIdeasArea
        }
    }

    @ViewBuilder
    private var titleIdeasArea: some View {
        if isLoadingTitles {
            HStack(spacing: ArkSpacing.xs) {
                ProgressView().scaleEffect(0.8)
                Text("Coming up with title ideas…")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.top, ArkSpacing.xxs)
        } else if let titlesError {
            HStack(spacing: ArkSpacing.xs) {
                Text(titlesError)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
                Button("Retry") { Task { await loadTitles() } }
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.accent)
            }
        } else if let ideas = titleIdeas, !ideas.isEmpty {
            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                ideaGroup("Insights / Broadcast", ideas.broadcast)
                ideaGroup("X (Twitter)", ideas.x)
                ideaGroup("Instagram", ideas.instagram)
                Button { Task { await loadTitles() } } label: {
                    HStack(spacing: ArkSpacing.xxs) {
                        Image(systemName: "arrow.clockwise").font(.caption2)
                        Text("More ideas").font(ArkFonts.caption)
                    }
                    .foregroundColor(AppColors.accent)
                }
                .buttonStyle(.plain)
                .disabled(isLoadingTitles)
            }
            .padding(.top, ArkSpacing.xxs)
        } else {
            Button { Task { await loadTitles() } } label: {
                HStack(spacing: ArkSpacing.xxs) {
                    Image(systemName: "wand.and.stars").font(.caption)
                    Text("Suggest title ideas").font(ArkFonts.caption)
                }
                .foregroundColor(AppColors.accent)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func ideaGroup(_ label: String, _ ideas: [String]) -> some View {
        if !ideas.isEmpty {
            VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
                ForEach(ideas, id: \.self) { idea in
                    Button { applyTitle(idea) } label: {
                        HStack(spacing: ArkSpacing.xs) {
                            Image(systemName: titleText == idea ? "checkmark.circle.fill" : "plus.circle")
                                .font(.caption)
                                .foregroundColor(AppColors.accent)
                            Text(idea)
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, ArkSpacing.xs)
                        .padding(.horizontal, ArkSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.accent.opacity(0.08))
                        .cornerRadius(ArkSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
                title: titleText
            )
            output = result
            generatedFormats.insert(format)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadTitlesIfNeeded() async {
        guard titleIdeas == nil, !isLoadingTitles else { return }
        await loadTitles()
    }

    @MainActor
    private func loadTitles() async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoadingTitles = true
        titlesError = nil
        defer { isLoadingTitles = false }
        do {
            titleIdeas = try await ContentStudioService.shared.generateTitles(transcript: trimmed)
        } catch {
            titlesError = (error as? LocalizedError)?.errorDescription ?? "Couldn't get title ideas"
        }
    }

    private func applyTitle(_ idea: String) {
        titleText = idea
        saveTitleToNote()
    }

    /// Persist the current title back onto the source note (if any), once per change.
    private func saveTitleToNote() {
        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != lastSavedTitle else { return }
        lastSavedTitle = trimmed
        onTitleSaved?(trimmed)
        didSaveTitle = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { didSaveTitle = false }
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
