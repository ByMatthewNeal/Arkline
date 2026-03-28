import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct MarketDeckAdminView: View {
    @State private var viewModel = MarketDeckViewModel()
    @State private var showViewer = false
    @State private var selectedSlideType: DeckSlide.SlideType?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPDFImporter = false
    @State private var urlInput = ""
    @State private var showURLInput = false
    @State private var customWeekStart: Date = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
    @State private var useCustomWeek = false
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
                        insightsSection
                        slidesSection(deck)
                        actionsSection(deck)
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
            // Load both draft and latest published, show whichever is more recent
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
                generateWithParams()
            }) {
                HStack(spacing: ArkSpacing.xs) {
                    if viewModel.isGenerating {
                        ProgressView()
                            .tint(.white)
                            .controlSize(.small)
                        Text("Generating...")
                    } else {
                        Image(systemName: "wand.and.stars")
                        Text("Generate Next Week's Deck")
                    }
                }
                .font(AppFonts.body14Medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.sm)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.success))
            }
            .disabled(viewModel.isGenerating)
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

            Text("Add external context, data, or observations here. This will be woven into the narrative when you regenerate.")
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)

            TextField("Share additional market context, external data, screenshots insights...",
                      text: Binding(
                        get: { viewModel.adminInsights },
                        set: { viewModel.updateInsights($0) }
                      ),
                      axis: .vertical)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineLimit(4...12)
                .padding(ArkSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.textPrimary(colorScheme).opacity(0.05))
                )

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
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    await viewModel.addImage(data)
                }
                selectedPhoto = nil
            }
        }
        .fileImporter(isPresented: $showPDFImporter, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result {
                Task { await viewModel.addPDF(from: url) }
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
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
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

    // MARK: - Slides Section

    private func slidesSection(_ deck: MarketUpdateDeck) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack {
                Image(systemName: "rectangle.stack")
                    .foregroundColor(AppColors.accent)
                Text("Slides")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            ForEach(deck.slides) { slide in
                slideRow(slide)
            }
        }
        .padding(ArkSpacing.md)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground(colorScheme)))
    }

    private func slideRow(_ slide: DeckSlide) -> some View {
        let isExpanded = selectedSlideType == slide.type

        return VStack(alignment: .leading, spacing: 0) {
            // Slide header row
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedSlideType = isExpanded ? nil : slide.type
                }
            }) {
                HStack(spacing: ArkSpacing.sm) {
                    Image(systemName: slide.type.icon)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)
                        .frame(width: 24)

                    Text(slide.title)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, ArkSpacing.sm)
            }

            // Expanded data preview
            if isExpanded {
                VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                    slideDataPreview(slide)
                }
                .padding(.bottom, ArkSpacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if slide.type != .rundown {
                Divider().opacity(0.2)
            }
        }
    }

    @ViewBuilder
    private func slideDataPreview(_ slide: DeckSlide) -> some View {
        switch slide.data {
        case .cover(let data):
            HStack(spacing: ArkSpacing.md) {
                miniStat("Regime", data.regime)
                if let change = data.btcWeeklyChange {
                    miniStat("BTC", String(format: "%+.1f%%", change))
                }
                if let fg = data.fearGreedEnd {
                    miniStat("F&G", "\(fg)")
                }
            }
        case .marketPulse(let data):
            Text("\(data.assets.count) assets tracked")
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
        case .macro(let data):
            HStack(spacing: ArkSpacing.md) {
                if let vix = data.vixValue {
                    miniStat("VIX", String(format: "%.1f", vix))
                }
                if let dxy = data.dxyValue {
                    miniStat("DXY", String(format: "%.1f", dxy))
                }
            }
        case .positioning(let data):
            Text("\(data.signalChanges.count) signal changes this week")
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
        case .economic(let data):
            Text("\(data.thisWeek.count) events this week, \(data.nextWeek.count) upcoming")
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
        case .setups(let data):
            HStack(spacing: ArkSpacing.md) {
                miniStat("Triggered", "\(data.signalsTriggered)")
                miniStat("Resolved", "\(data.signalsResolved)")
                if let wr = data.winRate {
                    miniStat("WR", String(format: "%.0f%%", wr))
                }
            }
        case .rundown(let data):
            Text(data.narrative.prefix(100) + (data.narrative.count > 100 ? "..." : ""))
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
        case .sectionTitle(let data):
            Text(data.subtitle ?? "Section divider")
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
        case .editorial(let data):
            Text("\(data.bullets.count) bullet points — \(data.category ?? "analysis")")
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
        case .snapshot(let data):
            HStack(spacing: ArkSpacing.md) {
                miniStat("Risks", "\(data.assetRisks.count)")
                if let fg = data.fearGreedEnd {
                    miniStat("F&G", "\(fg)")
                }
                if let regime = data.sentimentRegime {
                    miniStat("Regime", regime)
                }
            }
        case .weeklyOutlook(let data):
            Text(data.headline)
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
        case .correlation(let data):
            HStack(spacing: ArkSpacing.md) {
                miniStat("Groups", "\(data.groups.count)")
                miniStat("Assets", "\(data.groups.flatMap(\.assets).count)")
            }
        }
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppColors.textSecondary)
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

    private var customWeekRange: (start: String, end: String) {
        let cal = Calendar(identifier: .gregorian)
        let weekday = cal.component(.weekday, from: customWeekStart)
        let daysToMonday = (weekday == 1) ? -6 : (2 - weekday)
        let monday = cal.date(byAdding: .day, value: daysToMonday, to: customWeekStart) ?? Date()
        let friday = cal.date(byAdding: .day, value: 4, to: monday) ?? Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return (fmt.string(from: monday), fmt.string(from: friday))
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

            // Generate new deck
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
                        Image(systemName: "wand.and.stars")
                        Text("Generate New Deck")
                    }
                }
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.sm)
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.cardBackground(colorScheme)))
                .animation(.easeInOut, value: viewModel.generationStep?.rawValue)
            }
            .disabled(viewModel.isGenerating)

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
                    Text("Custom Week")
                        .font(AppFonts.body14Medium)
                }
                .foregroundColor(AppColors.textPrimary(colorScheme))
            }
            .tint(AppColors.accent)

            if useCustomWeek {
                DatePicker(
                    "Week of",
                    selection: $customWeekStart,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

                let range = customWeekRange
                Text("Mon \(range.start) — Fri \(range.end)")
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

                Button(action: {
                    generateWithParams()
                }) {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: "wand.and.stars")
                        Text("Generate Deck")
                    }
                    .font(AppFonts.body14Medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, ArkSpacing.lg)
                    .padding(.vertical, ArkSpacing.sm)
                    .background(Capsule().fill(AppColors.accent))
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
