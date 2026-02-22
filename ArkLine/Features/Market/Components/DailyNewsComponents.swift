import SwiftUI

// MARK: - All News View
struct AllNewsView: View {
    let news: [NewsItem]
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var selectedFilter: NewsSourceType? = nil
    @State private var viewMode: NewsViewMode = .byTopic

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var filteredNews: [NewsItem] {
        if let filter = selectedFilter {
            return news.filter { $0.sourceType == filter }
        }
        return news
    }

    /// Group news by detected topic
    private var newsByTopic: [(topic: DetectedNewsTopic, items: [NewsItem])] {
        var grouped: [DetectedNewsTopic: [NewsItem]] = [:]

        for item in filteredNews {
            let topic = item.detectedTopic
            if grouped[topic] == nil {
                grouped[topic] = []
            }
            grouped[topic]?.append(item)
        }

        // Sort each group by date (newest first)
        for key in grouped.keys {
            grouped[key]?.sort { $0.publishedAt > $1.publishedAt }
        }

        // Return sorted by topic order, excluding empty groups
        return grouped
            .map { (topic: $0.key, items: $0.value) }
            .filter { !$0.items.isEmpty }
            .sorted { $0.topic.sortOrder < $1.topic.sortOrder }
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Filter tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            NewsFilterChip(
                                title: "All",
                                count: news.count,
                                isSelected: selectedFilter == nil,
                                action: { selectedFilter = nil }
                            )
                            NewsFilterChip(
                                title: "Twitter",
                                icon: "bird",
                                count: news.filter { $0.sourceType == .twitter }.count,
                                isSelected: selectedFilter == .twitter,
                                action: { selectedFilter = .twitter }
                            )
                            NewsFilterChip(
                                title: "Google",
                                icon: "g.circle",
                                count: news.filter { $0.sourceType == .googleNews }.count,
                                isSelected: selectedFilter == .googleNews,
                                action: { selectedFilter = .googleNews }
                            )
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)

                    // View Mode Toggle
                    HStack {
                        ForEach(NewsViewMode.allCases, id: \.self) { mode in
                            Button(action: { viewMode = mode }) {
                                Text(mode.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(viewMode == mode ? .white : AppColors.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(viewMode == mode ? AppColors.accent : Color.clear)
                                    .cornerRadius(8)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    // News content based on view mode
                    if viewMode == .byTopic {
                        // Grouped by topic with section headers
                        LazyVStack(alignment: .leading, spacing: 20) {
                            ForEach(newsByTopic, id: \.topic) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    // Section Header
                                    HStack(spacing: 8) {
                                        Image(systemName: group.topic.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppColors.accent)

                                        Text(group.topic.displayName)
                                            .font(.headline)
                                            .foregroundColor(AppColors.textPrimary(colorScheme))

                                        Text("\(group.items.count)")
                                            .font(.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(
                                                colorScheme == .dark
                                                    ? Color.white.opacity(0.1)
                                                    : Color.black.opacity(0.05)
                                            )
                                            .cornerRadius(10)

                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)

                                    // News items for this topic
                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                        NavigationLink(destination: NewsDetailView(allNews: group.items, initialIndex: index)) {
                                            NewsListRow(news: item)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                    } else {
                        // Flat list sorted by time (original behavior)
                        let sortedNews = filteredNews.sorted { $0.publishedAt > $1.publishedAt }
                        LazyVStack(spacing: 12) {
                            ForEach(Array(sortedNews.enumerated()), id: \.element.id) { index, item in
                                NavigationLink(destination: NewsDetailView(allNews: sortedNews, initialIndex: index)) {
                                    NewsListRow(news: item)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 100)
                }
            }
        }
        .navigationTitle("Daily News")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

// MARK: - News Filter Chip
struct NewsFilterChip: View {
    let title: String
    var icon: String? = nil
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.textSecondary)
            }
            .foregroundColor(isSelected ? .white : AppColors.textPrimary(colorScheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? AppColors.accent
                    : (colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
            )
            .cornerRadius(20)
        }
    }
}

// MARK: - News List Row
struct NewsListRow: View {
    let news: NewsItem
    @Environment(\.colorScheme) var colorScheme

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var isRead: Bool { ReadArticlesStore.shared.isRead(news.url) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with source
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: news.sourceType.icon)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.accent)

                    if news.sourceType == .twitter, let handle = news.twitterHandle {
                        Text("@\(handle)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        if news.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.accent)
                        }
                    } else {
                        Text(news.source)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }
                }

                Spacer()

                if isRead {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.success)
                }

                Text(news.timeAgo)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Title
            Text(news.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .opacity(isRead ? 0.6 : 1.0)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Chevron indicator
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(ArkSpacing.Radius.card)
        .arkShadow(ArkSpacing.Shadow.card)
    }
}

// MARK: - News Detail View
struct NewsDetailView: View {
    let allNews: [NewsItem]
    let initialIndex: Int
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) var openURL
    @State private var currentIndex: Int = 0

    // Single-article convenience init
    init(news: NewsItem) {
        self.allNews = [news]
        self.initialIndex = 0
    }

    init(allNews: [NewsItem], initialIndex: Int) {
        self.allNews = allNews
        self.initialIndex = initialIndex
    }

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(allNews.enumerated()), id: \.element.id) { index, item in
                NewsArticlePage(news: item, articleCount: allNews.count)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: allNews.count > 1 ? .automatic : .never))
        .indexViewStyle(.page(backgroundDisplayMode: .automatic))
        .navigationTitle("\(currentIndex + 1) of \(allNews.count)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { currentIndex = initialIndex }
    }
}

// MARK: - Single Article Page
private struct NewsArticlePage: View {
    let news: NewsItem
    var articleCount: Int = 1
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) var openURL

