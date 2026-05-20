import SwiftUI

// MARK: - Rotation Detail View

struct RotationDetailView: View {
    let signal: RotationSignal
    @Environment(\.colorScheme) var colorScheme
    @State private var sectors: [SectorPerformance] = []
    @State private var isLoadingSectors = true
    @State private var expandedSectorId: String?
    @State private var selectedTimeframe: RotationTimeframe = .thirtyDay

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(spacing: ArkSpacing.xl) {
                    // Gauge section
                    gaugeSection
                        .padding(.top, ArkSpacing.md)

                    // What to Do section
                    actionGuidanceSection

                    // Input breakdown
                    inputBreakdownSection

                    // Bear market warning
                    if let defensiveRank = defensiveRank, defensiveRank <= 3 {
                        riskOffBanner(rank: defensiveRank)
                    }

                    // Sector leaderboard
                    sectorLeaderboard

                    // Disclaimer
                    Text("For informational purposes only. Not investment advice.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        .padding(.horizontal, ArkSpacing.lg)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, ArkSpacing.lg)
            }
        }
        .navigationTitle("Rotation Signal")
        .navigationBarTitleDisplayMode(.large)
        .task {
            sectors = await RotationSignalService.shared.fetchLatestSectors()
            isLoadingSectors = false
        }
    }

    private var defensiveRank: Int? {
        guard let idx = sectors.firstIndex(where: { $0.isDefensive }) else { return nil }
        return idx + 1
    }

    // MARK: - Gauge Section

    private var gaugeSection: some View {
        VStack(spacing: 16) {
            // Regime badge
            Text(signal.regime.displayName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(regimeColor))

            // Large score
            Text(scoreText)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(regimeColor)

            // Gauge bar
            gaugeBar
                .padding(.horizontal, ArkSpacing.md)

            // Narrative
            if let narrative = signal.narrative {
                Text(narrative)
                    .font(.system(size: 14))
                    .foregroundColor(textPrimary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, ArkSpacing.md)
            }

            // Timeframe picker
            HStack(spacing: 6) {
                ForEach(RotationTimeframe.allCases) { tf in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTimeframe = tf }
                    } label: {
                        Text(tf.rawValue)
                            .font(.system(size: 13, weight: selectedTimeframe == tf ? .semibold : .regular))
                            .foregroundColor(selectedTimeframe == tf ? .white : AppColors.textSecondary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(
                                selectedTimeframe == tf
                                    ? AnyView(Capsule().fill(AppColors.accent))
                                    : AnyView(Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(AppColors.textSecondary.opacity(colorScheme == .dark ? 0.1 : 0.06))
            )

            // Returns comparison
            HStack(spacing: 20) {
                returnCard(label: "BTC \(selectedTimeframe.rawValue)", value: signal.btcReturn(for: selectedTimeframe), color: Color(hex: "F7931A"))
                returnCard(label: "SPY \(selectedTimeframe.rawValue)", value: signal.spyReturn(for: selectedTimeframe), color: Color(hex: "3B82F6"))
            }
        }
        .padding(ArkSpacing.lg)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }

    private var gaugeBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let center = width / 2
            let normalized = CGFloat(signal.rotationScore + 100) / 200.0
            let needleX = width * normalized

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "F7931A").opacity(0.4),
                                Color(hex: "9CA3AF").opacity(0.15),
                                Color(hex: "3B82F6").opacity(0.4),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 10)

                Rectangle()
                    .fill(textPrimary.opacity(0.3))
                    .frame(width: 1.5, height: 16)
                    .position(x: center, y: 5)

                Circle()
                    .fill(regimeColor)
                    .frame(width: 18, height: 18)
                    .shadow(color: regimeColor.opacity(0.5), radius: 6)
                    .position(x: needleX, y: 5)
            }
        }
        .frame(height: 18)
    }

    private func returnCard(label: String, value: Double?, color: Color) -> some View {
        let ret = value ?? 0
        let isPositive = ret >= 0
        return VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(textPrimary.opacity(0.5))
            Text(String(format: "%+.1f%%", ret))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.08))
        )
    }

    // MARK: - Action Guidance

    private var actionGuidanceSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(regimeColor)

                Text("What to Do")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                Text(signal.regime.actionLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(regimeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(regimeColor.opacity(0.12))
                    )
            }

            ForEach(Array(signal.actionBullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(regimeColor)
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    Text(bullet)
                        .font(.system(size: 13))
                        .foregroundColor(textPrimary.opacity(0.85))
                        .lineSpacing(3)
                }
            }

            // Top sectors callout when equity favored
            if signal.regime == .equityFavored, !sectors.isEmpty {
                let topNames = sectors.prefix(3).map(\.sectorName).joined(separator: ", ")
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                        .padding(.top, 4)

                    Text("Leading sectors: \(topNames)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.accent)
                        .lineSpacing(3)
                }
            }
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }

    // MARK: - Input Breakdown

    private var inputBreakdownSection: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Text("Signal Inputs")
                .font(.headline)
                .foregroundColor(textPrimary)

            VStack(spacing: ArkSpacing.sm) {
                inputRow(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "BTC vs SPY Performance",
                    detail: String(format: "BTC %+.1f%% vs SPY %+.1f%%", signal.btc30dReturn ?? 0, signal.spy30dReturn ?? 0),
                    weight: "30%"
                )
                inputRow(
                    icon: "gauge.with.needle",
                    label: "Risk Levels",
                    detail: "BTC: \(signal.btcRiskLevel ?? "—") / SPY: \(signal.spyRiskLevel ?? "—")",
                    weight: "20%"
                )
                inputRow(
                    icon: "speedometer",
                    label: "Fear & Greed",
                    detail: "\(signal.fearGreedValue ?? 0) (\(signal.fearGreedTrend ?? "flat"))",
                    weight: "15%"
                )
                inputRow(
                    icon: "dollarsign.arrow.trianglehead.counterclockwise.rotate.90",
                    label: "DXY Trend",
                    detail: "\(signal.dxyTrend ?? "flat") (\(String(format: "%.1f", signal.dxyValue ?? 0)))",
                    weight: "15%"
                )
                inputRow(
                    icon: "bitcoinsign.circle",
                    label: "BTC Dominance",
                    detail: String(format: "%.1f%% (%@)", signal.btcDominance ?? 0, signal.btcDominanceTrend ?? "flat"),
                    weight: "10%"
                )
                inputRow(
                    icon: "waveform.path.ecg",
                    label: "VIX",
                    detail: String(format: "%.1f", signal.vixLevel ?? 0),
                    weight: "10%"
                )
            }
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }

    private func inputRow(icon: String, label: String, detail: String, weight: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(AppColors.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(textPrimary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text(weight)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Risk-Off Banner

    private func riskOffBanner(rank: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 16))
                .foregroundColor(AppColors.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text("Defensive Sectors Leading")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.warning)

                Text("Defensives rank #\(rank) — when defensive names outperform, it typically signals risk-off conditions for growth assets.")
                    .font(.system(size: 12))
                    .foregroundColor(textPrimary.opacity(0.8))
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                .fill(AppColors.warning.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ArkSpacing.Radius.card)
                .stroke(AppColors.warning.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Sector Leaderboard

    private var sectorLeaderboard: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            HStack {
                Text("Sector Rankings")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                Text("vs SPY 30d")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }

            if isLoadingSectors {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if sectors.isEmpty {
                Text("No sector data available yet")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sectors.enumerated()), id: \.element.id) { index, sector in
                        VStack(spacing: 0) {
                            sectorLeaderboardRow(sector: sector, rank: index + 1)

                            // Expanded stock breakdown
                            if expandedSectorId == sector.sectorId,
                               let stockReturns = sector.stockReturns, !stockReturns.isEmpty {
                                stockBreakdown(stockReturns)
                            }

                            if index < sectors.count - 1 {
                                Divider().opacity(0.15).padding(.leading, 44)
                            }
                        }
                    }
                }
            }
        }
        .padding(ArkSpacing.md)
        .glassCard(cornerRadius: ArkSpacing.Radius.lg)
    }

    private func sectorLeaderboardRow(sector: SectorPerformance, rank: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                expandedSectorId = expandedSectorId == sector.sectorId ? nil : sector.sectorId
            }
        } label: {
            HStack(spacing: 10) {
                // Rank
                Text("\(rank)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(rank <= 3 ? AppColors.accent : AppColors.textSecondary)
                    .frame(width: 20)

                // Icon
                Image(systemName: sector.icon)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 16)

                // Name
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(sector.sectorName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(textPrimary)
                            .lineLimit(1)

                        if sector.isDefensive {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 8))
                                .foregroundColor(AppColors.warning)
                        }
                    }

                    if let top = sector.topPerformer, let topRet = sector.topPerformerReturn {
                        Text("\(top) \(String(format: "%+.1f%%", topRet))")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                // Relative strength
                if let rs = sector.relativeStrengthVsSpy {
                    Text(String(format: "%+.1f%%", rs))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(rs >= 0 ? AppColors.success : AppColors.error)
                }

                // 30d return
                if let ret = sector.return30d {
                    Text(String(format: "%+.1f%%", ret))
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 44, alignment: .trailing)
                }

                Image(systemName: expandedSectorId == sector.sectorId ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func stockBreakdown(_ stockReturns: [String: Double]) -> some View {
        let sorted = stockReturns.sorted { $0.value > $1.value }
        return VStack(spacing: 4) {
            ForEach(sorted, id: \.key) { ticker, ret in
                HStack {
                    Text(ticker)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(textPrimary.opacity(0.8))
                        .frame(width: 50, alignment: .leading)

                    // Bar
                    GeometryReader { geo in
                        let maxAbs = max(1, sorted.map { abs($0.value) }.max() ?? 1)
                        let barWidth = geo.size.width * CGFloat(abs(ret) / maxAbs) * 0.8
                        let isPositive = ret >= 0

                        ZStack(alignment: isPositive ? .leading : .trailing) {
                            Color.clear
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isPositive ? AppColors.success.opacity(0.3) : AppColors.error.opacity(0.3))
                                .frame(width: barWidth, height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text(String(format: "%+.1f%%", ret))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(ret >= 0 ? AppColors.success : AppColors.error)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding(.leading, 46)
        .padding(.bottom, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Helpers

    private var regimeColor: Color {
        switch signal.regime {
        case .cryptoFavored: return Color(hex: "F7931A")
        case .equityFavored: return Color(hex: "3B82F6")
        case .neutral: return AppColors.textSecondary
        case .riskOff: return AppColors.error
        }
    }

    private var scoreText: String {
        let s = signal.rotationScore
        return s >= 0 ? "+\(s)" : "\(s)"
    }
}
