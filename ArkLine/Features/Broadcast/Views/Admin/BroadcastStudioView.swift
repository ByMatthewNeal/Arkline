import SwiftUI

// MARK: - Broadcast Studio View

/// Admin-only view for creating, editing, and publishing broadcasts.
/// This is the main dashboard for the Broadcast Studio feature.
struct BroadcastStudioView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = BroadcastViewModel()

    @State private var showingEditor = false
    @State private var selectedBroadcast: Broadcast?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.lg) {
                    // Header
                    headerSection

                    // Quick Stats
                    statsSection

                    // Drafts Section
                    if !viewModel.drafts.isEmpty {
                        broadcastSection(title: "Drafts", broadcasts: viewModel.drafts)
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
        HStack(spacing: ArkSpacing.md) {
            StatCard(
                title: "Drafts",
                value: "\(viewModel.drafts.count)",
                icon: "doc",
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

    // MARK: - Broadcast Section

    private func broadcastSection(title: String, broadcasts: [Broadcast]) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text(title)
                .font(ArkFonts.subheadline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            ForEach(broadcasts) { broadcast in
                BroadcastRowView(
                    broadcast: broadcast,
                    onTap: {
                        selectedBroadcast = broadcast
                        showingEditor = true
                    },
                    onPublish: broadcast.status == .draft ? {
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
    @State private var targetAudience: TargetAudience = .all
    @State private var showingVoiceRecorder = false
    @State private var showingImageAnnotation = false
    @State private var showingAppReferencePicker = false
    @State private var showingAudiencePicker = false
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

                    // Image Annotation Section
                    imageAnnotationSection

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
                    targetAudience = broadcast.targetAudience
                }
            }
            .sheet(isPresented: $showingVoiceRecorder) {
                VoiceRecorderView(audioURL: $audioURL, transcribedText: $content)
            }
            .sheet(isPresented: $showingAppReferencePicker) {
                AppReferencePickerView(selectedReferences: $appReferences)
            }
            .sheet(isPresented: $showingImageAnnotation) {
                ImageAnnotationView(images: $images)
            }
            .sheet(isPresented: $showingAudiencePicker) {
                AudiencePickerView(targetAudience: $targetAudience)
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
            AsyncImage(url: image.imageURL) { phase in
                switch phase {
                case .success(let loadedImage):
                    loadedImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(AppColors.textTertiary)
                case .empty:
                    ProgressView()
                @unknown default:
                    EmptyView()
                }
            }
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

    private func comingSoonSection(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppColors.accent)

            Text(title)
                .font(ArkFonts.body)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Spacer()

            Text("Coming Soon")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, ArkSpacing.sm)
                .padding(.vertical, ArkSpacing.xxs)
                .background(AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.xs)
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme).opacity(0.5))
        .cornerRadius(ArkSpacing.sm)
    }

    private func saveBroadcast(publish: Bool = false) {
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
                    updated.targetAudience = targetAudience

                    if publish && updated.status != .published {
                        updated.status = .published
                        updated.publishedAt = Date()
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
                    let newBroadcast = Broadcast(
                        title: title,
                        content: content,
                        audioURL: audioURL,
                        images: images,
                        appReferences: appReferences,
                        targetAudience: targetAudience,
                        status: publish ? .published : .draft,
                        publishedAt: publish ? Date() : nil,
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
