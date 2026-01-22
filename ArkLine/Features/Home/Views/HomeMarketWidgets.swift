import SwiftUI

// MARK: - Home Fed Watch Widget
/// Compact Fed Watch widget for the Home screen
struct HomeFedWatchWidget: View {
    let meetings: [FedWatchData]
    var size: WidgetSize = .standard
    @State private var showInfoSheet = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var nextMeeting: FedWatchData? {
        meetings.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "building.columns")
                        .font(.system(size: size == .compact ? 12 : 14))
                        .foregroundColor(Color(hex: "2E7D32"))

                    Text("Fed Watch")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)
                }

                Spacer()

                Button(action: { showInfoSheet = true }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(textPrimary.opacity(0.4))
                }
            }

            if let meeting = nextMeeting {
                VStack(alignment: .leading, spacing: size == .compact ? 6 : 10) {
                    // Meeting date
                    HStack {
                        Text("Next FOMC: \(meeting.meetingDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: size == .compact ? 11 : 13))
                            .foregroundColor(textPrimary.opacity(0.6))

                        Spacer()

                        // Sentiment badge
                        Text(meeting.marketSentiment)
                            .font(.system(size: size == .compact ? 9 : 10, weight: .semibold))
                            .foregroundColor(meeting.sentimentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(meeting.sentimentColor.opacity(0.15))
                            )
                    }

                    // Probability bars
                    if size != .compact {
                        HStack(spacing: 8) {
                            HomeProbabilityPill(label: "Cut", probability: meeting.cutProbability, color: AppColors.success)
                            HomeProbabilityPill(label: "Hold", probability: meeting.holdProbability, color: AppColors.warning)
                            HomeProbabilityPill(label: "Hike", probability: meeting.hikeProbability, color: AppColors.error)
                        }
                    } else {
                        // Compact: just show dominant probability
                        HStack(spacing: 4) {
                            Text(meeting.dominantOutcome)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(textPrimary)
                            Text("\(Int(meeting.dominantProbability))%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(meeting.dominantColor)
                        }
                    }

                    if size == .expanded && meetings.count > 1 {
                        Divider()
                            .background(textPrimary.opacity(0.1))
                            .padding(.vertical, 4)

                        // Show next 2 meetings
                        ForEach(meetings.dropFirst().prefix(2), id: \.meetingDate) { futureMeeting in
                            HStack {
                                Text(futureMeeting.meetingDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.system(size: 11))
                                    .foregroundColor(textPrimary.opacity(0.5))

                                Spacer()

                                Text("\(futureMeeting.dominantOutcome) \(Int(futureMeeting.dominantProbability))%")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(futureMeeting.dominantColor)
                            }
                        }
                    }
                }
                .padding(size == .compact ? 10 : 14)
                .background(
                    RoundedRectangle(cornerRadius: size == .compact ? 10 : 12)
                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F8F8F8"))
                )
            }
        }
        .padding(size == .compact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .sheet(isPresented: $showInfoSheet) {
            FedWatchInfoSheet()
        }
    }
}

// MARK: - Probability Pill
struct HomeProbabilityPill: View {
    let label: String
    let probability: Double
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(textPrimary.opacity(0.5))

            Text("\(Int(probability))%")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Home Daily News Widget
/// Compact Daily News widget for the Home screen
struct HomeDailyNewsWidget: View {
    let news: [NewsItem]
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var maxItems: Int {
        switch size {
        case .compact: return 1
        case .standard: return 3
        case .expanded: return 5
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "newspaper")
                        .font(.system(size: size == .compact ? 12 : 14))
                        .foregroundColor(Color(hex: "1976D2"))

                    Text("Daily News")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)
                }

                Spacer()

