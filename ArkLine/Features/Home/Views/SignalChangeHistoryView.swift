import SwiftUI

// MARK: - Signal Change History View

struct SignalChangeHistoryView: View {
    @State private var changes: [DailyPositioningSignal] = []
    @State private var isLoading = true
    @Environment(\.colorScheme) var colorScheme

    // Date lookup
    @State private var selectedDate: Date = Date()
    @State private var lookupChanges: [DailyPositioningSignal]?
    @State private var isLoadingLookup = false
    @State private var showDatePicker = false
    @State private var expandedSignalId: UUID?

    private let service = PositioningSignalService()

    /// QPS launched March 18, 2026
    private let earliestDate: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 3; c.day = 18
        return Calendar.current.date(from: c) ?? Date()
    }()

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

    private let lookupFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
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
                // Date lookup section
                dateLookupSection

                // Lookup results
                if let lookup = lookupChanges {
                    if isLoadingLookup {
                        SkeletonCard()
                            .padding(.horizontal)
                    } else if lookup.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.textSecondary)
                            Text("No signal changes on \(lookupFormatter.string(from: selectedDate))")
                                .font(AppFonts.body14Medium)
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                        )
                        .padding(.horizontal)
                    } else {
                        daySection(
                            date: Calendar.current.startOfDay(for: selectedDate),
                            changes: lookup.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) },
                            isLookup: true
                        )
                    }

                    dividerRow
                }

                // Recent changes header
                if !changes.isEmpty || isLoading {
                    Text("RECENT")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(1.0)
                        .padding(.horizontal)
                }

                if isLoading {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonCard()
                    }
                    .padding(.horizontal)
                } else if changes.isEmpty && lookupChanges == nil {
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
            .padding(.bottom, 100)
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

    // MARK: - Date Lookup Section

    private var dateLookupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOOK UP DATE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1.0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDatePicker.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)

                    Text(lookupChanges != nil ? lookupFormatter.string(from: selectedDate) : "Select a date...")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(lookupChanges != nil ? AppColors.textPrimary(colorScheme) : AppColors.textSecondary)

                    Spacer()

                    if lookupChanges != nil {
                        Button {
                            withAnimation {
                                lookupChanges = nil
                                showDatePicker = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .rotationEffect(.degrees(showDatePicker ? 180 : 0))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.textSecondary.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            if showDatePicker {
                DatePicker(
                    "Select date",
                    selection: $selectedDate,
                    in: earliestDate...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(AppColors.accent)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(colorScheme == .dark ? Color(hex: "1A1A1A") : Color.white)
                )
                .onChange(of: selectedDate) { _, _ in
                    Task { await lookupDate() }
                }
            }
        }
        .padding(.horizontal)
    }

    private var dividerRow: some View {
        Rectangle()
            .fill(AppColors.textSecondary.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal)
    }

    // MARK: - Day Section

    private func daySection(date: Date, changes: [DailyPositioningSignal], isLookup: Bool = false) -> some View {
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

                if isLookup {
                    Text("LOOKUP")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(AppColors.accent.opacity(0.12))
                        )
                }
            }
            .padding(.horizontal)

            ForEach(changes) { signal in
                changeRow(signal)
            }
        }
    }

    // MARK: - Change Row

    private func changeRow(_ signal: DailyPositioningSignal) -> some View {
        let isExpanded = expandedSignalId == signal.id

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedSignalId = isExpanded ? nil : signal.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
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

                    // Category pill + chevron
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

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }

                // Expandable hint
                if isExpanded, let prev = signal.prevPositioningSignal {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 9))
                            .foregroundColor(signal.positioningSignal.color.opacity(0.6))
                        Text(signal.positioningSignal.changeHint(from: prev))
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
        .buttonStyle(.plain)
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

    private func lookupDate() async {
        isLoadingLookup = true
        lookupChanges = []
        showDatePicker = false
        defer { isLoadingLookup = false }
        do {
            lookupChanges = try await service.fetchSignalChangesForDate(selectedDate)
        } catch {
            logWarning("Failed to look up signal changes: \(error)", category: .network)
            lookupChanges = []
        }
    }
}
