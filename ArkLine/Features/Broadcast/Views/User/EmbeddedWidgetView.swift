import SwiftUI

// MARK: - Embedded Widget View

/// Displays live data widgets inline within broadcast content.
/// Provides compact, read-only versions of app section widgets.
struct EmbeddedWidgetView: View {
    let section: AppSection
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = EmbeddedWidgetViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Header
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: section.iconName)
                    .font(.caption)
                    .foregroundColor(AppColors.accent)

                Text(section.displayName)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            // Widget Content
            widgetContent
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
        .task {
            await viewModel.loadData(for: section)
        }
    }

    // MARK: - Widget Content

    @ViewBuilder
    private var widgetContent: some View {
        switch section {
        // Home Indicators
        case .arklineRiskScore:
            arklineRiskScoreWidget
        case .fearGreed:
            fearGreedWidget
        case .bitcoinRisk:
            bitcoinRiskWidget
        case .coreAssets:
            coreAssetsWidget
        case .supplyInProfit:
            supplyInProfitWidget
        case .fedWatch:
            fedWatchWidget
        case .dailyNews:
            dailyNewsWidget
        case .upcomingEvents:
            upcomingEventsWidget
        case .dcaReminders:
            genericSectionWidget(title: "DCA Reminders", subtitle: "Your scheduled buys")
        case .favorites:
            genericSectionWidget(title: "Favorites", subtitle: "Your watchlist assets")
        case .macroDashboard:
            macroDashboardWidget
        // Macro & Economy
        case .vix:
            vixWidget
        case .dxy:
            dxyWidget
        case .m2:
            m2Widget
        case .macroRegime:
            macroRegimeWidget
        // Sentiment & Retail
        case .sentimentOverview:
            sentimentOverviewWidget
        case .sentimentRegime:
            sentimentRegimeWidget
        case .coinbaseRanking:
            coinbaseRankingWidget
        case .bitcoinSearchIndex:
            bitcoinSearchWidget
        // Positioning & Allocation
        case .cryptoPositioning:
            cryptoPositioningWidget
        // Market Sections
        case .technicalAnalysis:
            technicalAnalysisWidget
        case .traditionalMarkets:
            traditionalMarketsWidget
        case .altcoinScreener:
            genericSectionWidget(title: "Altcoin Screener", subtitle: "Top & bottom 30D performers")
        case .portfolioShowcase:
            portfolioShowcaseWidget
        }
    }

    // MARK: - VIX Widget

    private var vixWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let vix = viewModel.vixData {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.2f", vix.value))
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(vixColor(vix.value))

                    Text(vixLabel(vix.value))
                        .font(ArkFonts.caption)
                        .foregroundColor(vixColor(vix.value))
                }

                Spacer()

                // Signal badge
                Text(vix.signalDescription)
                    .font(ArkFonts.caption)
                    .foregroundColor(vixColor(vix.value))
                    .padding(.horizontal, ArkSpacing.sm)
                    .padding(.vertical, ArkSpacing.xxs)
                    .background(vixColor(vix.value).opacity(0.1))
                    .cornerRadius(ArkSpacing.xs)
            } else {
                placeholderContent
            }
        }
    }

    private func vixColor(_ value: Double) -> Color {
        if value < 15 { return AppColors.success }
        if value < 20 { return Color(hex: "4ADE80") }
        if value < 25 { return AppColors.warning }
        return AppColors.error
    }

    private func vixLabel(_ value: Double) -> String {
        if value < 15 { return "Low Volatility" }
        if value < 20 { return "Normal" }
        if value < 25 { return "Elevated" }
        return "High Volatility"
    }

    // MARK: - DXY Widget

    private var dxyWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let dxy = viewModel.dxyData {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.2f", dxy.value))
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Dollar Index")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if let change = dxy.changePercent {
                    changeIndicator(change: change, inverted: true)
                }
            } else {
                placeholderContent
            }
        }
    }

    // MARK: - M2 Widget

    private var m2Widget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let m2 = viewModel.liquidityData {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatLiquidity(m2.current))
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    HStack(spacing: 4) {
                        Text(m2.monthlyChange >= 0 ? "+" : "")
                        Text(String(format: "%.1f%%", m2.monthlyChange))
                    }
                    .font(ArkFonts.caption)
                    .foregroundColor(m2.monthlyChange >= 0 ? AppColors.success : AppColors.error)
                }

                Spacer()

                Text(m2.monthlyChange > 0 ? "Expanding" : "Contracting")
                    .font(ArkFonts.caption)
                    .foregroundColor(m2.monthlyChange > 0 ? AppColors.success : AppColors.error)
                    .padding(.horizontal, ArkSpacing.sm)
                    .padding(.vertical, ArkSpacing.xxs)
                    .background((m2.monthlyChange > 0 ? AppColors.success : AppColors.error).opacity(0.1))
                    .cornerRadius(ArkSpacing.xs)
            } else {
                placeholderContent
            }
        }
    }

    private func formatLiquidity(_ value: Double) -> String {
        if value >= 1_000_000_000_000 {
            return String(format: "$%.1fT", value / 1_000_000_000_000)
        }
        return String(format: "$%.0fB", value / 1_000_000_000)
    }

    // MARK: - Bitcoin Risk Widget

    private var bitcoinRiskWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let risk = viewModel.riskLevel {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.3f", risk.riskLevel))
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(riskColor(risk.riskLevel))

                    Text(riskCategory(risk.riskLevel))
                        .font(ArkFonts.caption)
                        .foregroundColor(riskColor(risk.riskLevel))
                }

                Spacer()

                // Risk gauge mini
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 40, height: 40)

                    Circle()
                        .trim(from: 0, to: risk.riskLevel)
                        .stroke(riskColor(risk.riskLevel), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                }
            } else {
                placeholderContent
            }
        }
    }

    private func riskColor(_ value: Double) -> Color {
        if value < 0.25 { return AppColors.success }
        if value < 0.5 { return Color(hex: "4ADE80") }
        if value < 0.75 { return AppColors.warning }
        return AppColors.error
    }

    private func riskCategory(_ value: Double) -> String {
        if value < 0.25 { return "Low Risk" }
        if value < 0.5 { return "Moderate Risk" }
        if value < 0.75 { return "Elevated Risk" }
        return "High Risk"
    }

    // MARK: - Fear & Greed Widget

    private var fearGreedWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let fg = viewModel.fearGreedIndex {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(fg.value)")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(fearGreedColor(fg.value))

                    Text(fg.level.rawValue)
                        .font(ArkFonts.caption)
                        .foregroundColor(fearGreedColor(fg.value))
                }

                Spacer()

                // Mini gauge
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 40, height: 40)

                    Circle()
                        .trim(from: 0, to: Double(fg.value) / 100.0)
                        .stroke(fearGreedColor(fg.value), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))

                    Text("\(fg.value)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(fearGreedColor(fg.value))
                }
            } else {
                placeholderContent
            }
        }
    }

    private func fearGreedColor(_ value: Int) -> Color {
        if value < 25 { return AppColors.error }
        if value < 45 { return AppColors.warning }
        if value < 55 { return Color.gray }
        if value < 75 { return Color(hex: "4ADE80") }
        return AppColors.success
    }

    // MARK: - Upcoming Events Widget

    private var upcomingEventsWidget: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            if viewModel.upcomingEvents.isEmpty {
                Text("No upcoming events")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(viewModel.upcomingEvents.prefix(3)) { event in
                    HStack(spacing: ArkSpacing.sm) {
                        Circle()
                            .fill(impactColor(event.impact))
                            .frame(width: 6, height: 6)

                        Text(event.title)
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .lineLimit(1)

                        Spacer()

                        Text(formatEventDate(event.date))
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private func impactColor(_ impact: EventImpact) -> Color {
        switch impact {
        case .high: return AppColors.error
        case .medium: return AppColors.warning
        case .low: return AppColors.success
        }
    }

    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    // MARK: - ArkLine Risk Score Widget

    private var arklineRiskScoreWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let riskScore = viewModel.arklineRiskScore {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(riskScore.score)")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(riskScoreColor(riskScore.score))

                    Text(riskScore.tier.rawValue)
                        .font(ArkFonts.caption)
                        .foregroundColor(riskScoreColor(riskScore.score))
                }

                Spacer()

                Text(riskScore.recommendation)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
            } else {
                placeholderContent
            }
        }
    }

    private func riskScoreColor(_ score: Int) -> Color {
        if score < 25 { return AppColors.success }
        if score < 45 { return Color(hex: "4ADE80") }
        if score < 55 { return Color.gray }
        if score < 75 { return AppColors.warning }
        return AppColors.error
    }

    // MARK: - Core Assets Widget

    private var coreAssetsWidget: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            if viewModel.coreAssets.isEmpty {
                placeholderContent
            } else {
                ForEach(viewModel.coreAssets) { asset in
                    HStack(spacing: ArkSpacing.sm) {
                        Text(asset.symbol.uppercased())
                            .font(ArkFonts.bodySemibold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .frame(width: 40, alignment: .leading)

                        Text(formatCoreAssetPrice(asset.currentPrice))
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Spacer()

                        let change = asset.priceChangePercentage24h
                        HStack(spacing: 2) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2)
                            Text(String(format: "%.1f%%", abs(change)))
                                .font(ArkFonts.caption)
                        }
                        .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                    }
                }
            }
        }
    }

    private func formatCoreAssetPrice(_ price: Double) -> String {
        if price >= 1000 { return String(format: "$%,.0f", price) }
        if price >= 1 { return String(format: "$%.2f", price) }
        return String(format: "$%.4f", price)
    }

    // MARK: - Supply in Profit Widget

    private var supplyInProfitWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let supply = viewModel.supplyInProfit {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.1f%%", supply.value))
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(supplyColor(supply.value))

                    Text("BTC Supply in Profit")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                Text(supplySignal(supply.value))
                    .font(ArkFonts.caption)
                    .foregroundColor(supplyColor(supply.value))
                    .padding(.horizontal, ArkSpacing.sm)
                    .padding(.vertical, ArkSpacing.xxs)
                    .background(supplyColor(supply.value).opacity(0.1))
                    .cornerRadius(ArkSpacing.xs)
            } else {
                placeholderContent
            }
        }
    }

    private func supplyColor(_ value: Double) -> Color {
        if value > 95 { return AppColors.error }
        if value > 85 { return AppColors.warning }
        if value < 50 { return AppColors.success }
        return Color(hex: "4ADE80")
    }

    private func supplySignal(_ value: Double) -> String {
        if value > 95 { return "Overheated" }
        if value > 85 { return "Elevated" }
        if value < 50 { return "Opportunity" }
        return "Healthy"
    }

    // MARK: - Fed Watch Widget

    private var fedWatchWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let fedWatch = viewModel.fedWatchData {
                VStack(alignment: .leading, spacing: 2) {
                    Text(fedWatch.dominantOutcome)
                        .font(ArkFonts.bodySemibold)
                        .foregroundColor(fedWatch.dominantColor)

                    Text(fedWatch.nextMeetingFormatted)
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.0f%%", fedWatch.dominantProbability))
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(fedWatch.dominantColor)

                    Text(fedWatch.marketSentiment)
                        .font(ArkFonts.caption)
                        .foregroundColor(fedWatch.sentimentColor)
                }
            } else {
                placeholderContent
            }
        }
    }

    // MARK: - Daily News Widget

    private var dailyNewsWidget: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            if viewModel.newsHeadlines.isEmpty {
                placeholderContent
            } else {
                ForEach(viewModel.newsHeadlines.prefix(3)) { item in
                    HStack(spacing: ArkSpacing.sm) {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 4, height: 4)

                        Text(item.title)
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Macro Dashboard Widget

    private var macroDashboardWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let vix = viewModel.vixData {
                miniMetric(label: "VIX", value: String(format: "%.1f", vix.value), color: vixColor(vix.value))
            }
            if let dxy = viewModel.dxyData {
                miniMetric(label: "DXY", value: String(format: "%.1f", dxy.value), color: AppColors.textPrimary(colorScheme))
            }
            if let m2 = viewModel.liquidityData {
                miniMetric(label: "M2", value: formatLiquidity(m2.current), color: m2.monthlyChange > 0 ? AppColors.success : AppColors.error)
            }

            if viewModel.vixData == nil && viewModel.dxyData == nil && viewModel.liquidityData == nil {
                placeholderContent
            }
        }
    }

    private func miniMetric(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .default))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Macro Regime Widget

    private var macroRegimeWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let regime = viewModel.macroRegime {
                VStack(alignment: .leading, spacing: 2) {
                    Text(regime.quadrant.rawValue)
                        .font(ArkFonts.bodySemibold)
                        .foregroundColor(regime.quadrant.color)

                    HStack(spacing: ArkSpacing.sm) {
                        Text("Growth: \(Int(regime.growthScore))")
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Inflation: \(Int(regime.inflationScore))")
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                Text(regime.quadrant.shortLabel)
                    .font(ArkFonts.caption)
                    .foregroundColor(regime.quadrant.color)
                    .padding(.horizontal, ArkSpacing.sm)
                    .padding(.vertical, ArkSpacing.xxs)
                    .background(regime.quadrant.color.opacity(0.1))
                    .cornerRadius(ArkSpacing.xs)
            } else {
                placeholderContent
            }
        }
    }

    // MARK: - Sentiment Overview Widget

    private var sentimentOverviewWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let riskScore = viewModel.arklineRiskScore {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ArkLine Score")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text("\(riskScore.score)")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(riskScoreColor(riskScore.score))
                }
            }

            if let fg = viewModel.fearGreedIndex {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fear & Greed")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text("\(fg.value)")
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundColor(fearGreedColor(fg.value))
                }
            }

            Spacer()

            if viewModel.arklineRiskScore == nil && viewModel.fearGreedIndex == nil {
                placeholderContent
            }
        }
    }

    // MARK: - Sentiment Regime Widget

    private var sentimentRegimeWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let regime = viewModel.sentimentRegimeData {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: ArkSpacing.xs) {
                        Image(systemName: regime.currentRegime.icon)
                            .font(.caption)
                            .foregroundColor(Color(hex: regime.currentRegime.colorHex))
                        Text(regime.currentRegime.rawValue)
                            .font(ArkFonts.bodySemibold)
                            .foregroundColor(Color(hex: regime.currentRegime.colorHex))
                    }

                    HStack(spacing: ArkSpacing.sm) {
                        Text("Emotion: \(Int(regime.currentPoint.emotionScore))")
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text("Engagement: \(Int(regime.currentPoint.engagementScore))")
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()
            } else {
                placeholderContent
            }
        }
    }

    // MARK: - Coinbase Ranking Widget

    private var coinbaseRankingWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let rankings = viewModel.appStoreRankings, let coinbase = rankings.first(where: { $0.appName.lowercased().contains("coinbase") }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("#\(coinbase.ranking)")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(coinbase.ranking <= 50 ? AppColors.success : AppColors.textPrimary(colorScheme))

                    Text("App Store Finance")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if coinbase.change != 0 {
                    HStack(spacing: 2) {
                        // Negative change means moved UP in rank (better)
                        Image(systemName: coinbase.change < 0 ? "arrow.up" : "arrow.down")
                            .font(.caption2)
                        Text("\(abs(coinbase.change))")
                            .font(ArkFonts.caption)
                    }
                    .foregroundColor(coinbase.change < 0 ? AppColors.success : AppColors.error)
                    .padding(.horizontal, ArkSpacing.sm)
                    .padding(.vertical, ArkSpacing.xxs)
                    .background((coinbase.change < 0 ? AppColors.success : AppColors.error).opacity(0.1))
                    .cornerRadius(ArkSpacing.xs)
                }
            } else {
                placeholderContent
            }
        }
    }

    // MARK: - Bitcoin Search Interest Widget

    private var bitcoinSearchWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let trends = viewModel.googleTrends {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(trends.currentIndex)/100")
                        .font(.system(size: 28, weight: .bold, design: .default))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Search Interest")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: trends.trend.icon)
                        .font(.caption2)
                    Text(trends.trend.rawValue)
                        .font(ArkFonts.caption)
                }
                .foregroundColor(trendColor(trends.trend))
                .padding(.horizontal, ArkSpacing.sm)
                .padding(.vertical, ArkSpacing.xxs)
                .background(trendColor(trends.trend).opacity(0.1))
                .cornerRadius(ArkSpacing.xs)
            } else {
                placeholderContent
            }
        }
    }

    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .rising: return AppColors.success
        case .stable: return AppColors.textSecondary
        case .falling: return AppColors.error
        }
    }

    // MARK: - Crypto Positioning Widget

    private var cryptoPositioningWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            if let regime = viewModel.macroRegime {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Positioning")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(regime.quadrant.rawValue)
                        .font(ArkFonts.bodySemibold)
                        .foregroundColor(regime.quadrant.color)
                }

                Spacer()

                Text("View Allocations")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.accent)
            } else {
                placeholderContent
            }
        }
    }

    // MARK: - Technical Analysis Widget

    private var technicalAnalysisWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Technical Analysis")
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("BTC / ETH / SOL TA breakdown")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "chart.xyaxis.line")
                .font(.title2)
                .foregroundColor(AppColors.accent)
        }
    }

    // MARK: - Traditional Markets Widget

    private var traditionalMarketsWidget: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            if viewModel.traditionalMarketAssets.isEmpty {
                placeholderContent
            } else {
                ForEach(viewModel.traditionalMarketAssets, id: \.symbol) { asset in
                    HStack(spacing: ArkSpacing.sm) {
                        Text(asset.symbol)
                            .font(ArkFonts.bodySemibold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .frame(width: 50, alignment: .leading)

                        Text(String(format: "$%,.0f", asset.currentPrice))
                            .font(ArkFonts.body)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Spacer()

                        let change = asset.priceChangePercentage24h
                        HStack(spacing: 2) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2)
                            Text(String(format: "%.1f%%", abs(change)))
                                .font(ArkFonts.caption)
                        }
                        .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                    }
                }
            }
        }
    }

    // MARK: - Portfolio Showcase Widget

    private var portfolioShowcaseWidget: some View {
        HStack(spacing: ArkSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Portfolio Showcase")
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Portfolio allocation breakdown")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Image(systemName: "square.split.2x1")
                .font(.title2)
                .foregroundColor(AppColors.accent)
        }
    }

    // MARK: - Generic Section Widget

    private func genericSectionWidget(title: String, subtitle: String) -> some View {
        HStack(spacing: ArkSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ArkFonts.body)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(subtitle)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text("View in App")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.accent)
        }
    }

    // MARK: - Helper Views

    private var placeholderContent: some View {
        HStack {
            Text("Loading...")
                .font(ArkFonts.caption)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
    }

    private func changeIndicator(change: Double, inverted: Bool = false) -> some View {
        let isPositive = inverted ? change < 0 : change > 0
        let color = isPositive ? AppColors.success : AppColors.error
        let icon = change >= 0 ? "arrow.up.right" : "arrow.down.right"

        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(String(format: "%.2f%%", abs(change)))
                .font(ArkFonts.caption)
        }
        .foregroundColor(color)
        .padding(.horizontal, ArkSpacing.sm)
        .padding(.vertical, ArkSpacing.xxs)
        .background(color.opacity(0.1))
        .cornerRadius(ArkSpacing.xs)
    }
}

