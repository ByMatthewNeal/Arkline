import SwiftUI

// MARK: - Market Sentiment Section
struct MarketSentimentSection: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: SentimentViewModel
    let lastUpdated: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Main Header with ArkLine Score
            SentimentHeader(viewModel: viewModel, lastUpdated: lastUpdated)
                .padding(.horizontal, 20)

            // SECTION 1: Overall Market
            SentimentCategorySection(
                title: "Overall Market",
                icon: "chart.line.uptrend.xyaxis",
                iconColor: AppColors.accent
            ) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    // ArkLine Risk Score (Proprietary)
                    if let arkLineScore = viewModel.arkLineRiskScore {
                        ArkLineScoreCard(score: arkLineScore)
                    } else {
                        PlaceholderCard(title: "ArkLine Score", icon: "sparkles")
                    }

                    // Fear & Greed Index
                    if let fearGreed = viewModel.fearGreedIndex {
                        FearGreedSentimentCard(index: fearGreed)
                    } else {
                        PlaceholderCard(title: "Fear & Greed", icon: "gauge.with.needle")
                    }

                    // Bitcoin/Altcoin Season
                    if let altcoin = viewModel.altcoinSeason {
                        BitcoinSeasonCard(index: altcoin)
                    } else {
                        PlaceholderCard(title: "Season Indicator", icon: "bitcoinsign.circle")
                    }

                    // Market Cap
                    MarketCapCard(
                        marketCap: viewModel.totalMarketCap,
                        change: viewModel.marketCapChange24h,
                        sparklineData: viewModel.marketCapHistory
                    )

                    // BTC Dominance
                    if let btcDom = viewModel.btcDominance {
                        BTCDominanceCard(dominance: btcDom)
                    } else {
                        PlaceholderCard(title: "BTC Dominance", icon: "chart.pie")
                    }

                    // Liquidations hidden - requires paid Coinglass subscription
                }
            }

            // SECTION: Asset Risk Levels
            if viewModel.btcRiskLevel != nil || viewModel.ethRiskLevel != nil {
                SentimentCategorySection(
                    title: "Asset Risk Levels",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: AppColors.accent
                ) {
                    VStack(spacing: 12) {
                        // BTC and ETH Risk Cards in grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            // BTC Risk Level
                            if let btcRisk = viewModel.btcRiskLevel {
                                RiskCard(riskLevel: btcRisk, coinSymbol: "BTC")
                            }

                            // ETH Risk Level
                            if let ethRisk = viewModel.ethRiskLevel {
                                RiskCard(riskLevel: ethRisk, coinSymbol: "ETH")
                            }
                        }

                        // Historical trend chart (tappable)
                        if !viewModel.btcRiskHistory.isEmpty {
                            RiskHistoryCard(history: viewModel.btcRiskHistory)
                        }
                    }
                }
            }

            // SECTION 2: Retail Sentiment
            SentimentCategorySection(
                title: "Retail Sentiment",
                icon: "person.3.fill",
                iconColor: AppColors.accent
            ) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    // App Store Rankings (Multiple Apps)
                    if viewModel.appStoreRankings.isEmpty {
                        PlaceholderCard(title: "App Store Rankings", icon: "arrow.down.app")
                    } else {
                        NavigationLink(destination: AppStoreRankingDetailView(viewModel: viewModel)) {
                            AppStoreRankingsCard(rankings: viewModel.appStoreRankings)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Google Trends / Bitcoin Search
                    if let trends = viewModel.googleTrends {
                        GoogleTrendsCard(trends: trends, history: viewModel.googleTrendsHistory)
                    } else {
                        BitcoinSearchCard(searchIndex: viewModel.bitcoinSearchIndex, history: viewModel.googleTrendsHistory)
                    }
                }
            }

            // SECTION 3: Institutional Sentiment
            SentimentCategorySection(
                title: "Institutional",
                icon: "building.columns.fill",
                iconColor: AppColors.accent
            ) {
                // Funding Rate
                if let funding = viewModel.fundingRate {
                    FundingRateCard(fundingRate: funding)
                } else {
                    PlaceholderCard(title: "Funding Rate", icon: "percent")
                }
            }
        }
    }
}

