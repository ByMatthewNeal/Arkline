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
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading history…")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    // Current signal header
                    if let latest = history.last {
                        currentSignalCard(latest)
                    }

                    // History
                    if history.count > 1 {
                        historySection
                    }

                    if history.isEmpty {
                        VStack(spacing: 6) {
                            Text("No history available")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textPrimary(colorScheme))
                            Text("Signals are computed daily at midnight UTC.")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }
                }
                .padding(20)
            }
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

                        if signal.hasChanged {
                            Image(systemName: "waveform.path.ecg")
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
