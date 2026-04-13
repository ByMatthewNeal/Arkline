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
        HStack(spacing: 10) {
            if let logoURL = AssetRiskConfig.forSymbol(signal.asset)?.logoURL {
                KFImage(logoURL)
                    .resizable()
                    .fade(duration: 0.2)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
            }

            Text(signal.asset)
                .font(AppFonts.body14Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineLimit(1)
                .frame(width: 55, alignment: .leading)

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
}
