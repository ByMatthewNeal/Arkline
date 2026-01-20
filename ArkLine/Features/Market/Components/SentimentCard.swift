import SwiftUI

struct SentimentCard: View {
    let data: SentimentCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: data.icon)
                    .font(.system(size: 16))
                    .foregroundColor(data.color)
                    .frame(width: 32, height: 32)
                    .background(data.color.opacity(0.15))
                    .cornerRadius(8)

                Spacer()

                if let change = data.change {
                    HStack(spacing: 2) {
                        Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8, weight: .bold))

                        Text("\(abs(change), specifier: "%.1f")")
                            .font(.caption2)
                    }
                    .foregroundColor(change >= 0 ? Color(hex: "22C55E") : Color(hex: "EF4444"))
                }
            }

            // Title
            Text(data.title)
                .font(.caption)
                .foregroundColor(Color(hex: "A1A1AA"))

            // Value
            Text(data.value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            // Subtitle
            Text(data.subtitle)
                .font(.caption2)
                .foregroundColor(data.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(data.color.opacity(0.15))
                .cornerRadius(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(16)
    }
}

// MARK: - Large Sentiment Card
struct LargeSentimentCard: View {
    let data: SentimentCardData
    let detail: String?

    init(data: SentimentCardData, detail: String? = nil) {
        self.data = data
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(data.title)
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "A1A1AA"))

                    HStack(spacing: 12) {
                        Text(data.value)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)

                        if let change = data.change {
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption)

                                Text("\(abs(change), specifier: "%.1f")")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(change >= 0 ? Color(hex: "22C55E") : Color(hex: "EF4444"))
                        }
                    }

                    Text(data.subtitle)
                        .font(.caption)
                        .foregroundColor(data.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(data.color.opacity(0.15))
                        .cornerRadius(6)
                }

                Spacer()

                Image(systemName: data.icon)
                    .font(.system(size: 40))
                    .foregroundColor(data.color.opacity(0.5))
            }

            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(Color(hex: "A1A1AA"))
            }
        }
        .padding(20)
        .background(Color(hex: "1F1F1F"))
        .cornerRadius(16)
    }
}

// MARK: - Sentiment Indicator
struct SentimentIndicator: View {
    let value: Int
    let maxValue: Int
    let color: Color

    var progress: Double {
        Double(value) / Double(maxValue)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "2A2A2A"))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geometry.size.width * progress, height: 8)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Sentiment Scale
struct SentimentScale: View {
    let value: Int
    let labels: [String]

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background gradient
                    LinearGradient(
                        colors: [
                            Color(hex: "EF4444"),
                            Color(hex: "F97316"),
                            Color(hex: "EAB308"),
                            Color(hex: "84CC16"),
                            Color(hex: "22C55E")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 8)
                    .cornerRadius(4)

                    // Marker
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(x: (geometry.size.width - 16) * Double(value) / 100)
                }
            }
            .frame(height: 16)

            // Labels
            HStack {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(Color(hex: "A1A1AA"))
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SentimentCard(
            data: SentimentCardData(
                id: "fear_greed",
                title: "Fear & Greed",
                value: "65",
                subtitle: "Greed",
                change: 3,
                icon: "gauge.with.needle.fill",
                color: Color(hex: "22C55E")
            )
        )

        LargeSentimentCard(
            data: SentimentCardData(
                id: "fear_greed",
                title: "Fear & Greed Index",
                value: "65",
                subtitle: "Greed",
                change: 3,
                icon: "gauge.with.needle.fill",
                color: Color(hex: "22C55E")
            ),
            detail: "Market sentiment is currently in greed territory"
        )

        SentimentScale(
            value: 65,
            labels: ["Fear", "Neutral", "Greed"]
        )
        .padding(.horizontal, 20)
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
