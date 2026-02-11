import SwiftUI

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
