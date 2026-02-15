import SwiftUI

// MARK: - Derivatives Data Section
struct DerivativesDataSection: View {
    @Environment(\.colorScheme) var colorScheme
    let overview: DerivativesOverview?
    let isLoading: Bool

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(AppColors.accent)
                Text("Derivatives")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                if let overview = overview {
                    Text("Updated \(overview.lastUpdated.formatted(.relative(presentation: .numeric)))")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, 20)

            if isLoading {
                DerivativesLoadingView()
                    .padding(.horizontal, 20)
            } else if let overview = overview {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Open Interest Card
                        OpenInterestCard(
                            btcOI: overview.btcOpenInterest,
                            ethOI: overview.ethOpenInterest
                        )

                        // Liquidations Card
                        LiquidationsCard(liquidations: overview.totalLiquidations24h)

                        // Funding Rates Card
                        FundingRatesCard(
                            btcFunding: overview.btcFundingRate,
                            ethFunding: overview.ethFundingRate
                        )

                        // Long/Short Ratio Card
                        LongShortRatioCard(
                            btcRatio: overview.btcLongShortRatio,
                            ethRatio: overview.ethLongShortRatio
                        )
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                DerivativesEmptyView()
                    .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Open Interest Card
struct OpenInterestCard: View {
    @Environment(\.colorScheme) var colorScheme
    let btcOI: OpenInterestData
    let ethOI: OpenInterestData

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.pie")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)
                Text("Open Interest")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Divider()

            // BTC OI
            OIRow(
                symbol: "BTC",
                oi: btcOI.formattedOI,
                change: btcOI.openInterestChangePercent24h,
                isPositive: btcOI.isPositiveChange
            )

            // ETH OI
            OIRow(
                symbol: "ETH",
                oi: ethOI.formattedOI,
                change: ethOI.openInterestChangePercent24h,
                isPositive: ethOI.isPositiveChange
            )
        }
        .padding(16)
        .frame(width: max(160, UIScreen.main.bounds.width * 0.48), height: 160)
        .background(cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct OIRow: View {
    @Environment(\.colorScheme) var colorScheme
    let symbol: String
    let oi: String
    let change: Double
    let isPositive: Bool

    var body: some View {
        HStack {
            Text(symbol)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .frame(minWidth: 30, alignment: .leading)

            Text(oi)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Spacer()

            HStack(spacing: 2) {
                Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text(String(format: "%.1f%%", abs(change)))
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(isPositive ? AppColors.success : AppColors.error)
        }
    }
}

// MARK: - Liquidations Card
struct LiquidationsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let liquidations: CoinglassLiquidationData

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "flame")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.error)
                Text("24h Liquidations")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Divider()

            // Total
            VStack(alignment: .leading, spacing: 4) {
                Text("Total")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                Text(liquidations.formattedTotal)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            // Long/Short Bar
            LiquidationBar(
                longPercent: liquidations.longPercentage,
                shortPercent: liquidations.shortPercentage
            )

            // Long/Short Labels
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Longs")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(liquidations.formattedLongs)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.success)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Shorts")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    Text(liquidations.formattedShorts)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.error)
                }
            }
        }
        .padding(16)
        .frame(width: max(160, UIScreen.main.bounds.width * 0.48), height: 160)
        .background(cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct LiquidationBar: View {
    let longPercent: Double
    let shortPercent: Double

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                // Long bar (green)
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.success)
                    .frame(width: max(geo.size.width * (longPercent / 100) - 1, 0))

                // Short bar (red)
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.error)
                    .frame(width: max(geo.size.width * (shortPercent / 100) - 1, 0))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Funding Rates Card
struct FundingRatesCard: View {
    @Environment(\.colorScheme) var colorScheme
    let btcFunding: CoinglassFundingRateData
    let ethFunding: CoinglassFundingRateData

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "percent")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.warning)
                Text("Funding Rates")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Divider()

            // BTC Funding
            FundingRow(
                symbol: "BTC",
                rate: btcFunding.formattedRate,
                sentiment: btcFunding.sentiment
            )

            // ETH Funding
            FundingRow(
                symbol: "ETH",
                rate: ethFunding.formattedRate,
                sentiment: ethFunding.sentiment
            )

            // Sentiment indicator
            HStack {
                Image(systemName: btcFunding.sentiment.icon)
                    .font(.system(size: 12))
                Text(btcFunding.sentiment.rawValue)
                    .font(.caption2)
            }
            .foregroundColor(Color(hex: btcFunding.sentiment.color.replacingOccurrences(of: "#", with: "")))
        }
        .padding(16)
        .frame(width: max(160, UIScreen.main.bounds.width * 0.48), height: 160)
        .background(cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct FundingRow: View {
    @Environment(\.colorScheme) var colorScheme
    let symbol: String
    let rate: String
    let sentiment: FundingRateSentiment

    var body: some View {
        HStack {
            Text(symbol)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textSecondary)
                .frame(minWidth: 30, alignment: .leading)

            Text(rate)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: sentiment.color.replacingOccurrences(of: "#", with: "")))

            Spacer()
        }
    }
}

