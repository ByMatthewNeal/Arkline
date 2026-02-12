import SwiftUI
import AVFoundation
import Kingfisher

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

                    Text(formattedBroadcastDate(broadcast.publishedAt ?? broadcast.createdAt))
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)

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
    @State private var audioPlayer: AVPlayer?
    @State private var isPlayingAudio = false
    @State private var audioEndObserver: NSObjectProtocol?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                        Text(formattedBroadcastDate(broadcast.publishedAt ?? broadcast.createdAt))
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
                // Track broadcast read
                Task {
                    await AnalyticsService.shared.track("broadcast_read", properties: [
                        "broadcast_id": .string(broadcast.id.uuidString)
                    ])
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

    // MARK: - Audio Player

    private var audioPlayerPlaceholder: some View {
        HStack(spacing: ArkSpacing.md) {
            Button {
                toggleAudioPlayback()
            } label: {
                Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                Text("Voice Note")
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(isPlayingAudio ? "Playing..." : "Tap to play")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
        .onDisappear {
            audioPlayer?.pause()
            isPlayingAudio = false
            if let observer = audioEndObserver {
                NotificationCenter.default.removeObserver(observer)
                audioEndObserver = nil
            }
        }
    }

    private func toggleAudioPlayback() {
        if isPlayingAudio {
            audioPlayer?.pause()
            isPlayingAudio = false
        } else {
            if audioPlayer == nil, let url = broadcast.audioURL {
                let player = AVPlayer(url: url)
                audioPlayer = player

                // Observe when playback finishes
                audioEndObserver = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: player.currentItem,
                    queue: .main
                ) { _ in
                    isPlayingAudio = false
                    player.seek(to: .zero)
                }
            }
            audioPlayer?.play()
            isPlayingAudio = true
        }
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
                        KFImage(image.imageURL)
                            .resizable()
                            .placeholder {
                                ProgressView()
                            }
                            .fade(duration: 0.2)
                            .aspectRatio(contentMode: .fill)
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

// MARK: - Date Formatting Helper

/// Formats a broadcast date with friendly relative labels.
func formattedBroadcastDate(_ date: Date) -> String {
    let calendar = Calendar.current
    let timeFormatter = DateFormatter()
    timeFormatter.dateFormat = "h:mm a"
    let time = timeFormatter.string(from: date)

    if calendar.isDateInToday(date) {
        return "Today at \(time)"
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday at \(time)"
    } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), date >= weekAgo {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"
        return "\(dayFormatter.string(from: date)) at \(time)"
    } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        return "\(dateFormatter.string(from: date)) at \(time)"
    } else {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        return "\(dateFormatter.string(from: date)) at \(time)"
    }
}
