import SwiftUI

// MARK: - Market Sentiment Section
struct MarketSentimentSection: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: SentimentViewModel
    let lastUpdated: Date
    var isPro: Bool = false

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
            if !viewModel.riskLevels.isEmpty {
                SentimentCategorySection(
                    title: "Asset Risk Levels",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: AppColors.accent
                ) {
                    let visibleCoins = isPro
                        ? Array(viewModel.riskLevels.keys.sorted())
                        : viewModel.riskLevels.keys.sorted().filter { $0 == "BTC" }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(visibleCoins, id: \.self) { coin in
                            if let riskLevel = viewModel.riskLevels[coin] {
                                RiskCard(
                                    riskLevel: riskLevel,
                                    coinSymbol: coin,
                                    daysAtLevel: consecutiveDays(for: coin, current: riskLevel)
                                )
                            }
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

    private func consecutiveDays(for coin: String, current: ITCRiskLevel) -> Int? {
        let history = viewModel.riskHistories[coin] ?? []
        guard !history.isEmpty else { return nil }
        let currentCategory = current.riskCategory
        let currentRisk = current.riskLevel
        var count = 0
        for level in history.reversed() {
            if level.riskCategory == currentCategory ||
                abs(level.riskLevel - currentRisk) < 0.05 {
                count += 1
            } else {
                break
            }
        }
        return count >= 1 ? count : nil
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

// MARK: - Placeholder Card (Loading/No Data)
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

                Text("No Data")
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

#Preview {
    ScrollView {
        MarketSentimentSection(
            viewModel: SentimentViewModel(),
            lastUpdated: Date()
        )
    }
    .background(Color(hex: "0F0F0F"))
}
