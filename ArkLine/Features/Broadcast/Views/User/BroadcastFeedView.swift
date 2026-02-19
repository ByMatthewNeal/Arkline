import SwiftUI

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
    @State private var navigationPath = NavigationPath()

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
        NavigationStack(path: $navigationPath) {
            if appState.isPro {
                broadcastContent
            } else {
                PremiumFeatureGate(feature: .broadcasts) {}
            }
        }
    }

    private var broadcastContent: some View {
            ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: ArkSpacing.md) {
                    Color.clear.frame(height: 0).id("scrollTop")
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
            .onChange(of: appState.insightsNavigationReset) { _, _ in
                navigationPath = NavigationPath()
                withAnimation(.arkSpring) {
                    scrollProxy.scrollTo("scrollTop", anchor: .top)
                }
            }
            } // ScrollViewReader
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
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No Results Found",
            message: "Try adjusting your search or filters",
            style: .compact
        )
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
        EmptyStateView(
            icon: "antenna.radiowaves.left.and.right",
            title: "No Insights Yet",
            message: "Market insights and analysis will appear here when published"
        )
    }
}

// MARK: - Preview

#Preview {
    BroadcastFeedView()
        .environmentObject(AppState())
}
