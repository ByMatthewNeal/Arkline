import SwiftUI

// MARK: - QPS Full Grid View (Dedicated Screen)

struct QPSFullGridView: View {
    let signals: [DailyPositioningSignal]
    @Environment(\.colorScheme) var colorScheme

    private var groupedSignals: [(QPSAssetCategory, [DailyPositioningSignal])] {
        let grouped = Dictionary(grouping: signals) { $0.assetCategory }
        return grouped.sorted { $0.key.sortOrder < $1.key.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groupedSignals, id: \.0) { category, categorySignals in
                    categorySection(category, signals: categorySignals)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7"))
        .navigationTitle("Daily Positioning")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
            .padding(.leading, 24)

            // Signal rows
            LazyVStack(spacing: 0) {
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
            .padding(.horizontal, 20)
        }
    }

    private func signalRow(_ signal: DailyPositioningSignal) -> some View {
        HStack(spacing: 10) {
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

            Text(signal.positioningSignal.label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(signal.positioningSignal.color)
                .cornerRadius(4)
                .frame(width: 70)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppColors.textSecondary.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
