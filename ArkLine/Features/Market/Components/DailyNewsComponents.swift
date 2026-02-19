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

            if isDarkMode {
                BrushEffectOverlay()
            }

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
                            NewsFilterChip(
                                title: "Traditional",
                                icon: "newspaper",
                                count: news.filter { $0.sourceType == .traditional }.count,
                                isSelected: selectedFilter == .traditional,
                                action: { selectedFilter = .traditional }
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
                                    ForEach(group.items) { item in
                                        NavigationLink(destination: NewsDetailView(news: item)) {
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
                        LazyVStack(spacing: 12) {
                            ForEach(filteredNews.sorted { $0.publishedAt > $1.publishedAt }) { item in
                                NavigationLink(destination: NewsDetailView(news: item)) {
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

                Text(news.timeAgo)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Title
            Text(news.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
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
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - News Detail View
struct NewsDetailView: View {
    let news: NewsItem
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @Environment(\.openURL) var openURL

    @State private var summary: String?
    @State private var isSummaryLoading = false
    @State private var summaryError: String?

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

            if isDarkMode {
                BrushEffectOverlay()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Source card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            // Source icon and name
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.accent.opacity(0.15))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: news.sourceType.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(AppColors.accent)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        if news.sourceType == .twitter, let handle = news.twitterHandle {
                                            Text("@\(handle)")
                                                .font(.headline)
                                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                        } else {
                                            Text(news.source)
                                                .font(.headline)
                                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                        }

                                        if news.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppColors.accent)
                                        }
                                    }

                                    Text(news.sourceType.displayName)
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }

                            Spacer()

                            // Source type badge
                            Text(news.sourceType.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    colorScheme == .dark
                                        ? Color.white.opacity(0.1)
                                        : Color.black.opacity(0.05)
                                )
                                .cornerRadius(8)
                        }

                        // Timestamp
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(20)
                    .background(cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)

                    // Content card
                    VStack(alignment: .leading, spacing: 16) {
                        Text(news.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .lineSpacing(4)

                        // If there's additional content/description
                        if let description = news.description, !description.isEmpty {
                            Divider()

                            Text(description)
                                .font(.body)
                                .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.9))
                                .lineSpacing(6)
                        }
                    }
                    .padding(20)
                    .background(cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
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
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("News")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadSummary()
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.accent)

                Text("Quick Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()
            }

            if isSummaryLoading {
                // Loading state
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating summary...")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.vertical, 8)
            } else if let summary = summary {
                // Summary content
                Text(summary)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.9))
                    .lineSpacing(6)

                // Disclaimer
                Text("AI-generated summary")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                    .padding(.top, 4)
            } else if let error = summaryError {
                // Error state
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
            }
        }
        .padding(20)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
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