// MARK: - Embedded Asset Widget

/// Displays a compact live-price card for a crypto, stock, or commodity asset.
struct EmbeddedAssetWidget: View {
    let assetReference: AssetReference
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel = EmbeddedAssetWidgetViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Header
            HStack(spacing: ArkSpacing.xs) {
                Image(systemName: assetReference.iconName)
                    .font(.caption)
                    .foregroundColor(AppColors.accent)

                Text(assetReference.assetType.rawValue.capitalized)
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }

            // Content
            HStack(spacing: ArkSpacing.md) {
                if viewModel.hasData {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(assetReference.displayName) (\(assetReference.symbol))")
                            .font(ArkFonts.bodySemibold)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                            .lineLimit(1)

                        Text(viewModel.formattedPrice)
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }

                    Spacer()

                    if let change = viewModel.changePercent {
                        priceChangeIndicator(change: change)
                    }
                } else if !viewModel.isLoading {
                    Text("Price unavailable")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                } else {
                    Text("Loading...")
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
        .task {
            await viewModel.loadData(for: assetReference)
        }
    }

    private func priceChangeIndicator(change: Double) -> some View {
        let isPositive = change >= 0
        let color = isPositive ? AppColors.success : AppColors.error
        let icon = isPositive ? "arrow.up.right" : "arrow.down.right"

        return HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
            Text(String(format: "%.2f%%", abs(change)))
                .font(ArkFonts.caption)
        }
        .foregroundColor(color)
        .padding(.horizontal, ArkSpacing.sm)
        .padding(.vertical, ArkSpacing.xxs)
        .background(color.opacity(0.1))
        .cornerRadius(ArkSpacing.xs)
    }
}