// MARK: - Sentiment Header with ArkLine Score
struct SentimentHeader: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: SentimentViewModel
    let lastUpdated: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Market Sentiment")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Upd: \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Overall Sentiment Tier Badge
                if let score = viewModel.arkLineRiskScore {
                    SentimentTierBadge(tier: score.tier)
                }
            }
        }
    }
}

// MARK: - Sentiment Tier Badge
struct SentimentTierBadge: View {
    @Environment(\.colorScheme) var colorScheme
    let tier: SentimentTier

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tier.icon)
                .font(.system(size: 12, weight: .bold))

            Text(tier.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.8))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            colorScheme == .dark
                ? Color.white.opacity(0.1)
                : Color.black.opacity(0.06)
        )
        .cornerRadius(20)
    }
}

// MARK: - Sentiment Category Section
struct SentimentCategorySection<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
            .padding(.horizontal, 20)

            // Content
            content
                .padding(.horizontal, 20)
        }
    }
}

// MARK: - Placeholder Card (Coming Soon)
struct PlaceholderCard: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))

                Text("Coming Soon")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
        .opacity(0.7)
    }
}

// MARK: - ArkLine Score Card (Proprietary 0-100)
struct ArkLineScoreCard: View {
    @Environment(\.colorScheme) var colorScheme
    let score: ArkLineRiskScore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ArkLine Score")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.accent)
            }

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(score.score)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(score.tier.rawValue)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Circular Progress
                ArkLineScoreGauge(score: score.score)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - ArkLine Score Gauge
struct ArkLineScoreGauge: View {
    @Environment(\.colorScheme) var colorScheme
    let score: Int

    private var progress: Double {
        Double(score) / 100.0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.08),
                    lineWidth: 6
                )
                .frame(width: 50, height: 50)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Bitcoin Season Card (Enhanced)
struct BitcoinSeasonCard: View {
    @Environment(\.colorScheme) var colorScheme
    let index: AltcoinSeasonIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Season Indicator")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: index.isBitcoinSeason ? "bitcoinsign.circle.fill" : "sparkles")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.accent)

                    Text(index.isBitcoinSeason ? "Bitcoin" : "Altcoin")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }

                // Season Progress Bar
                SeasonProgressBar(value: index.value, isBitcoinSeason: index.isBitcoinSeason)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Season Progress Bar
struct SeasonProgressBar: View {
    @Environment(\.colorScheme) var colorScheme
    let value: Int
    let isBitcoinSeason: Bool

    private var progress: Double {
        Double(value) / 100.0
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(0.1)
                                : Color.black.opacity(0.08)
                        )

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.accent.opacity(0.5), AppColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)

                    // Indicator
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                                .frame(width: 5, height: 5)
                        )
                        .offset(x: geometry.size.width * progress - 6)
                }
            }
            .frame(height: 8)

            HStack {
                Text("BTC")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("\(value)/100")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("ALT")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Coinbase iOS Ranking Card (Simplified)
struct CoinbaseRankingCard: View {
    @Environment(\.colorScheme) var colorScheme
    let rankings: [AppStoreRanking]

    // Get Coinbase ranking (iOS US) - ranking of 0 means >200
    private var coinbaseRanking: AppStoreRanking? {
        rankings.first { $0.appName == "Coinbase" }
    }

    private var isRanked: Bool {
        guard let ranking = coinbaseRanking else { return false }
        return ranking.ranking > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Coinbase iOS")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
            }

            Spacer()

            if let ranking = coinbaseRanking, isRanked {
                // Ranked in top 200
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("#")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                            Text("\(ranking.ranking)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                        }

                        Text("US App Store")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    if ranking.change != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: ranking.isImproving ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(abs(ranking.change))")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(ranking.isImproving ? AppColors.success : AppColors.error)
                    }
                }
            } else {
                // Not in top 200
                VStack(alignment: .leading, spacing: 4) {
                    Text(">200")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)

                    Text("US App Store")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// Legacy alias for backward compatibility
typealias AppStoreRankingsCard = CoinbaseRankingCard

// MARK: - Google Trends Card
struct GoogleTrendsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let trends: GoogleTrendsData
    var history: [GoogleTrendsDTO] = []
    @State private var showingDetail = false

    // Use green/red for up/down trends only
    var trendColor: Color {
        trends.changeFromLastWeek >= 0 ? AppColors.success : AppColors.error
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Bitcoin Search")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(trends.currentIndex)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Text("/100")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: trends.changeFromLastWeek >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text("(\(trends.changeFromLastWeek >= 0 ? "+" : "")\(trends.changeFromLastWeek))")
                            .font(.caption)
                    }
                    .foregroundColor(trendColor)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            GoogleTrendsDetailView(trends: trends, history: history)
        }
    }
}

