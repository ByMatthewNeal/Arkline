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

                if let onSeeAll = onSeeAll {
                    Button(action: onSeeAll) {
                        HStack(spacing: 4) {
                            Text("See All")
                                .font(.caption)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundColor(AppColors.accent)
                    }
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
                        DailyNewsCard(news: item)
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
