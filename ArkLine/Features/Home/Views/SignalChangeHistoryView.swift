import SwiftUI

// MARK: - Signal Change History View

struct SignalChangeHistoryView: View {
    @State private var changes: [DailyPositioningSignal] = []
    @State private var isLoading = true
    @Environment(\.colorScheme) var colorScheme

    private let service = PositioningSignalService()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    /// Group changes by signal_date
    private var groupedChanges: [(date: Date, changes: [DailyPositioningSignal])] {
        let grouped = Dictionary(grouping: changes) { signal in
            Calendar.current.startOfDay(for: signal.signalDate)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, changes: $0.value.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonCard()
                    }
                    .padding(.horizontal)
                } else if changes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.textSecondary.opacity(0.4))
                        Text("No signal changes in the last 30 days")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    ForEach(groupedChanges, id: \.date) { group in
                        daySection(date: group.date, changes: group.changes)
                    }
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle("Signal History")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadChanges()
        }
        .refreshable {
            await loadChanges()
        }
    }

    // MARK: - Day Section

    private func daySection(date: Date, changes: [DailyPositioningSignal]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day header
            HStack {
                Text(dayFormatter.string(from: date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text("\(changes.count) change\(changes.count == 1 ? "" : "s")")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()
            }
            .padding(.horizontal)

            ForEach(changes) { signal in
                changeRow(signal)
            }
        }
    }

    // MARK: - Change Row

    private func changeRow(_ signal: DailyPositioningSignal) -> some View {
        HStack(spacing: 12) {
            // Asset name
            VStack(alignment: .leading, spacing: 2) {
                Text(signal.asset)
                    .font(AppFonts.body14Bold)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if let created = signal.createdAt {
                    Text(timeFormatter.string(from: created) + " ET")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .frame(width: 80, alignment: .leading)

            // Signal change badges
            if let prev = signal.prevPositioningSignal {
                HStack(spacing: 6) {
                    Text(prev.label.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(prev.color)
                        .cornerRadius(4)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)

                    Text(signal.positioningSignal.label.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(signal.positioningSignal.color)
                        .cornerRadius(4)
                }
            }

            Spacer()

            // Category pill
            if let cat = signal.assetCategory as QPSAssetCategory? {
                Text(cat.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(AppColors.textSecondary.opacity(0.1))
                    )
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
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func changeDirectionColor(_ signal: DailyPositioningSignal) -> Color {
        guard let prev = signal.prevPositioningSignal else { return AppColors.textSecondary }
        let order: [PositioningSignal] = [.bearish, .neutral, .bullish]
        let prevIdx = order.firstIndex(of: prev) ?? 1
        let newIdx = order.firstIndex(of: signal.positioningSignal) ?? 1
        if newIdx > prevIdx { return AppColors.success }
        if newIdx < prevIdx { return AppColors.error }
        return AppColors.warning
    }

    private func loadChanges() async {
        isLoading = true
        defer { isLoading = false }
        do {
            changes = try await service.fetchRecentSignalChanges(days: 30)
        } catch {
            logWarning("Failed to load signal change history: \(error)", category: .network)
        }
    }
}
