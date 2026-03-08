import SwiftUI

// MARK: - Entry Strategy Section

struct EntryStrategySectionView: View {
    let signal: TradeSignal
    @Binding var strategy: EntryStrategy
    let calculation: LeverageCalculation?

    @Environment(\.colorScheme) private var colorScheme
    @State private var showComparison = false

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var subtleBg: Color { colorScheme == .dark ? Color(hex: "2A2A2E") : Color(hex: "F5F5F7") }
    private var isLong: Bool { signal.signalType.isBuy }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ENTRY STRATEGY")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            // Zone label
            HStack(spacing: 4) {
                Text("Zone:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Text("$\(signal.entryZoneLow.asSignalPrice) — $\(signal.entryZoneHigh.asSignalPrice)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()
            }

            // Wide zone warning
            if let calc = calculation, calc.zoneWidthPercent > 5 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.warning)
                    Text("Wide entry zone (\(String(format: "%.1f%%", calc.zoneWidthPercent))). Entry precision is critical at your leverage.")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.warning)
                }
            }

            // Strategy pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EntryStrategy.allCases) { strat in
                        strategyPill(strat)
                    }
                }
            }

            // Strategy detail card
            strategyDetailCard

            // Zone visualization bar
            ZoneVisualizationBar(
                zoneLow: signal.entryZoneLow,
                zoneHigh: signal.entryZoneHigh,
                effectiveEntry: calculation?.entryPrice ?? signal.entryPriceMid,
                strategy: strategy,
                isLong: isLong
            )

            // Split entry detail
            if strategy == .split, let detail = calculation?.splitDetail {
                splitEntryCard(detail)
            }

            // Compare all toggle
            Button {
                withAnimation { showComparison.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 10))
                    Text(showComparison ? "Hide Comparison" : "Compare All")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(AppColors.accent)
            }
            .buttonStyle(PlainButtonStyle())

            if showComparison, let calc = calculation {
                comparisonTable(calc)
            }
        }
    }

    // MARK: - Strategy Pill

    private func strategyPill(_ strat: EntryStrategy) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { strategy = strat }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: strat.iconName)
                    .font(.system(size: 10))
                Text(strat.label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(strategy == strat ? .white : AppColors.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(strategy == strat ? AppColors.accent : AppColors.accent.opacity(colorScheme == .dark ? 0.15 : 0.1))
            .cornerRadius(14)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Strategy Detail Card

    private var strategyDetailCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: strategy.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.accent)
                Text(strategy.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textPrimary)
            }

            if let calc = calculation {
                HStack(spacing: 0) {
                    Text("Effective Entry: ")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    Text("$\(calc.entryPrice.asSignalPrice)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                if strategy != .midpoint, calc.hasEntryZone {
                    let delta = calc.entryDeltaVsMidpoint
                    let midPrice = (signal.entryZoneHigh + signal.entryZoneLow) / 2.0
                    let favorable = calc.isEntryDeltaFavorable
                    HStack(spacing: 0) {
                        Text("vs. Midpoint $\(midPrice.asSignalPrice): ")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        Text(String(format: "%+.0f", delta))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(favorable ? AppColors.success : AppColors.error)
                            .monospacedDigit()
                    }
                }
            }

            Text(strategy.shortDescription)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(subtleBg))
    }

    // MARK: - Split Entry Card

    private func splitEntryCard(_ detail: SplitEntryDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.accent)
                Text("SPLIT ENTRY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(1)
            }

            splitRow("Entry 1", price: detail.entry1Price, pct: "40%")
            splitRow("Entry 2", price: detail.entry2Price, pct: "60%")

            Divider()

            HStack {
                Text("Average Entry")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("$\(detail.averageEntryPrice.asSignalPrice)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(textPrimary)
                    .monospacedDigit()
            }

            // Partial fill scenario
            partialFillCard(detail)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(subtleBg))
    }

    private func splitRow(_ label: String, price: Double, pct: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text("$\(price.asSignalPrice)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(textPrimary)
                .monospacedDigit()
            Text(pct)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.accent)
        }
    }

    private func partialFillCard(_ detail: SplitEntryDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.warning)
                Text("Partial Fill Scenario")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.warning)
            }

            Text("If only Entry 1 fills at $\(detail.entry1Price.asSignalPrice):")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)

            HStack {
                Text("Notional:")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
                Text(formatDollar(detail.partialFillNotional))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(textPrimary)
                Text("(vs \(formatDollar(detail.totalNotional)) full)")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(AppColors.warning.opacity(colorScheme == .dark ? 0.1 : 0.06)))
    }

    // MARK: - Comparison Table

    private func comparisonTable(_ baseCalc: LeverageCalculation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STRATEGY COMPARISON")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            // Header row
            HStack {
                Text("Strategy")
                    .frame(width: 80, alignment: .leading)
                Text("Entry")
                    .frame(width: 70, alignment: .trailing)
                Text("Stop %")
                    .frame(width: 50, alignment: .trailing)
                Text("R:R")
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(AppColors.textSecondary)

            ForEach(EntryStrategy.allCases) { strat in
                let calc = LeverageCalculation(
                    signal: signal,
                    leverage: baseCalc.leverageMultiplier,
                    margin: baseCalc.marginAmount,
                    strategy: strat
                )
                HStack {
                    HStack(spacing: 3) {
                        Image(systemName: strat.iconName)
                            .font(.system(size: 8))
                        Text(strat.label)
                    }
                    .frame(width: 80, alignment: .leading)
                    .foregroundColor(strat == strategy ? AppColors.accent : textPrimary)

                    Text("$\(calc.entryPrice.asSignalPrice)")
                        .frame(width: 70, alignment: .trailing)
                        .monospacedDigit()
                        .foregroundColor(textPrimary)

                    Text(String(format: "%.2f%%", calc.stopLossPercent))
                        .frame(width: 50, alignment: .trailing)
                        .monospacedDigit()
                        .foregroundColor(AppColors.textSecondary)

                    if let rr = calc.adjustedRiskReward {
                        Text(String(format: "%.1fx", rr))
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                            .foregroundColor(AppColors.accent)
                    } else {
                        Text("—")
                            .frame(width: 40, alignment: .trailing)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .font(.system(size: 10, weight: strat == strategy ? .semibold : .regular))
            }

            // Best picks
            let bestRR = EntryStrategy.allCases.compactMap { strat -> (EntryStrategy, Double)? in
                let calc = LeverageCalculation(signal: signal, leverage: baseCalc.leverageMultiplier, margin: baseCalc.marginAmount, strategy: strat)
                guard let rr = calc.adjustedRiskReward else { return nil }
                return (strat, rr)
            }.max(by: { $0.1 < $1.1 })

            if let best = bestRR {
                HStack(spacing: 4) {
                    Text("Best R:R:")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    Text("\(best.0.label) (\(String(format: "%.1fx", best.1)))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.accent)
                }
                .padding(.top, 2)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(subtleBg))
    }

    // MARK: - Helpers

    private func formatDollar(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        } else if value >= 10_000 {
            return String(format: "$%.1fK", value / 1_000)
        } else {
            return String(format: "$%.2f", value)
        }
    }
}

// MARK: - Zone Visualization Bar

struct ZoneVisualizationBar: View {
    let zoneLow: Double
    let zoneHigh: Double
    let effectiveEntry: Double
    let strategy: EntryStrategy
    let isLong: Bool

    @Environment(\.colorScheme) private var colorScheme

    private var zoneRange: Double { zoneHigh - zoneLow }

    private func normalizedPosition(_ price: Double) -> CGFloat {
        guard zoneRange > 0 else { return 0.5 }
        return CGFloat((price - zoneLow) / zoneRange)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let entryPos = normalizedPosition(effectiveEntry) * width

            ZStack(alignment: .leading) {
                // Zone background
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(height: 24)

                // Filled portion from aggressive edge to entry
                let fillStart: CGFloat = isLong ? entryPos : 0
                let fillWidth: CGFloat = isLong ? (width - entryPos) : entryPos
                RoundedRectangle(cornerRadius: 4)
                    .fill(AppColors.accent.opacity(0.3))
                    .frame(width: max(0, fillWidth), height: 24)
                    .offset(x: fillStart)

                // Split entry: two markers
                if strategy == .split {
                    let pos1 = max(0, min(normalizedPosition(isLong ? zoneHigh : zoneLow) * width, width))
                    let pos2 = max(0, min(normalizedPosition(isLong ? zoneLow : zoneHigh) * width, width))
                    Circle()
                        .fill(AppColors.accent.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .offset(x: max(0, min(pos1 - 4, width - 8)), y: 0)
                    Circle()
                        .fill(AppColors.accent.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .offset(x: max(0, min(pos2 - 4, width - 8)), y: 0)
                    // Average marker
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 12, height: 12)
                        .offset(x: max(0, min(entryPos - 6, width - 12)), y: 0)
                } else {
                    // Single entry marker
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 12, height: 12)
                        .offset(x: max(0, min(entryPos - 6, width - 12)), y: 0)
                }

                // Edge labels
                HStack {
                    Text("$\(zoneLow.asSignalPrice)")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("$\(zoneHigh.asSignalPrice)")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                }
                .monospacedDigit()
                .offset(y: 18)

                // Entry price label
                Text("$\(effectiveEntry.asSignalPrice)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .monospacedDigit()
                    .offset(x: max(0, min(entryPos - 25, width - 55)), y: -16)
            }
        }
        .frame(height: 50)
        .animation(.easeInOut(duration: 0.25), value: strategy)
    }
}
