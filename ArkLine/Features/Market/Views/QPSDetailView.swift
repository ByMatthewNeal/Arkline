import SwiftUI

// MARK: - QPS Detail View (Per-Asset Signal History)

struct QPSDetailView: View {
    let asset: String
    @State private var history: [DailyPositioningSignal] = []
    @State private var isLoading = true
    @Environment(\.colorScheme) var colorScheme

    private let service = PositioningSignalService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Current signal header
                if let latest = history.last {
                    currentSignalCard(latest)
                }

                // Inputs
                if let latest = history.last {
                    inputsSection(latest)
                }

                // History
                if history.count > 1 {
                    historySection
                }
            }
            .padding(20)
        }
        .background(colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7"))
        .navigationTitle("\(asset) Positioning")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            do {
                history = try await service.fetchSignalHistory(asset: asset, days: 30)
            } catch {
                logWarning("QPS history fetch failed: \(error.localizedDescription)", category: .network)
            }
            isLoading = false
        }
    }

    private func currentSignalCard(_ signal: DailyPositioningSignal) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: signal.positioningSignal.icon)
                    .font(.system(size: 24))
                    .foregroundColor(signal.positioningSignal.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.positioningSignal.label)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(signal.positioningSignal.color)

                    if let change = signal.changeDescription {
                        Text(change)
                            .font(AppFonts.caption12Medium)
                            .foregroundColor(AppColors.warning)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Score")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    Text(String(format: "%.0f", signal.trendScore))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                }
            }

            Text("$\(String(format: "%.2f", signal.price))")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(signal.positioningSignal.color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func inputsSection(_ signal: DailyPositioningSignal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Signal Inputs")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            HStack(spacing: 0) {
                inputItem(label: "Trend Score", value: String(format: "%.0f", signal.trendScore))
                Divider().frame(height: 30).opacity(0.2)
                inputItem(label: "RSI", value: signal.rsi.map { String(format: "%.0f", $0) } ?? "—")
                Divider().frame(height: 30).opacity(0.2)
                inputItem(label: "Above 200 SMA", value: signal.above200Sma ? "Yes" : "No")
            }
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
            )
        }
    }

    private func inputItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("30-Day History")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 0) {
                ForEach(history.suffix(30).reversed()) { signal in
                    HStack {
                        Text(formatDate(signal.signalDate))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 60, alignment: .leading)

                        Text(signal.positioningSignal.label)
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(signal.positioningSignal.color)
                            .cornerRadius(4)

                        Spacer()

                        Text(String(format: "%.0f", signal.trendScore))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                            .monospacedDigit()

                        if signal.hasChanged {
                            Image(systemName: "arrow.triangle.swap")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(AppColors.warning)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)

                    Divider().opacity(0.1)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
            )
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
