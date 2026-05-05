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
                        .foregroundColor(AppColors.textPrimary(colorScheme))

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

                    Text("Search Interest")
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

// MARK: - Perpetual Premium Sentiment Card
struct PerpPremiumSentimentCard: View {
    @Environment(\.colorScheme) var colorScheme
    let btcPremium: PerpetualPremiumData?
    let ethPremium: PerpetualPremiumData?
    var isLoading: Bool = false
    @State private var showExplainer = false

    private var primary: PerpetualPremiumData? { btcPremium ?? ethPremium }

    private var scoreColor: Color {
        guard let p = primary else { return AppColors.textSecondary }
        return Color(hex: p.sentiment.color.replacingOccurrences(of: "#", with: ""))
    }

    var body: some View {
        Button { showExplainer = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Perp Premium")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary.opacity(0.4))

                    Spacer()

                    Text("Binance")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }

                if let p = primary {
                    // Directional score
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(p.formattedScore)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(scoreColor)

                        Text(p.sentiment.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(scoreColor)
                    }

                    // Score bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.15))

                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 1)
                                .offset(x: geo.size.width / 2)

                            let normalized = (p.directionalScore + 100) / 200
                            let barWidth = geo.size.width * abs(normalized - 0.5)
                            let barOffset = normalized >= 0.5
                                ? geo.size.width / 2
                                : geo.size.width * normalized

                            RoundedRectangle(cornerRadius: 3)
                                .fill(scoreColor)
                                .frame(width: barWidth)
                                .offset(x: barOffset)
                        }
                    }
                    .frame(height: 6)

                    // BTC / ETH spreads
                    HStack(spacing: 12) {
                        if let btc = btcPremium {
                            HStack(spacing: 4) {
                                Text("BTC")
                                    .font(.system(size: 9))
                                    .foregroundColor(AppColors.textSecondary)
                                Text(btc.formattedSpread)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(btc.directionalScore > 10 ? AppColors.success : btc.directionalScore < -10 ? AppColors.error : AppColors.textSecondary)
                            }
                        }
                        if let eth = ethPremium {
                            HStack(spacing: 4) {
                                Text("ETH")
                                    .font(.system(size: 9))
                                    .foregroundColor(AppColors.textSecondary)
                                Text(eth.formattedSpread)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(eth.directionalScore > 10 ? AppColors.success : eth.directionalScore < -10 ? AppColors.error : AppColors.textSecondary)
                            }
                        }
                    }
                } else {
                    Spacer()
                    if isLoading {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading...")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    } else {
                        Text("Unavailable")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    }
                    Spacer()
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 120)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showExplainer) {
            PerpPremiumExplainerView(
                btcPremium: btcPremium,
                ethPremium: ethPremium
            )
        }
    }
}

