import SwiftUI

// MARK: - Performance Summary Card
struct PerformanceSummaryCard: View {
    @Environment(\.colorScheme) var colorScheme
    let metrics: PerformanceMetrics

    var body: some View {
        VStack(spacing: 16) {
            // Total Return
            VStack(spacing: 4) {
                Text("Total Return")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)

                Text(metrics.totalReturn.asCurrency)
                    .font(AppFonts.number36)
                    .foregroundColor(metrics.totalReturn >= 0 ? AppColors.success : AppColors.error)

                HStack(spacing: 4) {
                    Image(systemName: metrics.totalReturnPercentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12))
                    Text("\(metrics.totalReturnPercentage >= 0 ? "+" : "")\(String(format: "%.2f", metrics.totalReturnPercentage))%")
                        .font(AppFonts.body14Bold)
                }
                .foregroundColor(metrics.totalReturn >= 0 ? AppColors.success : AppColors.error)
            }

            Divider()

            // Quick Stats Row
            HStack(spacing: 0) {
                QuickMetricItem(title: "Trades", value: "\(metrics.numberOfTrades)")
                Divider().frame(height: 40)
                QuickMetricItem(title: "Win Rate", value: String(format: "%.1f%%", metrics.winRate))
                Divider().frame(height: 40)
                QuickMetricItem(title: "Sharpe", value: String(format: "%.2f", metrics.sharpeRatio))
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Win/Loss Stats Card
struct WinLossStatsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let metrics: PerformanceMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Win/Loss Analysis")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            HStack(spacing: 16) {
                // Wins
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppColors.success.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Text("\(metrics.winningTrades)")
                            .font(AppFonts.number20)
                            .foregroundColor(AppColors.success)
                    }

                    Text("Winning")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)

                    Text(metrics.averageWin.asCurrency)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.success)

                    Text("Avg Win")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)

                // VS Divider
                VStack {
                    Text("VS")
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Losses
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppColors.error.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Text("\(metrics.losingTrades)")
                            .font(AppFonts.number20)
                            .foregroundColor(AppColors.error)
                    }

                    Text("Losing")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)

                    Text(metrics.averageLoss.asCurrency)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.error)

                    Text("Avg Loss")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Risk/Reward Ratio
            HStack {
                Text("Risk/Reward Ratio")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text(metrics.riskRewardRatio)
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
            }
            .padding(.top, 8)
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Risk Metrics Card
struct RiskMetricsCard: View {
    @Environment(\.colorScheme) var colorScheme
    let metrics: PerformanceMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Risk Metrics")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 12) {
                RiskMetricRow(
                    title: "Maximum Drawdown",
                    value: String(format: "%.2f%%", metrics.maxDrawdown),
                    subtitle: metrics.maxDrawdownValue.asCurrency,
                    icon: "chart.line.downtrend.xyaxis",
                    color: AppColors.error
                )

                Divider()

                RiskMetricRow(
                    title: "Sharpe Ratio",
                    value: String(format: "%.2f", metrics.sharpeRatio),
                    subtitle: metrics.sharpeRating,
                    icon: "chart.bar.doc.horizontal",
                    color: metrics.sharpeColor
                )

                Divider()

                RiskMetricRow(
                    title: "Avg Holding Period",
                    value: String(format: "%.1f days", metrics.averageHoldingPeriodDays),
                    subtitle: metrics.holdingPeriodDescription,
                    icon: "clock",
                    color: AppColors.accent
                )
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Equity Curve Card
struct EquityCurveCard: View {
    @Environment(\.colorScheme) var colorScheme
    let historyPoints: [PortfolioHistoryPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Equity Curve")
                    .font(AppFonts.title18SemiBold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                if let first = historyPoints.first?.value, let last = historyPoints.last?.value, first > 0 {
                    let change = ((last - first) / first) * 100
                    Text("\(change >= 0 ? "+" : "")\(String(format: "%.1f", change))%")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                }
            }

            EquityCurveChart(data: historyPoints)
                .frame(height: 180)
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Supporting Views

struct QuickMetricItem: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
        .frame(maxWidth: .infinity)
    }
}

struct RiskMetricRow: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)

                Text(subtitle)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary.opacity(0.7))
            }

            Spacer()

            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))
        }
    }
}

// MARK: - Equity Curve Chart
struct EquityCurveChart: View {
    let data: [PortfolioHistoryPoint]

    private var sortedData: [PortfolioHistoryPoint] {
        data.sorted { $0.date < $1.date }
    }

    var body: some View {
        GeometryReader { geometry in
            let values = sortedData.map { $0.value }
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = maxValue - minValue
            let isPositive = (values.last ?? 0) >= (values.first ?? 0)

            ZStack {
                // Grid lines
                VStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { _ in
                        Divider()
                            .background(Color.white.opacity(0.1))
                        Spacer()
                    }
                    Divider()
                        .background(Color.white.opacity(0.1))
                }

                // Area fill
                Path { path in
                    guard sortedData.count > 1 else { return }

                    let stepX = geometry.size.width / CGFloat(sortedData.count - 1)

                    path.move(to: CGPoint(x: 0, y: geometry.size.height))

                    for (index, point) in sortedData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = range > 0
                            ? geometry.size.height - (CGFloat(point.value - minValue) / CGFloat(range)) * geometry.size.height
                            : geometry.size.height / 2

                        path.addLine(to: CGPoint(x: x, y: y))
                    }

                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            (isPositive ? AppColors.success : AppColors.error).opacity(0.3),
                            (isPositive ? AppColors.success : AppColors.error).opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Line
                Path { path in
                    guard sortedData.count > 1 else { return }

                    let stepX = geometry.size.width / CGFloat(sortedData.count - 1)

                    for (index, point) in sortedData.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = range > 0
                            ? geometry.size.height - (CGFloat(point.value - minValue) / CGFloat(range)) * geometry.size.height
                            : geometry.size.height / 2

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    isPositive ? AppColors.success : AppColors.error,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }
}

// MARK: - Empty Performance State
struct EmptyPerformanceState: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textSecondary.opacity(0.5))

            Text("No Performance Data")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Complete some trades to see your performance metrics and analytics.")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Export View (for screenshot capture)
struct PerformanceExportView: View {
    let portfolioName: String
    let metrics: PerformanceMetrics
    let historyPoints: [PortfolioHistoryPoint]

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Text(portfolioName)
                    .font(AppFonts.title24)
                    .foregroundColor(.white)

                Text("Performance Report")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)

                Text(Date(), style: .date)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.top, 20)

            PerformanceSummaryCard(metrics: metrics)
                .padding(.horizontal, 20)

            WinLossStatsCard(metrics: metrics)
                .padding(.horizontal, 20)

            RiskMetricsCard(metrics: metrics)
                .padding(.horizontal, 20)

            if !historyPoints.isEmpty {
                EquityCurveCard(historyPoints: historyPoints)
                    .padding(.horizontal, 20)
            }

            // Branding
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AppColors.accent)
                Text("Generated by ArkLine")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.bottom, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0F0F0F"))
    }
}
