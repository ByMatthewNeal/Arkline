import SwiftUI
import Kingfisher

// MARK: - Admin Broadcast Detail View

/// Read-only detail view for admins showing broadcast content + engagement stats.
struct AdminBroadcastDetailView: View {
    let broadcast: Broadcast
    @ObservedObject var viewModel: BroadcastViewModel
    let onEdit: () -> Void

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) private var openURL

    @State private var reactionSummary: [ReactionSummary] = []
    @State private var showingImageViewer = false
    @State private var selectedImageIndex = 0
    @State private var isPinned: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.lg) {
                    // Engagement stats banner
                    engagementBanner

                    // Header
                    VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                        HStack {
                            Text(formattedBroadcastDate(broadcast.publishedAt ?? broadcast.createdAt))
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textSecondary)

                            if let btcPrice = broadcast.btcPriceAtPublish, btcPrice > 0 {
                                HStack(spacing: 4) {
                                    Text("₿")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(hex: "F7931A"))
                                    Text(btcPrice.asCurrencyWhole)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(.horizontal, ArkSpacing.xs)
                                .padding(.vertical, 2)
                                .background(Color(hex: "F7931A").opacity(0.08))
                                .cornerRadius(ArkSpacing.xxs)
                            }
                        }

                        Text(broadcast.title)
                            .font(ArkFonts.title2)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        if !broadcast.tags.isEmpty {
                            HStack(spacing: ArkSpacing.xxs) {
                                ForEach(broadcast.tags, id: \.self) { tag in
                                    let color = BroadcastTag(rawValue: tag)?.color ?? AppColors.accent
                                    Text("#\(tag)")
                                        .font(ArkFonts.caption)
                                        .foregroundColor(color)
                                        .padding(.horizontal, ArkSpacing.xs)
                                        .padding(.vertical, 2)
                                        .background(color.opacity(0.1))
                                        .cornerRadius(ArkSpacing.xxs)
                                }
                            }
                        }
                    }

                    // Audio Player
                    if let audioURL = broadcast.audioURL {
                        AudioPlayerView(url: audioURL)
                    }

                    // Meeting Link
                    if let meetingURL = broadcast.meetingLink {
                        Button {
                            openURL(meetingURL)
                        } label: {
                            HStack(spacing: ArkSpacing.md) {
                                Image(systemName: "video.fill")
                                    .font(.title2)
                                    .foregroundColor(AppColors.accent)

                                VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                                    Text("Join Meeting")
                                        .font(ArkFonts.bodySemibold)
                                        .foregroundColor(AppColors.textPrimary(colorScheme))

                                    Text(meetingURL.host ?? meetingURL.absoluteString)
                                        .font(ArkFonts.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(AppColors.accent)
                            }
                            .padding(ArkSpacing.md)
                            .background(AppColors.accent.opacity(0.1))
                            .cornerRadius(ArkSpacing.sm)
                        }
                        .buttonStyle(.plain)
                    }

                    // Video Recording
                    if let videoURL = broadcast.videoURL {
                        Button {
                            openURL(videoURL)
                        } label: {
                            HStack(spacing: ArkSpacing.md) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.title2)
                                    .foregroundColor(Color(hex: "8B5CF6"))

                                VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                                    Text("Watch Recording")
                                        .font(ArkFonts.bodySemibold)
                                        .foregroundColor(AppColors.textPrimary(colorScheme))

                                    Text(videoURL.host ?? videoURL.absoluteString)
                                        .font(ArkFonts.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "8B5CF6"))
                            }
                            .padding(ArkSpacing.md)
                            .background(Color(hex: "8B5CF6").opacity(0.1))
                            .cornerRadius(ArkSpacing.sm)
                        }
                        .buttonStyle(.plain)
                    }

                    // Content
                    MarkdownContentView(content: broadcast.content)

                    // Portfolio Showcase
                    if let portfolioAttachment = broadcast.portfolioAttachment, portfolioAttachment.hasContent {
                        EmbeddedPortfolioWidget(attachment: portfolioAttachment)
                    }

                    // Images
                    if !broadcast.images.isEmpty {
                        imagesSection
                            .fullScreenCover(isPresented: $showingImageViewer) {
                                FullscreenImageViewer(images: broadcast.images, initialIndex: selectedImageIndex)
                            }
                    }

                    // Reactions breakdown
                    if !reactionSummary.isEmpty {
                        reactionsBreakdown
                    }
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

                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: ArkSpacing.md) {
                        if broadcast.status == .published {
                            Button {
                                Task {
                                    try? await viewModel.togglePin(broadcast)
                                    isPinned.toggle()
                                }
                            } label: {
                                Image(systemName: isPinned ? "pin.slash" : "pin")
                                    .foregroundColor(isPinned ? AppColors.warning : AppColors.textSecondary)
                            }
                        }

                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onEdit()
                            }
                        } label: {
                            Label("Edit", systemImage: "pencil")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                }
            }
            .task {
                isPinned = broadcast.isPinned
                await loadReactions()
            }
        }
    }

    // MARK: - Engagement Banner

    private var engagementBanner: some View {
        VStack(spacing: ArkSpacing.sm) {
            HStack(spacing: ArkSpacing.md) {
                // Views
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.success)
                    Text("\(broadcast.viewCount ?? 0)")
                        .font(ArkFonts.bodySemibold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    Text("views")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Total reactions
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(AppColors.error)
                    Text("\(broadcast.reactionCount ?? 0)")
                        .font(ArkFonts.bodySemibold)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    Text("reactions")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Per-emoji breakdown
            if !reactionSummary.isEmpty {
                HStack(spacing: ArkSpacing.sm) {
                    ForEach(reactionSummary, id: \.emoji) { summary in
                        HStack(spacing: 4) {
                            Text(summary.emoji)
                                .font(.system(size: 14))
                            Text("\(summary.count)")
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, ArkSpacing.sm)
                        .padding(.vertical, ArkSpacing.xxs)
                        .background(AppColors.cardBackground(colorScheme))
                        .cornerRadius(ArkSpacing.sm)
                    }
                    Spacer()
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.accent.opacity(0.05))
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
                    ForEach(Array(broadcast.images.enumerated()), id: \.element.id) { index, image in
                        Button {
                            selectedImageIndex = index
                            showingImageViewer = true
                        } label: {
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
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Reactions Breakdown

    private var reactionsBreakdown: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text("Reactions")
                .font(ArkFonts.subheadline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            HStack(spacing: ArkSpacing.sm) {
                ForEach(reactionSummary, id: \.emoji) { summary in
                    VStack(spacing: ArkSpacing.xxs) {
                        Text(summary.emoji)
                            .font(.title2)
                        Text("\(summary.count)")
                            .font(ArkFonts.bodySemibold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ArkSpacing.sm)
                    .background(AppColors.cardBackground(colorScheme))
                    .cornerRadius(ArkSpacing.sm)
                }
            }
        }
    }

    // MARK: - Load Reactions

    private func loadReactions() async {
        guard let userId = appState.currentUser?.id else { return }
        do {
            reactionSummary = try await viewModel.fetchReactionSummary(for: broadcast.id, userId: userId)
        } catch {
            logError("Failed to load reactions: \(error)", category: .data)
        }
    }
}

// MARK: - Stat Card

struct BroadcastStatCard: View {
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

struct BroadcastRowView: View {
    let broadcast: Broadcast
    let onTap: () -> Void
    var onEdit: (() -> Void)?
    var onPublish: (() -> Void)?
    var onPin: (() -> Void)?
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
                    HStack(spacing: ArkSpacing.xxs) {
                        if broadcast.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.accent)
                        }
                        Text(broadcast.title.isEmpty ? "Untitled" : broadcast.title)
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .lineLimit(1)
                    }

                    HStack(spacing: ArkSpacing.xs) {
                        if broadcast.status == .published, let publishedAt = broadcast.publishedAt {
                            Text(publishedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text("\u{2022}")
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
                                Text("\u{2022}")
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

                // Engagement + media indicators
                VStack(alignment: .trailing, spacing: ArkSpacing.xxs) {
                    if broadcast.status == .published {
                        HStack(spacing: ArkSpacing.sm) {
                            HStack(spacing: 3) {
                                Image(systemName: "eye")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppColors.success)
                                Text("\(broadcast.viewCount ?? 0)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            HStack(spacing: 3) {
                                Image(systemName: "heart")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppColors.error)
                                Text("\(broadcast.reactionCount ?? 0)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }

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

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }

                    // Delete button
                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.error.opacity(0.6))
                            .padding(6)
                            .background(AppColors.error.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(ArkSpacing.md)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.sm)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onEdit = onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if let onPublish = onPublish {
                Button {
                    onPublish()
                } label: {
                    Label("Publish", systemImage: "paperplane.fill")
                }
            }

            if broadcast.status == .published, let onPin = onPin {
                Button {
                    onPin()
                } label: {
                    Label(broadcast.isPinned ? "Unpin" : "Pin to Top", systemImage: broadcast.isPinned ? "pin.slash" : "pin")
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
