import SwiftUI
import Kingfisher

// MARK: - Broadcast Studio View

/// Admin-only view for creating, editing, and publishing broadcasts.
/// This is the main dashboard for the Broadcast Studio feature.
struct BroadcastStudioView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = BroadcastViewModel()

    @State private var showingEditor = false
    @State private var showingAnalytics = false
    @State private var selectedBroadcast: Broadcast?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Header
                    headerSection

                    // Quick Stats
                    statsSection

                    // Scheduled Section
                    if !scheduledBroadcasts.isEmpty {
                        broadcastSection(title: "Scheduled", broadcasts: scheduledBroadcasts, icon: "clock.fill", color: AppColors.warning)
                    }

                    // Drafts Section
                    if !viewModel.drafts.isEmpty {
                        broadcastSection(title: "Drafts", broadcasts: viewModel.drafts.filter { $0.status != .scheduled })
                    }

                    // Published Section
                    if !viewModel.published.isEmpty {
                        broadcastSection(title: "Published", broadcasts: viewModel.published)
                    }

                    // Empty State
                    if viewModel.drafts.isEmpty && viewModel.published.isEmpty && !viewModel.isLoading {
                        emptyStateView
                    }
                }
                .padding(.horizontal, ArkSpacing.md)
                .padding(.bottom, 100)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Broadcast Studio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAnalytics = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(AppColors.accent)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        selectedBroadcast = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            .refreshable {
                await viewModel.loadBroadcasts()
            }
            .sheet(isPresented: $showingEditor) {
                BroadcastEditorView(broadcast: selectedBroadcast, viewModel: viewModel)
            }
            .sheet(isPresented: $showingAnalytics) {
                BroadcastAnalyticsView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadBroadcasts()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Welcome, \(appState.currentUser?.firstName ?? "Admin")")
                .font(ArkFonts.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Create and publish market insights to your users")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, ArkSpacing.md)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: ArkSpacing.sm) {
            StatCard(
                title: "Drafts",
                value: "\(viewModel.drafts.filter { $0.status != .scheduled }.count)",
                icon: "doc",
                color: AppColors.textSecondary
            )

            StatCard(
                title: "Scheduled",
                value: "\(scheduledBroadcasts.count)",
                icon: "clock",
                color: AppColors.warning
            )

            StatCard(
                title: "Published",
                value: "\(viewModel.published.count)",
                icon: "checkmark.circle",
                color: AppColors.success
            )
        }
    }

    // MARK: - Computed Properties

    private var scheduledBroadcasts: [Broadcast] {
        viewModel.drafts.filter { $0.status == .scheduled }
            .sorted { ($0.scheduledAt ?? .distantPast) < ($1.scheduledAt ?? .distantPast) }
    }

    // MARK: - Broadcast Section

    private func broadcastSection(
        title: String,
        broadcasts: [Broadcast],
        icon: String? = nil,
        color: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack(spacing: ArkSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(color ?? AppColors.textSecondary)
                }
                Text(title)
                    .font(ArkFonts.subheadline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("\(broadcasts.count)")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textTertiary)
            }

            ForEach(broadcasts) { broadcast in
                BroadcastRowView(
                    broadcast: broadcast,
                    onTap: {
                        selectedBroadcast = broadcast
                        showingEditor = true
                    },
                    onPublish: broadcast.status == .draft || broadcast.status == .scheduled ? {
                        Task {
                            try? await viewModel.publishBroadcast(broadcast)
                        }
                    } : nil,
                    onDelete: {
                        Task {
                            try? await viewModel.deleteBroadcast(broadcast)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: ArkSpacing.md) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)

            Text("No Broadcasts Yet")
                .font(ArkFonts.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Tap the + button to create your first broadcast")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showingEditor = true
            } label: {
                Text("Create Broadcast")
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, ArkSpacing.lg)
                    .padding(.vertical, ArkSpacing.sm)
                    .background(AppColors.accent)
                    .cornerRadius(ArkSpacing.sm)
            }
        }
        .padding(.vertical, ArkSpacing.xxl)
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(value)
                .font(ArkFonts.title2)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }
}

// MARK: - Broadcast Row View