                NavigationLink(destination: Text("Full News List")) {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.accent)
                }
            }

            // News items
            VStack(spacing: 0) {
                ForEach(Array(news.prefix(maxItems).enumerated()), id: \.element.id) { index, item in
                    HomeNewsRow(item: item, isCompact: size == .compact)

                    if index < min(maxItems, news.count) - 1 {
                        Divider()
                            .background(textPrimary.opacity(0.1))
                    }
                }
            }
            .padding(size == .compact ? 10 : 12)
            .background(
                RoundedRectangle(cornerRadius: size == .compact ? 10 : 12)
                    .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F8F8F8"))
            )
        }
        .padding(size == .compact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Home News Row
struct HomeNewsRow: View {
    let item: NewsItem
    var isCompact: Bool = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
            Text(item.title)
                .font(.system(size: isCompact ? 12 : 13, weight: .medium))
                .foregroundColor(textPrimary)
                .lineLimit(isCompact ? 1 : 2)

            HStack(spacing: 6) {
                Text(item.source)
                    .font(.system(size: isCompact ? 9 : 10))
                    .foregroundColor(textPrimary.opacity(0.5))

                Text("•")
                    .font(.system(size: 8))
                    .foregroundColor(textPrimary.opacity(0.3))

                Text(item.publishedAt.timeAgoDisplay())
                    .font(.system(size: isCompact ? 9 : 10))
                    .foregroundColor(textPrimary.opacity(0.5))
            }
        }
        .padding(.vertical, isCompact ? 4 : 8)
    }
}

// MARK: - Home Market Sentiment Widget
/// Compact Market Sentiment widget for the Home screen
struct HomeMarketSentimentWidget: View {
    @Bindable var viewModel: SentimentViewModel
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: size == .compact ? 12 : 14))
                        .foregroundColor(Color(hex: "9C27B0"))

                    Text("Market Sentiment")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)
                }

                Spacer()

                // Sentiment tier badge
                Text(viewModel.overallSentimentTier.rawValue)
                    .font(.system(size: size == .compact ? 9 : 10, weight: .semibold))
                    .foregroundColor(Color(hex: viewModel.overallSentimentTier.color))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(hex: viewModel.overallSentimentTier.color).opacity(0.15))
                    )
            }

            // Content based on size
            if size == .compact {
                // Compact: just Fear & Greed
                if let fg = viewModel.fearGreedIndex {
                    HStack {
                        Text("Fear & Greed")
                            .font(.system(size: 11))
                            .foregroundColor(textPrimary.opacity(0.6))

                        Spacer()

                        Text("\(fg.value)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: fg.level.color))

                        Text(fg.level.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: fg.level.color))
                    }
                }
            } else {
                // Standard/Expanded: show multiple indicators
                VStack(spacing: 8) {
                    // Fear & Greed
                    if let fg = viewModel.fearGreedIndex {
                        SentimentIndicatorRow(
                            label: "Fear & Greed",
                            value: "\(fg.value)",
                            subValue: fg.level.rawValue,
                            color: Color(hex: fg.level.color)
                        )
                    }

                    // Bitcoin Season
                    SentimentIndicatorRow(
                        label: "Season",
                        value: viewModel.isBitcoinSeason ? "Bitcoin" : "Altcoin",
                        subValue: nil,
                        color: viewModel.isBitcoinSeason ? Color(hex: "F7931A") : AppColors.meshPurple
                    )

                    if size == .expanded {
                        // App Store Ranking (top exchange)
                        if let topRanking = viewModel.primaryAppRanking {
                            SentimentIndicatorRow(
                                label: "Coinbase Rank",
                                value: "#\(topRanking.ranking)",
                                subValue: topRanking.change > 0 ? "+\(topRanking.change)" : "\(topRanking.change)",
                                color: topRanking.change > 0 ? AppColors.success : (topRanking.change < 0 ? AppColors.error : textPrimary)
                            )
                        }

                        // Google Trends
                        if let trends = viewModel.googleTrends {
                            SentimentIndicatorRow(
                                label: "Search Interest",
                                value: "\(trends.currentIndex)",
                                subValue: trends.trend.rawValue,
                                color: trends.trend == .rising ? AppColors.success : (trends.trend == .falling ? AppColors.error : textPrimary)
                            )
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F8F8F8"))
                )
            }
        }
        .padding(size == .compact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Sentiment Indicator Row
struct SentimentIndicatorRow: View {
    let label: String
    let value: String
    let subValue: String?
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(textPrimary.opacity(0.6))

            Spacer()

            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)

                if let sub = subValue {
                    Text(sub)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(color.opacity(0.8))
                }
            }
        }
    }
}


