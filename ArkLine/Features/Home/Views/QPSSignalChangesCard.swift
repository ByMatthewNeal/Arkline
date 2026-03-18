import SwiftUI

// MARK: - QPS Signal Changes Card (Home Tab)

struct QPSSignalChangesCard: View {
    let signals: [DailyPositioningSignal]
    let isPro: Bool
    var size: WidgetSize = .standard
    @State private var showPaywall = false
    @Environment(\.colorScheme) var colorScheme

    private var changedSignals: [DailyPositioningSignal] {
        signals.filter { $0.hasChanged }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "arrow.triangle.swap")
                    .foregroundColor(AppColors.accent)
                Text("Signal Changes")
                    .font(size == .compact ? .subheadline : .title3)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Spacer()
            }

            if isPro {
                if changedSignals.isEmpty {
                    noChangesCard
                } else {
                    ForEach(changedSignals) { signal in
                        signalChangeRow(signal)
                    }
                }
            } else {
                Button { showPaywall = true } label: { lockedCard }
                    .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .swingSetups)
        }
    }

    private func signalChangeRow(_ signal: DailyPositioningSignal) -> some View {
        HStack(spacing: 12) {
            Text(signal.asset)
                .font(AppFonts.body14Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .frame(width: 60, alignment: .leading)

            if let prev = signal.prevPositioningSignal {
                HStack(spacing: 6) {
                    Text(prev.label)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(prev.color.opacity(0.7))
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

            Text(String(format: "%.0f", signal.trendScore))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(signal.positioningSignal.color.opacity(0.3), lineWidth: 1)
                )
        )
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
