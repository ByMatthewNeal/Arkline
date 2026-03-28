import SwiftUI

struct SnapshotSlideView: View {
    let data: SnapshotSlideData
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    private let riskColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            SlideHeader(title: title)

            // Regression Risk Levels — card style matching app
            if !data.assetRisks.isEmpty {
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    Text(data.riskTypeLabel)
                        .font(AppFonts.interFont(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.accent.opacity(0.6))
                        .tracking(1.5)

                    ForEach(data.assetRisks) { asset in
                        riskCard(asset)
                    }
                }
            }

            // Equities — S&P 500 & Nasdaq with trend signals
            if data.spyWeekChange != nil || data.qqqWeekChange != nil {
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    Text("EQUITIES")
                        .font(AppFonts.interFont(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.accent.opacity(0.6))
                        .tracking(1.5)

                    HStack(spacing: ArkSpacing.sm) {
                        if let spyChange = data.spyWeekChange {
                            equityTile(
                                label: "S&P 500",
                                price: data.spyPrice,
                                change: spyChange,
                                signal: data.spySignal
                            )
                        }
                        if let qqqChange = data.qqqWeekChange {
                            equityTile(
                                label: "NASDAQ",
                                price: data.qqqPrice,
                                change: qqqChange,
                                signal: data.qqqSignal
                            )
                        }
                    }
                }
            }