// MARK: - Perp Premium Explainer
struct PerpPremiumExplainerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    let btcPremium: PerpetualPremiumData?
    let ethPremium: PerpetualPremiumData?

    private var primary: PerpetualPremiumData? { btcPremium ?? ethPremium }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ArkSpacing.lg) {

                    // Current reading
                    if let p = primary {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CURRENT READING")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.accent)
                                .tracking(1)

                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(p.formattedScore)
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(Color(hex: p.sentiment.color.replacingOccurrences(of: "#", with: "")))

                                Text(p.sentiment.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Color(hex: p.sentiment.color.replacingOccurrences(of: "#", with: "")))
                            }

                            Text(p.sentiment.explanation)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)

                            // BTC vs ETH comparison
                            if let btc = btcPremium, let eth = ethPremium {
                                let agree = (btc.directionalScore > 0) == (eth.directionalScore > 0)
                                HStack(spacing: ArkSpacing.md) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("BTC")
                                            .font(.caption2)
                                            .foregroundColor(AppColors.textSecondary)
                                        Text(btc.formattedScore)
                                            .font(.headline)
                                            .foregroundColor(Color(hex: btc.sentiment.color.replacingOccurrences(of: "#", with: "")))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("ETH")
                                            .font(.caption2)
                                            .foregroundColor(AppColors.textSecondary)
                                        Text(eth.formattedScore)
                                            .font(.headline)
                                            .foregroundColor(Color(hex: eth.sentiment.color.replacingOccurrences(of: "#", with: "")))
                                    }
                                    Spacer()
                                    Text(agree ? "Aligned" : "Diverging")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(agree ? AppColors.success : AppColors.warning)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background((agree ? AppColors.success : AppColors.warning).opacity(0.12))
                                        .cornerRadius(6)
                                }
                                .padding(ArkSpacing.md)
                                .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                                .cornerRadius(ArkSpacing.Radius.sm)
                            }
                        }
                        .padding(ArkSpacing.lg)
                        .background(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
                        .cornerRadius(ArkSpacing.Radius.card)
                    }

                    // What is it
                    explainerSection(
                        title: "WHAT IS IT",
                        body: "The Perp Premium score measures which side of the perpetual futures market is more aggressive. It ranges from -100 (extreme short bias) to +100 (extreme long bias). When traders are willing to pay a premium to hold long positions, funding rates go positive — the score rises. When shorts dominate, rates go negative — the score drops."
                    )

                    // How to read it
                    explainerSection(title: "HOW TO READ IT", body: nil) {
                        VStack(alignment: .leading, spacing: 10) {
                            readingRow(range: "+50 to +100", label: "Strong Long Bias", detail: "Longs are crowded and paying high premiums. Historically precedes sharp pullbacks — be cautious adding longs here.", color: AppColors.success)
                            readingRow(range: "+20 to +50", label: "Long Bias", detail: "Bullish positioning with conviction. If price is also rising, this confirms the move is backed by leveraged money.", color: Color(hex: "4ADE80"))
                            readingRow(range: "-20 to +20", label: "Neutral", detail: "No strong directional bet. The market is waiting for a catalyst. Good time to watch, not chase.", color: AppColors.textSecondary)
                            readingRow(range: "-50 to -20", label: "Short Bias", detail: "Bearish positioning. If price is dropping, shorts are in control. If price holds here, a squeeze may be building.", color: Color(hex: "F87171"))
                            readingRow(range: "-100 to -50", label: "Strong Short Bias", detail: "Shorts are crowded. Historically a contrarian buy signal — short squeezes often start from these levels.", color: AppColors.error)
                        }
                    }

                    // BTC vs ETH divergence
                    explainerSection(
                        title: "BTC vs ETH DIVERGENCE",
                        body: "When BTC and ETH funding rates point in opposite directions, the market is in transition. One side hasn't committed yet. Wait for alignment — when both agree on direction, the move tends to be stronger and more sustained."
                    )

                    // How we calculate it
                    explainerSection(
                        title: "HOW IT'S CALCULATED",
                        body: "The score is derived from funding rates on Binance perpetual futures. Funding is charged every 8 hours — when longs pay shorts, the rate is positive (bullish). When shorts pay longs, negative (bearish). We normalize the rate into a -100 to +100 scale so you can read it at a glance."
                    )

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, ArkSpacing.lg)
                .padding(.top, ArkSpacing.md)
            }
            .background(Color(colorScheme == .dark ? UIColor.systemBackground : UIColor.secondarySystemBackground))
            .navigationTitle("Perp Premium")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private func explainerSection(title: String, body: String?, @ViewBuilder content: () -> some View = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.accent)
                .tracking(1)

            if let body {
                Text(body)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineSpacing(4)
            }

            content()
        }
        .padding(ArkSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        .cornerRadius(ArkSpacing.Radius.card)
    }

    private func readingRow(range: String, label: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                Text(range)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }

            Text(detail)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(2)
        }
    }
}

// MARK: - Funding Rate Card
struct FundingRateCard: View {
    @Environment(\.colorScheme) var colorScheme
    let fundingRate: FundingRate
    @State private var showingDetail = false

    private func rateColor(for rate: Double) -> Color {
        if rate > 0.0005 { return AppColors.success }
        if rate < -0.0005 { return AppColors.error }
        return AppColors.warning
    }

    private var btcRate: ExchangeFundingRate? {
        fundingRate.exchanges.first(where: { $0.exchange == "BTC" })
    }

    private var ethRate: ExchangeFundingRate? {
        fundingRate.exchanges.first(where: { $0.exchange == "ETH" })
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Funding Rate")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Text("Binance")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 16) {
                    if let btc = btcRate {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BTC")
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary)
                            Text(String(format: "%.4f%%", btc.rate * 100))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(rateColor(for: btc.rate))
                        }
                    }
                    if let eth = ethRate {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ETH")
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary)
                            Text(String(format: "%.4f%%", eth.rate * 100))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(rateColor(for: eth.rate))
                        }
                    }
                }

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
