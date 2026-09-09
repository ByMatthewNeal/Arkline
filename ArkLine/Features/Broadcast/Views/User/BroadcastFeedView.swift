import SwiftUI

// MARK: - Date Filter

enum BroadcastDateFilter: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
}

// MARK: - Learn tab segments

/// Splits the Learn screen so the evergreen library and the daily "From the Desk"
/// feed each get their own space instead of the library burying the feed.
enum LearnTab: String, CaseIterable {
    case fromTheDesk = "From the Desk"
    case lessons = "Lessons"
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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = BroadcastViewModel()
    @ObservedObject private var notificationService = BroadcastNotificationService.shared

    @State private var selectedBroadcast: Broadcast?
    @State private var showNotificationPrompt = false
    @State private var hasCheckedNotifications = false
    @State private var searchText = ""
    @State private var selectedDateFilter: BroadcastDateFilter = .all
    @State private var selectedTags: Set<String> = []
    @State private var showSavedOnly = false
    @State private var navigationPath = NavigationPath()
    @State private var showDictionary = false
    @State private var showMemberQA = false
    @State private var learnTab: LearnTab = .fromTheDesk
    /// Bumped when a lesson is completed so the curriculum progress UI refreshes.
    @State private var progressVersion = 0

    // MARK: - Filtered Broadcasts

