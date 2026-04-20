import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MarketDeckAdminView: View {
    @State private var viewModel = MarketDeckViewModel()
    @State private var showViewer = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showPDFImporter = false
    @State private var urlInput = ""
    @State private var showURLInput = false
    @State private var customStart: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var customEnd: Date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var useCustomWeek = false
    @State private var pipelineInsights: String = ""
    @State private var showContextEditor = false
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    private var generationManager = DeckGenerationManager.shared

    var body: some View {
        ZStack {
            MeshGradientBackground()

            if viewModel.isGenerating && viewModel.deck == nil, let step = viewModel.generationStep {
                generationProgressView(step: step)
            } else if viewModel.isLoading && viewModel.deck == nil {
                ProgressView("Loading deck...")
                    .tint(AppColors.accent)
            } else if let deck = viewModel.deck {
                ScrollView {
                    VStack(spacing: ArkSpacing.md) {
                        deckHeader(deck)

                        // Show pipeline steps if a pipeline run exists
                        if generationManager.pipelineRun != nil {
                            pipelineStepsView
                        }

                        insightsSection
                        actionsSection(deck)
                    }
                    .padding(.horizontal, ArkSpacing.md)
                    .padding(.bottom, 120)
                }
            } else if generationManager.pipelineRun != nil {
                // Pipeline started but no deck yet
                ScrollView {
                    VStack(spacing: ArkSpacing.md) {
                        pipelineStepsView
                    }
                    .padding(.horizontal, ArkSpacing.md)
                    .padding(.bottom, 120)
                }
            } else {
                emptyState
            }
        }
        .navigationTitle("Weekly Market Deck")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: MarketDeckHistoryView(isAdmin: true, userId: appState.currentUser?.id)) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .task {
            viewModel.checkForCompletedGeneration()
            await generationManager.loadLatestPipelineRun()
            await viewModel.loadMostRecentDeck()
        }
        .onAppear {
            viewModel.checkForCompletedGeneration()
        }
        .onChange(of: generationManager.isGenerating) { _, isGenerating in
            if !isGenerating {
                viewModel.checkForCompletedGeneration()
            }
        }
        .onChange(of: generationManager.isRegenerating) { _, isRegenerating in
            if !isRegenerating {
                viewModel.checkForCompletedGeneration()
            }
        }
        .fullScreenCover(isPresented: $showViewer) {
            MarketDeckViewer(viewModel: viewModel, isAdmin: true, userId: appState.currentUser?.id)
        }
        .overlay(alignment: .bottom) {
            if viewModel.hasUnsavedChanges {
                unsavedChangesBar
            }
        }
        .overlay {
            toastOverlay
        }
    }

    // MARK: - Deck Header

    private func deckHeader(_ deck: MarketUpdateDeck) -> some View {
        VStack(spacing: ArkSpacing.sm) {
            // Show "Generate Next Week" prompt when current deck is already published
            if deck.status == .published {
                generateNextWeekCard(currentDeck: deck)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deck.weekLabel)
                        .font(AppFonts.number20)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("\(deck.slides.count) slides")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                statusBadge(deck.status)
            }

            Button(action: { showViewer = true }) {
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "eye")
                    Text(deck.status == .published ? "View Published Deck" : "Preview Full Deck")
                }
                .font(AppFonts.body14Medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.sm)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.accent))
            }
        }
        .padding(ArkSpacing.md)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground(colorScheme)))
    }

    private func generateNextWeekCard(currentDeck: MarketUpdateDeck) -> some View {
        VStack(spacing: ArkSpacing.sm) {
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: "sparkles")
                    .foregroundColor(AppColors.accent)
                Text("This deck has been published")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Spacer()
            }

            Text("Ready to create next week's update?")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: {
                startPipelineWithParams()
            }) {
                HStack(spacing: ArkSpacing.xs) {
                    if generationManager.isPipelineRunning {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.small)
                        Text("Starting Pipeline...")
                    } else {
                        Image(systemName: "wand.and.stars")
                        Text("Start Next Week's Pipeline")
                    }
                }
                .font(AppFonts.body14Medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.sm)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.success))
            }
            .disabled(generationManager.isPipelineRunning)
        }
        .padding(ArkSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.success.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.success.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Pipeline Steps View

    private var pipelineStepsView: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack {
                Image(systemName: "gearshape.2")
                    .foregroundColor(AppColors.accent)
                Text("Pipeline")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                if let run = generationManager.pipelineRun {
                    Text("\(Int(run.progress * 100))%")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                }
            }

            if let run = generationManager.pipelineRun {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.textPrimary(colorScheme).opacity(0.1))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.accent)
                            .frame(width: geo.size.width * run.progress, height: 4)
                            .animation(.easeInOut(duration: 0.4), value: run.progress)
                    }
                }
                .frame(height: 4)

                ForEach(PipelineStep.allCases) { step in
                    pipelineStepRow(step: step, run: run)
                }

                // Pipeline error banner
                if let error = generationManager.pipelineError {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text(error)
                            .font(AppFonts.caption12)
                            .lineLimit(3)
                    }
                    .foregroundColor(AppColors.error)
                    .padding(ArkSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.error.opacity(0.1))
                    )
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground(colorScheme)))
    }

    @ViewBuilder
    private func pipelineStepRow(step: PipelineStep, run: DeckPipelineRun) -> some View {
        let status = run.status(for: step)
        let error = run.error(for: step)
        let isActive = generationManager.pipelineStepInProgress == step

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: ArkSpacing.sm) {
                // Step number
                Text("[\(step.stepNumber)]")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 22)

                // Status icon
                pipelineStepIcon(status: status, isActive: isActive)

                // Step name
                Text(step.displayName)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                // Action buttons based on status
                if status == "failed", let _ = error {
                    Button(action: { generationManager.retryStep(step) }) {
                        Text("Retry")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, ArkSpacing.sm)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .stroke(AppColors.error.opacity(0.4), lineWidth: 1)
                            )
                    }
                }

                if step == .addContext && status != "completed" && run.isResearchComplete {
                    Button(action: { withAnimation { showContextEditor.toggle() } }) {
                        Text("Edit")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, ArkSpacing.sm)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .stroke(AppColors.accent.opacity(0.4), lineWidth: 1)
                            )
                    }
                }

                if step == .generateSlides && status == "pending" && run.isContextComplete {
                    Button(action: { generationManager.continuePipelineGeneration() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9))
                            Text("Run")
                        }
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, ArkSpacing.sm)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.accent))
                    }
                }
            }

            // Error detail
            if let error, status == "failed" {
                Text(error)
                    .font(AppFonts.footnote10)
                    .foregroundColor(AppColors.error)
                    .padding(.leading, 36)
                    .lineLimit(2)
            }

            // Context editor (step 3)
            if step == .addContext && showContextEditor && run.isResearchComplete {
                pipelineContextEditor
                    .padding(.leading, 36)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func pipelineStepIcon(status: String, isActive: Bool) -> some View {
        if isActive {
            ProgressView()
                .controlSize(.small)
                .tint(AppColors.accent)
                .frame(width: 18, height: 18)
        } else {
            switch status {
            case "completed":
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.success)
            case "failed":
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.error)
            case "running":
                ProgressView()
                    .controlSize(.small)
                    .tint(AppColors.accent)
                    .frame(width: 18, height: 18)
            default:
                Image(systemName: "circle")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary.opacity(0.4))
            }
        }
    }

    private var pipelineContextEditor: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text("Paste transcripts, external context, or observations.")
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)

            TextField("Add market context or insights...",
                      text: $pipelineInsights,
                      axis: .vertical)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineLimit(4...30)
                .padding(ArkSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.textPrimary(colorScheme).opacity(0.05))
                )

            HStack {
                let charCount = pipelineInsights.count
                Text("\(charCount.formatted()) characters")
                    .font(.system(size: 10))
                    .foregroundColor(charCount > 40000 ? AppColors.error : AppColors.textSecondary)

                Spacer()

                Button(action: {
                    Task {
                        await generationManager.savePipelineContext(insights: pipelineInsights)
                        withAnimation { showContextEditor = false }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11))
                        Text("Save Context")
                    }
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, ArkSpacing.sm)
                    .padding(.vertical, ArkSpacing.xs)
                    .background(Capsule().fill(AppColors.accent))
                }
                .disabled(pipelineInsights.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: - Admin Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(AppColors.accent)
                Text("Admin Insights")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Text("Paste transcripts, external context, data, or observations. This will be woven into the narrative when you regenerate.")
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)

            TextField("Paste transcript or share market context...",
                      text: Binding(
                        get: { viewModel.adminInsights },
                        set: { viewModel.updateInsights($0) }
                      ),
                      axis: .vertical)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineLimit(4...50)
                .padding(ArkSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.textPrimary(colorScheme).opacity(0.05))
                )

            // Character count + limit warning
            HStack {
                let charCount = viewModel.adminInsights.count
                let limit = 40000
                Text("\(charCount.formatted()) characters")
                    .font(.system(size: 10))
                    .foregroundColor(charCount > limit ? AppColors.error : AppColors.textSecondary)
                if charCount > limit {
                    Text("— will be truncated to \(limit.formatted())")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.warning)
                }
                Spacer()
            }

            // Attachments
            attachmentsBar

            // Attached items list
            if !viewModel.attachments.isEmpty {
                attachmentsList
            }

            Button(action: {
                Task { await viewModel.regenerateNarrative() }
            }) {
                HStack(spacing: ArkSpacing.xs) {
                    if viewModel.isRegenerating {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(viewModel.isRegenerating ? "Regenerating..." : "Regenerate Narrative with Insights")
                }
                .font(AppFonts.body14Medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.sm)
                .background(RoundedRectangle(cornerRadius: 10).fill(
                    (viewModel.adminInsights.isEmpty && viewModel.attachments.isEmpty) ? Color.gray.opacity(0.3) : AppColors.accent.opacity(0.8)
                ))
            }
            .disabled(viewModel.isRegenerating || (viewModel.adminInsights.isEmpty && viewModel.attachments.isEmpty))
        }
        .padding(ArkSpacing.md)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground(colorScheme)))
        .onChange(of: selectedPhotos) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        await viewModel.addImage(data)
                    }
                }
                selectedPhotos = []
            }
        }
        .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task {
                    for url in urls {
                        await viewModel.addPDF(from: url)
                    }
                }
            }
        }
    }

    // MARK: - Attachments

    private var attachmentsBar: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            Text("Attachments")
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: ArkSpacing.sm) {
                // Image picker
                PhotosPicker(selection: $selectedPhotos, matching: .images) {
                    Label("Image", systemImage: "photo")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, ArkSpacing.sm)
                        .padding(.vertical, ArkSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.accent.opacity(0.4), lineWidth: 1)
                        )
                }

                // PDF picker
                Button(action: { showPDFImporter = true }) {
                    Label("PDF", systemImage: "doc.fill")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, ArkSpacing.sm)
                        .padding(.vertical, ArkSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.accent.opacity(0.4), lineWidth: 1)
                        )
                }

                // URL input toggle
                Button(action: { withAnimation { showURLInput.toggle() } }) {
                    Label("URL", systemImage: "link")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, ArkSpacing.sm)
                        .padding(.vertical, ArkSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppColors.accent.opacity(0.4), lineWidth: 1)
                        )
                }

                if viewModel.isUploading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppColors.accent)
                }

                Spacer()
            }

            // URL input field
            if showURLInput {
                HStack(spacing: ArkSpacing.xs) {
                    TextField("https://...", text: $urlInput)
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(ArkSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppColors.textPrimary(colorScheme).opacity(0.05))
                        )

                    Button(action: {
                        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        viewModel.addURL(trimmed)
                        urlInput = ""
                        withAnimation { showURLInput = false }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.accent)
                    }
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var attachmentsList: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            ForEach(viewModel.attachments) { attachment in
                HStack(spacing: ArkSpacing.sm) {
                    Image(systemName: attachmentIcon(attachment.type))
                        .font(.system(size: 14))
                        .foregroundColor(attachmentColor(attachment.type))
                        .frame(width: 20)

                    Text(attachment.label ?? "Attachment")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .lineLimit(1)

                    Spacer()

                    if attachment.type == .pdf, let text = attachment.extractedText {
                        Text("\(text.count) chars")
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Button(action: { viewModel.removeAttachment(attachment) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, ArkSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.textPrimary(colorScheme).opacity(0.03))
                )
            }
        }
    }

    private func attachmentIcon(_ type: InsightAttachment.AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .pdf: return "doc.fill"
        case .url: return "link"
        }
    }

    private func attachmentColor(_ type: InsightAttachment.AttachmentType) -> Color {
        switch type {
        case .image: return .purple
        case .pdf: return .red
        case .url: return .blue
        }
    }

    // MARK: - Narrative Editor

    @State private var showPreviousNarrative = false

    private var narrativeSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(AppColors.accent)
                Text("The Rundown — Narrative")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            // Regeneration summary banner
            if let summary = viewModel.regenerationSummary {
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                    Text(summary)
                        .font(AppFonts.caption12)
                    Spacer()
                    Button(action: { viewModel.clearRegenerationState() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                    }
                }
                .foregroundColor(AppColors.accent)
                .padding(ArkSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.accent.opacity(0.1))
                )
            }

            // Show previous narrative toggle
            if viewModel.previousNarrative != nil {
                Button(action: { withAnimation { showPreviousNarrative.toggle() } }) {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: showPreviousNarrative ? "eye.slash" : "eye")
                            .font(.system(size: 11))
                        Text(showPreviousNarrative ? "Hide Previous" : "Show Previous Narrative")
                            .font(AppFonts.caption12Medium)
                    }
                    .foregroundColor(AppColors.textSecondary)
                }

                if showPreviousNarrative, let prev = viewModel.previousNarrative {
                    Text(prev)
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        .lineLimit(8...20)
                        .padding(ArkSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.textPrimary(colorScheme).opacity(0.03))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(AppColors.textSecondary.opacity(0.1), lineWidth: 1)
                                )
                        )
                }
            }

            Text("Direct edit the weekly recap narrative. Changes are saved when you tap Save.")
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)

            TextField("Weekly narrative...",
                      text: Binding(
                        get: { viewModel.editedNarrative },
                        set: { viewModel.updateNarrative($0) }
                      ),
                      axis: .vertical)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineLimit(8...30)
                .padding(ArkSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.textPrimary(colorScheme).opacity(0.05))
                )
        }
        .padding(ArkSpacing.md)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground(colorScheme)))
    }

    // MARK: - Custom Week Helpers

    /// Snaps a weekend date to the nearest weekday.
    /// Start dates snap to Monday (next weekday), End dates snap to Friday (previous weekday).
    private func snapToWeekday(_ date: Date, preferEarlier: Bool) -> Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)  // 1=Sun, 7=Sat
        if weekday == 1 {
            // Sunday -> Friday (back 2) or Monday (forward 1)
            return cal.date(byAdding: .day, value: preferEarlier ? -2 : 1, to: date) ?? date
        } else if weekday == 7 {
            // Saturday -> Friday (back 1) or Monday (forward 2)
            return cal.date(byAdding: .day, value: preferEarlier ? -1 : 2, to: date) ?? date
        }
        return date
    }

    private var customWeekRange: (start: String, end: String) {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return (fmt.string(from: customStart), fmt.string(from: customEnd))
    }

    private func startPipelineWithParams() {
        let range: (start: String, end: String)
        if useCustomWeek {
            range = customWeekRange
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let cal = Calendar.current
            let start = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let end = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            range = (fmt.string(from: start), fmt.string(from: end))
        }
        generationManager.runPipeline(weekStart: range.start, weekEnd: range.end)
    }

    private func generateWithParams() {
        if useCustomWeek {
            let range = customWeekRange
            viewModel.generate(weekStart: range.start, weekEnd: range.end)
        } else {
            viewModel.generate()
        }
    }

    // MARK: - Actions

    private func actionsSection(_ deck: MarketUpdateDeck) -> some View {
        VStack(spacing: ArkSpacing.sm) {
            // Custom week picker
            customWeekPicker

            // Pipeline button (primary path)
            Button(action: {
                startPipelineWithParams()
            }) {
                HStack(spacing: ArkSpacing.xs) {
                    if generationManager.isPipelineRunning {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.small)
                        Text("Pipeline Running...")
                    } else {
                        Image(systemName: "wand.and.stars")
                        Text("Start Pipeline")
                    }
                }
                .font(AppFonts.body14Medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.md)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.accent))
            }
            .disabled(generationManager.isPipelineRunning || viewModel.isGenerating)

            // Legacy generate button (fallback)
            Button(action: {
                generateWithParams()
            }) {
                HStack(spacing: ArkSpacing.xs) {
                    if viewModel.isGenerating {
                        ProgressView()
                            .tint(AppColors.textSecondary)
                            .controlSize(.small)
                        if let step = viewModel.generationStep {
                            Text(step.rawValue)
                        } else {
                            Text("Generating...")
                        }
                    } else {
                        Image(systemName: "bolt.fill")
                        Text("Generate (One-Shot)")
                    }
                }
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.textSecondary.opacity(0.3), lineWidth: 1)
                )
                .animation(.easeInOut, value: viewModel.generationStep?.rawValue)
            }
            .disabled(viewModel.isGenerating || generationManager.isPipelineRunning)

            // Publish
            if deck.status == .draft, let authorId = appState.currentUser?.id {
                Button(action: {
                    Task { await viewModel.publish(authorId: authorId) }
                }) {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "paperplane.fill")
                        Text("Publish to All Users")
                    }
                    .font(AppFonts.body14Medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ArkSpacing.sm)
                    .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.success))
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground(colorScheme)))
    }

    // MARK: - Custom Week Picker

    private var customWeekPicker: some View {
        VStack(spacing: ArkSpacing.xs) {
            Toggle(isOn: $useCustomWeek) {
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 14))
                    Text("Custom Range")
                        .font(AppFonts.body14Medium)
                }
                .foregroundColor(AppColors.textPrimary(colorScheme))
            }
            .tint(AppColors.accent)

            if useCustomWeek {
                DatePicker(
                    "Start",
                    selection: $customStart,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .onChange(of: customStart) { _, newValue in
                    customStart = snapToWeekday(newValue, preferEarlier: true)
                }

                DatePicker(
                    "End",
                    selection: $customEnd,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .onChange(of: customEnd) { _, newValue in
                    customEnd = snapToWeekday(newValue, preferEarlier: false)
                }

                let displayFmt: DateFormatter = {
                    let f = DateFormatter()
                    f.dateFormat = "MMM d, yyyy"
                    return f
                }()
                Text("\(displayFmt.string(from: customStart)) — \(displayFmt.string(from: customEnd))")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.accent)
            }
        }
        .padding(ArkSpacing.sm)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.textPrimary(colorScheme).opacity(0.05)))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: ArkSpacing.md) {
            if viewModel.isGenerating, let step = viewModel.generationStep {
                generationProgressView(step: step)
            } else {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.textSecondary)

                Text("No deck available")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textSecondary)

                customWeekPicker
                    .padding(.horizontal, ArkSpacing.lg)

                // Pipeline button (primary)
                Button(action: {
                    startPipelineWithParams()
                }) {
                    HStack(spacing: ArkSpacing.xs) {
                        if generationManager.isPipelineRunning {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.small)
                            Text("Starting Pipeline...")
                        } else {
                            Image(systemName: "wand.and.stars")
                            Text("Start Pipeline")
                        }
                    }
                    .font(AppFonts.body14Medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, ArkSpacing.lg)
                    .padding(.vertical, ArkSpacing.sm)
                    .background(Capsule().fill(AppColors.accent))
                }
                .disabled(generationManager.isPipelineRunning)

                // Legacy fallback
                Button(action: {
                    generateWithParams()
                }) {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "bolt.fill")
                        Text("Generate (One-Shot)")
                    }
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, ArkSpacing.lg)
                    .padding(.vertical, ArkSpacing.xs)
                }
            }
        }
    }

    // MARK: - Generation Progress

    private func generationProgressView(step: DeckGenerationManager.GenerationStep) -> some View {
        VStack(spacing: ArkSpacing.lg) {
            // Animated icon
            Image(systemName: step.icon)
                .font(.system(size: 40))
                .foregroundColor(AppColors.accent)
                .symbolEffect(.pulse, options: .repeating)

            Text(step.rawValue)
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .animation(.easeInOut, value: step)

            // Step dots
            HStack(spacing: ArkSpacing.sm) {
                ForEach(1...4, id: \.self) { i in
                    Circle()
                        .fill(i <= step.stepNumber ? AppColors.accent : AppColors.textSecondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: step.stepNumber)
                }
            }

            Text("Step \(step.stepNumber) of 4")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Unsaved Changes Bar

    private var unsavedChangesBar: some View {
        HStack(spacing: ArkSpacing.sm) {
            Circle()
                .fill(AppColors.warning)
                .frame(width: 8, height: 8)

            Text("Unsaved changes")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Spacer()

            Button(action: {
                Task { await viewModel.save() }
            }) {
                HStack(spacing: 4) {
                    if viewModel.isSaving {
                        ProgressView().tint(.white).controlSize(.mini)
                    }
                    Text(viewModel.isSaving ? "Saving..." : "Save")
                        .font(AppFonts.body14Medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, ArkSpacing.md)
                .padding(.vertical, ArkSpacing.xs)
                .background(Capsule().fill(AppColors.accent))
            }
            .disabled(viewModel.isSaving)
        }
        .padding(.horizontal, ArkSpacing.md)
        .padding(.vertical, ArkSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.cardBackground(colorScheme))
                .shadow(color: .black.opacity(0.3), radius: 8, y: -2)
        )
        .padding(.horizontal, ArkSpacing.md)
        .padding(.bottom, ArkSpacing.xs)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.25), value: viewModel.hasUnsavedChanges)
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let error = viewModel.errorMessage {
            toastView(message: error, color: AppColors.error)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        viewModel.errorMessage = nil
                    }
                }
        } else if let success = viewModel.successMessage {
            toastView(message: success, color: AppColors.success)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        viewModel.successMessage = nil
                    }
                }
        }
    }

    private func toastView(message: String, color: Color) -> some View {
        VStack {
            Text(message)
                .font(AppFonts.caption12Medium)
                .foregroundColor(.white)
                .padding(.horizontal, ArkSpacing.md)
                .padding(.vertical, ArkSpacing.sm)
                .background(Capsule().fill(color))
                .padding(.top, ArkSpacing.xl)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: viewModel.errorMessage)
    }

    // MARK: - Helpers

    private func statusBadge(_ status: MarketUpdateDeck.DeckStatus) -> some View {
        Text(status.rawValue.capitalized)
            .font(AppFonts.caption12Medium)
            .foregroundColor(.white)
            .padding(.horizontal, ArkSpacing.xs)
            .padding(.vertical, 2)
            .background(Capsule().fill(statusColor(status)))
    }

    private func statusColor(_ status: MarketUpdateDeck.DeckStatus) -> Color {
        switch status {
        case .draft: return AppColors.warning
        case .published: return AppColors.success
        case .archived: return AppColors.textSecondary
        }
    }
}