// MARK: - Long/Short Ratio Card
struct LongShortRatioCard: View {
    @Environment(\.colorScheme) var colorScheme
    let btcRatio: LongShortRatioData
    let ethRatio: LongShortRatioData

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.accent)
                Text("Long/Short")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }

            Divider()

            // BTC L/S
            LSRow(
                symbol: "BTC",
                longPercent: btcRatio.longRatio * 100,
                shortPercent: btcRatio.shortRatio * 100,
                ratio: btcRatio.formattedRatio
            )

            // ETH L/S
            LSRow(
                symbol: "ETH",
                longPercent: ethRatio.longRatio * 100,
                shortPercent: ethRatio.shortRatio * 100,
                ratio: ethRatio.formattedRatio
            )

            // Sentiment
            HStack {
                Text(btcRatio.sentiment.rawValue)
                    .font(.caption2)
                    .foregroundColor(Color(hex: btcRatio.sentiment.color.replacingOccurrences(of: "#", with: "")))
            }
        }
        .padding(16)
        .frame(width: max(160, UIScreen.main.bounds.width * 0.48), height: 160)
        .background(cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct LSRow: View {
    @Environment(\.colorScheme) var colorScheme
    let symbol: String
    let longPercent: Double
    let shortPercent: Double
    let ratio: String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(minWidth: 30, alignment: .leading)

                // Mini bar
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.success)
                            .frame(width: geo.size.width * (longPercent / 100))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.error)
                            .frame(width: geo.size.width * (shortPercent / 100))
                    }
                }
                .frame(height: 6)

                Text(ratio)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .frame(minWidth: 30, alignment: .trailing)
            }
        }
    }
}

// MARK: - Loading View
struct DerivativesLoadingView: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<4) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: max(160, UIScreen.main.bounds.width * 0.48), height: 160)
                    .shimmer(isLoading: true)
            }
        }
    }
}

// MARK: - Empty View
struct DerivativesEmptyView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textSecondary)

            Text("Unable to load derivatives data")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
    }
}

// MARK: - Preview
#Preview {
    VStack {
        DerivativesDataSection(
            overview: DerivativesOverview(
                btcOpenInterest: OpenInterestData(
                    id: UUID(),
                    symbol: "BTC",
                    openInterest: 38_500_000_000,
                    openInterestChange24h: 1_250_000_000,
                    openInterestChangePercent24h: 3.35,
                    timestamp: Date(),
                    exchangeBreakdown: nil
                ),
                ethOpenInterest: OpenInterestData(
                    id: UUID(),
                    symbol: "ETH",
                    openInterest: 14_200_000_000,
                    openInterestChange24h: -420_000_000,
                    openInterestChangePercent24h: -2.87,
                    timestamp: Date(),
                    exchangeBreakdown: nil
                ),
                totalMarketOI: 98_500_000_000,
                totalLiquidations24h: CoinglassLiquidationData(
                    id: UUID(),
                    symbol: "ALL",
                    longLiquidations24h: 145_000_000,
                    shortLiquidations24h: 98_000_000,
                    totalLiquidations24h: 243_000_000,
                    largestLiquidation: nil,
                    timestamp: Date()
                ),
                btcFundingRate: CoinglassFundingRateData(
                    id: UUID(),
                    symbol: "BTC",
                    fundingRate: 0.0082,
                    predictedRate: 0.0085,
                    nextFundingTime: Date().addingTimeInterval(3600),
                    annualizedRate: 8.97,
                    timestamp: Date(),
                    exchangeRates: nil
                ),
                ethFundingRate: CoinglassFundingRateData(
                    id: UUID(),
                    symbol: "ETH",
                    fundingRate: 0.0095,
                    predictedRate: 0.0092,
                    nextFundingTime: Date().addingTimeInterval(3600),
                    annualizedRate: 10.4,
                    timestamp: Date(),
                    exchangeRates: nil
                ),
                btcLongShortRatio: LongShortRatioData(
                    id: UUID(),
                    symbol: "BTC",
                    longRatio: 0.52,
                    shortRatio: 0.48,
                    longShortRatio: 1.08,
                    topTraderLongRatio: 0.55,
                    topTraderShortRatio: 0.45,
                    timestamp: Date(),
                    exchangeRatios: nil
                ),
                ethLongShortRatio: LongShortRatioData(
                    id: UUID(),
                    symbol: "ETH",
                    longRatio: 0.54,
                    shortRatio: 0.46,
                    longShortRatio: 1.17,
                    topTraderLongRatio: 0.58,
                    topTraderShortRatio: 0.42,
                    timestamp: Date(),
                    exchangeRatios: nil
                ),
                lastUpdated: Date()
            ),
            isLoading: false
        )
    }
    .background(Color(hex: "0F0F0F"))
}
