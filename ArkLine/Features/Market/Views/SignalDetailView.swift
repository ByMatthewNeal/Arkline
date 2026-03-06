import SwiftUI

// MARK: - Signal Detail View

struct SignalDetailView: View {
    let signalId: UUID
    @State private var signal: TradeSignal?
    @State private var confluenceZone: FibConfluenceZone?
    @State private var isLoading = true
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    private let service = SwingSetupService()
    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        ScrollView {
            if isLoading {
                VStack(spacing: 16) {
                    SkeletonCard()
                    SkeletonCard()
                    SkeletonCard()
                }
                .padding()
            } else if let signal {
                VStack(spacing: 20) {
                    headerSection(signal)
                    tradeParametersCard(signal)
                    confluenceVisualization(signal)
                    supportingSignalsGrid(signal)

                    if let briefing = signal.briefingText, !briefing.isEmpty {
                        aiAnalysisCard(briefing)
                    }

                    statusTimeline(signal)
                    disclaimerSection

                    Spacer(minLength: 100)
                }
                .padding()
            }
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Signal Detail")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            signal = try await service.fetchSignal(id: signalId)
            if let zoneId = signal?.confluenceZoneId {
                confluenceZone = try? await service.fetchConfluenceZone(id: zoneId)
            }
        } catch {
            logWarning("Failed to load signal: \(error)", category: .network)
        }
    }

    // MARK: - 1. Header

    private func headerSection(_ signal: TradeSignal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(signal.asset)
                    .font(.title.bold())
                    .foregroundColor(textPrimary)

                Text(signal.generatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text(signal.signalType.displayName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(signal.signalType.isBuy ? AppColors.success : AppColors.error)
                .cornerRadius(10)
        }
    }

    // MARK: - 2. Trade Parameters

    private func tradeParametersCard(_ signal: TradeSignal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trade Parameters")
                .font(.headline)
                .foregroundColor(textPrimary)

            VStack(spacing: 10) {
                paramRow(label: "Entry Zone",
                         value: "$\(formatSignalPrice(signal.entryZoneLow)) – $\(formatSignalPrice(signal.entryZoneHigh))")

                if let t1 = signal.target1, let pct = signal.entryPctFromTarget1 {
                    paramRow(label: "Target 1",
                             value: "$\(formatSignalPrice(t1))",
                             badge: String(format: "%+.1f%%", pct),
                             badgeColor: AppColors.success)
                }

                if let t2 = signal.target2, let pct = signal.entryPctFromTarget2 {
                    paramRow(label: "Target 2",
                             value: "$\(formatSignalPrice(t2))",
                             badge: String(format: "%+.1f%%", pct),
                             badgeColor: AppColors.success)
                }

                paramRow(label: "Stop Loss",
                         value: "$\(formatSignalPrice(signal.stopLoss))",
                         badge: String(format: "%.1f%%", signal.stopLossPct),
                         badgeColor: AppColors.error)

                Divider()

                paramRow(label: "Risk / Reward",
                         value: String(format: "%.1fx", signal.riskRewardRatio),
                         valueColor: AppColors.accent)
            }
        }
        .padding()
        .background(cardBackground)
    }

    // MARK: - 3. Confluence Visualization

    private func confluenceVisualization(_ signal: TradeSignal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confluence Zone")
                .font(.headline)
                .foregroundColor(textPrimary)

            if let zone = confluenceZone {
                // Contributing levels
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(zone.contributingLevels.indices, id: \.self) { index in
                        let level = zone.contributingLevels[index]
                        HStack(spacing: 8) {
                            Text(level.timeframe.uppercased())
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.accent)
                                .cornerRadius(4)

                            Text(formatLevelName(level.levelName))
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)

                            Spacer()

                            Text("$\(formatSignalPrice(level.price))")
                                .font(AppFonts.caption12Medium)
                                .foregroundColor(textPrimary)
                                .monospacedDigit()
                        }
                    }
                }

                // Strength indicator
                HStack(spacing: 4) {
                    Text("Strength:")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)

                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i < zone.strength ? AppColors.accent : AppColors.accent.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }

                    Text("\(zone.strength) levels from \(Set(zone.contributingLevels.map(\.timeframe)).count) timeframes")
                        .font(AppFonts.footnote10)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, 4)
            } else {
                Text("Confluence data unavailable")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Price scale visualization
            priceScale(signal)
        }
        .padding()
        .background(cardBackground)
    }

    private func priceScale(_ signal: TradeSignal) -> some View {
        VStack(spacing: 0) {
        GeometryReader { geo in
            let width = geo.size.width
            let allPrices = [signal.stopLoss, signal.entryZoneLow, signal.entryZoneHigh,
                             signal.target1, signal.target2].compactMap { $0 }
            let minP = allPrices.min() ?? signal.stopLoss
            let maxP = allPrices.max() ?? (signal.target1 ?? signal.entryZoneHigh)
            let range = maxP - minP

            let safeRange = range > 0 ? range : 1.0

            ZStack(alignment: .leading) {
                // Base line
                Rectangle()
                    .fill(AppColors.textSecondary.opacity(0.2))
                    .frame(height: 2)
                    .frame(width: width)

                // Stop loss marker
                Circle()
                    .fill(AppColors.error)
                    .frame(width: 8, height: 8)
                    .offset(x: CGFloat((signal.stopLoss - minP) / safeRange) * width - 4)

                // Entry zone
                Rectangle()
                    .fill(AppColors.accent.opacity(0.3))
                    .frame(width: max(1, CGFloat((signal.entryZoneHigh - signal.entryZoneLow) / safeRange) * width), height: 16)
                    .offset(x: CGFloat((signal.entryZoneLow - minP) / safeRange) * width)
                    .cornerRadius(3)

                // Target markers
                if let t1 = signal.target1 {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 8, height: 8)
                        .offset(x: CGFloat((t1 - minP) / safeRange) * width - 4)
                }
                if let t2 = signal.target2 {
                    Circle()
                        .fill(AppColors.success.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .offset(x: CGFloat((t2 - minP) / safeRange) * width - 4)
                }
            }
        }
        .frame(height: 20)
        .padding(.top, 8)

        // Legend
        HStack(spacing: 12) {
            legendDot(color: AppColors.error, label: "Stop")
            legendDot(color: AppColors.accent.opacity(0.5), label: "Entry Zone")
            legendDot(color: AppColors.success, label: "Targets")
        }
        .font(.system(size: 9))
        .foregroundColor(AppColors.textSecondary)
        } // VStack
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }

    // MARK: - 4. Supporting Signals

    private func supportingSignalsGrid(_ signal: TradeSignal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supporting Signals")
                .font(.headline)
                .foregroundColor(textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let risk = signal.btcRiskScore {
                    supportingMetric(
                        icon: "gauge.with.needle",
                        label: "BTC Risk Score",
                        value: String(format: "%.2f", risk),
                        detail: risk <= 0.3 ? "Low Risk" : (risk <= 0.5 ? "Moderate" : "Elevated"),
                        color: risk <= 0.3 ? AppColors.success : (risk <= 0.5 ? AppColors.warning : AppColors.error)
                    )
                }

                if let fg = signal.fearGreedIndex {
                    supportingMetric(
                        icon: "heart.fill",
                        label: "Fear & Greed",
                        value: "\(fg)",
                        detail: fg < 25 ? "Extreme Fear" : (fg < 45 ? "Fear" : "Neutral"),
                        color: fg < 25 ? AppColors.error : (fg < 45 ? Color(hex: "F97316") : AppColors.warning)
                    )
                }

                if let regime = signal.macroRegime {
                    supportingMetric(
                        icon: "globe.americas",
                        label: "Macro Regime",
                        value: regime,
                        detail: nil,
                        color: AppColors.accent
                    )
                }

                if let rank = signal.coinbaseRanking {
                    supportingMetric(
                        icon: "apps.iphone",
                        label: "Coinbase Rank",
                        value: rank > 200 ? ">200" : "#\(rank)",
                        detail: rank > 200 ? "Retail absent" : (rank > 50 ? "Low interest" : "Retail active"),
                        color: rank > 50 ? AppColors.success : AppColors.warning
                    )
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    private func supportingMetric(icon: String, label: String, value: String, detail: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.accent)
                Text(label)
                    .font(AppFonts.footnote10)
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
        )
    }

    // MARK: - 5. AI Analysis

    private func aiAnalysisCard(_ briefing: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(AppColors.accent)
                Text("AI Analysis")
                    .font(.headline)
                    .foregroundColor(textPrimary)
            }

            Text(briefing)
                .font(AppFonts.body14)
                .foregroundColor(textPrimary.opacity(0.9))
                .lineSpacing(4)
        }
        .padding()
        .background(cardBackground)
    }

    // MARK: - 6. Status Timeline

    private func statusTimeline(_ signal: TradeSignal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline")
                .font(.headline)
                .foregroundColor(textPrimary)

            VStack(alignment: .leading, spacing: 12) {
                timelineRow(label: "Signal Generated",
                            time: signal.generatedAt.formatted(date: .abbreviated, time: .shortened),
                            isCompleted: true)

                timelineRow(label: "Price Entered Zone",
                            time: signal.triggeredAt?.formatted(date: .abbreviated, time: .shortened) ?? "Pending",
                            isCompleted: signal.triggeredAt != nil)

                if let t1Time = signal.t1HitAt {
                    timelineRow(label: "Target 1 Hit",
                                time: t1Time.formatted(date: .abbreviated, time: .shortened),
                                isCompleted: true,
                                color: AppColors.success)
                }

                if signal.outcome == .win {
                    timelineRow(label: "Target Hit",
                                time: signal.closedAt?.formatted(date: .abbreviated, time: .shortened) ?? "",
                                isCompleted: true,
                                color: AppColors.success)
                } else if signal.outcome == .partial {
                    timelineRow(label: "Stopped Out (Partial Win)",
                                time: signal.closedAt?.formatted(date: .abbreviated, time: .shortened) ?? "",
                                isCompleted: true,
                                color: AppColors.warning)
                } else if signal.outcome == .loss {
                    timelineRow(label: "Stopped Out",
                                time: signal.closedAt?.formatted(date: .abbreviated, time: .shortened) ?? "",
                                isCompleted: true,
                                color: AppColors.error)
                } else {
                    if let expires = signal.expiresAt {
                        let remaining = expires.timeIntervalSince(Date())
                        let hoursLeft = max(0, Int(remaining / 3600))
                        timelineRow(label: "Expires in \(hoursLeft)h",
                                    time: expires.formatted(date: .abbreviated, time: .shortened),
                                    isCompleted: false)
                    } else {
                        timelineRow(label: "Outcome",
                                    time: "Pending",
                                    isCompleted: false)
                    }
                }

                if let pct = signal.outcomePct {
                    HStack {
                        Text("Result:")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                        Text(String(format: "%+.1f%%", pct))
                            .font(AppFonts.body14Bold)
                            .foregroundColor(pct >= 0 ? AppColors.success : AppColors.error)
                        if let hours = signal.durationHours {
                            Text("(\(hours)h)")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.leading, 28)
                }
            }
        }
        .padding()
        .background(cardBackground)
    }

    private func timelineRow(label: String, time: String, isCompleted: Bool, color: Color? = nil) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isCompleted ? (color ?? AppColors.accent) : AppColors.textSecondary.opacity(0.3))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary)
                Text(time)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    // MARK: - 7. Disclaimer

    private var disclaimerSection: some View {
        Text("This is not financial advice. Always do your own research and consult a licensed advisor before making crypto-related decisions.")
            .font(.system(size: 10))
            .foregroundColor(AppColors.textSecondary.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.top, 8)
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
    }

    private func paramRow(label: String, value: String, badge: String? = nil, badgeColor: Color? = nil, valueColor: Color? = nil) -> some View {
        HStack {
            Text(label)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppFonts.body14Medium)
                .foregroundColor(valueColor ?? textPrimary)
                .monospacedDigit()

            if let badge, let color = badgeColor {
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(color)
            }
        }
    }

    private func formatSignalPrice(_ price: Double) -> String {
        price.asSignalPrice
    }

    private func formatLevelName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "retracement_", with: "Ret ")
            .replacingOccurrences(of: "extension_", with: "Ext ")
            .replacingOccurrences(of: "ext_", with: "Ext ")
            .replacingOccurrences(of: "_", with: ".")
    }
}