    private var filteredBroadcasts: [Broadcast] {
        var result = viewModel.published

        // Saved filter
        if showSavedOnly {
            result = result.filter { viewModel.isBookmarked($0.id) }
        }

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

    /// Pinned broadcast (shown above everything)
    private var pinnedBroadcast: Broadcast? {
        viewModel.published.first(where: { $0.isPinned })
    }

    /// Non-pinned filtered broadcasts
    private var unpinnedFilteredBroadcasts: [Broadcast] {
        filteredBroadcasts.filter { !$0.isPinned }
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

        let grouped = Dictionary(grouping: unpinnedFilteredBroadcasts) { broadcast -> DateSectionKey in
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

    // MARK: - Sequential Reading Order

    /// The feed's display order flattened: pinned first, then each date section.
    /// Drives previous/next navigation inside the detail sheet.
    private var orderedFeedBroadcasts: [Broadcast] {
        var result: [Broadcast] = []
        if let pinned = pinnedBroadcast { result.append(pinned) }
        result.append(contentsOf: groupedBroadcasts.flatMap { $0.broadcasts })
        return result
    }

    private func neighbor(of broadcast: Broadcast, offset: Int) -> Broadcast? {
        let ordered = orderedFeedBroadcasts
        guard let index = ordered.firstIndex(where: { $0.id == broadcast.id }) else { return nil }
        let target = index + offset
        guard ordered.indices.contains(target) else { return nil }
        return ordered[target]
    }

    /// Open an insight in the detail sheet and mark it read — used by both
    /// card taps and prev/next navigation so the two paths never diverge.
    private func openBroadcast(_ broadcast: Broadcast) {
        selectedBroadcast = broadcast
        if let userId = appState.currentUser?.id {
            viewModel.readBroadcastIds.insert(broadcast.id)
            Task { try? await viewModel.markAsRead(broadcastId: broadcast.id, userId: userId) }
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            broadcastContent
        }
        // Return to root when the Insights tab is (re)selected. Broadcast detail
        // is pushed with closure-based NavigationLinks the path never tracks, so
        // re-identifying the stack is the reliable reset. View model is
        // @StateObject on this struct (outside the stack), so no reload.
        .id(appState.insightsNavigationReset)
    }

    // Structured-learning launcher at the top of the Learn tab: the guided
    // Foundations trail and the guides/glossary, sitting above the broadcasts feed
    // (which is Matt teaching in real time).
    private var learnColumns: [GridItem] {
        [GridItem(.flexible(), spacing: ArkSpacing.sm), GridItem(.flexible(), spacing: ArkSpacing.sm)]
    }

    private func learnGroupLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .bold)).tracking(0.5)
            .foregroundColor(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private var learnLauncher: some View {
        // Re-read live each render; progressVersion forces a refresh when a lesson
        // is completed (see the .onReceive below).
        _ = progressVersion
        let next = Curriculum.nextLesson()
        let nextKind = next?.kind
        let overall = Curriculum.overall()
        return VStack(alignment: .leading, spacing: ArkSpacing.md) {
            continueLearningCard(next: next, overall: overall)

            NavigationLink { CurriculumPathView() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accent)
                    Text("View your full path")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.accent.opacity(0.6))
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            learnGroupLabel("Start here")
            learnCard {
                NavigationLink { TrailOverviewView(kind: .beforeInvesting) } label: {
                    learnRow(number: "01", title: "Before You Invest", subtitle: "The groundwork first", level: TrailKind.beforeInvesting.difficulty, kind: .beforeInvesting, isNext: nextKind == .beforeInvesting)
                }
                .buttonStyle(.plain)
                learnRowDivider
                NavigationLink { StartHereTrailView() } label: {
                    learnRow(number: "02", title: "Start Here", subtitle: "Learn the basics", level: TrailKind.foundations.difficulty, kind: .foundations, isNext: nextKind == .foundations)
                }
                .buttonStyle(.plain)
                learnRowDivider
                NavigationLink { PilotChecklistView() } label: {
                    learnRow(number: "03", title: "Get the Most", subtitle: "Habits that help")
                }
                .buttonStyle(.plain)
            }

            learnGroupLabel("Core skills")
            learnCard {
                NavigationLink { TrailOverviewView(kind: .behavioral) } label: {
                    learnRow(number: "04", title: "Your Brain vs Your Money", subtitle: "Master your own mind", level: TrailKind.behavioral.difficulty, kind: .behavioral, isNext: nextKind == .behavioral)
                }
                .buttonStyle(.plain)
                learnRowDivider
                NavigationLink { TrailOverviewView(kind: .scams) } label: {
                    learnRow(number: "05", title: "Spotting Scams", subtitle: "Protect yourself", level: TrailKind.scams.difficulty, kind: .scams, isNext: nextKind == .scams)
                }
                .buttonStyle(.plain)
            }

            learnGroupLabel("By asset")
            learnCard {
                NavigationLink { TrailOverviewView(kind: .crypto) } label: {
                    learnRow(number: "06", title: "Understanding Crypto", subtitle: "Go deeper on crypto", level: TrailKind.crypto.difficulty, kind: .crypto, isNext: nextKind == .crypto)
                }
                .buttonStyle(.plain)
                learnRowDivider
                NavigationLink { TrailOverviewView(kind: .markets) } label: {
                    learnRow(number: "07", title: "Understanding the Markets", subtitle: "Go deeper on stocks", level: TrailKind.markets.difficulty, kind: .markets, isNext: nextKind == .markets)
                }
                .buttonStyle(.plain)
                learnRowDivider
                NavigationLink { TrailOverviewView(kind: .hedging) } label: {
                    learnRow(number: "08", title: "Understanding Hedges", subtitle: "Gold, silver, and oil", level: TrailKind.hedging.difficulty, kind: .hedging, isNext: nextKind == .hedging)
                }
                .buttonStyle(.plain)
            }

            learnGroupLabel("Going deeper")
            learnCard {
                NavigationLink { TrailOverviewView(kind: .trading) } label: {
                    learnRow(number: "09", title: "Trading vs Investing", subtitle: "Two different games", level: TrailKind.trading.difficulty, kind: .trading, isNext: nextKind == .trading)
                }
                .buttonStyle(.plain)
                learnRowDivider
                NavigationLink { TrailOverviewView(kind: .macro) } label: {
                    learnRow(number: "10", title: "Understanding Macro", subtitle: "The Fed, rates, and cycles", level: TrailKind.macro.difficulty, kind: .macro, isNext: nextKind == .macro)
                }
                .buttonStyle(.plain)
                learnRowDivider
                NavigationLink { TrailOverviewView(kind: .fees) } label: {
                    learnRow(number: "11", title: "Fees & Taxes", subtitle: "Keep more of what's yours", level: TrailKind.fees.difficulty, kind: .fees, isNext: nextKind == .fees)
                }
                .buttonStyle(.plain)
                learnRowDivider
                NavigationLink { TrailOverviewView(kind: .sizing) } label: {
                    learnRow(number: "12", title: "How Much to Own", subtitle: "Position sizing & weight", level: TrailKind.sizing.difficulty, kind: .sizing, isNext: nextKind == .sizing)
                }
                .buttonStyle(.plain)
            }

            learnGroupLabel("Reference")
            learnCard {
                NavigationLink { ResourcesView() } label: {
                    learnRow(number: "13", title: "Guides", subtitle: "Plain-English how-tos")
                }
                .buttonStyle(.plain)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .trailProgressChanged)) { _ in
            progressVersion &+= 1
        }
    }

    // MARK: - Continue-learning card (guided next step + overall progress)

    @ViewBuilder
    private func continueLearningCard(next: (kind: TrailKind, position: Int, title: String)?,
                                      overall: (done: Int, total: Int)) -> some View {
        if let next {
            NavigationLink { TrailOverviewView(kind: next.kind) } label: {
                HStack(spacing: 14) {
                    learnProgressRing(done: overall.done, total: overall.total)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(overall.done == 0 ? "START LEARNING" : "CONTINUE")
                            .font(.system(size: 10, weight: .bold)).tracking(0.6)
                            .foregroundColor(AppColors.accent)
                        Text(next.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text("\(next.kind.navTitle) · \(overall.done) of \(overall.total) lessons")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(AppColors.accent)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.accent.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.accent.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 30))
                    .foregroundColor(AppColors.success)
                VStack(alignment: .leading, spacing: 3) {
                    Text("ALL LESSONS COMPLETE")
                        .font(.system(size: 10, weight: .bold)).tracking(0.6)
                        .foregroundColor(AppColors.success)
                    Text("You've finished the whole path")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                    Text("Revisit any trail below anytime.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer(minLength: 8)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.success.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.success.opacity(0.25), lineWidth: 1))
        }
    }

    private func learnProgressRing(done: Int, total: Int) -> some View {
        let pct = total > 0 ? Double(done) / Double(total) : 0
        return ZStack {
            Circle().stroke(AppColors.accent.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(pct * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.accent)
        }
        .frame(width: 46, height: 46)
    }

    @ViewBuilder
    private func learnCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground(colorScheme)))
    }

    private var learnRowDivider: some View {
        Divider().padding(.leading, 54)
    }

    private func learnRow(number: String, title: String, subtitle: String, level: TrailDifficulty? = nil,
                          kind: TrailKind? = nil, isNext: Bool = false) -> some View {
        let status = kind.map { Curriculum.status(for: $0) }
        return HStack(spacing: 14) {
            Text(number)
                .font(.system(size: 20, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .foregroundColor(isNext ? AppColors.accent : AppColors.textTertiary.opacity(0.55))
                .frame(width: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            // Progress / next indicator
            if isNext {
                Text("NEXT")
                    .font(.system(size: 9, weight: .bold)).tracking(0.4)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.accent))
            } else if case .complete? = status {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.success)
            } else if case .inProgress(let done, let total)? = status {
                Text("\(done)/\(total)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.accent)
            } else if let level {
                Text(level.label)
                    .font(.system(size: 9, weight: .bold)).tracking(0.3)
                    .foregroundColor(level.color)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(level.color.opacity(0.15)))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Spacer()
        }
        .padding(.top, 8)
    }

    private func learnTile(icon: String, title: String, subtitle: String, level: TrailDifficulty? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Badge on its own reserved row so it never collides with the title,
            // and tiles without a badge still align (row keeps its height).
            HStack {
                Spacer()
                if let level {
                    Text(level.label)
                        .font(.system(size: 9, weight: .bold)).tracking(0.3)
                        .foregroundColor(level.color)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(level.color.opacity(0.15)))
                }
            }
            .frame(height: 18)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.cardBackground(colorScheme)))
    }

