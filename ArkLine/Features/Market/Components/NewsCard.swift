import SwiftUI

struct NewsCard: View {
    let news: NewsItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageUrl = news.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(hex: "2A2A2A"))
                }
                .frame(width: 80, height: 80)
                .cornerRadius(8)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "6366F1").opacity(0.3), Color(hex: "8B5CF6").opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "6366F1"))
                }
                .frame(width: 80, height: 80)
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(news.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack {
                    Text(news.source)
                        .font(.caption)
                        .foregroundColor(Color(hex: "6366F1"))

                    Text("•")
                        .foregroundColor(Color(hex: "A1A1AA"))

                    Text(news.publishedAt.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(Color(hex: "A1A1AA"))
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(12)
    }
}

// MARK: - Featured News Card
struct FeaturedNewsCard: View {
    let news: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image
            if let imageUrl = news.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(hex: "2A2A2A"))
                }
                .frame(height: 180)
                .cornerRadius(12)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(height: 180)
            }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(news.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack {
                    Text(news.source)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "6366F1"))

                    Spacer()

                    Text(news.publishedAt.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(Color(hex: "A1A1AA"))
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(16)
    }
}

// MARK: - Compact News Row
struct CompactNewsRow: View {
    let title: String
    let source: String
    let time: Date

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: "6366F1"))
                .frame(width: 8, height: 8)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            Text(time.timeAgoDisplay())
                .font(.caption2)
                .foregroundColor(Color(hex: "A1A1AA"))
        }
    }
}

// MARK: - Time Ago Extension
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    VStack(spacing: 16) {
        NewsCard(
            news: NewsItem(
                id: UUID(),
                title: "Bitcoin Surges Past $67,000 Amid ETF Inflows",
                source: "CoinDesk",
                publishedAt: Date().addingTimeInterval(-3600),
                imageUrl: nil,
                url: "https://coindesk.com"
            )
        )

        FeaturedNewsCard(
            news: NewsItem(
                id: UUID(),
                title: "Ethereum Layer 2 Networks See Record Activity as Adoption Grows",
                source: "The Block",
                publishedAt: Date().addingTimeInterval(-7200),
                imageUrl: nil,
                url: "https://theblock.co"
            )
        )

        CompactNewsRow(
            title: "Federal Reserve Signals Potential Rate Cut",
            source: "Reuters",
            time: Date().addingTimeInterval(-14400)
        )
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
