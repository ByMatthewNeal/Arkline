import SwiftUI
import Kingfisher

// MARK: - Broadcast Card View

struct BroadcastCardView: View {
    let broadcast: Broadcast
    var isAdmin: Bool = false
    var isUnread: Bool = false
    var hasReacted: Bool = false
    var onQuickReact: (() -> Void)?
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                // Header
                HStack {
                    // Unread dot
                    if isUnread {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }

                    // Pinned indicator
                    if broadcast.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.accent)
                    }

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

                        if broadcast.meetingLink != nil {
                            Image(systemName: "video.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.accent)
                        }

                        if broadcast.videoURL != nil {
                            Image(systemName: "play.rectangle.fill")
                                .font(.caption)
                                .foregroundColor(Color(hex: "8B5CF6"))
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

                // Tags
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

                // App References
                if !broadcast.appReferences.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ArkSpacing.xs) {
                            ForEach(broadcast.appReferences) { reference in
                                HStack(spacing: ArkSpacing.xxs) {
                                    Image(systemName: reference.iconName)
                                        .font(.caption2)

                                    Text(reference.displayName)
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

                // Engagement footer: quick-react + stats + BTC price
                HStack(spacing: ArkSpacing.sm) {
                    // Quick-react heart button
                    Button {
                        Haptics.selection()
                        onQuickReact?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: hasReacted ? "heart.fill" : "heart")
                                .font(.system(size: 12))
                                .foregroundColor(hasReacted ? AppColors.error : AppColors.textSecondary)

                            if let reactions = broadcast.reactionCount, reactions > 0 {
                                Text("\(reactions)")
                                    .font(ArkFonts.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(.horizontal, ArkSpacing.xs)
                        .padding(.vertical, ArkSpacing.xxxs)
                        .background(hasReacted ? AppColors.error.opacity(0.1) : Color.clear)
                        .cornerRadius(ArkSpacing.Radius.full)
                    }
                    .buttonStyle(.plain)

                    if isAdmin, let views = broadcast.viewCount, views > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.success)
                            Text("\(views)")
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    // BTC price at publish time
                    if let btcPrice = broadcast.btcPriceAtPublish, btcPrice > 0 {
                        HStack(spacing: 3) {
                            Text("₿")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "F7931A"))
                            Text(btcPrice.asCurrencyWhole)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(AppColors.textSecondary)
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
    @Environment(\.openURL) private var openURL
    @State private var showingImageViewer = false
    @State private var selectedImageIndex = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                        HStack {
                            Text(formattedBroadcastDate(broadcast.publishedAt ?? broadcast.createdAt))
                                .font(ArkFonts.caption)
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            // Admin-only view count
                            if appState.currentUser?.isAdmin == true, let views = broadcast.viewCount, views > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "eye.fill")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.success)
                                    Text("\(views) views")
                                        .font(ArkFonts.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
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
                // Increment total view count
                viewModel.incrementViewCount(broadcastId: broadcast.id)
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

                    // Dispatch by reference kind
                    switch reference.referenceKind {
                    case .macroIndicator:
                        if let section = reference.section {
                            EmbeddedWidgetView(section: section)
                                .onTapGesture {
                                    appState.selectedTab = section.navigationTab
                                    dismiss()
                                }
                        }

                    case .asset:
                        if let assetRef = reference.assetReference {
                            NavigationLink {
                                AssetReferenceDestination(assetReference: assetRef)
                            } label: {
                                EmbeddedAssetWidget(assetReference: assetRef)
                            }
                            .buttonStyle(.plain)
                        }

                    case .externalLink:
                        if let link = reference.externalLink {
                            Button {
                                openURL(link.url)
                            } label: {
                                ExternalLinkPreviewCard(link: link)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Asset Reference Destination

/// Bridges an AssetReference to the appropriate detail view by loading the asset first.
private struct AssetReferenceDestination: View {
    let assetReference: AssetReference
    @State private var cryptoAsset: CryptoAsset?
    @State private var stockAsset: StockAsset?
    @State private var metalAsset: MetalAsset?
    @State private var isLoading = true
    @Environment(\.colorScheme) var colorScheme

    private let marketService: MarketServiceProtocol = ServiceContainer.shared.marketService

    var body: some View {
        Group {
            if let crypto = cryptoAsset {
                AssetDetailView(asset: crypto)
            } else if let stock = stockAsset {
                StockDetailView(asset: stock)
            } else if let metal = metalAsset {
                MetalDetailView(asset: metal)
            } else if isLoading {
                ProgressView("Loading \(assetReference.displayName)...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.background(colorScheme))
            } else {
                VStack(spacing: ArkSpacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(AppColors.textSecondary)
                    Text("Could not load \(assetReference.displayName)")
                        .font(ArkFonts.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.background(colorScheme))
            }
        }
        .task {
            await loadAsset()
        }
    }

    private func loadAsset() async {
        defer { isLoading = false }

        do {
            switch assetReference.assetType {
            case .crypto:
                if let cgId = assetReference.coinGeckoId {
                    let results = try await marketService.searchCrypto(query: cgId)
                    cryptoAsset = results.first(where: { $0.id == cgId || $0.symbol.uppercased() == assetReference.symbol.uppercased() })
                }
            case .stock:
                let results = try await marketService.fetchStockAssets(symbols: [assetReference.symbol])
                stockAsset = results.first
            case .commodity:
                let results = try await marketService.fetchMetalAssets(symbols: [assetReference.symbol])
                metalAsset = results.first
            }
        } catch {
            // Loading failed — will show error state
        }
    }
}

// MARK: - Cached DateFormatters

private enum BroadcastDateFormatters {
    /// "h:mm a" — e.g. "2:30 PM"
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    /// "EEEE" — e.g. "Thursday"
    static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    /// "MMM d" — e.g. "Mar 13"
    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    /// "MMM d, yyyy" — e.g. "Mar 13, 2026"
    static let monthDayYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}

// MARK: - Date Formatting Helper

/// Formats a broadcast date with friendly relative labels.
func formattedBroadcastDate(_ date: Date) -> String {
    let calendar = Calendar.current
    let time = BroadcastDateFormatters.time.string(from: date)

    if calendar.isDateInToday(date) {
        return "Today at \(time)"
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday at \(time)"
    } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()), date >= weekAgo {
        return "\(BroadcastDateFormatters.weekday.string(from: date)) at \(time)"
    } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
        return "\(BroadcastDateFormatters.monthDay.string(from: date)) at \(time)"
    } else {
        return "\(BroadcastDateFormatters.monthDayYear.string(from: date)) at \(time)"
    }
}