private struct BroadcastRowView: View {
    let broadcast: Broadcast
    let onTap: () -> Void
    var onPublish: (() -> Void)?
    var onDelete: (() -> Void)?
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: ArkSpacing.md) {
                // Status indicator
                Circle()
                    .fill(broadcast.status.color)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                    Text(broadcast.title.isEmpty ? "Untitled" : broadcast.title)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .lineLimit(1)

                    HStack(spacing: ArkSpacing.xs) {
                        if broadcast.status == .published, let publishedAt = broadcast.publishedAt {
                            Text(publishedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text("•")
                                .foregroundColor(AppColors.textTertiary)
                            Text("Published")
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.success)
                        } else if broadcast.status == .scheduled, let scheduledAt = broadcast.scheduledAt {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.warning)
                            Text(scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.warning)
                        } else {
                            Text(broadcast.timeAgo)
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                            if broadcast.status == .draft {
                                Text("•")
                                    .foregroundColor(AppColors.textTertiary)
                                Text("Draft")
                                    .font(ArkFonts.caption)
                                    .foregroundColor(AppColors.warning)
                            }
                        }
                    }

                    // Tags
                    if !broadcast.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(broadcast.tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(AppColors.textTertiary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(AppColors.cardBackground(colorScheme).opacity(0.5))
                                    .cornerRadius(3)
                            }
                            if broadcast.tags.count > 2 {
                                Text("+\(broadcast.tags.count - 2)")
                                    .font(.system(size: 9))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                    }
                }

                Spacer()

                // Media indicators
                HStack(spacing: ArkSpacing.xs) {
                    if broadcast.audioURL != nil {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    if !broadcast.images.isEmpty {
                        Image(systemName: "photo")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    if broadcast.portfolioAttachment != nil {
                        Image(systemName: "square.split.2x1")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    if !broadcast.appReferences.isEmpty {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.sm)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onPublish = onPublish {
                Button {
                    onPublish()
                } label: {
                    Label("Publish", systemImage: "paperplane.fill")
                }
            }

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Broadcast Editor View

/// Full-featured editor for creating and editing broadcasts.
struct BroadcastEditorView: View {
    let broadcast: Broadcast?
    @ObservedObject var viewModel: BroadcastViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var audioURL: URL?
    @State private var images: [BroadcastImage] = []
    @State private var appReferences: [AppReference] = []
    @State private var portfolioAttachment: BroadcastPortfolioAttachment?
    @State private var targetAudience: TargetAudience = .all
    @State private var selectedTags: [String] = []
    @State private var isScheduled = false
    @State private var scheduledDate = Date().addingTimeInterval(3600)
    @State private var showingVoiceRecorder = false
    @State private var showingImageAnnotation = false
    @State private var showingAppReferencePicker = false
    @State private var showingPortfolioPicker = false
    @State private var showingAudiencePicker = false
    @State private var showingTemplatePicker = false
    @State private var showingError = false
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Title Field
                    VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                        Text("Title")
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)

                        TextField("Enter broadcast title", text: $title)
                            .font(ArkFonts.body)
                            .padding(ArkSpacing.md)
                            .background(AppColors.cardBackground(colorScheme))
                            .cornerRadius(ArkSpacing.sm)
                    }

                    // Voice Recording Section
                    voiceRecordingSection

                    // Content Field
                    VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                        Text("Content")
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)

                        TextEditor(text: $content)
                            .font(ArkFonts.body)
                            .frame(minHeight: 200)
                            .padding(ArkSpacing.sm)
                            .scrollContentBackground(.hidden)
                            .background(AppColors.cardBackground(colorScheme))
                            .cornerRadius(ArkSpacing.sm)
                    }

                    // App References Section
                    appReferencesSection

                    // Portfolio Showcase Section
                    portfolioShowcaseSection

                    // Image Annotation Section
                    imageAnnotationSection

                    // Tags Section
                    tagsSection

                    // Scheduling Section
                    schedulingSection

                    // Target Audience Section
                    targetAudienceSection
                }
                .padding(ArkSpacing.md)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle(broadcast == nil ? "New Broadcast" : "Edit Broadcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    if broadcast == nil {
                        Button {
                            showingTemplatePicker = true
                        } label: {
                            Label("Templates", systemImage: "doc.text")
                                .font(.caption)
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Menu {
                            Button {
                                saveBroadcast(publish: false)
                            } label: {
                                Label("Save as Draft", systemImage: "doc")
                            }

                            if isScheduled {
                                Button {
                                    saveBroadcast(publish: false, schedule: true)
                                } label: {
                                    Label("Schedule", systemImage: "clock")
                                }
                            }

                            Button {
                                saveBroadcast(publish: true)
                            } label: {
                                Label("Publish Now", systemImage: "paperplane.fill")
                            }
                        } label: {
                            Text(broadcast?.status == .published ? "Update" : "Save")
                                .fontWeight(.semibold)
                        }
                        .disabled(title.isEmpty)
                    }
                }
            }
            .onAppear {
                if let broadcast {
                    title = broadcast.title
                    content = broadcast.content
                    audioURL = broadcast.audioURL
                    images = broadcast.images
                    appReferences = broadcast.appReferences
                    portfolioAttachment = broadcast.portfolioAttachment
                    targetAudience = broadcast.targetAudience
                    selectedTags = broadcast.tags
                    if let scheduled = broadcast.scheduledAt {
                        isScheduled = true
                        scheduledDate = scheduled
                    }
                }
            }
            .sheet(isPresented: $showingVoiceRecorder) {
                VoiceRecorderView(audioURL: $audioURL, transcribedText: $content)
            }
            .sheet(isPresented: $showingAppReferencePicker) {
                AppReferencePickerView(selectedReferences: $appReferences)
            }
            .sheet(isPresented: $showingPortfolioPicker) {
                BroadcastPortfolioPicker(attachment: $portfolioAttachment)
            }
            .sheet(isPresented: $showingImageAnnotation) {
                ImageAnnotationView(images: $images)
            }
            .sheet(isPresented: $showingAudiencePicker) {
                AudiencePickerView(targetAudience: $targetAudience)
            }
            .sheet(isPresented: $showingTemplatePicker) {
                TemplatePickerView { template in
                    applyTemplate(template)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Voice Recording Section

    private var voiceRecordingSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Voice Note")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            if let audioURL = audioURL {
                // Audio recorded - show player preview
                HStack(spacing: ArkSpacing.md) {
                    Image(systemName: "waveform")
                        .font(.title2)
                        .foregroundColor(AppColors.accent)

                    VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                        Text("Voice note recorded")
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Text(audioURL.lastPathComponent)
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Re-record button
                    Button {
                        showingVoiceRecorder = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.body)
                            .foregroundColor(AppColors.accent)
                    }

                    // Delete button
                    Button {
                        self.audioURL = nil
                    } label: {
                        Image(systemName: "trash")
                            .font(.body)
                            .foregroundColor(AppColors.error)
                    }
                }
                .padding(ArkSpacing.md)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.sm)
            } else {
                // No audio - show record button
                Button {
                    showingVoiceRecorder = true
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(AppColors.accent)

                        Text("Record Voice Note")
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(ArkSpacing.md)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - App References Section

    private var appReferencesSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("App References")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            if appReferences.isEmpty {
                // No references - show add button
                Button {
                    showingAppReferencePicker = true
                } label: {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(AppColors.accent)

                        Text("Link App Sections")
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(ArkSpacing.md)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)
                }
                .buttonStyle(.plain)
            } else {
                // Show selected references
                VStack(spacing: ArkSpacing.xs) {
                    ForEach(appReferences) { reference in
                        HStack(spacing: ArkSpacing.sm) {
                            Image(systemName: reference.section.iconName)
                                .font(.body)
                                .foregroundColor(AppColors.accent)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(reference.section.displayName)
                                    .font(ArkFonts.body)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))

                                if let note = reference.note, !note.isEmpty {
                                    Text(note)
                                        .font(ArkFonts.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()

                            Button {
                                appReferences.removeAll { $0.id == reference.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(ArkSpacing.sm)
                        .background(AppColors.cardBackground(colorScheme))
                        .cornerRadius(ArkSpacing.xs)
                    }

                    // Add more button
                    Button {
                        showingAppReferencePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                                .font(.caption)
                            Text("Add More")
                                .font(ArkFonts.caption)
                        }
                        .foregroundColor(AppColors.accent)
                        .padding(.vertical, ArkSpacing.xs)
                    }
                }
            }
        }
    }

    // MARK: - Portfolio Showcase Section

    private var portfolioShowcaseSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Portfolio Showcase")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            if let attachment = portfolioAttachment, attachment.hasContent {
                // Show attached portfolio(s)
                VStack(spacing: ArkSpacing.sm) {
                    HStack(spacing: ArkSpacing.md) {
                        Image(systemName: "square.split.2x1.fill")
                            .font(.title2)
                            .foregroundColor(AppColors.accent)

                        VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                            if attachment.isComparison {
                                Text("Portfolio Comparison")
                                    .font(ArkFonts.body)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                HStack(spacing: ArkSpacing.xs) {
                                    Text(attachment.leftSnapshot?.portfolioName ?? "")
                                        .font(ArkFonts.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    Text("vs")
                                        .font(ArkFonts.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                    Text(attachment.rightSnapshot?.portfolioName ?? "")
                                        .font(ArkFonts.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            } else {
                                Text(attachment.leftSnapshot?.portfolioName ?? attachment.rightSnapshot?.portfolioName ?? "Portfolio")
                                    .font(ArkFonts.body)
                                    .foregroundColor(AppColors.textPrimary(colorScheme))
                                Text("Single portfolio showcase")
                                    .font(ArkFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }

                        Spacer()

                        // Edit button
                        Button {
                            showingPortfolioPicker = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(AppColors.accent)
                        }
                        .buttonStyle(.plain)

                        // Remove button
                        Button {
                            portfolioAttachment = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Privacy badge
                    HStack {
                        Image(systemName: attachment.privacyLevel.icon)
                            .font(.caption)
                        Text(attachment.privacyLevel.displayName)
                            .font(ArkFonts.caption)
                    }
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, ArkSpacing.sm)
                    .padding(.vertical, ArkSpacing.xxs)
                    .background(AppColors.accent.opacity(0.1))
                    .cornerRadius(ArkSpacing.xs)
                }
                .padding(ArkSpacing.md)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.sm)
            } else {
                // No portfolio - show add button
                Button {
                    showingPortfolioPicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.split.2x1")
                            .foregroundColor(AppColors.accent)

                        Text("Attach Portfolio Showcase")
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(ArkSpacing.md)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Image Annotation Section

    private var imageAnnotationSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Annotated Images")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            if images.isEmpty {
                // No images - show add button
                Button {
                    showingImageAnnotation = true
                } label: {
                    HStack {
                        Image(systemName: "scribble")
                            .foregroundColor(AppColors.accent)

                        Text("Add Annotated Image")
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(ArkSpacing.md)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)
                }
                .buttonStyle(.plain)
            } else {
                // Show image thumbnails
                VStack(spacing: ArkSpacing.sm) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ArkSpacing.sm) {
                            ForEach(images) { image in
                                imagePreviewThumbnail(image)
                            }

                            // Add more button
                            Button {
                                showingImageAnnotation = true
                            } label: {
                                VStack {
                                    Image(systemName: "plus")
                                        .font(.title2)
                                        .foregroundColor(AppColors.accent)
                                }
                                .frame(width: 80, height: 80)
                                .background(AppColors.cardBackground(colorScheme))
                                .cornerRadius(ArkSpacing.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("\(images.count) image\(images.count == 1 ? "" : "s") attached")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func imagePreviewThumbnail(_ image: BroadcastImage) -> some View {
        ZStack(alignment: .topTrailing) {
            KFImage(image.imageURL)
                .resizable()
                .placeholder {
                    ProgressView()
                }
                .fade(duration: 0.2)
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.sm)
            .clipped()

            // Annotation indicator
            if !image.annotations.isEmpty {
                Image(systemName: "scribble")
                    .font(.caption2)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(AppColors.accent)
                    .clipShape(Circle())
                    .offset(x: -4, y: 4)
            }

            // Delete button
            Button {
                images.removeAll { $0.id == image.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
    }

    // MARK: - Target Audience Section

    private var targetAudienceSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Target Audience")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            Button {
                showingAudiencePicker = true
            } label: {
                HStack(spacing: ArkSpacing.md) {
                    Image(systemName: audienceIcon)
                        .font(.title3)
                        .foregroundColor(audienceColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(targetAudience.displayName)
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Text(audienceDescription)
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                .padding(ArkSpacing.md)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.sm)
            }
            .buttonStyle(.plain)
        }
    }

    private var audienceIcon: String {
        switch targetAudience {
        case .all: return "person.3.fill"
        case .premium: return "star.fill"
        case .specific: return "person.crop.circle.badge.checkmark"
        }
    }

    private var audienceColor: Color {
        switch targetAudience {
        case .all: return AppColors.accent
        case .premium: return AppColors.warning
        case .specific: return AppColors.success
        }
    }

    private var audienceDescription: String {
        switch targetAudience {
        case .all: return "Everyone will receive this broadcast"
        case .premium: return "Only premium subscribers"
        case .specific(let ids): return "\(ids.count) selected user\(ids.count == 1 ? "" : "s")"
        }
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Tags")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            // Selected tags
            if !selectedTags.isEmpty {
                FlowLayout(spacing: ArkSpacing.xs) {
                    ForEach(selectedTags, id: \.self) { tag in
                        tagChip(tag, isSelected: true) {
                            selectedTags.removeAll { $0 == tag }
                        }
                    }
                }
            }

            // Available tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArkSpacing.xs) {
                    ForEach(BroadcastTag.allCases, id: \.rawValue) { tag in
                        if !selectedTags.contains(tag.rawValue) {
                            tagChip(tag.rawValue, isSelected: false, color: tag.color) {
                                selectedTags.append(tag.rawValue)
                            }
                        }
                    }
                }
            }
        }
    }

    private func tagChip(_ tag: String, isSelected: Bool, color: Color = AppColors.accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(tag)
                    .font(.system(size: 12, weight: .medium))
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                }
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, ArkSpacing.sm)
            .padding(.vertical, ArkSpacing.xxs)
            .background(isSelected ? color : color.opacity(0.15))
            .cornerRadius(ArkSpacing.xs)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scheduling Section

    private var schedulingSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack {
                Text("Schedule")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Toggle("", isOn: $isScheduled)
                    .labelsHidden()
            }

            if isScheduled {
                VStack(spacing: ArkSpacing.sm) {
                    DatePicker(
                        "Publish Date",
                        selection: $scheduledDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .padding(ArkSpacing.sm)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)

                    // Schedule preview
                    HStack(spacing: ArkSpacing.sm) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(AppColors.warning)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Will be published")
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text(scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                .font(ArkFonts.bodySemibold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                        }

                        Spacer()
                    }
                    .padding(ArkSpacing.md)
                    .background(AppColors.warning.opacity(0.1))
                    .cornerRadius(ArkSpacing.sm)
                }
            }
        }
    }

    // MARK: - Template Actions

    private func applyTemplate(_ template: BroadcastTemplate) {
        title = template.titleTemplate
        content = template.contentTemplate
        selectedTags = template.defaultTags
    }

    private func saveBroadcast(publish: Bool = false, schedule: Bool = false) {
        guard let userId = appState.currentUser?.id else { return }

        isSaving = true

        Task {
            do {
                if let existing = broadcast {
                    var updated = existing
                    updated.title = title
                    updated.content = content
                    updated.audioURL = audioURL
                    updated.images = images
                    updated.appReferences = appReferences
                    updated.portfolioAttachment = portfolioAttachment
                    updated.targetAudience = targetAudience
                    updated.tags = selectedTags

                    if schedule && isScheduled {
                        updated.status = .scheduled
                        updated.scheduledAt = scheduledDate
                    } else if publish && updated.status != .published {
                        updated.status = .published
                        updated.publishedAt = Date()
                        updated.scheduledAt = nil
                    }

                    try await viewModel.updateBroadcast(updated)

                    // Send notification if publishing
                    if publish && updated.status == .published {
                        await BroadcastNotificationService.shared.sendBroadcastNotification(
                            for: updated,
                            audience: targetAudience
                        )
                    }
                } else {
                    var status: BroadcastStatus = .draft
                    var publishedAt: Date? = nil
                    var scheduledAt: Date? = nil

                    if schedule && isScheduled {
                        status = .scheduled
                        scheduledAt = scheduledDate
                    } else if publish {
                        status = .published
                        publishedAt = Date()
                    }

                    let newBroadcast = Broadcast(
                        title: title,
                        content: content,
                        audioURL: audioURL,
                        images: images,
                        appReferences: appReferences,
                        portfolioAttachment: portfolioAttachment,
                        targetAudience: targetAudience,
                        status: status,
                        publishedAt: publishedAt,
                        scheduledAt: scheduledAt,
                        tags: selectedTags,
                        authorId: userId
                    )
                    try await viewModel.createBroadcast(newBroadcast)

                    // Send notification if publishing immediately
                    if publish {
                        await BroadcastNotificationService.shared.sendBroadcastNotification(
                            for: newBroadcast,
                            audience: targetAudience
                        )
                    }
                }

                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
                showingError = true
                logError("Failed to save broadcast: \(error)", category: .data)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BroadcastStudioView()
        .environmentObject(AppState())
}
