import SwiftUI

// MARK: - QPS Detail View (Per-Asset Signal History)

struct QPSDetailView: View {
    let asset: String
    @State private var history: [DailyPositioningSignal] = []
    @State private var isLoading = true
    @State private var days: Int = 30
    @Environment(\.colorScheme) var colorScheme

    private let service = PositioningSignalService()
    private let dayOptions = [30, 90, 180]

    // Newest first.
    private var sortedDesc: [DailyPositioningSignal] {
        history.sorted { $0.signalDate > $1.signalDate }
    }

    /// Days the current stance has held within the loaded window.
    private var currentRunDays: Int {
        guard let current = sortedDesc.first?.positioningSignal.label else { return 0 }
        var count = 0
        for s in sortedDesc {
            if s.positioningSignal.label == current { count += 1 } else { break }
        }
        return count
    }

    /// True when the current stance fills the whole window, so its true start
    /// is older than the loaded range (show "N+ days").
    private var runIsAtLeast: Bool {
        !history.isEmpty && currentRunDays == history.count
    }

    /// The days the signal flipped from the prior day, newest first.
    private var shifts: [DailyPositioningSignal] {
        sortedDesc.filter { $0.hasChanged && $0.prevPositioningSignal != nil }
    }

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
                    if let latest = history.last {
                        currentSignalCard(latest)
                    }

                    if history.count > 1 {
                        rangePicker
                        shiftsSection
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
        .refreshable { await load() }
        .background(colorScheme == .dark ? Color(hex: "141414") : Color(hex: "F5F5F7"))
        .navigationTitle("\(asset) Positioning")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await load(initial: true) }
        .onChange(of: days) { _, _ in Task { await load() } }
    }

    private func load(initial: Bool = false) async {
        do {
            history = try await service.fetchSignalHistory(asset: asset, days: days)
        } catch {
            logWarning("QPS history fetch failed: \(error.localizedDescription)", category: .network)
        }
        if initial { isLoading = false }
    }

    // MARK: - Current Signal

    private func currentSignalCard(_ signal: DailyPositioningSignal) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(signal.positioningSignal.color)
                    .frame(width: 10, height: 10)

                Text(signal.positioningSignal.label)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(signal.positioningSignal.color)

                Spacer()

                Text("Holding \(currentRunDays)\(runIsAtLeast ? "+" : "") day\(currentRunDays == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }

            Text(signal.hasChanged && signal.prevPositioningSignal != nil
                 ? signal.positioningSignal.changeHint(from: signal.prevPositioningSignal!)
                 : signal.positioningSignal.actionGuidance)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

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

    // MARK: - Range Picker

    private var rangePicker: some View {
        HStack(spacing: 8) {
            ForEach(dayOptions, id: \.self) { opt in
                Button { days = opt } label: {
                    Text("\(opt)D")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(days == opt ? .white : AppColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(days == opt ? AppColors.accent : AppColors.textSecondary.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Signal Changes (shifts)

    private var shiftsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Signal Changes")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if shifts.isEmpty {
                Text("No changes in the last \(days) days. \(history.last?.positioningSignal.label ?? "The stance") held throughout.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(shifts.enumerated()), id: \.element.id) { index, shift in
                        HStack(spacing: 10) {
                            Text(formatDate(shift.signalDate))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 60, alignment: .leading)

                            if let prev = shift.prevPositioningSignal {
                                Text(prev.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(prev.color)
                                Text("→")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            Text(shift.positioningSignal.label)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(shift.positioningSignal.color)

                            Spacer()

                            Text(formatPrice(shift.price, category: shift.assetCategory))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        }
                        .padding(.vertical, 9)
                        .padding(.horizontal, 12)

                        if index != shifts.count - 1 {
                            Divider().opacity(0.1)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                )
            }
        }
    }

    // MARK: - Full History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(days)-Day History")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            VStack(spacing: 0) {
                ForEach(Array(sortedDesc.enumerated()), id: \.element.id) { index, signal in
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

                        if signal.hasChanged {
                            Circle()
                                .fill(AppColors.warning)
                                .frame(width: 5, height: 5)
                        }

                        Spacer()

                        Text(formatPrice(signal.price, category: signal.assetCategory))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(AppColors.textSecondary.opacity(0.7))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)

                    if index != sortedDesc.count - 1 {
                        Divider().opacity(0.1)
                    }
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

    private func formatPrice(_ price: Double, category: QPSAssetCategory) -> String {
        // Crypto keeps tiered decimals (small coins need more precision); stocks,
        // indices, and commodities always show cents with thousands separators.
        if category == .crypto || category == .alt_btc {
            return price.asCryptoPrice(code: "USD")
        }
        return price.asCurrency
    }
}