// MARK: - Embedded Asset Widget ViewModel

@MainActor
class EmbeddedAssetWidgetViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var formattedPrice: String = ""
    @Published var changePercent: Double?
    @Published var hasData = false

    // Loaded asset models for navigation handoff
    @Published var cryptoAsset: CryptoAsset?
    @Published var stockAsset: StockAsset?
    @Published var metalAsset: MetalAsset?

    private let marketService: MarketServiceProtocol

    init() {
        self.marketService = ServiceContainer.shared.marketService
    }

    func loadData(for ref: AssetReference) async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch ref.assetType {
            case .crypto:
                if let cgId = ref.coinGeckoId {
                    let assets = try await marketService.searchCrypto(query: cgId)
                    if let asset = assets.first(where: { $0.id == cgId || $0.symbol.uppercased() == ref.symbol.uppercased() }) {
                        cryptoAsset = asset
                        formattedPrice = formatPrice(asset.currentPrice)
                        changePercent = asset.priceChangePercentage24h
                        hasData = true
                    }
                }

            case .stock:
                let assets = try await marketService.fetchStockAssets(symbols: [ref.symbol])
                if let asset = assets.first {
                    stockAsset = asset
                    formattedPrice = formatPrice(asset.currentPrice)
                    changePercent = asset.priceChangePercentage24h
                    hasData = true
                }

            case .commodity:
                let assets = try await marketService.fetchMetalAssets(symbols: [ref.symbol])
                if let asset = assets.first {
                    metalAsset = asset
                    formattedPrice = formatPrice(asset.currentPrice)
                    changePercent = asset.priceChangePercentage24h
                    hasData = true
                }
            }
        } catch {
            // Silently fail - widget will show placeholder
        }
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 1 {
            return String(format: "$%,.2f", price)
        } else {
            return String(format: "$%.4f", price)
        }
    }
}

