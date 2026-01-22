import SwiftUI

struct SentimentCard: View {
    let data: SentimentCardData
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header - simplified monochrome icon
            HStack {
                Image(systemName: data.icon)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(
                        colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.black.opacity(0.05)
                    )
                    .cornerRadius(8)

                Spacer()

                if let change = data.change {
                    HStack(spacing: 2) {
                        Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8, weight: .bold))

                        Text("\(abs(change), specifier: "%.1f")")
                            .font(.caption2)
                    }
                    .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                }
            }

            // Title
            Text(data.title)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            // Value
            Text(data.value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            // Subtitle - simplified neutral badge
            Text(data.subtitle)
                .font(.caption2)
                .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.05)
                )
                .cornerRadius(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Large Sentiment Card
struct LargeSentimentCard: View {
    @Environment(\.colorScheme) var colorScheme
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
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: 12) {
                        Text(data.value)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        if let change = data.change {
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption)

                                Text("\(abs(change), specifier: "%.1f")")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                        }
                    }

                    Text(data.subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            colorScheme == .dark
                                ? Color.white.opacity(0.08)
                                : Color.black.opacity(0.05)
                        )
                        .cornerRadius(6)
                }

                Spacer()

                Image(systemName: data.icon)
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
            }

            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Sentiment Indicator
struct SentimentIndicator: View {
    @Environment(\.colorScheme) var colorScheme
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
                    .fill(
                        colorScheme == .dark
                            ? Color.white.opacity(0.1)
                            : Color.black.opacity(0.08)
                    )
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.accent)
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
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background - simplified monochrome
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(0.1)
                                : Color.black.opacity(0.08)
                        )
                        .frame(height: 8)

                    // Progress fill - blue accent
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.accent.opacity(0.5), AppColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * Double(value) / 100, height: 8)

                    // Marker
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                                .frame(width: 6, height: 6)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(x: (geometry.size.width - 14) * Double(value) / 100)
                }
            }
            .frame(height: 16)

            // Labels
            HStack {
                ForEach(labels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
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
