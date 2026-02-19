import SwiftUI

// MARK: - Market Sentiment Section
struct MarketSentimentSection: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: SentimentViewModel
    let lastUpdated: Date
    var isPro: Bool = false
    @Namespace private var zoomNamespace

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
                        NavigationLink(destination: ArkLineScoreDetailView(riskScore: arkLineScore).zoomDestination(id: "arkline-score", in: zoomNamespace)) {
                            ArkLineScoreCard(score: arkLineScore)
                                .cardAppearance(delay: 0)
                        }
                        .zoomSource(id: "arkline-score", in: zoomNamespace)
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        ShimmerPlaceholderCard(title: "ArkLine Score", icon: "sparkles", isLoading: viewModel.isLoading) {
                            await viewModel.retryArkLineScore()
                        }
                    }

                    // Fear & Greed Index
                    if let fearGreed = viewModel.fearGreedIndex {
                        FearGreedSentimentCard(index: fearGreed)
                            .cardAppearance(delay: 1)
                    } else {
                        ShimmerPlaceholderCard(title: "Fear & Greed", icon: "gauge.with.needle", isLoading: viewModel.isLoading) {
                            await viewModel.retryFearGreed()
                        }
                    }

                    // Bitcoin/Altcoin Season
                    if let altcoin = viewModel.altcoinSeason {
                        BitcoinSeasonCard(index: altcoin)
                            .cardAppearance(delay: 2)
                    } else {
                        ShimmerPlaceholderCard(title: "Season Indicator", icon: "bitcoinsign.circle", isLoading: viewModel.isLoading) {
                            await viewModel.retryAltcoinSeason()
                        }
                    }

                    // Market Cap
                    if viewModel.totalMarketCap > 0 {
                        MarketCapCard(
                            marketCap: viewModel.totalMarketCap,
                            change: viewModel.marketCapChange24h,
                            sparklineData: viewModel.marketCapHistory
                        )
                        .cardAppearance(delay: 3)
                    } else {
                        ShimmerPlaceholderCard(title: "Market Cap", icon: "chart.bar", isLoading: viewModel.isLoading)
                    }

                    // BTC Dominance
                    if let btcDom = viewModel.btcDominance {
                        BTCDominanceCard(dominance: btcDom)
                            .cardAppearance(delay: 4)
                    } else {
                        ShimmerPlaceholderCard(title: "BTC Dominance", icon: "chart.pie", isLoading: viewModel.isLoading) {
                            await viewModel.retryBTCDominance()
                        }
                    }

                    // Sentiment Regime Quadrant
                    if let regimeData = viewModel.sentimentRegimeData {
                        NavigationLink(destination: SentimentRegimeDetailView(viewModel: viewModel).zoomDestination(id: "sentiment-regime", in: zoomNamespace)) {
                            SentimentRegimeCard(regimeData: regimeData)
                                .cardAppearance(delay: 5)
                        }
                        .zoomSource(id: "sentiment-regime", in: zoomNamespace)
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        ShimmerPlaceholderCard(
                            title: "Sentiment Regime",
                            icon: "square.grid.2x2",
                            isLoading: viewModel.isLoadingRegimeData
                        ) {
                            await viewModel.retrySentimentRegime()
                        }
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
                    let daysCache = consecutiveDaysCache
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(visibleCoins, id: \.self) { coin in
                            if let riskLevel = viewModel.riskLevels[coin] {
                                RiskCard(
                                    riskLevel: riskLevel,
                                    coinSymbol: coin,
                                    daysAtLevel: daysCache[coin]
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
                        ShimmerPlaceholderCard(title: "App Store Rankings", icon: "arrow.down.app", isLoading: viewModel.isLoading) {
                            await viewModel.retryAppStoreRankings()
                        }
                    } else {
                        NavigationLink(destination: AppStoreRankingDetailView(viewModel: viewModel).zoomDestination(id: "app-store-rankings", in: zoomNamespace)) {
                            AppStoreRankingsCard(rankings: viewModel.appStoreRankings)
                        }
                        .zoomSource(id: "app-store-rankings", in: zoomNamespace)
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
                    ShimmerPlaceholderCard(title: "Funding Rate", icon: "percent", isLoading: viewModel.isLoading) {
                        await viewModel.retryFundingRate()
                    }
                }
            }
        }
    }

    /// Pre-compute consecutive days at current risk level for all coins
    private var consecutiveDaysCache: [String: Int] {
        var cache: [String: Int] = [:]
        for (coin, current) in viewModel.riskLevels {
            let history = viewModel.riskHistories[coin] ?? []
            guard !history.isEmpty else { continue }
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
            if count >= 1 { cache[coin] = count }
        }
        return cache
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

// MARK: - Shimmer Placeholder Card (Loading vs No Data with Retry)
struct ShimmerPlaceholderCard: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let icon: String
    let isLoading: Bool
    var onRetry: (() async -> Void)? = nil

    var body: some View {
        if isLoading {
            // Shimmer skeleton during loading
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(height: 12, cornerRadius: 4)
                    .frame(width: 80)

                Spacer()

                VStack(spacing: 8) {
                    SkeletonView(height: 28, cornerRadius: 6)
                        .frame(width: 60)
                    SkeletonView(height: 10, cornerRadius: 4)
                        .frame(width: 50)
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120)
            .glassCard(cornerRadius: 16)
        } else if let onRetry {
            // Tappable "No Data" with retry
            Button {
                Task { await onRetry() }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    VStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.accent.opacity(0.7))

                        Text("Tap to retry")
                            .font(.caption2)
                            .foregroundColor(AppColors.accent.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)

                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 120)
                .glassCard(cornerRadius: 16)
                .opacity(0.7)
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            PlaceholderCard(title: title, icon: icon)
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