// MARK: - Fear & Greed Card (with Gauge)
struct FearGreedSentimentCard: View {
    @Environment(\.colorScheme) var colorScheme
    let index: FearGreedIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fear & Greed")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index.value)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(index.level.rawValue)
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                CompactSentimentGauge(value: index.value)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Risk Level Card
struct RiskLevelCard: View {
    @Environment(\.colorScheme) var colorScheme
    let riskLevel: RiskLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Risk Level")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("SOL")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                    Text(String(format: "%.3f", Double(riskLevel.level) / 10.0))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                    Text("2.29%")
                        .font(.caption)
                }
                .foregroundColor(AppColors.success)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Altcoin Season Card
struct AltcoinSeasonCard: View {
    @Environment(\.colorScheme) var colorScheme
    let index: AltcoinSeasonIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Altcoin Season")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("\(index.value)/100")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                // Progress Bar
                AltcoinSeasonBar(value: index.value)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Altcoin Season Progress Bar
struct AltcoinSeasonBar: View {
    @Environment(\.colorScheme) var colorScheme
    let value: Int

    private var progress: Double {
        Double(value) / 100.0
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(0.1)
                                : Color.black.opacity(0.08)
                        )

                    // Progress
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.accent)
                            .frame(width: geometry.size.width * progress)

                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 8)

