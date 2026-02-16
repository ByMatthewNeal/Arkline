import SwiftUI

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

// MARK: - Bitcoin Season Card (Enhanced)
struct BitcoinSeasonCard: View {
    @Environment(\.colorScheme) var colorScheme
    let index: AltcoinSeasonIndex

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Season Indicator")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Text(index.windowLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                    )
            }

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

// MARK: - Sentiment Regime Card (Compact)
struct SentimentRegimeCard: View {
    @Environment(\.colorScheme) var colorScheme
    let regimeData: SentimentRegimeData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sentiment Regime")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                Image(systemName: regimeData.currentRegime.icon)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: regimeData.currentRegime.colorHex))
            }

            Spacer()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(regimeData.currentRegime.rawValue)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("F&G: \(regimeData.currentPoint.fearGreedValue)")
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                MiniQuadrantIndicator(activeRegime: regimeData.currentRegime)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Mini Quadrant Indicator
/// A tiny 2x2 grid showing which quadrant is currently active
struct MiniQuadrantIndicator: View {
    @Environment(\.colorScheme) var colorScheme
    let activeRegime: SentimentRegime

    private let regimeLayout: [[SentimentRegime]] = [
        [.panic, .fomo],      // top row: high volume
        [.apathy, .complacency] // bottom row: low volume
    ]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<2, id: \.self) { col in
                        let regime = regimeLayout[row][col]
                        let isActive = regime == activeRegime
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                isActive
                                    ? Color(hex: regime.colorHex)
                                    : (colorScheme == .dark
                                        ? Color.white.opacity(0.08)
                                        : Color.black.opacity(0.06))
                            )
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
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
