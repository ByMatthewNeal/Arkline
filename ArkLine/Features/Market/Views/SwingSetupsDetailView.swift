import SwiftUI

// MARK: - Swing Setups Detail View

struct SwingSetupsDetailView: View {
    @State private var viewModel = SwingSetupsViewModel()
    @State private var selectedFilter: SignalFilter = .active
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    enum SignalFilter: String, CaseIterable {
        case active = "Active"
        case history = "History"
    }

    private var filteredSignals: [TradeSignal] {
        switch selectedFilter {
        case .active:
            return viewModel.activeSignals
        case .history:
            return viewModel.recentSignals.filter { !$0.status.isLive }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats header
                if let stats = viewModel.stats, stats.totalSignals > 0 {
                    statsCard(stats)
                }

                // Filter picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(SignalFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Signal list
                if viewModel.isLoading {
                    VStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonCard()
                        }
                    }
                    .padding(.horizontal)
                } else if filteredSignals.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSignals) { signal in
                            NavigationLink {
                                SignalDetailView(signalId: signal.id)
                            } label: {
                                SignalCard(signal: signal, colorScheme: colorScheme)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }

                // Per-asset breakdown
                if let stats = viewModel.stats, !stats.assetBreakdown.isEmpty, selectedFilter == .history {
                    assetBreakdownSection(stats.assetBreakdown)
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Swing Setups")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadAllData()
        }
        .refreshable {
            await viewModel.loadAllData()
        }
    }

    // MARK: - Stats Card

    private func statsCard(_ stats: SignalStats) -> some View {
        VStack(spacing: 12) {
            // Primary stats row
            HStack(spacing: 0) {
                statColumn(label: "Signals", value: "\(stats.totalSignals)")
                Divider().frame(height: 36)
                statColumn(label: "Wins", value: "\(stats.wins)", color: AppColors.success)
                Divider().frame(height: 36)
                statColumn(label: "Partial", value: "\(stats.partials)", color: AppColors.warning)
                Divider().frame(height: 36)
                statColumn(label: "Losses", value: "\(stats.losses)", color: AppColors.error)
            }

            Divider()

            // Secondary stats row
            HStack(spacing: 0) {
                statColumn(label: "Hit Rate", value: String(format: "%.0f%%", stats.hitRate))
                Divider().frame(height: 36)
                statColumn(label: "Avg Win", value: String(format: "+%.1f%%", stats.avgWinPct), color: AppColors.success)
                Divider().frame(height: 36)
                statColumn(label: "Avg Loss", value: String(format: "%.1f%%", stats.avgLossPct), color: AppColors.error)
                Divider().frame(height: 36)
                statColumn(
                    label: "Streak",
                    value: stats.currentStreak >= 0 ? "+\(stats.currentStreak)" : "\(stats.currentStreak)",
                    color: stats.currentStreak >= 0 ? AppColors.success : AppColors.error
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    private func statColumn(label: String, value: String, color: Color? = nil) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(AppFonts.body14Bold)
                .foregroundColor(color ?? textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Asset Breakdown

    private func assetBreakdownSection(_ assets: [AssetStats]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BY ASSET")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            ForEach(assets) { asset in
                HStack {
                    Text(asset.asset)
                        .font(AppFonts.body14Bold)
                        .foregroundColor(textPrimary)
                        .frame(width: 60, alignment: .leading)

                    // Win/loss bar
                    GeometryReader { geo in
                        let total = max(asset.total, 1)
                        let winWidth = geo.size.width * CGFloat(asset.wins + asset.partials) / CGFloat(total)
                        HStack(spacing: 1) {
                            Rectangle()
                                .fill(AppColors.success)
                                .frame(width: max(winWidth, 0))
                            Rectangle()
                                .fill(AppColors.error)
                        }
                        .cornerRadius(3)
                    }
                    .frame(height: 8)

                    Text(String(format: "%.0f%%", asset.hitRate))
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 40, alignment: .trailing)

                    Text(String(format: "%+.1f%%", asset.avgReturnPct))
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(asset.avgReturnPct >= 0 ? AppColors.success : AppColors.error)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .padding(.horizontal)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))

            Text(selectedFilter == .active ? "No active setups" : "No signal history yet")
                .font(AppFonts.body14Medium)
                .foregroundColor(textPrimary)

            Text("Signals fire when price approaches high-confluence Fibonacci zones with supporting risk conditions.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Signal Card

struct SignalCard: View {
    let signal: TradeSignal
    let colorScheme: ColorScheme

    private var signalColor: Color {
        signal.signalType.isBuy ? AppColors.success : AppColors.error
    }

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: asset, type badge, time
            HStack {
                Text(signal.asset)
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Text(signal.signalType.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(signalColor)
                    .cornerRadius(6)

                confidenceBadge

                Spacer()

                Text(signal.timeAgo)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Entry zone
            HStack {
                Text("Entry")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Text("$\(formatSignalPrice(signal.entryZoneLow)) – $\(formatSignalPrice(signal.entryZoneHigh))")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(textPrimary)
            }

            // Targets + Stop
            HStack(spacing: 16) {
                if let t1 = signal.target1 {
                    miniMetric(label: "T1", value: "$\(formatSignalPrice(t1))", color: AppColors.success)
                }
                if let t2 = signal.target2 {
                    miniMetric(label: "T2", value: "$\(formatSignalPrice(t2))", color: AppColors.success)
                }
                miniMetric(label: "Stop", value: "$\(formatSignalPrice(signal.stopLoss))", color: AppColors.error)

                Spacer()

                // R:R badge
                Text("\(signal.riskRewardRatio, specifier: "%.1f")x")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColors.accent.opacity(0.15))
                    .cornerRadius(8)
            }

            // Bottom row: runner info + status
            HStack(spacing: 6) {
                if signal.status.isLive {
                    if signal.isRunnerPhase {
                        chipView(text: "T1 Hit", color: AppColors.success)
                        if let t1Pnl = signal.t1PnlPct {
                            chipView(text: String(format: "50%% @ %+.1f%%", t1Pnl), color: AppColors.success)
                        }
                        chipView(text: "Runner trailing", color: AppColors.accent)
                    } else {
                        if signal.emaTrendAligned == true {
                            chipView(text: "EMA Aligned", color: AppColors.accent)
                        }
                        if signal.isWeakDirection {
                            chipView(text: "Off-trend")
                        }
                        if signal.isCounterTrend {
                            chipView(text: "Counter-Trend", color: AppColors.warning)
                        }
                    }
                } else {
                    // Outcome details for closed signals
                    if let pct = signal.outcomePct {
                        chipView(
                            text: String(format: "%+.1f%%", pct),
                            color: pct >= 0 ? AppColors.success : AppColors.error
                        )
                    }
                    if let rMult = signal.rMultiple {
                        chipView(
                            text: String(format: "%+.1fR", rMult),
                            color: rMult >= 0 ? AppColors.success : AppColors.error
                        )
                    }
                    if let hours = signal.durationHours {
                        let display = hours >= 24 ? "\(hours / 24)d \(hours % 24)h" : "\(hours)h"
                        chipView(text: display)
                    }
                    if signal.isT1Hit {
                        chipView(text: "T1 Hit", color: AppColors.success)
                    }
                }

                Spacer()

                // Status badge
                Text(signal.phaseDescription)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }

    private var confidenceBadge: some View {
        let color: Color = {
            switch signal.confidence {
            case .high: return AppColors.success
            case .medium: return AppColors.warning
            case .low: return AppColors.error
            }
        }()
        return Text(signal.confidence.displayName)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }

    private var statusColor: Color {
        switch signal.status {
        case .active: return AppColors.warning
        case .triggered: return AppColors.accent
        case .targetHit: return AppColors.success
        case .invalidated: return AppColors.error
        case .expired: return AppColors.textSecondary
        }
    }

    private func chipView(text: String, color: Color? = nil) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color ?? AppColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (color ?? (colorScheme == .dark ? Color.white : Color.black))
                    .opacity(color != nil ? 0.12 : (colorScheme == .dark ? 0.08 : 0.05))
            )
            .cornerRadius(4)
    }

    private func miniMetric(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
        }
    }

    private func formatSignalPrice(_ price: Double) -> String {
        price.asSignalPrice
    }
}
