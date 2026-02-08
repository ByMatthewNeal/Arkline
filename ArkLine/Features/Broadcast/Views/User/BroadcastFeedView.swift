import SwiftUI
import AVFoundation

// MARK: - Date Filter

enum BroadcastDateFilter: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
}

// MARK: - Date Section Key

private struct DateSectionKey: Hashable, Comparable {
    let order: Int
    let label: String

    static func < (lhs: DateSectionKey, rhs: DateSectionKey) -> Bool {
        lhs.order < rhs.order
    }
}

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
    @State private var searchText = ""
    @State private var selectedDateFilter: BroadcastDateFilter = .all
    @State private var selectedTags: Set<String> = []

    // MARK: - Filtered Broadcasts

    private var filteredBroadcasts: [Broadcast] {
        var result = viewModel.published

        // Date filter
        if selectedDateFilter != .all {
            let calendar = Calendar.current
            let now = Date()
            result = result.filter { broadcast in
                let date = broadcast.publishedAt ?? broadcast.createdAt
                switch selectedDateFilter {
                case .all: return true
                case .today: return calendar.isDateInToday(date)
                case .thisWeek:
                    guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return true }
                    return date >= weekAgo
                case .thisMonth:
                    guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else { return true }
                    return date >= monthAgo
                }
            }
        }

        // Tag filter
        if !selectedTags.isEmpty {
            result = result.filter { broadcast in
                !selectedTags.isDisjoint(with: Set(broadcast.tags))
            }
        }

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { broadcast in
                broadcast.title.lowercased().contains(query)
                || broadcast.content.lowercased().contains(query)
                || broadcast.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }

        return result
    }

    /// All unique tags from published broadcasts
    private var availableTags: [String] {
        let allTags = viewModel.published.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }

    /// Group filtered broadcasts into date sections
    private var groupedBroadcasts: [(key: DateSectionKey, broadcasts: [Broadcast])] {
        let calendar = Calendar.current
        let now = Date()

        let grouped = Dictionary(grouping: filteredBroadcasts) { broadcast -> DateSectionKey in
            let date = broadcast.publishedAt ?? broadcast.createdAt
            if calendar.isDateInToday(date) {
                return DateSectionKey(order: 0, label: "Today")
            } else if calendar.isDateInYesterday(date) {
                return DateSectionKey(order: 1, label: "Yesterday")
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now), date >= weekAgo {
                return DateSectionKey(order: 2, label: "This Week")
            } else {
                // Group by month
                let formatter = DateFormatter()
                formatter.dateFormat = calendar.component(.year, from: date) == calendar.component(.year, from: now)
                    ? "MMMM"
                    : "MMMM yyyy"
                let monthLabel = formatter.string(from: date)
                // Order by how far back the month is (3+ for anything older than this week)
                let monthsAgo = calendar.dateComponents([.month], from: date, to: now).month ?? 0
                return DateSectionKey(order: 3 + monthsAgo, label: monthLabel)
            }
        }

        return grouped.map { (key: $0.key, broadcasts: $0.value.sorted { ($0.publishedAt ?? $0.createdAt) > ($1.publishedAt ?? $1.createdAt) }) }
            .sorted { $0.key < $1.key }
    }

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
                        // Filter bar
                        filterBar

                        // Broadcast list (grouped)
                        if filteredBroadcasts.isEmpty {
                            noResultsView
                        } else {
                            groupedBroadcastList
                        }
                    }
                }
                .padding(.horizontal, ArkSpacing.md)
                .padding(.bottom, 100)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search insights...")
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

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: ArkSpacing.sm) {
            // Date filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArkSpacing.xs) {
                    ForEach(BroadcastDateFilter.allCases, id: \.self) { filter in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDateFilter = filter
                            }
                        } label: {
                            Text(filter.rawValue)
                                .font(ArkFonts.caption)
                                .foregroundColor(selectedDateFilter == filter ? .white : AppColors.textSecondary)
                                .padding(.horizontal, ArkSpacing.sm)
                                .padding(.vertical, ArkSpacing.xs)
                                .background(selectedDateFilter == filter ? AppColors.accent : AppColors.cardBackground(colorScheme))
                                .cornerRadius(ArkSpacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Tag pills (only if tags exist)
            if !availableTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ArkSpacing.xs) {
                        ForEach(availableTags, id: \.self) { tag in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }
                            } label: {
                                HStack(spacing: ArkSpacing.xxs) {
                                    Text("#\(tag)")
                                        .font(ArkFonts.caption)
                                }
                                .foregroundColor(selectedTags.contains(tag) ? .white : AppColors.accent)
                                .padding(.horizontal, ArkSpacing.sm)
                                .padding(.vertical, ArkSpacing.xxs)
                                .background(selectedTags.contains(tag) ? AppColors.accent : AppColors.accent.opacity(0.1))
                                .cornerRadius(ArkSpacing.xs)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Grouped Broadcast List

    private var groupedBroadcastList: some View {
        LazyVStack(spacing: ArkSpacing.md, pinnedViews: [.sectionHeaders]) {
            ForEach(groupedBroadcasts, id: \.key) { section in
                Section {
                    ForEach(section.broadcasts) { broadcast in
                        BroadcastCardView(broadcast: broadcast) {
                            selectedBroadcast = broadcast
                        }
                    }
                } header: {
                    HStack {
                        Text(section.key.label)
                            .font(ArkFonts.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                    .padding(.vertical, ArkSpacing.xs)
                    .background(AppColors.background(colorScheme))
                }
            }
        }
        .padding(.top, ArkSpacing.xs)
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: ArkSpacing.sm) {
            Spacer().frame(height: 40)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textTertiary)

            Text("No Results Found")
                .font(ArkFonts.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Try adjusting your search or filters")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()
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
                            UserDefaults.standard.set(true, forKey: Constants.UserDefaults.notificationsPrompted)
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
                    UserDefaults.standard.set(true, forKey: Constants.UserDefaults.notificationsPrompted)
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
        let alreadyPrompted = UserDefaults.standard.bool(forKey: Constants.UserDefaults.notificationsPrompted)
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
                NotificationCenter.default.addObserver(
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

// MARK: - Date Formatting Helper

/// Formats a broadcast date with friendly relative labels.
/// - "Today at 2:30 PM"
/// - "Yesterday at 9:15 AM"
/// - "Monday at 4:00 PM" (this week)
/// - "Jan 15 at 11:30 AM" (older, same year)
/// - "Dec 3, 2025 at 8:00 AM" (different year)
private func formattedBroadcastDate(_ date: Date) -> String {
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

// MARK: - Preview

#Preview {
    BroadcastFeedView()
        .environmentObject(AppState())
}