            HStack {
                Text("Bitcoin")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("Altcoin")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Market Cap Card (with Sparkline)
struct MarketCapCard: View {
    @Environment(\.colorScheme) var colorScheme
    let marketCap: Double
    let change: Double
    let sparklineData: [Double]

    var isPositive: Bool { change >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Market Cap")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(marketCap.asCurrencyCompact)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    HStack(spacing: 4) {
                        Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(abs(change), specifier: "%.2f")%")
                            .font(.caption)
                    }
                    .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                }

                Spacer()

                if !sparklineData.isEmpty {
                    MiniSparkline(data: sparklineData, isPositive: isPositive)
                        .frame(width: 50, height: 25)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - App Store Rank Card
struct AppStoreRankCard: View {
    @Environment(\.colorScheme) var colorScheme
    let ranking: AppStoreRanking

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coinbase AppStore")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text("\(ranking.ranking)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                HStack(spacing: 4) {
                    Image(systemName: ranking.isImproving ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(abs(ranking.change))")
                        .font(.caption)
                }
                .foregroundColor(ranking.isImproving ? AppColors.success : AppColors.error)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - BTC Dominance Card
struct BTCDominanceCard: View {
    @Environment(\.colorScheme) var colorScheme
    let dominance: BTCDominance

    var isPositive: Bool { dominance.change24h >= 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BTC Dominance")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(dominance.displayValue)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(abs(dominance.change24h), specifier: "%.2f")%")
                        .font(.caption)
                }
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Bitcoin Search Card (Google Trends)
struct BitcoinSearchCard: View {
    @Environment(\.colorScheme) var colorScheme
    let searchIndex: Int
    var history: [GoogleTrendsDTO] = []
    @State private var showingDetail = false

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Bitcoin Search")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(searchIndex)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Google Trends")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            GoogleTrendsDetailView(trends: nil, searchIndex: searchIndex, history: history)
        }
    }
}

// MARK: - Google Trends Detail View
struct GoogleTrendsDetailView: View {
    let trends: GoogleTrendsData?
    var searchIndex: Int? = nil
    var history: [GoogleTrendsDTO] = []
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private var currentIndex: Int {
        trends?.currentIndex ?? searchIndex ?? 0
    }

    // Filter history to only show days where value changed
    private var changedHistory: [(dto: GoogleTrendsDTO, change: Int)] {
        guard history.count > 1 else {
            return history.map { ($0, 0) }
        }

        var result: [(dto: GoogleTrendsDTO, change: Int)] = []
        let sortedHistory = history.sorted { $0.date > $1.date } // Most recent first

        for (index, item) in sortedHistory.enumerated() {
            if index == 0 {
                // Most recent - always show, calculate change from previous
                let change = sortedHistory.count > 1 ? item.searchIndex - sortedHistory[1].searchIndex : 0
                if change != 0 || result.isEmpty {
                    result.append((item, change))
                }
            } else {
                // Compare with previous day
                let previousIndex = sortedHistory[index - 1].searchIndex
                let change = previousIndex - item.searchIndex // Change that happened after this day
                if change != 0 {
                    result.append((item, change))
                }
            }
        }

        return result
    }

    // Static historical events for reference
    private var historicalEvents: [(date: String, event: String, searchIndex: Int, btcPrice: String)] {
        [
            ("Jan 2025", "New ATH", 88, "$109,000"),
            ("Dec 2024", "BTC Breaks $100K", 95, "$100,000"),
            ("Nov 2024", "Trump Election Rally", 82, "$93,000"),
            ("Apr 2024", "Bitcoin Halving", 68, "$64,000"),
            ("Mar 2024", "Pre-Halving ATH", 75, "$73,000"),
            ("Jan 2024", "Spot ETF Approved", 85, "$46,000"),
            ("Nov 2021", "Previous Cycle ATH", 100, "$69,000"),
            ("May 2021", "China Mining Ban", 85, "$37,000"),
            ("Apr 2021", "Coinbase IPO", 78, "$64,000"),
            ("Jan 2021", "Tesla Buys BTC", 72, "$40,000"),
            ("Dec 2017", "2017 Bull Run Peak", 100, "$20,000")
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current Index
                    VStack(spacing: 12) {
                        Text("\(currentIndex)")
                            .font(.system(size: 64, weight: .bold, design: .default))
                            .foregroundColor(textPrimary)
                            .monospacedDigit()

                        Text("of 100")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        if let change = trends?.changeFromLastWeek {
                            HStack(spacing: 4) {
                                Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(change >= 0 ? "+" : "")\(change) from last week")
                                    .font(.subheadline)
                            }
                            .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                        }
                    }
                    .padding(.top, 20)

                    // What is Google Trends
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What is Google Trends?")
                            .font(.headline)
                            .foregroundColor(textPrimary)
                        Text("Google Trends measures relative search interest for \"Bitcoin\" on a scale of 0-100. A value of 100 represents peak popularity, while 50 means half as popular. It's a useful gauge of retail interest and potential market tops/bottoms.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Recent Changes (from database)
                    if !changedHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recent Changes")
                                    .font(.headline)
                                    .foregroundColor(textPrimary)

                                Spacer()

                                Text("\(history.count) days tracked")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if changedHistory.isEmpty || changedHistory.allSatisfy({ $0.change == 0 }) {
                                HStack {
                                    Image(systemName: "equal.circle.fill")
                                        .foregroundColor(AppColors.warning)
                                    Text("No changes recorded yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            } else {
                                ForEach(changedHistory.prefix(10), id: \.dto.id) { item in
                                    GoogleTrendsHistoryRow(
                                        date: item.dto.shortDateDisplay,
                                        searchIndex: item.dto.searchIndex,
                                        change: item.change,
                                        btcPrice: item.dto.btcPriceDisplay
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }

                    // Historical Events
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Historical Events")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        ForEach(historicalEvents, id: \.date) { event in
                            SearchEventRow(
                                date: event.date,
                                event: event.event,
                                searchIndex: event.searchIndex,
                                btcPrice: event.btcPrice,
                                isHighlight: event.searchIndex >= 80
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Interpretation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to Interpret")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        SearchLevelRow(range: "80-100", label: "Extreme Interest", description: "Often signals market tops, FOMO peak", color: AppColors.error)
                        SearchLevelRow(range: "50-80", label: "High Interest", description: "Strong retail participation", color: AppColors.warning)
                        SearchLevelRow(range: "20-50", label: "Moderate Interest", description: "Healthy market, accumulation phase", color: AppColors.success)
                        SearchLevelRow(range: "0-20", label: "Low Interest", description: "Potential bottom, smart money accumulates", color: AppColors.accent)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Trading Insight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trading Insight")
                            .font(.headline)
                            .foregroundColor(textPrimary)
                        Text("""
- Peak search interest often coincides with local/global tops
- Low search interest during bear markets can signal accumulation zones
- Sudden spikes may indicate news-driven volatility
- Divergence between price and search interest can signal trend changes
""")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                .padding()
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Bitcoin Search Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Google Trends History Row
struct GoogleTrendsHistoryRow: View {
    let date: String
    let searchIndex: Int
    let change: Int
    let btcPrice: String

    var changeColor: Color {
        if change > 0 { return AppColors.success }
        if change < 0 { return AppColors.error }
        return .secondary
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if btcPrice != "--" {
                    Text(btcPrice)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                // Change indicator
                if change != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(change > 0 ? "+" : "")\(change)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(changeColor)
                }

                // Current value
                Text("\(searchIndex)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(searchIndex >= 80 ? AppColors.error : .primary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
    }
}

struct SearchEventRow: View {
    let date: String
    let event: String
    let searchIndex: Int
    let btcPrice: String
    let isHighlight: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(searchIndex)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isHighlight ? AppColors.error : .primary)
                    .monospacedDigit()
                Text(btcPrice)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
    }
}

struct SearchLevelRow: View {
    let range: String
    let label: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(range)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                    Text("-")
                        .foregroundColor(.secondary)
                    Text(label)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Funding Rate Card
struct FundingRateCard: View {
    @Environment(\.colorScheme) var colorScheme
    let fundingRate: FundingRate
    @State private var showingDetail = false

    var rateColor: Color {
        // Thresholds: > 0.05% bullish, < -0.05% bearish
        if fundingRate.averageRate > 0.0005 {
            return AppColors.success
        } else if fundingRate.averageRate < -0.0005 {
            return AppColors.error
        }
        return AppColors.warning
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Funding Rate")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    // Source indicator
                    Text("Binance")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text(fundingRate.displayRate)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(rateColor)

                    HStack(spacing: 4) {
                        Text(fundingRate.sentiment)
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)

                        Text("•")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))

                        Text(fundingRate.annualizedDisplay)
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            FundingRateDetailView(fundingRate: fundingRate)
        }
    }
}

// MARK: - Liquidation Levels Card
struct LiquidationLevelsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let liquidation: LiquidationData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Liquidation Levels")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("High")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("$109K")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.success)
                }

                HStack {
                    Text("Low")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("$106K")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.error)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Risk History Card (Tappable)
struct RiskHistoryCard: View {
    let history: [ITCRiskLevel]
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var chartData: [CGFloat] {
        // Convert risk levels to chart data points
        history.suffix(30).map { CGFloat($0.riskLevel) }
    }

    private var latestRisk: ITCRiskLevel? {
        history.last
    }

    private var trendDirection: String {
        guard history.count >= 2 else { return "stable" }
        let recent = history.suffix(7)
        guard let first = recent.first, let last = recent.last else { return "stable" }
        let diff = last.riskLevel - first.riskLevel
        if diff > 0.05 { return "rising" }
        else if diff < -0.05 { return "falling" }
        return "stable"
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("BTC Risk History")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(textPrimary)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        }

                        Text("30 Day Trend")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    // Trend indicator
                    HStack(spacing: 4) {
                        Image(systemName: trendIcon)
                            .font(.system(size: 12, weight: .bold))
                        Text(trendLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(trendColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(trendColor.opacity(0.15))
                    )
                }

                // Mini chart
                if !chartData.isEmpty {
                    RiskSparkline(dataPoints: chartData, colorScheme: colorScheme)
                        .frame(height: 60)
                }

                // Subtle attribution
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundColor(textPrimary.opacity(0.35))

                    Text("intothecryptoverse.com")
                        .font(.system(size: 9))
                        .foregroundColor(textPrimary.opacity(0.35))
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            RiskLevelChartView()
        }
    }

    private var trendIcon: String {
        switch trendDirection {
        case "rising": return "arrow.up.right"
        case "falling": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private var trendLabel: String {
        switch trendDirection {
        case "rising": return "Rising"
        case "falling": return "Falling"
        default: return "Stable"
        }
    }

    private var trendColor: Color {
        switch trendDirection {
        case "rising": return AppColors.error
        case "falling": return AppColors.success
        default: return AppColors.warning
        }
    }
}

// Legacy alias
typealias ITCRiskHistoryCard = RiskHistoryCard

// MARK: - ITC Risk Sparkline
struct RiskSparkline: View {
    let dataPoints: [CGFloat]
    let colorScheme: ColorScheme

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let stepX = width / CGFloat(max(dataPoints.count - 1, 1))

            ZStack {
                // Risk zone backgrounds (6-tier system)
                VStack(spacing: 0) {
                    // Extreme risk zone (0.90-1.0 = 10%)
                    Rectangle()
                        .fill(RiskColors.extremeRisk.opacity(0.08))
                        .frame(height: height * 0.10)

                    // High risk zone (0.70-0.90 = 20%)
                    Rectangle()
                        .fill(RiskColors.highRisk.opacity(0.08))
                        .frame(height: height * 0.20)

                    // Elevated risk zone (0.55-0.70 = 15%)
                    Rectangle()
                        .fill(RiskColors.elevatedRisk.opacity(0.08))
                        .frame(height: height * 0.15)

                    // Neutral zone (0.40-0.55 = 15%)
                    Rectangle()
                        .fill(RiskColors.neutral.opacity(0.08))
                        .frame(height: height * 0.15)

                    // Low risk zone (0.20-0.40 = 20%)
                    Rectangle()
                        .fill(RiskColors.lowRisk.opacity(0.08))
                        .frame(height: height * 0.20)

                    // Very low risk zone (0.00-0.20 = 20%)
                    Rectangle()
                        .fill(RiskColors.veryLowRisk.opacity(0.08))
                        .frame(height: height * 0.20)
                }

                // Risk line (6-tier gradient)
                Path { path in
                    guard dataPoints.count > 1 else { return }

                    for (index, point) in dataPoints.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - (point * height) // Invert Y axis

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            RiskColors.veryLowRisk,
                            RiskColors.lowRisk,
                            RiskColors.neutral,
                            RiskColors.elevatedRisk,
                            RiskColors.highRisk,
                            RiskColors.extremeRisk
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                // End point indicator
                if let lastPoint = dataPoints.last {
                    let lastX = CGFloat(dataPoints.count - 1) * stepX
                    let lastY = height - (lastPoint * height)

                    Circle()
                        .fill(RiskColors.color(for: Double(lastPoint), colorScheme: colorScheme))
                        .frame(width: 8, height: 8)
                        .position(x: lastX, y: lastY)

                    // Glow effect
                    Circle()
                        .fill(RiskColors.color(for: Double(lastPoint), colorScheme: colorScheme).opacity(0.3))
                        .frame(width: 16, height: 16)
                        .blur(radius: 4)
                        .position(x: lastX, y: lastY)
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        MarketSentimentSection(
            viewModel: SentimentViewModel(),
            lastUpdated: Date()
        )
    }
    .background(Color(hex: "0F0F0F"))
}
