import SwiftUI

// MARK: - Daily News Section
struct DailyNewsSection: View {
    @Environment(\.colorScheme) var colorScheme
    let news: [NewsItem]
    var onSeeAll: (() -> Void)? = nil

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
                        .foregroundColor(Color(hex: "6366F1"))
                    }
                }
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

// MARK: - Daily News Card (Gradient Style)
struct DailyNewsCard: View {
    let news: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category Badge
            Text(news.category.uppercased())
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2))
                .cornerRadius(4)
                .padding(.bottom, 12)

            Spacer()

            // Headlines
            VStack(alignment: .leading, spacing: 6) {
                ForEach(news.headlines.prefix(2), id: \.self) { headline in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)

                        Text(headline)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 280, height: 160)
        .background(
            LinearGradient(
                colors: gradientColors(for: news.category),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    private func gradientColors(for category: String) -> [Color] {
        switch category.lowercased() {
        case "macro news":
            return [Color(hex: "1A4D3E"), Color(hex: "0D2B23")]
        case "market news":
            return [Color(hex: "2A1A4D"), Color(hex: "1A0D2B")]
        case "crypto news":
            return [Color(hex: "4D3A1A"), Color(hex: "2B1A0D")]
        case "tech news":
            return [Color(hex: "1A2A4D"), Color(hex: "0D1A2B")]
        default:
            return [Color(hex: "1F3D4D"), Color(hex: "0D1F2B")]
        }
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
}

#Preview {
    VStack {
        DailyNewsSection(
            news: [
                NewsItem(
                    id: UUID(),
                    title: "China confirms US tariff exclusions amid trade tensions",
                    source: "Reuters",
                    publishedAt: Date(),
                    imageUrl: nil,
                    url: ""
                ),
                NewsItem(
                    id: UUID(),
                    title: "Bitcoin nears ATH with huge volume spike",
                    source: "CoinDesk",
                    publishedAt: Date(),
                    imageUrl: nil,
                    url: ""
                ),
                NewsItem(
                    id: UUID(),
                    title: "Federal Reserve signals potential rate changes",
                    source: "Bloomberg",
                    publishedAt: Date(),
                    imageUrl: nil,
                    url: ""
                )
            ]
        )
    }
    .background(Color(hex: "0F0F0F"))
}
