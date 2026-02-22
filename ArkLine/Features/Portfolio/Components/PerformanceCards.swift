import SwiftUI

// MARK: - Return Summary Card
struct ReturnSummaryCard: View {
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
                QuickMetricItem(title: "Invested", value: metrics.totalInvested.asCurrency)
                Divider().frame(height: 40)
                QuickMetricItem(title: "Current", value: metrics.currentValue.asCurrency)
                Divider().frame(height: 40)
                QuickMetricItem(title: "Assets", value: "\(metrics.numberOfAssets)")
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Asset Performance Card
struct AssetPerformanceCard: View {
    @Environment(\.colorScheme) var colorScheme
    let holdings: [PortfolioHolding]
    let totalValue: Double

    private var sortedHoldings: [PortfolioHolding] {
        holdings.sorted { $0.profitLossPercentage > $1.profitLossPercentage }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Asset Performance")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if sortedHoldings.isEmpty {
                Text("No holdings to display")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 12) {
                    ForEach(sortedHoldings.prefix(8)) { holding in
                        AssetPerformanceRow(holding: holding, totalValue: totalValue)

                        if holding.id != sortedHoldings.prefix(8).last?.id {
                            Divider()
                        }
                    }

                    if sortedHoldings.count > 8 {
                        Text("+\(sortedHoldings.count - 8) more")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Asset Performance Row
private struct AssetPerformanceRow: View {
    @Environment(\.colorScheme) var colorScheme
    let holding: PortfolioHolding
    let totalValue: Double

    private var contribution: Double {
        guard totalValue > 0 else { return 0 }
        return holding.currentValue / totalValue
    }

    var body: some View {
        HStack(spacing: 12) {
            CoinIconView(symbol: holding.symbol, size: 32, iconUrl: holding.iconUrl)

            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol.uppercased())
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                // Contribution bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.textSecondary.opacity(0.15))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(holding.isProfit ? AppColors.success : AppColors.error)
                            .frame(width: max(4, geometry.size.width * contribution), height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(holding.profitLossPercentage >= 0 ? "+" : "")\(String(format: "%.1f", holding.profitLossPercentage))%")
                    .font(AppFonts.body14Bold)
                    .foregroundColor(holding.isProfit ? AppColors.success : AppColors.error)

                Text(holding.profitLoss.asCurrency)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Investment Activity Card
struct InvestmentActivityCard: View {
    @Environment(\.colorScheme) var colorScheme
    let monthlyInvestments: [MonthlyInvestment]

    private var maxAmount: Double {
        monthlyInvestments.map(\.amount).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Investment Activity")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if monthlyInvestments.isEmpty {
                Text("No buy transactions yet")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach(monthlyInvestments) { month in
                        HStack(spacing: 12) {
                            Text(month.label)
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 55, alignment: .trailing)

                            GeometryReader { geometry in
                                let barWidth = maxAmount > 0
                                    ? max(4, geometry.size.width * (month.amount / maxAmount))
                                    : 4

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.accent)
                                    .frame(width: barWidth, height: 20)
                            }
                            .frame(height: 20)

                            Text(month.amount.asCurrency)
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                                .frame(width: 80, alignment: .trailing)
                        }
                    }
                }
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
                Text("Portfolio Value")
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

            Text("Add holdings to your portfolio to see performance metrics and analytics.")
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
    let holdings: [PortfolioHolding]

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

            ReturnSummaryCard(metrics: metrics)
                .padding(.horizontal, 20)

            if !holdings.isEmpty {
                AssetPerformanceCard(
                    holdings: holdings,
                    totalValue: metrics.currentValue
                )
                .padding(.horizontal, 20)
            }

            if !historyPoints.isEmpty {
                EquityCurveCard(historyPoints: historyPoints)
                    .padding(.horizontal, 20)
            }

            if !metrics.monthlyInvestments.isEmpty {
                InvestmentActivityCard(monthlyInvestments: metrics.monthlyInvestments)
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
