import SwiftUI

/// Admin pipeline for research notes: generate a draft from a ticker
/// (edge function gathers FMP data and Claude writes the prose), review it
/// in the exact view users will see, then publish or discard.
struct ResearchNotesAdminView: View {
    @Environment(\.colorScheme) var colorScheme

    @State private var drafts: [ResearchNote] = []
    @State private var previewNote: ResearchNote?
    @State private var ticker = ""
    @State private var classification = "thematic"
    @State private var isGenerating = false
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var statusIsError = false

    private let service = ResearchNoteService()

    var body: some View {
        List {
            // Generate
            Section {
                HStack {
                    TextField("Ticker (e.g. AVGO)", text: $ticker)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    Picker("", selection: $classification) {
                        Text("Core").tag("core")
                        Text("Thematic").tag("thematic")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                Button {
                    Task { await generate() }
                } label: {
                    HStack {
                        Spacer()
                        if isGenerating {
                            ProgressView()
                            Text("Researching… (takes about a minute)")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textTertiary)
                        } else {
                            Text("Generate Research Draft")
                                .font(AppFonts.body14Bold)
                        }
                        Spacer()
                    }
                }
                .disabled(ticker.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)

                if let statusMessage {
                    Text(statusMessage)
                        .font(AppFonts.caption12)
                        .foregroundColor(statusIsError ? AppColors.error : AppColors.success)
                }
            } header: {
                Text("New Research")
            } footer: {
                Text("Pulls fundamentals, analyst estimates, the latest earnings call, and news from FMP; Claude drafts the note in the Arkline framework. Numbers come from data, prose from the model — you are the editor of record.")
            }
            .listRowBackground(AppColors.cardBackground(colorScheme))

            // Drafts awaiting review
            Section {
                if drafts.isEmpty {
                    Text("No drafts awaiting review")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textTertiary)
                } else {
                    ForEach(drafts) { draft in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(draft.ticker)
                                    .font(AppFonts.body14Bold)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                Text("v\(draft.version)")
                                    .font(AppFonts.caption12)
                                    .foregroundColor(AppColors.textTertiary)
                                Spacer()
                                Button("Preview") { previewNote = draft }
                                    .font(AppFonts.caption12Medium)
                                    .buttonStyle(.bordered)
                            }
                            Text(draft.title)
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)

                            HStack(spacing: ArkSpacing.sm) {
                                Button {
                                    Task { await publish(draft) }
                                } label: {
                                    Text("Publish")
                                        .font(AppFonts.caption12Medium)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppColors.success)

                                Button(role: .destructive) {
                                    Task { await discard(draft) }
                                } label: {
                                    Text("Discard")
                                        .font(AppFonts.caption12Medium)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Drafts Awaiting Review")
            } footer: {
                Text("Drafts are never visible to users. Review carefully — published notes version rather than disappear, so accuracy at publish matters.")
            }
            .listRowBackground(AppColors.cardBackground(colorScheme))
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background(colorScheme))
        .navigationTitle("Research Notes")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadDrafts() }
        .refreshable { await loadDrafts() }
        .sheet(item: $previewNote) { note in
            ResearchNoteView(note: note, currentPrice: nil)
        }
        .overlay { if isLoading { ProgressView() } }
    }

    // MARK: - Actions

    private func loadDrafts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            drafts = try await service.fetchDrafts()
        } catch {
            statusMessage = "Failed to load drafts: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    private func generate() async {
        let symbol = ticker.trimmingCharacters(in: .whitespaces).uppercased()
        guard !symbol.isEmpty else { return }
        isGenerating = true
        defer { isGenerating = false }
        statusMessage = nil
        do {
            let created = try await service.generateDraft(
                ticker: symbol,
                classification: classification,
                targetWeight: nil
            )
            statusMessage = "Draft ready: \(created). Review below."
            statusIsError = false
            ticker = ""
            Haptics.success()
            await loadDrafts()
        } catch {
            statusMessage = "Generation failed: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    private func publish(_ note: ResearchNote) async {
        do {
            try await service.publish(noteId: note.id)
            statusMessage = "\(note.ticker) v\(note.version) published."
            statusIsError = false
            Haptics.success()
            await loadDrafts()
        } catch {
            statusMessage = "Publish failed: \(error.localizedDescription)"
            statusIsError = true
        }
    }

    private func discard(_ note: ResearchNote) async {
        do {
            try await service.archive(noteId: note.id)
            await loadDrafts()
        } catch {
            statusMessage = "Discard failed: \(error.localizedDescription)"
            statusIsError = true
        }
    }
}
