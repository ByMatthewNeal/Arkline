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
                    }

                    // Fear & Greed Index
                    if let fearGreed = viewModel.fearGreedIndex {
                        NavigationLink(destination: FearGreedDetailView()) {
                            FearGreedSentimentCard(index: fearGreed)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Bitcoin/Altcoin Season
                    if let altcoin = viewModel.altcoinSeason {
                        NavigationLink(destination: AltcoinSeasonDetailView()) {
                            BitcoinSeasonCard(index: altcoin)
                        }
                        .buttonStyle(PlainButtonStyle())
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
                    }

                    // Liquidation Levels
                    if let liquidation = viewModel.liquidations {
                        NavigationLink(destination: LiquidationDetailView()) {
                            LiquidationLevelsCard(liquidation: liquidation)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // SECTION 2: Retail Sentiment
            SentimentCategorySection(
                title: "Retail Sentiment",
                icon: "person.3.fill",
                iconColor: Color(hex: "8B5CF6")
            ) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    // App Store Rankings (Multiple Apps)
                    AppStoreRankingsCard(rankings: viewModel.appStoreRankings)

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
                iconColor: Color(hex: "F59E0B")
            ) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    // BTC ETF Net Flow
                    if let etf = viewModel.etfNetFlow {
                        NavigationLink(destination: ETFNetFlowDetailView()) {
                            ETFNetFlowCard(etfFlow: etf)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Funding Rate
                    if let funding = viewModel.fundingRate {
                        NavigationLink(destination: FundingRateDetailView()) {
                            FundingRateCard(fundingRate: funding)
                        }
                        .buttonStyle(PlainButtonStyle())
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
    let tier: SentimentTier

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tier.icon)
                .font(.system(size: 12, weight: .bold))

            Text(tier.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(Color(hex: tier.color.replacingOccurrences(of: "#", with: "")))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: tier.color.replacingOccurrences(of: "#", with: "")).opacity(0.15))
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
                        .foregroundColor(Color(hex: score.tier.color.replacingOccurrences(of: "#", with: "")))
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
    let score: Int

    private var progress: Double {
        Double(score) / 100.0
    }

    private var color: Color {
        Color(hex: SentimentTier.from(score: score).color.replacingOccurrences(of: "#", with: ""))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "2A2A2A"), lineWidth: 6)
                .frame(width: 50, height: 50)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Bitcoin Season Card (Enhanced)
struct BitcoinSeasonCard: View {
    @Environment(\.colorScheme) var colorScheme
    let index: AltcoinSeasonIndex

    var seasonColor: Color {
        index.isBitcoinSeason ? Color(hex: "F7931A") : Color(hex: "8B5CF6")
    }

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
                        .foregroundColor(seasonColor)

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
    let value: Int
    let isBitcoinSeason: Bool

    private var progress: Double {
        Double(value) / 100.0
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background gradient
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "F7931A"), Color(hex: "8B5CF6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(0.3)

                    // Indicator
                    Circle()
                        .fill(isBitcoinSeason ? Color(hex: "F7931A") : Color(hex: "8B5CF6"))
                        .frame(width: 12, height: 12)
                        .offset(x: geometry.size.width * progress - 6)
                }
            }
            .frame(height: 8)

            HStack {
                Text("BTC")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "F7931A"))
                Spacer()
                Text("\(value)/100")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("ALT")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "8B5CF6"))
            }
        }
    }
}

// MARK: - App Store Rankings Card (Multiple Apps)
struct AppStoreRankingsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let rankings: [AppStoreRanking]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App Store Rankings")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            if rankings.isEmpty {
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(rankings.prefix(3)) { ranking in
                        HStack {
                            Text(ranking.appName)
                                .font(.caption)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                .lineLimit(1)

                            Spacer()

                            Text("#\(ranking.ranking)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary(colorScheme))

                            HStack(spacing: 2) {
                                Image(systemName: ranking.isImproving ? "arrow.up" : "arrow.down")
                                    .font(.system(size: 8, weight: .bold))
                                Text("\(abs(ranking.change))")
                                    .font(.caption2)
                            }
                            .foregroundColor(ranking.isImproving ? AppColors.success : AppColors.error)
                            .frame(width: 36, alignment: .trailing)
                        }
                    }
                }
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

    var trendColor: Color {
        Color(hex: trends.trend.color.replacingOccurrences(of: "#", with: ""))
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
                    Image(systemName: trends.trend.icon)
                        .font(.system(size: 10, weight: .bold))
                    Text(trends.trend.rawValue)
                        .font(.caption)
                    Text("(\(trends.changeFromLastWeek >= 0 ? "+" : "")\(trends.changeFromLastWeek))")
                        .font(.caption2)
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
                        .foregroundColor(Color(hex: index.level.color.replacingOccurrences(of: "#", with: "")))
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
                .foregroundColor(Color(hex: "22C55E"))
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
                        .fill(Color(hex: "2A2A2A"))

                    // Progress
                    HStack(spacing: 0) {
                        // Bitcoin side (orange)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: "F7931A"))
                            .frame(width: geometry.size.width * progress)

                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 8)

            HStack {
                Text("Bitcoin")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "F7931A"))
                Spacer()
                Text("Altcoin")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "8B5CF6"))
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
                    .foregroundColor(isPositive ? Color(hex: "22C55E") : Color(hex: "EF4444"))
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
                .foregroundColor(ranking.isImproving ? Color(hex: "22C55E") : Color(hex: "EF4444"))
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
                .foregroundColor(isPositive ? Color(hex: "22C55E") : Color(hex: "EF4444"))
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

#Preview {
    ScrollView {
        MarketSentimentSection(
            viewModel: SentimentViewModel(),
            lastUpdated: Date()
        )
    }
    .background(Color(hex: "0F0F0F"))
}
