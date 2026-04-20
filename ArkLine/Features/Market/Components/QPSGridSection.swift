import SwiftUI

// MARK: - QPS Summary Card (Market Tab Widget)

struct QPSGridSection: View {
    let signals: [DailyPositioningSignal]
    let isPro: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var showMethodology = false

    private var bullishCount: Int { signals.filter { $0.positioningSignal == .bullish }.count }
    private var neutralCount: Int { signals.filter { $0.positioningSignal == .neutral }.count }
    private var bearishCount: Int { signals.filter { $0.positioningSignal == .bearish }.count }
    private var changedCount: Int { signals.filter { $0.hasChanged }.count }

    private var total: Int { max(signals.count, 1) }
    private var bullishPct: Double { Double(bullishCount) / Double(total) * 100 }
    private var neutralPct: Double { Double(neutralCount) / Double(total) * 100 }
    private var bearishPct: Double { Double(bearishCount) / Double(total) * 100 }

    /// Risk Appetite: 0-100, weighted by signal distribution + category importance
    private var riskAppetite: Double {
        guard !signals.isEmpty else { return 50 }
        // Weight crypto signals more heavily (core focus of the app)
        var weightedBullish = 0.0
        var weightedTotal = 0.0
        for signal in signals {
            let weight: Double = switch signal.assetCategory {
            case .crypto, .alt_btc: 1.5
            case .index: 1.2
            case .stock: 1.0
            case .commodity, .macro: 0.8
            }
            if signal.positioningSignal == .bullish {
                weightedBullish += weight
            } else if signal.positioningSignal == .neutral {
                weightedBullish += weight * 0.4  // Neutral contributes partially
            }
            weightedTotal += weight
        }
        return weightedTotal > 0 ? (weightedBullish / weightedTotal) * 100 : 50
    }

    private var riskLabel: String {
        if riskAppetite >= 70 { return "Risk-On" }
        if riskAppetite >= 55 { return "Leaning Risk-On" }
        if riskAppetite >= 45 { return "Mixed" }
        if riskAppetite >= 30 { return "Leaning Risk-Off" }
        return "Risk-Off"
    }

    private var riskColor: Color {
        if riskAppetite >= 70 { return AppColors.success }
        if riskAppetite >= 55 { return AppColors.success.opacity(0.7) }
        if riskAppetite >= 45 { return AppColors.warning }
        if riskAppetite >= 30 { return AppColors.error.opacity(0.7) }
        return AppColors.error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(AppColors.accent)
                Text("Daily Positioning")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if !isPro {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(AppColors.accent.opacity(0.15))
                        .clipShape(Circle())
                }

                Spacer()

                Button { showMethodology = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .sheet(isPresented: $showMethodology) {
                QPSMethodologySheet()
            }

            if isPro {
                NavigationLink {
                    QPSFullGridView(signals: signals)
                } label: {
                    summaryCard
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                lockedCard
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 14) {
            if signals.isEmpty {
                emptyState
            } else {
                // Risk Appetite bar
                VStack(spacing: 6) {
                    HStack {
                        Text("Risk Appetite")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text(riskLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(riskColor)
                        Text(String(format: "%.0f%%", riskAppetite))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(riskColor)
                    }

                    // Distribution bar
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColors.success)
                                .frame(width: max(geo.size.width * bullishPct / 100, 2))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColors.warning)
                                .frame(width: max(geo.size.width * neutralPct / 100, 2))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(AppColors.error)
                                .frame(width: max(geo.size.width * bearishPct / 100, 2))
                        }
                    }
                    .frame(height: 6)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }

                // Signal counts with percentages
                HStack(spacing: 0) {
                    signalCountWithPct(count: bullishCount, pct: bullishPct, signal: .bullish)
                    Divider().frame(height: 32).opacity(0.15)
                    signalCountWithPct(count: neutralCount, pct: neutralPct, signal: .neutral)
                    Divider().frame(height: 32).opacity(0.15)
                    signalCountWithPct(count: bearishCount, pct: bearishPct, signal: .bearish)
                }

                // Changes today
                if changedCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppColors.warning)
                        Text("\(changedCount) signal \(changedCount == 1 ? "change" : "changes") today")
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.warning)
                    }
                }

                // Tap hint
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("View all \(signals.count) assets")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    }
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

    // MARK: - Signal Count

    private func signalCountWithPct(count: Int, pct: Double, signal: PositioningSignal) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(signal.color)
                Text(String(format: "%.0f%%", pct))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(signal.color.opacity(0.7))
            }
            Text(signal.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func signalCount(count: Int, signal: PositioningSignal) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(signal.color)
            Text(signal.label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty & Locked States

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No positioning signals yet")
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))
            Text("Signals are computed daily at midnight UTC.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var lockedCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.title2)
                .foregroundColor(AppColors.accent.opacity(0.5))
            Text("Unlock daily positioning signals across 54 assets with Arkline Premium.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
        .opacity(0.6)
        .padding(.horizontal)
    }
}
