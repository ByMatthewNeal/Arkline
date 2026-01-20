import SwiftUI

// MARK: - Market Sentiment Section
struct MarketSentimentSection: View {
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: SentimentViewModel
    let lastUpdated: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Market Sentiment")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Upd: \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 20)

            // 2-Column Grid with 10 Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // 1. Fear & Greed Index
                if let fearGreed = viewModel.fearGreedIndex {
                    NavigationLink(destination: FearGreedDetailView()) {
                        FearGreedSentimentCard(index: fearGreed)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // 2. Risk Level
                if let riskLevel = viewModel.riskLevel {
                    RiskLevelCard(riskLevel: riskLevel)
                }

                // 3. Altcoin Season
                if let altcoin = viewModel.altcoinSeason {
                    NavigationLink(destination: AltcoinSeasonDetailView()) {
                        AltcoinSeasonCard(index: altcoin)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // 4. Market Cap
                MarketCapCard(
                    marketCap: viewModel.totalMarketCap,
                    change: viewModel.marketCapChange24h,
                    sparklineData: viewModel.marketCapHistory
                )

                // 5. Coinbase App Store Ranking
                if let appStore = viewModel.appStoreRanking {
                    AppStoreRankCard(ranking: appStore)
                }

                // 6. BTC Dominance
                if let btcDom = viewModel.btcDominance {
                    NavigationLink(destination: BTCDominanceDetailView()) {
                        BTCDominanceCard(dominance: btcDom)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // 7. Bitcoin Search (Google Trends)
                BitcoinSearchCard(searchIndex: viewModel.bitcoinSearchIndex)

                // 8. BTC ETF Net Flow
                if let etf = viewModel.etfNetFlow {
                    NavigationLink(destination: ETFNetFlowDetailView()) {
                        ETFNetFlowCard(etfFlow: etf)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // 9. Funding Rate
                if let funding = viewModel.fundingRate {
                    NavigationLink(destination: FundingRateDetailView()) {
                        FundingRateCard(fundingRate: funding)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // 10. Liquidation Levels
                if let liquidation = viewModel.liquidations {
                    NavigationLink(destination: LiquidationDetailView()) {
                        LiquidationLevelsCard(liquidation: liquidation)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
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