// MARK: - External Link Preview Card

/// Displays a preview card for an external URL with metadata.
struct ExternalLinkPreviewCard: View {
    let link: ExternalLink
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: ArkSpacing.md) {
            Image(systemName: "link")
                .font(.title3)
                .foregroundColor(AppColors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                Text(link.title ?? link.url.absoluteString)
                    .font(ArkFonts.bodySemibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(2)

                if let description = link.description, !description.isEmpty {
                    Text(description)
                        .font(ArkFonts.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                if let domain = link.domain {
                    HStack(spacing: 4) {
                        Text(domain)
                            .font(ArkFonts.caption)
                            .foregroundColor(AppColors.accent)

                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundColor(AppColors.accent)
                    }
                }
            }

            Spacer()
        }
        .padding(ArkSpacing.md)
        .background(AppColors.cardBackground(colorScheme))
        .cornerRadius(ArkSpacing.sm)
    }
}

// MARK: - Embedded Widget ViewModel

@MainActor
class EmbeddedWidgetViewModel: ObservableObject {
    @Published var isLoading = false

    // Existing data
    @Published var vixData: VIXData?
    @Published var dxyData: DXYData?
    @Published var liquidityData: GlobalLiquidityChanges?
    @Published var riskLevel: ITCRiskLevel?
    @Published var fearGreedIndex: FearGreedIndex?
    @Published var upcomingEvents: [EconomicEvent] = []

    // New data
    @Published var arklineRiskScore: ArkLineRiskScore?
    @Published var coreAssets: [CryptoAsset] = []
    @Published var supplyInProfit: SupplyProfitData?
    @Published var fedWatchData: FedWatchData?
    @Published var newsHeadlines: [NewsItem] = []
    @Published var macroRegime: MacroRegimeResult?
    @Published var sentimentRegimeData: SentimentRegimeData?
    @Published var appStoreRankings: [AppStoreRanking]?
    @Published var googleTrends: GoogleTrendsData?
    @Published var traditionalMarketAssets: [StockAsset] = []

    private let vixService: VIXServiceProtocol
    private let dxyService: DXYServiceProtocol
    private let globalLiquidityService: GlobalLiquidityServiceProtocol
    private let itcRiskService: ITCRiskServiceProtocol
    private let sentimentService: SentimentServiceProtocol
    private let newsService: NewsServiceProtocol
    private let marketService: MarketServiceProtocol
    private let santimentService: SantimentServiceProtocol
    private let crudeOilService: CrudeOilServiceProtocol
    private let macroStatisticsService: MacroStatisticsServiceProtocol

    init() {
        self.vixService = ServiceContainer.shared.vixService
        self.dxyService = ServiceContainer.shared.dxyService
        self.globalLiquidityService = ServiceContainer.shared.globalLiquidityService
        self.itcRiskService = ServiceContainer.shared.itcRiskService
        self.sentimentService = ServiceContainer.shared.sentimentService
        self.newsService = ServiceContainer.shared.newsService
        self.marketService = ServiceContainer.shared.marketService
        self.santimentService = ServiceContainer.shared.santimentService
        self.crudeOilService = ServiceContainer.shared.crudeOilService
        self.macroStatisticsService = ServiceContainer.shared.macroStatisticsService
    }

    func loadData(for section: AppSection) async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch section {
            // Home Indicators
            case .arklineRiskScore:
                arklineRiskScore = try await sentimentService.fetchArkLineRiskScore()
            case .fearGreed:
                fearGreedIndex = try await sentimentService.fetchFearGreedIndex()
            case .bitcoinRisk:
                riskLevel = try await itcRiskService.fetchLatestRiskLevel(coin: "BTC")
            case .coreAssets:
                let allAssets = try await marketService.fetchCryptoAssets(page: 1, perPage: 10)
                coreAssets = allAssets.filter { ["btc", "eth", "sol"].contains($0.symbol.lowercased()) }
            case .supplyInProfit:
                supplyInProfit = try await santimentService.fetchLatestSupplyInProfit()
            case .fedWatch:
                fedWatchData = try await newsService.fetchFedWatchData()
            case .dailyNews:
                newsHeadlines = try await newsService.fetchCombinedNewsFeed(limit: 5, includeTwitter: false, includeGoogleNews: true, topics: nil, customKeywords: nil)
            case .upcomingEvents:
                upcomingEvents = try await newsService.fetchUpcomingEvents(days: 7, impactFilter: [.high, .medium])
            case .dcaReminders, .favorites:
                break // These require user context; show generic widget
            case .macroDashboard:
                async let v = vixService.fetchLatestVIX()
                async let d = dxyService.fetchLatestDXY()
                async let l = globalLiquidityService.fetchLiquidityChanges()
                vixData = try await v
                dxyData = try await d
                liquidityData = try await l
            // Macro & Economy
            case .vix:
                vixData = try await vixService.fetchLatestVIX()
            case .dxy:
                dxyData = try await dxyService.fetchLatestDXY()
            case .m2:
                liquidityData = try await globalLiquidityService.fetchLiquidityChanges()
            case .macroRegime:
                await loadMacroRegime()
            // Sentiment & Retail
            case .sentimentOverview:
                async let rs = sentimentService.fetchArkLineRiskScore()
                async let fg = sentimentService.fetchFearGreedIndex()
                arklineRiskScore = try await rs
                fearGreedIndex = try await fg
            case .sentimentRegime:
                await loadSentimentRegime()
            case .coinbaseRanking:
                appStoreRankings = try await sentimentService.fetchAppStoreRankings()
            case .bitcoinSearchIndex:
                googleTrends = try await sentimentService.fetchGoogleTrends()
            // Positioning & Allocation
            case .cryptoPositioning:
                await loadMacroRegime()
            // Market Sections
            case .technicalAnalysis, .altcoinScreener, .portfolioShowcase:
                break // Show generic widget
            case .traditionalMarkets:
                traditionalMarketAssets = try await marketService.fetchStockAssets(symbols: ["^GSPC", "^DJI"])
            }
        } catch {
            // Silently fail - widget will show placeholder
        }
    }

    // MARK: - Composite Loaders

    private func loadMacroRegime() async {
        do {
            async let v = vixService.fetchLatestVIX()
            async let d = dxyService.fetchLatestDXY()
            async let l = globalLiquidityService.fetchLiquidityChanges()
            async let o = crudeOilService.fetchLatestCrudeOil()

            let vixResult = try? await v
            let dxyResult = try? await d
            let m2Result = try? await l
            let oilResult = try? await o

            vixData = vixResult
            dxyData = dxyResult
            liquidityData = m2Result

            let zScores = try await macroStatisticsService.fetchAllZScores()
            macroRegime = MacroRegimeCalculator.computeRegime(
                vixData: vixResult,
                dxyData: dxyResult,
                globalM2Data: m2Result,
                crudeOilData: oilResult,
                macroZScores: zScores
            )
        } catch {
            // Silently fail
        }
    }

    private func loadSentimentRegime() async {
        do {
            let fgHistory = try await sentimentService.fetchFearGreedHistory(days: 90)
            let btcAssets = try await marketService.fetchCryptoAssets(page: 1, perPage: 1)
            let volumeData: [[Double]] = btcAssets.first.map { [[$0.totalVolume ?? 0]] } ?? []

            // Build live indicator snapshot for richer data
            let fearGreed = try? await sentimentService.fetchFearGreedIndex()
            let trends = try? await sentimentService.fetchGoogleTrends()
            let rankings = try? await sentimentService.fetchAppStoreRankings()
            let riskLvl = try? await itcRiskService.fetchLatestRiskLevel(coin: "BTC")

            var snapshot = RegimeIndicatorSnapshot()
            snapshot.btcRiskLevel = riskLvl?.riskLevel
            snapshot.searchInterest = trends?.currentIndex

            sentimentRegimeData = SentimentRegimeService.computeRegimeData(
                fearGreedHistory: fgHistory,
                volumeData: volumeData,
                liveIndicators: snapshot
            )
        } catch {
            // Silently fail
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        EmbeddedWidgetView(section: .vix)
        EmbeddedWidgetView(section: .fearGreed)
        EmbeddedWidgetView(section: .bitcoinRisk)
        EmbeddedAssetWidget(assetReference: AssetReference(
            symbol: "BTC",
            assetType: .crypto,
            displayName: "Bitcoin",
            coinGeckoId: "bitcoin"
        ))
        ExternalLinkPreviewCard(link: ExternalLink(
            url: URL(string: "https://example.com/article")!,
            title: "Sample Article",
            description: "A brief description of the article",
            domain: "example.com"
        ))
    }
    .padding()
}