    @State private var summary: String?
    @State private var isSummaryLoading = false
    @State private var summaryError: String?

    private var readStore: ReadArticlesStore { ReadArticlesStore.shared }

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: news.publishedAt)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Source + date header
                    HStack {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.accent.opacity(0.15))
                                    .frame(width: 40, height: 40)

                                Image(systemName: news.sourceType.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.accent)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    if news.sourceType == .twitter, let handle = news.twitterHandle {
                                        Text("@\(handle)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.textPrimary(colorScheme))
                                    } else {
                                        Text(news.source)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.textPrimary(colorScheme))
                                    }

                                    if news.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppColors.accent)
                                    }
                                }

                                Text(formattedDate)
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)

                    // Title card
                    VStack(alignment: .leading, spacing: 12) {
                        Text(news.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .background(cardBackground)
                    .cornerRadius(ArkSpacing.Radius.card)
                    .arkShadow(ArkSpacing.Shadow.card)
                    .padding(.horizontal, 20)

                    // Quick Summary card
                    if !news.url.isEmpty {
                        summaryCard
                    }

                    // Open in Browser button
                    if !news.url.isEmpty {
                        Button(action: {
                            if let url = URL(string: news.url) {
                                openURL(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "safari")
                                    .font(.system(size: 16))
                                Text("Read Full Article")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppColors.accent)
                            .cornerRadius(ArkSpacing.Radius.md)
                        }
                        .padding(.horizontal, 20)

                        // Mark as Read toggle
                        let isMarkedRead = readStore.isRead(news.url)
                        Button(action: { readStore.toggleRead(news.url) }) {
                            HStack {
                                Image(systemName: isMarkedRead ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16))
                                Text(isMarkedRead ? "Marked as Read" : "Mark as Read")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(isMarkedRead ? AppColors.success : AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.06)
                                    : Color.black.opacity(0.04)
                            )
                            .cornerRadius(ArkSpacing.Radius.md)
                        }
                        .padding(.horizontal, 20)
                    }

                    // Swipe hint
                    if articleCount > 1 {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .medium))
                            Text("Swipe for more articles")
                                .font(.caption)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 12)
            }
        }
        .task {
            readStore.markRead(news.url)
            await loadSummary()
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with read time
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accent)

                Text("Quick Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                if summary != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("45 sec read")
                            .font(.caption2)
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }

            if isSummaryLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating summary...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.vertical, 8)
            } else if let summary = summary {
                Text(summary)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.9))
                    .lineSpacing(6)

                Text("AI-generated summary")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    .padding(.top, 4)
            } else if let error = summaryError {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
            }
        }
        .padding(20)
        .background(cardBackground)
        .cornerRadius(ArkSpacing.Radius.card)
        .arkShadow(ArkSpacing.Shadow.card)
        .padding(.horizontal, 20)
    }

    // MARK: - Load Summary

    private func loadSummary() async {
        guard !news.url.isEmpty else { return }

        isSummaryLoading = true
        defer { isSummaryLoading = false }

        do {
            let result = try await ArticleSummaryService.shared.fetchSummary(
                url: news.url,
                title: news.title
            )
            summary = result
        } catch {
            summaryError = "Summary unavailable for this article. Tap below to read the full article in your browser."
        }
    }
}