    private var broadcastContent: some View {
            ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: ArkSpacing.md) {
                    Color.clear.frame(height: 0).id("scrollTop")

                    Picker("", selection: $learnTab) {
                        ForEach(LearnTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    if learnTab == .lessons {
                        learnLauncher
                        dictionaryTile
                    } else {
                        // Notification prompt banner
                        if showNotificationPrompt {
                            notificationPromptBanner
                        }

                        if viewModel.isLoading && viewModel.published.isEmpty {
                            loadingView
                        } else if viewModel.published.isEmpty {
                            emptyStateView
                        } else {
                            // Filter bar — content tools lead; promos follow
                            filterBar

                            // Member questions answered from the desk
                            memberQATile

                            // Pinned post (always at top)
                            if let pinned = pinnedBroadcast {
                                pinnedSection(pinned)
                            }

                            // Broadcast list (grouped)
                            if unpinnedFilteredBroadcasts.isEmpty && pinnedBroadcast == nil {
                                noResultsView
                            } else {
                                groupedBroadcastList
                            }
                        }
                    }
                }
                .padding(.horizontal, ArkSpacing.md)
                .padding(.bottom, 100)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                if let userId = appState.currentUser?.id {
                    await viewModel.loadPublishedBroadcasts(for: userId)
                }
            }
            .sheet(item: $selectedBroadcast) { broadcast in
                BroadcastDetailView(
                    broadcast: broadcast,
                    viewModel: viewModel,
                    previousBroadcast: neighbor(of: broadcast, offset: -1),
                    nextBroadcast: neighbor(of: broadcast, offset: +1),
                    onNavigate: { target in openBroadcast(target) }
                )
                .id(broadcast.id) // fresh state (reactions, players) per insight
            }
            .task {
                if let userId = appState.currentUser?.id {
                    await viewModel.loadPublishedBroadcasts(for: userId)
                    await viewModel.loadReadStatus(userId: userId)
                    await viewModel.loadUserHearts(userId: userId)
                    await viewModel.loadBookmarks(userId: userId)
                }
                await checkNotificationStatus()
            }
            .onChange(of: appState.insightsNavigationReset) { _, _ in
                navigationPath = NavigationPath()
                withAnimation(.arkSpring) {
                    scrollProxy.scrollTo("scrollTop", anchor: .top)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BroadcastNotificationTapped"))) { notification in
                if let id = notification.userInfo?["id"] as? String {
                    appState.selectedTab = .insights
                    appState.pendingBroadcastId = id
                    // Reload feed so the new broadcast is available, then open it
                    Task {
                        if let userId = appState.currentUser?.id {
                            await viewModel.loadPublishedBroadcasts(for: userId)
                        }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("BroadcastReceived"))) { _ in
                // New broadcast arrived while app is in foreground — refresh feed
                Task {
                    if let userId = appState.currentUser?.id {
                        await viewModel.loadPublishedBroadcasts(for: userId)
                    }
                }
            }
            .onChange(of: appState.pendingBroadcastId) { _, newId in
                guard let id = newId else { return }
                if let broadcast = viewModel.published.first(where: { $0.id.uuidString == id }) {
                    selectedBroadcast = broadcast
                    appState.pendingBroadcastId = nil
                }
            }
            .onChange(of: viewModel.published) { _, _ in
                if let id = appState.pendingBroadcastId,
                   let broadcast = viewModel.published.first(where: { $0.id.uuidString == id }) {
                    selectedBroadcast = broadcast
                    appState.pendingBroadcastId = nil
                }
            }
            .onChange(of: viewModel.unreadCount) { _, newCount in
                appState.insightsUnreadCount = newCount
            }
            .onChange(of: appState.selectedTab) { _, newTab in
                if newTab == .insights {
                    // Refresh read status when returning to tab
                    if let userId = appState.currentUser?.id {
                        Task { await viewModel.loadReadStatus(userId: userId) }
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Refresh feed when returning from background (may have missed a notification)
                    Task {
                        if let userId = appState.currentUser?.id {
                            await viewModel.loadPublishedBroadcasts(for: userId)
                        }
                    }
                }
            }
            } // ScrollViewReader
    }

    // MARK: - Filter Bar

    /// Resolve a tag string to its predefined color, falling back to accent
    private func tagColor(for tag: String) -> Color {
        BroadcastTag(rawValue: tag)?.color ?? AppColors.accent
    }

    private var filterBar: some View {
        VStack(spacing: ArkSpacing.sm) {
            // Always-visible search bar
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textSecondary)
                    .font(ArkFonts.body)

                TextField("Search posts...", text: $searchText)
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ArkSpacing.sm)
            .padding(.vertical, ArkSpacing.xs + 2)
            .background(AppColors.cardBackground(colorScheme))
            .cornerRadius(ArkSpacing.sm)

            // Combined filter row: date filters + tag pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ArkSpacing.xs) {
                    // Saved filter chip
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSavedOnly.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showSavedOnly ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 10))
                            Text("Saved")
                                .font(ArkFonts.caption)
                        }
                        .foregroundColor(showSavedOnly ? .white : AppColors.textSecondary)
                        .padding(.horizontal, ArkSpacing.sm)
                        .padding(.vertical, ArkSpacing.xs)
                        .background(showSavedOnly ? AppColors.accent : AppColors.cardBackground(colorScheme))
                        .cornerRadius(ArkSpacing.sm)
                    }
                    .buttonStyle(.plain)

                    // Divider
                    RoundedRectangle(cornerRadius: 1)
                        .fill(AppColors.textSecondary.opacity(0.2))
                        .frame(width: 1, height: 20)
                        .padding(.horizontal, 2)

                    // Date filter chips
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

                    // Divider between date and tag filters
                    if !availableTags.isEmpty {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(AppColors.textSecondary.opacity(0.2))
                            .frame(width: 1, height: 20)
                            .padding(.horizontal, 2)
                    }

                    // Tag pills
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
                            let color = tagColor(for: tag)
                            Text("#\(tag)")
                                .font(ArkFonts.caption)
                                .foregroundColor(selectedTags.contains(tag) ? .white : color)
                                .padding(.horizontal, ArkSpacing.sm)
                                .padding(.vertical, ArkSpacing.xs)
                                .background(selectedTags.contains(tag) ? color : color.opacity(0.1))
                                .cornerRadius(ArkSpacing.sm)
                        }
                        .buttonStyle(.plain)
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
                        broadcastCard(broadcast)
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

    // MARK: - Pinned Section

    private func pinnedSection(_ broadcast: Broadcast) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack(spacing: ArkSpacing.xxs) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.accent)
                Text("Pinned")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.accent)
                    .fontWeight(.semibold)
            }

            broadcastCard(broadcast)
        }
    }

    // MARK: - Broadcast Card Helper

    private func broadcastCard(_ broadcast: Broadcast) -> some View {
        BroadcastCardView(
            broadcast: broadcast,
            isAdmin: appState.currentUser?.isAdmin == true,
            isUnread: !viewModel.isRead(broadcast.id),
            hasReacted: viewModel.userHeartedBroadcastIds.contains(broadcast.id),
            isBookmarked: viewModel.isBookmarked(broadcast.id),
            onQuickReact: {
                guard let userId = appState.currentUser?.id else { return }
                Task { await viewModel.quickToggleHeart(broadcastId: broadcast.id, userId: userId) }
            }
        ) {
            openBroadcast(broadcast)
        }
        .onAppear {
            // Reach: log that this insight appeared in the user's feed (deduped
            // per session). Skip admins so the founder's own scrolling isn't
            // counted. Distinct from a read, which only fires on opening the post.
            if appState.currentUser?.isAdmin != true, let userId = appState.currentUser?.id {
                viewModel.recordImpression(broadcastId: broadcast.id, userId: userId)
            }
        }
        .contextMenu {
            // Bookmark / save
            if let userId = appState.currentUser?.id {
                Button {
                    Task { await viewModel.toggleBookmark(broadcastId: broadcast.id, userId: userId) }
                } label: {
                    Label(
                        viewModel.isBookmarked(broadcast.id) ? "Remove from Saved" : "Save",
                        systemImage: viewModel.isBookmarked(broadcast.id) ? "bookmark.slash" : "bookmark"
                    )
                }
            }

            // Admin-only pin
            if appState.currentUser?.isAdmin == true {
                Button {
                    Task { try? await viewModel.togglePin(broadcast) }
                } label: {
                    Label(broadcast.isPinned ? "Unpin" : "Pin to Top", systemImage: broadcast.isPinned ? "pin.slash" : "pin")
                }
            }
        }
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

    // MARK: - Dictionary Card

    // MARK: - Utility Row (Dictionary + Member Q&A)

    /// Compact half-width tiles below the filter bar. The feed leads with
    /// insights; utilities are one glance down instead of owning the top slot.
    // Dictionary (glossary) lives with the Lessons library.
    private var dictionaryTile: some View {
        utilityTile(
            icon: "character.book.closed.fill",
            color: .purple,
            title: "Dictionary"
        ) { showDictionary = true }
        .sheet(isPresented: $showDictionary) {
            NavigationStack {
                DictionaryView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showDictionary = false }
                        }
                    }
            }
        }
    }

    // Member Q&A lives with the From the Desk feed.
    private var memberQATile: some View {
        utilityTile(
            icon: "bubble.left.and.bubble.right.fill",
            color: .teal,
            title: "Member Q&A"
        ) { showMemberQA = true }
        .sheet(isPresented: $showMemberQA) {
            MemberQAView().environmentObject(appState)
        }
    }

    private func utilityTile(icon: String, color: Color, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)

                Text(title)
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
            }
            .padding(.horizontal, ArkSpacing.sm)
            .padding(.vertical, ArkSpacing.xs + 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cardBackground(colorScheme))
            )
        }
        .buttonStyle(.plain)
    }

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