            // Fear & Greed + Sentiment Regime row
            HStack(spacing: ArkSpacing.sm) {
                if data.fearGreedEnd != nil || data.fearGreedAvg != nil {
                    VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                        Text("FEAR & GREED")
                            .font(AppFonts.interFont(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.accent.opacity(0.6))
                            .tracking(1.5)

                        VStack(spacing: ArkSpacing.xxs) {
                            if let end = data.fearGreedEnd {
                                HStack(spacing: 4) {
                                    Text("\(end)")
                                        .font(AppFonts.number24)
                                        .foregroundColor(fearGreedColor(end))
                                    Text(fearGreedLabel(end))
                                        .font(AppFonts.footnote10)
                                        .foregroundColor(fearGreedColor(end).opacity(0.7))
                                }
                            }
                            if let avg = data.fearGreedAvg {
                                Text("Week avg: \(avg)")
                                    .font(AppFonts.caption12)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(ArkSpacing.md)
                        .background(AppColors.textPrimary(colorScheme).opacity(0.06))
                        .cornerRadius(ArkSpacing.Radius.md)
                    }
                }

                if let regime = data.sentimentRegime, !regime.isEmpty {
                    VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                        Text("SENTIMENT")
                            .font(AppFonts.interFont(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.accent.opacity(0.6))
                            .tracking(1.5)

                        VStack(spacing: ArkSpacing.xxs) {
                            Image(systemName: regimeIcon(regime))
                                .font(.system(size: 20))
                                .foregroundColor(regimeColor(regime))
                            Text(regime)
                                .font(AppFonts.body14Medium)
                                .foregroundColor(regimeColor(regime))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(ArkSpacing.md)
                        .background(AppColors.textPrimary(colorScheme).opacity(0.06))
                        .cornerRadius(ArkSpacing.Radius.md)
                    }
                }
            }

            // BTC Supply in Profit
            if let supply = data.btcSupplyInProfit {
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    Text("BTC SUPPLY IN PROFIT")
                        .font(AppFonts.interFont(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.accent.opacity(0.6))
                        .tracking(1.5)

                    HStack(spacing: ArkSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1f%%", supply))
                                .font(AppFonts.number20)
                                .foregroundColor(supplyColor(supply))
                            Text(supplyZoneLabel(supply))
                                .font(AppFonts.footnote10)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AppColors.textPrimary(colorScheme).opacity(0.08))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(supplyGradient(supply))
                                    .frame(width: geo.size.width * CGFloat(min(supply, 100) / 100))
                            }
                        }
                        .frame(width: 120, height: 6)
                    }
                    .padding(ArkSpacing.md)
                    .background(AppColors.textPrimary(colorScheme).opacity(0.04))
                    .cornerRadius(ArkSpacing.Radius.md)
                }
            }
        }
    }

    // MARK: - Risk Card (matches app's existing style)

    @ViewBuilder
    private func riskCard(_ asset: AssetRiskSnapshot) -> some View {
        let color = riskLevelColor(asset.riskLevel)

        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            // Header: symbol + signal badge
            HStack {
                Text(asset.symbol)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if let signal = asset.signal {
                    signalBadge(signal)
                }

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary.opacity(0.4))
            }

            // Big decimal risk number
            Text(String(format: "%.3f", asset.riskLevel))
                .font(AppFonts.number24)
                .foregroundColor(color)

            // Risk label with dot
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(asset.riskLabel)
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(color)
            }

            // Days at level
            if let days = asset.daysAtLevel, days > 0 {
                Text("\(days) days at this level")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Rectangle()
                .fill(AppColors.textPrimary(colorScheme).opacity(0.06))
                .frame(height: 1)

            // 7d Average
            if let avg = asset.weekAverage {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                    Text("7d Avg")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(String(format: "%.3f", avg))
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(riskLevelColor(avg))
                }
            }
        }
        .padding(ArkSpacing.md)
        .background(AppColors.textPrimary(colorScheme).opacity(0.04))
        .cornerRadius(ArkSpacing.Radius.lg)
    }

    // MARK: - Signal Badge

    @ViewBuilder
    private func signalBadge(_ signal: String) -> some View {
        let color = signalColor(signal)
        Text(signal.uppercased())
            .font(AppFonts.interFont(size: 9, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    // MARK: - Equity Tile

    @ViewBuilder
    private func equityTile(label: String, price: Double?, change: Double, signal: String?) -> some View {
        let isPositive = change >= 0

        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
            HStack {
                Text(label)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Spacer()
            }

            if let price {
                Text(price.asCurrency)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(String(format: "%+.2f%%", change))
                .font(AppFonts.number20)
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)

            if let signal {
                HStack(spacing: 4) {
                    Image(systemName: signal == "bullish" ? "arrow.up.right" : signal == "bearish" ? "arrow.down.right" : "minus")
                        .font(.system(size: 10, weight: .semibold))
                    Text(signal == "bullish" ? "Bullish Trend" : signal == "bearish" ? "Bearish Trend" : "Neutral")
                        .font(AppFonts.interFont(size: 10, weight: .semibold))
                }
                .foregroundColor(signalColor(signal))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ArkSpacing.md)
        .background(AppColors.textPrimary(colorScheme).opacity(0.06))
        .cornerRadius(ArkSpacing.Radius.md)
    }

    // MARK: - Color Helpers

    private func riskLevelColor(_ risk: Double) -> Color {
        switch risk {
        case 0..<0.2: return AppColors.success
        case 0.2..<0.4: return Color(hex: "84CC16")
        case 0.4..<0.55: return AppColors.warning
        case 0.55..<0.7: return Color(hex: "F97316")
        case 0.7..<0.9: return AppColors.error
        default: return Color(hex: "DC2626")
        }
    }

    private func signalColor(_ signal: String) -> Color {
        switch signal.lowercased() {
        case "bullish": return AppColors.success
        case "bearish": return AppColors.error
        default: return AppColors.warning
        }
    }

    private func fearGreedColor(_ value: Int) -> Color {
        switch value {
        case 0...24: return AppColors.error
        case 25...44: return Color(hex: "F97316")
        case 45...55: return AppColors.warning
        case 56...75: return Color(hex: "84CC16")
        default: return AppColors.success
        }
    }

    private func fearGreedLabel(_ value: Int) -> String {
        switch value {
        case 0...24: return "Extreme Fear"
        case 25...44: return "Fear"
        case 45...55: return "Neutral"
        case 56...75: return "Greed"
        default: return "Extreme Greed"
        }
    }

    private func regimeColor(_ regime: String) -> Color {
        switch regime.lowercased() {
        case "panic": return AppColors.error
        case "fomo": return Color(hex: "F97316")
        case "apathy": return AppColors.textSecondary
        case "complacency": return AppColors.warning
        default: return AppColors.accent
        }
    }

    private func regimeIcon(_ regime: String) -> String {
        switch regime.lowercased() {
        case "panic": return "exclamationmark.triangle.fill"
        case "fomo": return "flame.fill"
        case "apathy": return "moon.zzz.fill"
        case "complacency": return "sun.max.fill"
        default: return "questionmark.circle"
        }
    }

    private func supplyColor(_ pct: Double) -> Color {
        switch pct {
        case 0..<50: return AppColors.success
        case 50..<85: return AppColors.textPrimary(.light)
        case 85..<97: return AppColors.warning
        default: return AppColors.error
        }
    }

    private func supplyZoneLabel(_ pct: Double) -> String {
        switch pct {
        case 0..<50: return "Buy Zone"
        case 50..<85: return "Normal Range"
        case 85..<97: return "Elevated"
        default: return "Overheated"
        }
    }

    private func supplyGradient(_ pct: Double) -> LinearGradient {
        LinearGradient(
            colors: [AppColors.success, supplyColor(pct)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
