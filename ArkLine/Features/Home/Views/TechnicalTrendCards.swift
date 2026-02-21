import SwiftUI
import Kingfisher

// MARK: - Multi-Timeframe Trend Card
struct MultiTimeframeTrendCard: View {
    let trends: [AnalysisTimeframe: TrendAnalysis]
    let isLoading: Bool
    let colorScheme: ColorScheme
    @State private var showInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Trend Overview")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Button {
                    showInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }
                .accessibilityLabel("Info about Trend Overview")

                Spacer()
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading trends...")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
                .padding(.vertical, ArkSpacing.md)
            } else {
                HStack(spacing: ArkSpacing.sm) {
                    ForEach(AnalysisTimeframe.allCases) { timeframe in
                        TimeframeTrendCell(
                            timeframe: timeframe,
                            trend: trends[timeframe],
                            colorScheme: colorScheme
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .alert("Trend Overview", isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Shows the price trend across daily, weekly, and monthly timeframes. Signal bars indicate trend strength.")
        }
    }
}

// MARK: - Timeframe Trend Cell
struct TimeframeTrendCell: View {
    let timeframe: AnalysisTimeframe
    let trend: TrendAnalysis?
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 8) {
            // Timeframe label
            Text(timeframe.label)
                .font(.caption.bold())
                .foregroundColor(AppColors.textSecondary)

            if let trend = trend {
                // Trend icon
                ZStack {
                    Circle()
                        .fill(trend.direction.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: trend.direction.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(trend.direction.color)
                }

                // Trend label
                Text(trend.direction.shortLabel)
                    .font(.caption2.bold())
                    .foregroundColor(trend.direction.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Strength indicator (signal bars)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(index < trend.strength.level ? trend.direction.color : trend.direction.color.opacity(0.2))
                            .frame(width: 4, height: CGFloat(6 + (index * 4)))
                    }
                }
                .frame(height: 14)
            } else {
                // No data state
                ZStack {
                    Circle()
                        .fill(AppColors.textSecondary.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "minus")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textSecondary)
                }

                Text("N/A")
                    .font(.caption2.bold())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ArkSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
    }
}

// MARK: - Timeframe Picker
struct TimeframePicker: View {
    @Binding var selectedTimeframe: AnalysisTimeframe
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AnalysisTimeframe.allCases) { timeframe in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTimeframe = timeframe
                    }
                } label: {
                    Text(timeframe.label)
                        .font(.system(size: 14, weight: selectedTimeframe == timeframe ? .semibold : .medium))
                        .foregroundColor(selectedTimeframe == timeframe ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTimeframe == timeframe
                                ? AppColors.accent
                                : Color.clear
                        )
                }
                .accessibilityLabel("\(timeframe.label) timeframe\(selectedTimeframe == timeframe ? ", selected" : "")")
            }
        }
        .background(
            colorScheme == .dark
                ? Color(hex: "1F1F1F")
                : Color(hex: "F0F0F0")
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Asset Header Section
struct AssetHeaderSection: View {
    let asset: CryptoAsset
    let colorScheme: ColorScheme

    var isPositive: Bool { asset.priceChangePercentage24h >= 0 }

    var body: some View {
        HStack(spacing: ArkSpacing.md) {
            // Icon
            KFImage(URL(string: asset.iconUrl ?? ""))
                .resizable()
                .placeholder {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.fillPrimary, AppColors.accentLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text(asset.symbol.prefix(1))
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }
                }
                .fade(duration: 0.2)
                .aspectRatio(contentMode: .fit)
                .frame(width: 56, height: 56)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.title2.bold())
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(asset.currentPrice.asCryptoPrice)
                    .font(.title3)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Spacer()

            // Change badge
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.caption.bold())
                    Text("\(abs(asset.priceChangePercentage24h), specifier: "%.2f")%")
                        .font(.subheadline.bold())
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)

                Text("24h")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - Overall Sentiment Card
struct OverallSentimentCard: View {
    let analysis: TechnicalAnalysis
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Market Sentiment")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            HStack(spacing: ArkSpacing.lg) {
                AssetSentimentIndicatorView(
                    label: "Overall",
                    sentiment: analysis.sentiment.overall,
                    colorScheme: colorScheme
                )

                AssetSentimentIndicatorView(
                    label: "Short Term",
                    sentiment: analysis.sentiment.shortTerm,
                    colorScheme: colorScheme
                )

                AssetSentimentIndicatorView(
                    label: "Long Term",
                    sentiment: analysis.sentiment.longTerm,
                    colorScheme: colorScheme
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - Asset Sentiment Indicator View
struct AssetSentimentIndicatorView: View {
    let label: String
    let sentiment: AssetSentiment
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: sentiment.icon)
                .font(.title2)
                .foregroundColor(sentiment.color)
                .frame(width: 44, height: 44)
                .background(sentiment.color.opacity(0.15))
                .clipShape(Circle())

            Text(label)
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)

            Text(shortLabel(sentiment))
                .font(.caption.bold())
                .foregroundColor(sentiment.color)
        }
        .frame(maxWidth: .infinity)
    }

    private func shortLabel(_ sentiment: AssetSentiment) -> String {
        switch sentiment {
        case .stronglyBullish: return "Very Bullish"
        case .bullish: return "Bullish"
        case .neutral: return "Neutral"
        case .bearish: return "Bearish"
        case .stronglyBearish: return "Very Bearish"
        }
    }
}

// MARK: - Trend Analysis Card
struct TrendAnalysisCard: View {
    let trend: TrendAnalysis
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Trend Analysis")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                // Trend badge
                HStack(spacing: 6) {
                    Image(systemName: trend.direction.icon)
                        .font(.subheadline)
                    Text(trend.direction.rawValue)
                        .font(.subheadline.bold())
                }
                .foregroundColor(trend.direction.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(trend.direction.color.opacity(0.15))
                .clipShape(Capsule())
            }

            Divider()
                .background(AppColors.divider(colorScheme))

            // Trend details
            VStack(spacing: ArkSpacing.sm) {
                TrendDetailRow(
                    label: "Strength",
                    value: trend.strength.rawValue,
                    colorScheme: colorScheme
                )

                TrendDetailRow(
                    label: "Days in Trend",
                    value: "\(trend.daysInTrend) days",
                    colorScheme: colorScheme
                )

                TrendDetailRow(
                    label: "Higher Highs",
                    value: trend.higherHighs ? "Yes" : "No",
                    valueColor: trend.higherHighs ? AppColors.success : AppColors.error,
                    colorScheme: colorScheme
                )

                TrendDetailRow(
                    label: "Higher Lows",
                    value: trend.higherLows ? "Yes" : "No",
                    valueColor: trend.higherLows ? AppColors.success : AppColors.error,
                    colorScheme: colorScheme
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }
}

// MARK: - Trend Detail Row
struct TrendDetailRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil
    let colorScheme: ColorScheme

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(valueColor ?? AppColors.textPrimary(colorScheme))
        }
    }
}
