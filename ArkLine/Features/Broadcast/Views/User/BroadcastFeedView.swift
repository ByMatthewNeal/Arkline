import SwiftUI

// MARK: - Broadcast Feed View

/// User-facing view showing published broadcasts from the admin.
struct BroadcastFeedView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = BroadcastViewModel()
    @StateObject private var notificationService = BroadcastNotificationService.shared

    @State private var selectedBroadcast: Broadcast?
    @State private var showNotificationPrompt = false
    @State private var hasCheckedNotifications = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ArkSpacing.md) {
                    // Notification prompt banner
                    if showNotificationPrompt {
                        notificationPromptBanner
                    }

                    if viewModel.isLoading && viewModel.published.isEmpty {
                        loadingView
                    } else if viewModel.published.isEmpty {
                        emptyStateView
                    } else {
                        broadcastList
                    }
                }
                .padding(.horizontal, ArkSpacing.md)
                .padding(.bottom, 100)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadBroadcasts()
            }
            .sheet(item: $selectedBroadcast) { broadcast in
                BroadcastDetailView(broadcast: broadcast, viewModel: viewModel)
            }
            .task {
                await viewModel.loadBroadcasts()
                await checkNotificationStatus()
            }
        }
    }

    // MARK: - Notification Prompt Banner

    private var notificationPromptBanner: some View {
        VStack(spacing: ArkSpacing.sm) {
            HStack(spacing: ArkSpacing.sm) {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Stay Updated")
                        .font(ArkFonts.bodySemibold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Get notified when new insights are published")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation {
                        showNotificationPrompt = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            HStack(spacing: ArkSpacing.sm) {
                Button {
                    Task {
                        let granted = await notificationService.requestPermission()
                        withAnimation {
                            showNotificationPrompt = false
                        }
                        if granted {
                            // Mark that user enabled notifications
                            UserDefaults.standard.set(true, forKey: "arkline_notifications_prompted")
                        }
                    }
                } label: {
                    Text("Enable Notifications")
                        .font(ArkFonts.bodySemibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ArkSpacing.sm)
                        .background(AppColors.accent)
                        .cornerRadius(ArkSpacing.sm)
                }

                Button {
                    withAnimation {
                        showNotificationPrompt = false
                    }
                    UserDefaults.standard.set(true, forKey: "arkline_notifications_prompted")
                } label: {
                    Text("Not Now")
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ArkSpacing.sm)
                        .background(AppColors.cardBackground(colorScheme))
                        .cornerRadius(ArkSpacing.sm)
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.md)
        .padding(.top, ArkSpacing.sm)
    }

    // MARK: - Check Notification Status

    private func checkNotificationStatus() async {
        guard !hasCheckedNotifications else { return }
        hasCheckedNotifications = true

        // Check if we've already prompted
        let alreadyPrompted = UserDefaults.standard.bool(forKey: "arkline_notifications_prompted")
        guard !alreadyPrompted else { return }

        // Check current status
        await notificationService.checkNotificationStatus()

        // Show prompt if not determined
        if notificationService.notificationStatus == .notDetermined {
            withAnimation {
                showNotificationPrompt = true
            }
        }
    }

    // MARK: - Broadcast List

    private var broadcastList: some View {
        LazyVStack(spacing: ArkSpacing.md) {
            ForEach(viewModel.published) { broadcast in
                BroadcastCardView(broadcast: broadcast) {
                    selectedBroadcast = broadcast
                }
            }
        }
        .padding(.top, ArkSpacing.sm)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: ArkSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: ArkSpacing.sm)
                    .fill(AppColors.cardBackground(colorScheme))
                    .frame(height: 120)
                    .shimmer(isLoading: true)
            }
        }
        .padding(.top, ArkSpacing.sm)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: ArkSpacing.md) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 56))
                .foregroundColor(AppColors.textTertiary)

            Text("No Insights Yet")
                .font(ArkFonts.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Market insights and analysis will appear here when published")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ArkSpacing.xl)

            Spacer()
        }
    }
}

// MARK: - Broadcast Card View

struct BroadcastCardView: View {
    let broadcast: Broadcast
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                // Header
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(AppColors.accent)

