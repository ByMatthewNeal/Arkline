import SwiftUI

// MARK: - Reel Scripts View
/// Admin view for viewing and managing auto-generated Instagram Reel scripts.

struct ReelScriptsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var scripts: [ReelScriptDTO] = []
    @State private var isLoading = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var copiedId: UUID?
    @State private var showGenerateSuccess = false
    @State private var showGenerateError = false
    @State private var customPrompt = ""
    @State private var showPromptField = false

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            if isLoading && scripts.isEmpty {
                ProgressView("Loading scripts...")
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ScrollView {
                    VStack(spacing: ArkSpacing.lg) {
                        // Custom prompt input
                        if showPromptField {
                            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                                Text("PIVOT TOPIC")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(AppColors.warning)
                                    .tracking(1)

                                TextField("e.g. Fed just cut rates, BTC breaking $100K, new tariffs announced...", text: $customPrompt, axis: .vertical)
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                    .lineLimit(2...4)
                                    .padding(ArkSpacing.sm)
                                    .background(Color.black.opacity(0.2))
                                    .cornerRadius(ArkSpacing.Radius.sm)

                                HStack {
                                    Button {
                                        withAnimation { showPromptField = false }
                                        customPrompt = ""
                                    } label: {
                                        Text("Cancel")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(AppColors.textSecondary)
                                    }

                                    Spacer()

                                    Button {
                                        Task { await generateScript() }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "sparkles")
                                                .font(.caption)
                                            Text(customPrompt.isEmpty ? "Generate" : "Generate with topic")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(customPrompt.isEmpty ? AppColors.accent : AppColors.warning)
                                        .cornerRadius(8)
                                    }
                                    .disabled(isGenerating)
                                }
                            }
                            .padding(ArkSpacing.lg)
                            .background(cardBackground)
                            .cornerRadius(ArkSpacing.Radius.card)
                            .arkShadow(ArkSpacing.Shadow.card)
                            .padding(.horizontal, ArkSpacing.lg)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Today's script (featured)
                        if let today = todayScript {
                            featuredScriptCard(today)
                        } else {
                            noScriptCard
                        }

                        // Recent scripts
                        if !pastScripts.isEmpty {
                            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                                Text("Recent Scripts")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                    .padding(.horizontal, ArkSpacing.lg)

                                ForEach(pastScripts) { script in
                                    pastScriptCard(script)
                                }
                            }
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.top, ArkSpacing.md)
                }
                .refreshable { await loadScripts() }
            }
        }
        .overlay(alignment: .top) {
            if showGenerateError, let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        showGenerateError = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(ArkSpacing.md)
                .background(AppColors.error)
                .cornerRadius(ArkSpacing.Radius.md)
                .padding(.horizontal, ArkSpacing.lg)
                .padding(.top, ArkSpacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: showGenerateError)
            }
        }
        .navigationTitle("Reel Scripts")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if isGenerating { return }
                    withAnimation { showPromptField.toggle() }
                } label: {
                    if isGenerating {
                        ProgressView()
                            .controlSize(.small)
                    } else if showGenerateSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.success)
                    } else if showGenerateError {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.error)
                    } else {
                        Image(systemName: showPromptField ? "xmark.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(showPromptField ? AppColors.textSecondary : AppColors.accent)
                    }
                }
                .disabled(isGenerating)
            }
        }
        .task { await loadScripts() }
    }

    // MARK: - Computed

    private var todayScript: ReelScriptDTO? {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        return scripts.first { $0.scriptDate == today }
    }

    private var pastScripts: [ReelScriptDTO] {
        let today = DateFormatter.yyyyMMdd.string(from: Date())
        return scripts.filter { $0.scriptDate != today }
    }

    // MARK: - Featured Card

    private func featuredScriptCard(_ script: ReelScriptDTO) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "video.fill")
                        .foregroundColor(AppColors.accent)
                    Text("Today's Script")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }

                Spacer()

                if let topic = script.topic {
                    Text(topic.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.accent.opacity(0.15))
                        .cornerRadius(4)
                }
            }

            // Hook
            VStack(alignment: .leading, spacing: 4) {
                Text("HOOK")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.error)
                    .tracking(1)
                Text(script.hook)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Divider()

            // Body
            VStack(alignment: .leading, spacing: 4) {
                Text("BODY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.accent)
                    .tracking(1)
                Text(script.body)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.9))
                    .lineSpacing(4)
            }

            Divider()

            // CTA
            VStack(alignment: .leading, spacing: 4) {
                Text("CTA")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.success)
                    .tracking(1)
                Text(script.cta)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Divider()

            // Actions
            HStack {
                if let wordCount = script.wordCount {
                    Text("\(wordCount) words · ~\(max(wordCount / 3, 20))s")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Button {
                    copyScript(script)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedId == script.id ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        Text(copiedId == script.id ? "Copied" : "Copy")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(copiedId == script.id ? AppColors.success : AppColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.accent.opacity(0.1))
                    .cornerRadius(8)
                }

                Button {
                    Task { await generateScript() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text("Redo")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppColors.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppColors.warning.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(isGenerating)
            }
        }
        .padding(ArkSpacing.lg)
        .background(cardBackground)
        .cornerRadius(ArkSpacing.Radius.card)
        .arkShadow(ArkSpacing.Shadow.card)
        .padding(.horizontal, ArkSpacing.lg)
    }

    // MARK: - No Script Card

    private var noScriptCard: some View {
        VStack(spacing: ArkSpacing.md) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 36))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))

            Text("No script for today")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Button {
                Task { await generateScript() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Generate Script")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, ArkSpacing.lg)
                .padding(.vertical, 10)
                .background(AppColors.accent)
                .cornerRadius(ArkSpacing.Radius.md)
            }
            .disabled(isGenerating)
        }
        .frame(maxWidth: .infinity)
        .padding(ArkSpacing.xl)
        .background(cardBackground)
        .cornerRadius(ArkSpacing.Radius.card)
        .arkShadow(ArkSpacing.Shadow.card)
        .padding(.horizontal, ArkSpacing.lg)
    }

    // MARK: - Past Script Card

    private func pastScriptCard(_ script: ReelScriptDTO) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack {
                Text(formatDate(script.scriptDate))
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                if let topic = script.topic {
                    Text(topic)
                        .font(.caption2)
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppColors.accent.opacity(0.1))
                        .cornerRadius(4)
                }

                Spacer()

                Button {
                    copyScript(script)
                } label: {
                    Image(systemName: copiedId == script.id ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(copiedId == script.id ? AppColors.success : AppColors.accent)
                }
            }

            Text(script.hook)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineLimit(2)

            Text(script.body)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(3)
        }
        .padding(ArkSpacing.md)
        .background(cardBackground)
        .cornerRadius(ArkSpacing.Radius.card)
        .arkShadow(ArkSpacing.Shadow.card)
        .padding(.horizontal, ArkSpacing.lg)
    }

    // MARK: - Actions

    private func loadScripts() async {
        isLoading = true
        defer { isLoading = false }

        guard SupabaseManager.shared.isConfigured else { return }

        do {
            let rows: [ReelScriptDTO] = try await SupabaseManager.shared.database
                .from(SupabaseTable.reelScripts.rawValue)
                .select()
                .order("script_date", ascending: false)
                .limit(14)
                .execute()
                .value
            scripts = rows
        } catch {
            logError("Failed to load reel scripts: \(error)", category: .network)
            errorMessage = "Failed to load scripts"
        }
    }

    private func generateScript() async {
        isGenerating = true
        defer { isGenerating = false }

        do {
            var params: [String: Any] = ["regenerate": true]
            let trimmed = customPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                params["topic_override"] = trimmed
            }
            let _: Data = try await SupabaseManager.shared.functions.invoke(
                "generate-reel-script",
                options: .init(body: JSONSerialization.data(withJSONObject: params))
            )
            await loadScripts()
            customPrompt = ""
            withAnimation { showPromptField = false }
            #if canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
            showGenerateSuccess = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                await MainActor.run { showGenerateSuccess = false }
            }
        } catch {
            logError("Failed to generate script: \(error)", category: .network)
            errorMessage = "Generation failed"
            #if canImport(UIKit)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            #endif
            showGenerateError = true
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { showGenerateError = false }
            }
        }
    }

    private func copyScript(_ script: ReelScriptDTO) {
        let fullScript = "\(script.hook)\n\n\(script.body)\n\n\(script.cta)"
        #if canImport(UIKit)
        UIPasteboard.general.string = fullScript
        #endif
        copiedId = script.id
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { copiedId = nil }
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: dateStr) else { return dateStr }
        let output = DateFormatter()
        output.dateFormat = "EEEE, MMM d"
        return output.string(from: date)
    }
}

// MARK: - DTO

struct ReelScriptDTO: Codable, Identifiable {
    let id: UUID
    let hook: String
    let body: String
    let cta: String
    let topic: String?
    let sourceHeadlines: [String]?
    let wordCount: Int?
    let scriptDate: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, hook, body, cta, topic, status
        case sourceHeadlines = "source_headlines"
        case wordCount = "word_count"
        case scriptDate = "script_date"
    }
}

// MARK: - Date Formatter Helper

private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()
}

#Preview {
    NavigationStack {
        ReelScriptsView()
            .environmentObject(AppState())
    }
}
