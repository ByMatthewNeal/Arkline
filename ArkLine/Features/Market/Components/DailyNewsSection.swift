import SwiftUI

// MARK: - Daily News Section
struct DailyNewsSection: View {
    @Environment(\.colorScheme) var colorScheme
    let news: [NewsItem]
    var onSeeAll: (() -> Void)? = nil

    // Group news by source type for filter tabs
    private var twitterNews: [NewsItem] {
        news.filter { $0.sourceType == .twitter }
    }

    private var googleNews: [NewsItem] {
        news.filter { $0.sourceType == .googleNews }
    }

    private var traditionalNews: [NewsItem] {
        news.filter { $0.sourceType == .traditional }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Daily News")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                NavigationLink(destination: AllNewsView(news: news)) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(AppColors.accent)
                }
            }
            .padding(.horizontal, 20)

            // Source Type Indicators
            HStack(spacing: 12) {
                NewsSourceBadge(sourceType: .twitter, count: twitterNews.count)
                NewsSourceBadge(sourceType: .googleNews, count: googleNews.count)
                NewsSourceBadge(sourceType: .traditional, count: traditionalNews.count)
            }
            .padding(.horizontal, 20)

            // Horizontal News Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(news) { item in
                        NavigationLink(destination: NewsDetailView(news: item)) {
                            DailyNewsCard(news: item)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - News Source Badge
struct NewsSourceBadge: View {
    let sourceType: NewsSourceType
    let count: Int
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: sourceType.icon)
                .font(.system(size: 10))
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            colorScheme == .dark
                ? Color.white.opacity(0.08)
                : Color.black.opacity(0.05)
        )
        .cornerRadius(8)
    }
}

// MARK: - Daily News Card (Simplified Dark Style)
struct DailyNewsCard: View {
    let news: NewsItem
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Source Type Badge with Icon - monochrome
            HStack(spacing: 6) {
                Image(systemName: news.sourceType.icon)
                    .font(.system(size: 10, weight: .medium))

                if news.sourceType == .twitter, let handle = news.twitterHandle {
                    Text("@\(handle)")
                        .font(.caption2)
                        .fontWeight(.medium)

                    if news.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.accent)
                    }
                } else {
                    Text(news.source)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                colorScheme == .dark
                    ? Color.white.opacity(0.08)
                    : Color.black.opacity(0.05)
            )
            .cornerRadius(4)
            .padding(.bottom, 8)

            // Time ago
            Text(news.timeAgo)
                .font(.caption2)
                .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.5))
                .padding(.bottom, 8)

            Spacer()

            // Title/Headline
            Text(news.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(width: 280, height: 160)
        .background(
            colorScheme == .dark
                ? Color(hex: "1A1A1A")
                : Color.white
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.06)
                        : Color.black.opacity(0.06),
                    lineWidth: 1
                )
        )
        .cornerRadius(16)
    }
}

// MARK: - Extended NewsItem for Daily News
extension NewsItem {
    var category: String {
        // Derive category from source or use default
        switch source.lowercased() {
        case "coindesk", "the block", "defillama":
            return "Crypto News"
        case "reuters", "bloomberg", "wsj":
            return "Macro News"
        case "techcrunch", "wired":
            return "Tech News"
        default:
            return "Market News"
        }
    }

    var headlines: [String] {
        // Split long title into bullet points or return as single item
        [title]
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }

    /// Detect the topic of this news item based on title keywords
    var detectedTopic: DetectedNewsTopic {
        let titleLower = title.lowercased()

        // Check for custom keywords first (user-defined)
        if let customKeywords = UserDefaults.standard.stringArray(forKey: Constants.UserDefaults.customNewsTopics) {
            for keyword in customKeywords {
                if titleLower.contains(keyword.lowercased()) {
                    return .custom(keyword)
                }
            }
        }

        // Check pre-defined topics
        if titleLower.contains("bitcoin") || titleLower.contains("btc") ||
           titleLower.contains("ethereum") || titleLower.contains("eth") ||
           titleLower.contains("crypto") || titleLower.contains("blockchain") {
            return .predefined(.crypto)
        }

        if titleLower.contains("fed") || titleLower.contains("powell") ||
           titleLower.contains("interest rate") || titleLower.contains("inflation") ||
           titleLower.contains("treasury") || titleLower.contains("fomc") ||
           titleLower.contains("central bank") || titleLower.contains("monetary") {
            return .predefined(.macroEconomy)
        }

        if titleLower.contains("stock") || titleLower.contains("s&p") ||
           titleLower.contains("nasdaq") || titleLower.contains("dow") ||
           titleLower.contains("equity") || titleLower.contains("earnings") {
            return .predefined(.stocks)
        }

        if titleLower.contains("ai") || titleLower.contains("artificial intelligence") ||
           titleLower.contains("nvidia") || titleLower.contains("openai") ||
           titleLower.contains("tech") || titleLower.contains("microsoft") ||
           titleLower.contains("google") || titleLower.contains("apple") {
            return .predefined(.techAI)
        }

        if titleLower.contains("trump") || titleLower.contains("china") ||
           titleLower.contains("russia") || titleLower.contains("iran") ||
           titleLower.contains("war") || titleLower.contains("tariff") ||
           titleLower.contains("sanctions") || titleLower.contains("geopolit") {
            return .predefined(.geopolitics)
        }

        if titleLower.contains("defi") || titleLower.contains("decentralized finance") ||
           titleLower.contains("yield") || titleLower.contains("liquidity") {
            return .predefined(.defi)
        }

        if titleLower.contains("nft") || titleLower.contains("non-fungible") ||
           titleLower.contains("collectible") || titleLower.contains("opensea") {
            return .predefined(.nfts)
        }

        if titleLower.contains("sec") || titleLower.contains("regulat") ||
           titleLower.contains("cftc") || titleLower.contains("legislation") ||
           titleLower.contains("compliance") || titleLower.contains("law") {
            return .predefined(.regulation)
        }

        return .other
    }
}

// MARK: - Detected News Topic
enum DetectedNewsTopic: Hashable {
    case predefined(Constants.NewsTopic)
    case custom(String)
    case other

    var displayName: String {
        switch self {
        case .predefined(let topic):
            return topic.displayName
        case .custom(let keyword):
            return keyword.capitalized
        case .other:
            return "Other"
        }
    }

    var icon: String {
        switch self {
        case .predefined(let topic):
            return topic.icon
        case .custom:
            return "tag.fill"
        case .other:
            return "newspaper"
        }
    }

    var sortOrder: Int {
        switch self {
        case .predefined(let topic):
            switch topic {
            case .crypto: return 0
            case .macroEconomy: return 1
            case .geopolitics: return 2
            case .stocks: return 3
            case .techAI: return 4
            case .defi: return 5
            case .regulation: return 6
            case .nfts: return 7
            }
        case .custom: return 8
        case .other: return 9
        }
    }
}

// MARK: - News View Mode
enum NewsViewMode: String, CaseIterable {
    case byTime = "Latest"
    case byTopic = "Topics"
}

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
                                Text("Open in Browser")
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
    }
}

#Preview {
    VStack {
        DailyNewsSection(
            news: [
                // Twitter source
                NewsItem(
                    id: UUID(),
                    title: "BREAKING: 🚨 Whale Alert - 1,500 BTC ($145M) transferred from unknown wallet to Coinbase",
                    source: "Whale Alert",
                    publishedAt: Date().addingTimeInterval(-300), // 5 min ago
                    imageUrl: nil,
                    url: "",
                    sourceType: .twitter,
                    twitterHandle: "whale_alert",
                    isVerified: true
                ),
                // Google News source
                NewsItem(
                    id: UUID(),
                    title: "Bitcoin ETF inflows hit record $1.2B as institutional adoption accelerates",
                    source: "Google News",
                    publishedAt: Date().addingTimeInterval(-1800), // 30 min ago
                    imageUrl: nil,
                    url: "",
                    sourceType: .googleNews
                ),
                // Traditional source
                NewsItem(
                    id: UUID(),
                    title: "Federal Reserve signals potential rate changes in upcoming meeting",
                    source: "Bloomberg",
                    publishedAt: Date().addingTimeInterval(-3600), // 1 hr ago
                    imageUrl: nil,
                    url: "",
                    sourceType: .traditional
                ),
                // Another Twitter source
                NewsItem(
                    id: UUID(),
                    title: "*CHINA CONFIRMS US TARIFF EXCLUSIONS - SOURCES",
                    source: "DeItaone",
                    publishedAt: Date().addingTimeInterval(-600), // 10 min ago
                    imageUrl: nil,
                    url: "",
                    sourceType: .twitter,
                    twitterHandle: "DeItaone",
                    isVerified: true
                )
            ]
        )
    }
    .background(Color(hex: "0F0F0F"))
}
