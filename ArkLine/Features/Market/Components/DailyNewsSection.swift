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
            if news.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "newspaper")
                            .font(.title2)
                            .foregroundColor(AppColors.textSecondary)
                        Text("No news available")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(news.enumerated()), id: \.element.id) { index, item in
                            NavigationLink(destination: NewsDetailView(allNews: news, initialIndex: index)) {
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

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var timeAgo: String {
        Self.relativeFormatter.localizedString(for: publishedAt, relativeTo: Date())
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
