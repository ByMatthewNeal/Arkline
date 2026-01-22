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
                        NavigationLink(destination: FearGreedDetailView()) {
                            FearGreedSentimentCard(index: fearGreed)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        PlaceholderCard(title: "Fear & Greed", icon: "gauge.with.needle")
                    }

                    // Bitcoin/Altcoin Season
                    if let altcoin = viewModel.altcoinSeason {
                        NavigationLink(destination: AltcoinSeasonDetailView()) {
                            BitcoinSeasonCard(index: altcoin)
                        }
                        .buttonStyle(PlainButtonStyle())
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
                        NavigationLink(destination: BTCDominanceDetailView()) {
                            BTCDominanceCard(dominance: btcDom)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        PlaceholderCard(title: "BTC Dominance", icon: "chart.pie")
                    }

                    // Liquidation Levels
                    if let liquidation = viewModel.liquidations {
                        NavigationLink(destination: LiquidationDetailView()) {
                            LiquidationLevelsCard(liquidation: liquidation)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        PlaceholderCard(title: "Liquidations", icon: "flame")
                    }
                }
            }

            // SECTION: ITC Risk Levels (Into The Cryptoverse)
            if viewModel.btcRiskLevel != nil || viewModel.ethRiskLevel != nil {
                SentimentCategorySection(
                    title: "ITC Risk Levels",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: AppColors.accent
                ) {
                    VStack(spacing: 12) {
                        // BTC and ETH Risk Cards in grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            // BTC Risk Level
                            if let btcRisk = viewModel.btcRiskLevel {
                                ITCRiskCard(riskLevel: btcRisk, coinSymbol: "BTC")
                            }

                            // ETH Risk Level
                            if let ethRisk = viewModel.ethRiskLevel {
                                ITCRiskCard(riskLevel: ethRisk, coinSymbol: "ETH")
                            }
                        }

                        // Historical trend chart (if expanded and data available)
                        if !viewModel.btcRiskHistory.isEmpty {
                            ITCRiskHistoryCard(history: viewModel.btcRiskHistory)
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
                        GoogleTrendsCard(trends: trends)
                    } else {
                        BitcoinSearchCard(searchIndex: viewModel.bitcoinSearchIndex)
                    }
                }
            }

            // SECTION 3: Institutional Sentiment
            SentimentCategorySection(
                title: "Institutional",
                icon: "building.columns.fill",
                iconColor: AppColors.accent
            ) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    // BTC ETF Net Flow
                    if let etf = viewModel.etfNetFlow {
                        NavigationLink(destination: ETFNetFlowDetailView()) {
                            ETFNetFlowCard(etfFlow: etf)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        PlaceholderCard(title: "ETF Net Flow", icon: "building.2")
                    }

                    // Funding Rate
                    if let funding = viewModel.fundingRate {
                        NavigationLink(destination: FundingRateDetailView()) {
                            FundingRateCard(fundingRate: funding)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        PlaceholderCard(title: "Funding Rate", icon: "percent")
                    }
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

// MARK: - App Store Rankings Card (Multiple Apps)
struct AppStoreRankingsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let rankings: [AppStoreRanking]

    // Calculate composite sentiment from the rankings
    private var compositeSentiment: AppStoreCompositeSentiment {
        let primaryRankings = rankings.filter { ranking in
            ["Coinbase", "Binance", "Kraken"].contains(ranking.appName) &&
            ranking.platform == .ios
        }
        return AppStoreRankingCalculator.calculateComposite(from: primaryRankings)
    }

    // Get primary ranking (Coinbase iOS US)
    private var primaryRanking: AppStoreRanking? {
        rankings.first { $0.appName == "Coinbase" && $0.platform == .ios && $0.region == .us }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Coinbase AppStore")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                // Chevron to indicate tappable
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
            }

            Spacer()

            if let ranking = primaryRanking {
                VStack(alignment: .leading, spacing: 6) {
                    // Main ranking number
                    Text("\(ranking.ranking)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    // Change indicator
                    HStack(spacing: 4) {
                        Image(systemName: ranking.isImproving ? "arrow.up" : "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(abs(ranking.change)) positions")
                            .font(.caption)
                    }
                    .foregroundColor(ranking.isImproving ? AppColors.success : AppColors.error)
                }
            } else if !rankings.isEmpty {
                // Fallback to first available ranking
                if let first = rankings.first {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(first.ranking)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        HStack(spacing: 4) {
                            Image(systemName: first.isImproving ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            Text("\(abs(first.change)) positions")
                                .font(.caption)
                        }
                        .foregroundColor(first.isImproving ? AppColors.success : AppColors.error)
                    }
                }
            } else {
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Google Trends Card
struct GoogleTrendsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let trends: GoogleTrendsData

    // Use green/red for up/down trends only
    var trendColor: Color {
        trends.changeFromLastWeek >= 0 ? AppColors.success : AppColors.error
    }

    var body: some View {
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

    var body: some View {
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
}

// MARK: - ETF Net Flow Card
struct ETFNetFlowCard: View {
    @Environment(\.colorScheme) var colorScheme
    let etfFlow: ETFNetFlow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BTC ETF Net Flow")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(etfFlow.dailyFormatted)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(etfFlow.isPositive ? AppColors.success : AppColors.error)

                Text(etfFlow.isPositive ? "Inflow" : "Outflow")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Funding Rate Card
struct FundingRateCard: View {
    @Environment(\.colorScheme) var colorScheme
    let fundingRate: FundingRate

    var rateColor: Color {
        if fundingRate.averageRate > 0.01 {
            return AppColors.success
        } else if fundingRate.averageRate < -0.01 {
            return AppColors.error
        }
        return AppColors.warning
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Funding Rate")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                Text(fundingRate.displayRate)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(rateColor)

                Text(fundingRate.sentiment)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
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

// MARK: - ITC Risk History Card
struct ITCRiskHistoryCard: View {
    let history: [ITCRiskLevel]
    @Environment(\.colorScheme) var colorScheme

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
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BTC Risk History")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(textPrimary)

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
                ITCRiskSparkline(dataPoints: chartData, colorScheme: colorScheme)
                    .frame(height: 60)
            }

            // Attribution
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.accent)

                Text("Powered by Into The Cryptoverse")
                    .font(.caption2)
                    .foregroundColor(textPrimary.opacity(0.5))
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
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

// MARK: - ITC Risk Sparkline
struct ITCRiskSparkline: View {
    let dataPoints: [CGFloat]
    let colorScheme: ColorScheme

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let stepX = width / CGFloat(max(dataPoints.count - 1, 1))

            ZStack {
                // Risk zone backgrounds
                VStack(spacing: 0) {
                    // High risk zone (top)
                    Rectangle()
                        .fill(AppColors.error.opacity(0.05))
                        .frame(height: height * 0.3)

                    // Medium risk zone
                    Rectangle()
                        .fill(AppColors.warning.opacity(0.05))
                        .frame(height: height * 0.4)

                    // Low risk zone (bottom)
                    Rectangle()
                        .fill(AppColors.success.opacity(0.05))
                        .frame(height: height * 0.3)
                }

                // Risk line
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
                        colors: [AppColors.success, AppColors.warning, AppColors.error],
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
                        .fill(ITCRiskColors.color(for: Double(lastPoint), colorScheme: colorScheme))
                        .frame(width: 8, height: 8)
                        .position(x: lastX, y: lastY)

                    // Glow effect
                    Circle()
                        .fill(ITCRiskColors.color(for: Double(lastPoint), colorScheme: colorScheme).opacity(0.3))
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