                    if let publishedAt = broadcast.publishedAt {
                        Text(publishedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text(broadcast.timeAgo)
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    // Media indicators
                    HStack(spacing: ArkSpacing.xs) {
                        if broadcast.audioURL != nil {
                            Image(systemName: "waveform")
                                .font(.caption)
                                .foregroundColor(AppColors.accent)
                        }

                        if !broadcast.images.isEmpty {
                            Image(systemName: "photo.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.accent)
                        }

                        if broadcast.portfolioAttachment != nil {
                            Image(systemName: "square.split.2x1.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }

                // Title
                Text(broadcast.title)
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(2)

                // Preview
                Text(broadcast.contentPreview)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(3)

                // App References
                if !broadcast.appReferences.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ArkSpacing.xs) {
                            ForEach(broadcast.appReferences) { reference in
                                HStack(spacing: ArkSpacing.xxs) {
                                    Image(systemName: reference.section.iconName)
                                        .font(.caption2)

                                    Text(reference.section.displayName)
                                        .font(ArkFonts.caption)
                                }
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, ArkSpacing.sm)
                                .padding(.vertical, ArkSpacing.xxs)
                                .background(AppColors.accent.opacity(0.1))
                                .cornerRadius(ArkSpacing.xs)
                            }
                        }
                    }
                }
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Broadcast Detail View

struct BroadcastDetailView: View {
    let broadcast: Broadcast
    @ObservedObject var viewModel: BroadcastViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    @State private var reactionSummary: [ReactionSummary] = []
    @State private var isLoadingReactions = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                        Text(broadcast.timeAgo)
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)

                        Text(broadcast.title)
                            .font(ArkFonts.title2)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }

                    // Audio Player (placeholder)
                    if broadcast.audioURL != nil {
                        audioPlayerPlaceholder
                    }

                    // Content
                    Text(broadcast.content)
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    // Portfolio Showcase
                    if let portfolioAttachment = broadcast.portfolioAttachment, portfolioAttachment.hasContent {
                        EmbeddedPortfolioWidget(attachment: portfolioAttachment)
                    }

                    // Images (placeholder)
                    if !broadcast.images.isEmpty {
                        imagesSection
                    }

                    // App References
                    if !broadcast.appReferences.isEmpty {
                        appReferencesSection
                    }

                    // Reactions
                    reactionsSection
                }
                .padding(ArkSpacing.md)
            }
            .background(AppColors.background(colorScheme))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .task {
                // Mark as read
                if let userId = appState.currentUser?.id {
                    try? await viewModel.markAsRead(broadcastId: broadcast.id, userId: userId)
                }
                // Load reactions
                await loadReactions()
            }
        }
    }

    // MARK: - Reactions Section

    private var reactionsSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("React")
                .font(ArkFonts.subheadline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            // Emoji buttons row
            HStack(spacing: ArkSpacing.sm) {
                ForEach(ReactionEmoji.allCases, id: \.rawValue) { emoji in
                    reactionButton(for: emoji)
                }
            }

            // Current reactions summary
            if !reactionSummary.isEmpty {
                HStack(spacing: ArkSpacing.xs) {
                    ForEach(reactionSummary, id: \.emoji) { summary in
                        HStack(spacing: 4) {
                            Text(summary.emoji)
                                .font(.system(size: 14))
                            Text("\(summary.count)")
                                .font(ArkFonts.caption)
                                .foregroundColor(summary.hasUserReacted ? AppColors.accent : AppColors.textSecondary)
                        }
                        .padding(.horizontal, ArkSpacing.sm)
                        .padding(.vertical, ArkSpacing.xxs)
                        .background(
                            summary.hasUserReacted
                                ? AppColors.accent.opacity(0.15)
                                : AppColors.cardBackground(colorScheme)
                        )
                        .cornerRadius(ArkSpacing.sm)
                    }
                }
            }
        }
        .padding(.top, ArkSpacing.md)
    }

    private func reactionButton(for emoji: ReactionEmoji) -> some View {
        let hasReacted = reactionSummary.first(where: { $0.emoji == emoji.rawValue })?.hasUserReacted ?? false

        return Button {
            Task {
                await toggleReaction(emoji: emoji.rawValue)
            }
        } label: {
            Text(emoji.rawValue)
                .font(.system(size: 24))
                .padding(ArkSpacing.xs)
                .background(
                    hasReacted
                        ? AppColors.accent.opacity(0.2)
                        : AppColors.cardBackground(colorScheme)
                )
                .cornerRadius(ArkSpacing.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: ArkSpacing.sm)
                        .stroke(hasReacted ? AppColors.accent : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    private func loadReactions() async {
        guard let userId = appState.currentUser?.id else { return }
        isLoadingReactions = true

        do {
            reactionSummary = try await viewModel.fetchReactionSummary(for: broadcast.id, userId: userId)
        } catch {
            logError("Failed to load reactions: \(error)", category: .data)
        }

        isLoadingReactions = false
    }

    private func toggleReaction(emoji: String) async {
        guard let userId = appState.currentUser?.id else { return }

        do {
            try await viewModel.toggleReaction(broadcastId: broadcast.id, userId: userId, emoji: emoji)
            // Reload reactions to update UI
            await loadReactions()
        } catch {
            logError("Failed to toggle reaction: \(error)", category: .data)
        }
    }

    // MARK: - Audio Player Placeholder

    private var audioPlayerPlaceholder: some View {
        HStack(spacing: ArkSpacing.md) {
            Button {
                // TODO: Implement audio playback
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                Text("Voice Note")
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Audio playback coming soon")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }

    // MARK: - Images Section

    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Attached Images")
                .font(ArkFonts.subheadline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArkSpacing.sm) {
                    ForEach(broadcast.images) { image in
                        AsyncImage(url: image.imageURL) { phase in
                            switch phase {
                            case .success(let loadedImage):
                                loadedImage
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                Image(systemName: "photo")
                                    .foregroundColor(AppColors.textTertiary)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 200, height: 150)
                        .cornerRadius(ArkSpacing.sm)
                        .clipped()
                    }
                }
            }
        }
    }

    // MARK: - App References Section

    private var appReferencesSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Referenced Data")
                .font(ArkFonts.subheadline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            ForEach(broadcast.appReferences) { reference in
                VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                    // Admin's note about this reference
                    if let note = reference.note, !note.isEmpty {
                        Text(note)
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .italic()
                    }

                    // Embedded live data widget
                    EmbeddedWidgetView(section: reference.section)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BroadcastFeedView()
        .environmentObject(AppState())
}
