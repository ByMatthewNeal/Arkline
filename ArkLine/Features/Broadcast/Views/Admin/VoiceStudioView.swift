import SwiftUI

// MARK: - Voice Studio View Model

@Observable
final class VoiceStudioViewModel {
    var notes: [VoiceNote] = []
    var isLoading = false
    var errorMessage: String?

    private let library = VoiceLibraryService.shared

    func load(authorId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            notes = try await library.fetch(authorId: authorId)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Save a captured thought and prepend it to the in-memory list.
    @discardableResult
    func save(transcript: String, source: String, authorId: UUID) async -> VoiceNote? {
        do {
            let note = try await library.save(transcript: transcript, title: nil, source: source, authorId: authorId)
            notes.insert(note, at: 0)
            return note
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }

    func delete(_ note: VoiceNote) async {
        notes.removeAll { $0.id == note.id }
        do {
            try await library.delete(id: note.id)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Generate Target

private struct GenerateTarget: Identifiable {
    let id = UUID()
    let transcript: String
    let title: String
}

// MARK: - Voice Studio View

/// The voice engine home. Capture a thought (speak or type), keep a private
/// library of everything you've said, and turn any note into content for your
/// members, Instagram, or X — always in your voice.
struct VoiceStudioView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = VoiceStudioViewModel()
    @State private var search = ""

    // Capture state
    @State private var showingRecorder = false
    @State private var showingTypeSheet = false
    @State private var captureAudioURL: URL?
    @State private var captureText = ""

    // Generation
    @State private var generateTarget: GenerateTarget?

    private var authorId: UUID? { appState.currentUser?.id }

    private var filteredNotes: [VoiceNote] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return viewModel.notes }
        return viewModel.notes.filter {
            $0.transcript.lowercased().contains(q) || ($0.title?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    captureCard

                    if !viewModel.notes.isEmpty {
                        searchField
                    }

                    libraryList
                }
                .padding(ArkSpacing.md)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Voice Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingRecorder, onDismiss: handleCapturedRecording) {
                VoiceRecorderView(audioURL: $captureAudioURL, transcribedText: $captureText)
            }
            .sheet(isPresented: $showingTypeSheet) {
                TypeThoughtSheet { text in
                    Task { await capture(text: text, source: "typed") }
                }
            }
            .sheet(item: $generateTarget) { target in
                ContentGenerateSheet(input: target.transcript, title: target.title)
            }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    // MARK: - Capture Card

    private var captureCard: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Capture a thought")
                .font(ArkFonts.bodySemibold)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text("Speak your mind or jot it down. Every thought is saved to your library and ready to become content in your voice.")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: ArkSpacing.sm) {
                Button {
                    captureText = ""
                    captureAudioURL = nil
                    showingRecorder = true
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Record")
                    }
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ArkSpacing.sm)
                    .background(AppColors.accent)
                    .cornerRadius(ArkSpacing.sm)
                }
                .buttonStyle(.plain)

                Button {
                    showingTypeSheet = true
                } label: {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("Type")
                    }
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ArkSpacing.sm)
                    .background(AppColors.accent.opacity(0.12))
                    .cornerRadius(ArkSpacing.sm)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, ArkSpacing.xs)
        }
        .padding(ArkSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground(colorScheme)))
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: ArkSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textTertiary)
            TextField("Search your thoughts", text: $search)
                .font(ArkFonts.body)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }

    // MARK: - Library

    @ViewBuilder
    private var libraryList: some View {
        if viewModel.isLoading && viewModel.notes.isEmpty {
            ProgressView().padding(.top, 50)
        } else if viewModel.notes.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                HStack {
                    Text("Your library")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("\(viewModel.notes.count) saved")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textTertiary)
                }

                ForEach(filteredNotes) { note in
                    noteRow(note)
                }
            }
        }
    }

    private func noteRow(_ note: VoiceNote) -> some View {
        Button {
            generateTarget = GenerateTarget(transcript: note.transcript, title: note.displayTitle)
        } label: {
            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: note.source == "typed" ? "keyboard" : "waveform")
                        .font(.caption)
                        .foregroundColor(AppColors.accent)
                    Text(note.displayTitle)
                        .font(ArkFonts.bodySemibold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                Text(note.preview)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: ArkSpacing.sm) {
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                    Text("·")
                    Text("\(note.wordCount) words")
                }
                .font(.system(size: 11))
                .foregroundColor(AppColors.textTertiary)
            }
            .padding(ArkSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.cardBackground(colorScheme)))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await viewModel.delete(note) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: ArkSpacing.sm) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 38))
                .foregroundColor(AppColors.textTertiary)
            Text("Your library is empty")
                .font(ArkFonts.bodySemibold)
                .foregroundColor(AppColors.textSecondary)
            Text("Record or type your first thought to get started.")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    // MARK: - Actions

    private func reload() async {
        guard let authorId else { return }
        await viewModel.load(authorId: authorId)
    }

    private func handleCapturedRecording() {
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        captureText = ""
        captureAudioURL = nil
        guard !text.isEmpty else { return }
        Task { await capture(text: text, source: "voice") }
    }

    private func capture(text: String, source: String) async {
        guard let authorId else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let note = await viewModel.save(transcript: trimmed, source: source, authorId: authorId) {
            generateTarget = GenerateTarget(transcript: note.transcript, title: note.displayTitle)
        }
    }
}

// MARK: - Type Thought Sheet

private struct TypeThoughtSheet: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    let onSave: (String) -> Void

    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $text)
                    .font(ArkFonts.body)
                    .padding(ArkSpacing.sm)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)
                    .frame(minHeight: 220)
                    .padding()
                Spacer()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("New Thought")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VoiceStudioView()
        .environmentObject(AppState())
}
