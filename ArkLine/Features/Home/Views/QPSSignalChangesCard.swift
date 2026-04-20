import SwiftUI
import Kingfisher

// MARK: - QPS Signal Changes Card (Home Tab)

struct QPSSignalChangesCard: View {
    let signals: [DailyPositioningSignal]
    let isPro: Bool
    var size: WidgetSize = .standard
    @State private var showPaywall = false
    @State private var showShareSheet = false
    @Environment(\.colorScheme) var colorScheme

    private var changedSignals: [DailyPositioningSignal] {
        signals.filter { $0.hasChanged }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(AppColors.accent)
                Text("Signal Changes")
                    .font(size == .compact ? .subheadline : .title3)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()

                if isPro && !changedSignals.isEmpty {
                    Button { showShareSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isPro {
                // Risk appetite summary
                if !signals.isEmpty {
                    riskAppetiteBar
                }

                if changedSignals.isEmpty {
                    noChangesCard
                } else {
                    ForEach(changedSignals) { signal in
                        signalChangeRow(signal)
                    }
                }

                NavigationLink(destination: SignalChangeHistoryView()) {
                    HStack(spacing: 4) {
                        Text("View History")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
            } else {
                Button { showPaywall = true } label: { lockedCard }
                    .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .swingSetups)
        }
        .sheet(isPresented: $showShareSheet) {
            SignalChangesShareSheet(
                changes: changedSignals,
                totalAssets: signals.count
            )
        }
    }

    private func signalChangeRow(_ signal: DailyPositioningSignal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text(signal.asset)
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .lineLimit(1)
                    .frame(width: 70, alignment: .leading)

                if let prev = signal.prevPositioningSignal {
                    HStack(spacing: 6) {
                        Text(prev.label)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(prev.color)
                            .cornerRadius(4)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)

                        Text(signal.positioningSignal.label)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(signal.positioningSignal.color)
                            .cornerRadius(4)
                    }
                }

                Spacer()
            }

            // Action hint
            if let prev = signal.prevPositioningSignal {
                Text(signal.positioningSignal.changeHint(from: prev))
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(changeDirectionColor(signal).opacity(0.3), lineWidth: 1)
                )
        )
    }

    /// Border color based on direction of change: upgrade = green, downgrade = red, lateral = yellow
    private func changeDirectionColor(_ signal: DailyPositioningSignal) -> Color {
        guard let prev = signal.prevPositioningSignal else { return AppColors.textSecondary }
        let order: [PositioningSignal] = [.bearish, .neutral, .bullish]
        let prevIdx = order.firstIndex(of: prev) ?? 1
        let newIdx = order.firstIndex(of: signal.positioningSignal) ?? 1
        if newIdx > prevIdx { return AppColors.success }   // upgraded (e.g. neutral → bullish)
        if newIdx < prevIdx { return AppColors.error }     // downgraded (e.g. bullish → neutral)
        return AppColors.warning                           // lateral
    }

    private var noChangesCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 14))
                .foregroundColor(AppColors.success)

            Text("No signal changes today")
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textSecondary)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
    }

    private var lockedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Daily positioning signals")
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Upgrade to Pro for signal change alerts")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
    }

    // MARK: - Risk Appetite

    private var riskAppetite: Double {
        guard !signals.isEmpty else { return 50 }
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
                weightedBullish += weight * 0.4
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

    private var riskAppetiteBar: some View {
        HStack(spacing: 8) {
            Text("Risk Appetite")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            // Mini distribution bar
            GeometryReader { geo in
                let total = max(signals.count, 1)
                let bPct = Double(signals.filter { $0.positioningSignal == .bullish }.count) / Double(total)
                let nPct = Double(signals.filter { $0.positioningSignal == .neutral }.count) / Double(total)
                let bearPct = Double(signals.filter { $0.positioningSignal == .bearish }.count) / Double(total)
                HStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.success)
                        .frame(width: max(geo.size.width * bPct, 2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.warning)
                        .frame(width: max(geo.size.width * nPct, 2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.error)
                        .frame(width: max(geo.size.width * bearPct, 2))
                }
            }
            .frame(height: 5)
            .clipShape(RoundedRectangle(cornerRadius: 3))

            Text(riskLabel)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(riskColor)

            Text(String(format: "%.0f%%", riskAppetite))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(riskColor)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
    }
}