// MARK: - Home Derivatives Widget
/// Compact Derivatives widget for the Home screen
struct HomeDerivativesWidget: View {
    let overview: DerivativesOverview?
    var size: WidgetSize = .standard
    let isLoading: Bool
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: size == .compact ? 12 : 14))
                        .foregroundColor(AppColors.accent)

                    Text("Derivatives")
                        .font(size == .compact ? .subheadline : .headline)
                        .foregroundColor(textPrimary)
                }

                Spacer()

                if let overview = overview {
                    Text(overview.lastUpdated.formatted(.relative(presentation: .numeric)))
                        .font(.caption2)
                        .foregroundColor(textPrimary.opacity(0.4))
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                    Spacer()
                }
                .frame(height: size == .compact ? 40 : 60)
            } else if let overview = overview {
                VStack(spacing: size == .compact ? 6 : 10) {
                    if size == .compact {
                        // Compact: Show only liquidations summary
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("24h Liquidations")
                                    .font(.system(size: 10))
                                    .foregroundColor(textPrimary.opacity(0.6))
                                Text(overview.totalLiquidations24h.formattedTotal)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(textPrimary)
                            }

                            Spacer()

                            // Long/Short mini indicator
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(AppColors.success)
                                    .frame(width: 8, height: 8)
                                Text("\(Int(overview.totalLiquidations24h.longPercentage))%")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(AppColors.success)

                                Circle()
                                    .fill(AppColors.error)
                                    .frame(width: 8, height: 8)
                                Text("\(Int(overview.totalLiquidations24h.shortPercentage))%")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(AppColors.error)
                            }
                        }
                    } else {
                        // Standard/Expanded: Show more details
                        HStack(spacing: 12) {
                            // Liquidations
                            DerivativesMiniCard(
                                title: "Liquidations",
                                value: overview.totalLiquidations24h.formattedTotal,
                                icon: "flame",
                                iconColor: AppColors.error
                            )

                            // Open Interest Change
                            DerivativesMiniCard(
                                title: "BTC OI",
                                value: overview.btcOpenInterest.formattedOI,
                                subtitle: "\(overview.btcOpenInterest.isPositiveChange ? "+" : "")\(String(format: "%.1f", overview.btcOpenInterest.openInterestChangePercent24h))%",
                                subtitleColor: overview.btcOpenInterest.isPositiveChange ? AppColors.success : AppColors.error,
                                icon: "chart.pie",
                                iconColor: AppColors.accent
                            )
                        }

                        if size == .expanded {
                            HStack(spacing: 12) {
                                // Funding Rate
                                DerivativesMiniCard(
                                    title: "BTC Funding",
                                    value: overview.btcFundingRate.formattedRate,
                                    subtitle: overview.btcFundingRate.sentiment.rawValue,
                                    subtitleColor: Color(hex: overview.btcFundingRate.sentiment.color.replacingOccurrences(of: "#", with: "")),
                                    icon: "percent",
                                    iconColor: AppColors.warning
                                )

                                // Long/Short Ratio
                                DerivativesMiniCard(
                                    title: "BTC L/S",
                                    value: overview.btcLongShortRatio.formattedRatio,
                                    subtitle: overview.btcLongShortRatio.sentiment.rawValue,
                                    subtitleColor: Color(hex: overview.btcLongShortRatio.sentiment.color.replacingOccurrences(of: "#", with: "")),
                                    icon: "arrow.left.arrow.right",
                                    iconColor: AppColors.accent
                                )
                            }
                        }
                    }
                }
                .padding(size == .compact ? 10 : 14)
                .background(
                    RoundedRectangle(cornerRadius: size == .compact ? 10 : 12)
                        .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F8F8F8"))
                )
            } else {
                // Empty state
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 20))
                            .foregroundColor(textPrimary.opacity(0.3))
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(textPrimary.opacity(0.4))
                    }
                    Spacer()
                }
                .frame(height: size == .compact ? 40 : 60)
            }
        }
        .padding(size == .compact ? 12 : 16)
        .background(
            RoundedRectangle(cornerRadius: size == .compact ? 14 : 20)
                .fill(cardBackground)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Derivatives Mini Card
struct DerivativesMiniCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var subtitleColor: Color = AppColors.textSecondary
    let icon: String
    let iconColor: Color
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(textPrimary.opacity(0.6))
            }

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(textPrimary)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(subtitleColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            HomeFedWatchWidget(
                meetings: [],
                size: .standard
            )

            HomeDailyNewsWidget(
                news: [],
                size: .standard
            )

            HomeDerivativesWidget(
                overview: nil,
                size: .standard,
                isLoading: false
            )
        }
        .padding()
    }
    .background(Color(hex: "141414"))
}
