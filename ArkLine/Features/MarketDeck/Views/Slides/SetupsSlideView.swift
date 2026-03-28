import SwiftUI

struct SetupsSlideView: View {
    let data: SetupsSlideData
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            SlideHeader(title: title)

            // Stats row
            HStack(spacing: ArkSpacing.xs) {
                statCard(value: "\(data.signalsTriggered)", label: "Triggered")
                statCard(value: "\(data.signalsResolved)", label: "Resolved")
                if let wr = data.winRate {
                    statCard(value: String(format: "%.0f%%", wr), label: "Win Rate",
                             valueColor: wr >= 50 ? AppColors.success : AppColors.error)
                }
                if let pnl = data.avgPnl {
                    statCard(value: String(format: "%+.1f%%", pnl), label: "Avg P&L",
                             valueColor: pnl >= 0 ? AppColors.success : AppColors.error)
                }
            }

            // Signal list
            if !data.signals.isEmpty {
                VStack(spacing: ArkSpacing.xs) {
                    ForEach(data.signals) { signal in
                        signalRow(signal)
                    }
                }
            } else {
                Text("No signals triggered this week")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ArkSpacing.xxl)
            }
        }
    }

    @ViewBuilder
    private func statCard(value: String, label: String, valueColor: Color? = nil) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.number20)
                .foregroundColor(valueColor ?? AppColors.textPrimary(colorScheme))

            Text(label)
                .font(AppFonts.footnote10)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ArkSpacing.sm)
        .background(AppColors.textPrimary(colorScheme).opacity(0.06))
        .cornerRadius(ArkSpacing.Radius.md)
    }

    @ViewBuilder
    private func signalRow(_ signal: SetupSignalEntry) -> some View {
        let isLong = signal.direction.lowercased() == "long"
        let dirColor = isLong ? AppColors.success : AppColors.error

        HStack(spacing: ArkSpacing.sm) {
            // Direction badge
            Text(signal.direction.uppercased())
                .font(AppFonts.interFont(size: 10, weight: .semibold))
                .foregroundColor(dirColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(dirColor.opacity(0.15)))

            VStack(alignment: .leading, spacing: 1) {
                Text(signal.asset)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(signal.entry.asSignalPrice)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Outcome badge
            Text(signal.outcome.uppercased())
                .font(AppFonts.interFont(size: 10, weight: .semibold))
                .foregroundColor(outcomeColor(signal.outcome))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(outcomeColor(signal.outcome).opacity(0.15)))

            if let pnl = signal.pnl {
                Text(String(format: "%+.1f%%", pnl))
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(pnl >= 0 ? AppColors.success : AppColors.error)
                    .frame(width: 50, alignment: .trailing)
            }
        }
        .padding(ArkSpacing.sm)
        .background(AppColors.textPrimary(colorScheme).opacity(0.04))
        .cornerRadius(ArkSpacing.Radius.sm)
    }

    private func outcomeColor(_ outcome: String) -> Color {
        switch outcome.lowercased() {
        case "win": return AppColors.success
        case "loss": return AppColors.error
        case "in play": return AppColors.accent
        default: return AppColors.textSecondary
        }
    }
}
