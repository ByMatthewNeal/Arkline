import SwiftUI

// MARK: - QPS Grid Section (Market Tab)

struct QPSGridSection: View {
    let signals: [DailyPositioningSignal]
    let isPro: Bool
    @Environment(\.colorScheme) var colorScheme

    private var groupedSignals: [(QPSAssetCategory, [DailyPositioningSignal])] {
        let grouped = Dictionary(grouping: signals) { $0.assetCategory }
        return grouped
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.triangle.swap")
                    .foregroundColor(AppColors.accent)
                Text("Daily Positioning")
                    .font(.title3)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Spacer()
            }
            .padding(.horizontal, 4)

            if signals.isEmpty {
                emptyState
            } else {
                ForEach(groupedSignals, id: \.0) { category, categorySignals in
                    categorySection(category, signals: categorySignals)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func categorySection(_ category: QPSAssetCategory, signals: [DailyPositioningSignal]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Text(category.displayName)
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(0.5)
            }
            .padding(.leading, 4)

            // Signal rows
            VStack(spacing: 0) {
                ForEach(Array(signals.enumerated()), id: \.element.id) { index, signal in
                    NavigationLink {
                        QPSDetailView(asset: signal.asset)
                    } label: {
                        signalRow(signal)
                    }
                    .buttonStyle(PlainButtonStyle())

                    if index < signals.count - 1 {
                        Divider().opacity(0.1).padding(.horizontal, 12)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
            )
        }
    }

    private func signalRow(_ signal: DailyPositioningSignal) -> some View {
        HStack(spacing: 10) {
            // Asset name + ticker
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(signal.displayName)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    if signal.hasChanged {
                        Image(systemName: signal.positioningSignal == .bullish ? "arrow.up" : "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppColors.warning)
                    }
                }

                Text(signal.asset)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(minWidth: 90, alignment: .leading)

            Spacer()

            // Signal badge
            Text(signal.positioningSignal.label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(signal.positioningSignal.color)
                .cornerRadius(4)
                .frame(width: 70)

            // Trend score
            Text(String(format: "%.0f", signal.trendScore))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.textSecondary)
                .monospacedDigit()
                .frame(width: 30, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No positioning signals yet")
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text("Signals are computed daily at midnight UTC.")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
        )
    }
}
