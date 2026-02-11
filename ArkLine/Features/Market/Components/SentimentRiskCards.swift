import SwiftUI

// MARK: - Risk History Card (Tappable)
struct RiskHistoryCard: View {
    let history: [ITCRiskLevel]
    @Environment(\.colorScheme) var colorScheme
    @State private var showingDetail = false

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var chartData: [CGFloat] {
        // Convert risk levels to chart data points
        history.suffix(30).map { CGFloat($0.riskLevel) }
    }

    private var latestRisk: ITCRiskLevel? {
        history.last
    }

    private var trendDirection: String {
        guard history.count >= 2 else { return "stable" }
        let recent = history.suffix(7)
        guard let first = recent.first, let last = recent.last else { return "stable" }
        let diff = last.riskLevel - first.riskLevel
        if diff > 0.05 { return "rising" }
        else if diff < -0.05 { return "falling" }
        return "stable"
    }

    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("BTC Risk History")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(textPrimary)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        }

                        Text("30 Day Trend")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    // Trend indicator
                    HStack(spacing: 4) {
                        Image(systemName: trendIcon)
                            .font(.system(size: 12, weight: .bold))
                        Text(trendLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(trendColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(trendColor.opacity(0.15))
                    )
                }

                // Mini chart
                if !chartData.isEmpty {
                    RiskSparkline(dataPoints: chartData, colorScheme: colorScheme)
                        .frame(height: 60)
                }

                // Subtle attribution
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundColor(textPrimary.opacity(0.35))

                    Text("intothecryptoverse.com")
                        .font(.system(size: 9))
                        .foregroundColor(textPrimary.opacity(0.35))
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            RiskLevelChartView()
        }
    }

    private var trendIcon: String {
        switch trendDirection {
        case "rising": return "arrow.up.right"
        case "falling": return "arrow.down.right"
        default: return "arrow.right"
        }
    }

    private var trendLabel: String {
        switch trendDirection {
        case "rising": return "Rising"
        case "falling": return "Falling"
        default: return "Stable"
        }
    }

    private var trendColor: Color {
        switch trendDirection {
        case "rising": return AppColors.error
        case "falling": return AppColors.success
        default: return AppColors.warning
        }
    }
}

// Legacy alias
typealias ITCRiskHistoryCard = RiskHistoryCard

// MARK: - ITC Risk Sparkline
struct RiskSparkline: View {
    let dataPoints: [CGFloat]
    let colorScheme: ColorScheme

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let stepX = width / CGFloat(max(dataPoints.count - 1, 1))

            ZStack {
                // Risk zone backgrounds (6-tier system)
                VStack(spacing: 0) {
                    // Extreme risk zone (0.90-1.0 = 10%)
                    Rectangle()
                        .fill(RiskColors.extremeRisk.opacity(0.08))
                        .frame(height: height * 0.10)

                    // High risk zone (0.70-0.90 = 20%)
                    Rectangle()
                        .fill(RiskColors.highRisk.opacity(0.08))
                        .frame(height: height * 0.20)

                    // Elevated risk zone (0.55-0.70 = 15%)
                    Rectangle()
                        .fill(RiskColors.elevatedRisk.opacity(0.08))
                        .frame(height: height * 0.15)

                    // Neutral zone (0.40-0.55 = 15%)
                    Rectangle()
                        .fill(RiskColors.neutral.opacity(0.08))
                        .frame(height: height * 0.15)

                    // Low risk zone (0.20-0.40 = 20%)
                    Rectangle()
                        .fill(RiskColors.lowRisk.opacity(0.08))
                        .frame(height: height * 0.20)

                    // Very low risk zone (0.00-0.20 = 20%)
                    Rectangle()
                        .fill(RiskColors.veryLowRisk.opacity(0.08))
                        .frame(height: height * 0.20)
                }

                // Risk line (6-tier gradient)
                Path { path in
                    guard dataPoints.count > 1 else { return }

                    for (index, point) in dataPoints.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - (point * height) // Invert Y axis

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            RiskColors.veryLowRisk,
                            RiskColors.lowRisk,
                            RiskColors.neutral,
                            RiskColors.elevatedRisk,
                            RiskColors.highRisk,
                            RiskColors.extremeRisk
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                // End point indicator
                if let lastPoint = dataPoints.last {
                    let lastX = CGFloat(dataPoints.count - 1) * stepX
                    let lastY = height - (lastPoint * height)

                    Circle()
                        .fill(RiskColors.color(for: Double(lastPoint), colorScheme: colorScheme))
                        .frame(width: 8, height: 8)
                        .position(x: lastX, y: lastY)

                    // Glow effect
                    Circle()
                        .fill(RiskColors.color(for: Double(lastPoint), colorScheme: colorScheme).opacity(0.3))
                        .frame(width: 16, height: 16)
                        .blur(radius: 4)
                        .position(x: lastX, y: lastY)
                }
            }
        }
    }
}
