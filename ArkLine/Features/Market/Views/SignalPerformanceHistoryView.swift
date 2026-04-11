import SwiftUI

// MARK: - Signal Performance History View

/// Comprehensive signal performance breakdown with weekly stats,
/// calendar heatmap, and economic event density correlation.
struct SignalPerformanceHistoryView: View {
    @State var viewModel: SwingSetupsViewModel
    @State private var selectedPeriod: HistoryPeriod = .thirtyDays
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private var cardBg: Color { colorScheme == .dark ? Color(hex: "1F1F1F") : .white }

    enum HistoryPeriod: String, CaseIterable {
        case sevenDays = "7D"
        case thirtyDays = "30D"
        case ninetyDays = "90D"
        case allTime = "All"

        var days: Int? {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .ninetyDays: return 90
            case .allTime: return nil
            }
        }

        var label: String {
            switch self {
            case .sevenDays: return "LAST 7 DAYS"
            case .thirtyDays: return "LAST 30 DAYS"
            case .ninetyDays: return "LAST 90 DAYS"
            case .allTime: return "ALL TIME"
            }
        }

        /// Number of days to show in the calendar heatmap (capped for readability)
        var calendarDays: Int {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .ninetyDays: return 90
            case .allTime: return 90 // Cap calendar at 90 days for all-time
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Period picker
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(HistoryPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if viewModel.isLoadingHistory {
                    VStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            SkeletonCard()
                        }
                    }
                    .padding(.horizontal)
                } else if closedSignals.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.textSecondary.opacity(0.4))
                        Text("No closed trades in this period")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(textPrimary)
                    }
                    .padding(.top, 60)
                } else {
                    summaryHeader

                    eventDensityCard

                    calendarHeatmap

                    weeklyBreakdownCard

                    eventDaysList
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 8)
        }
        .background(AppColors.background(colorScheme))
        .navigationTitle("Signal History")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadHistoricalData(days: selectedPeriod.days)
        }
        .refreshable {
            viewModel.loadedHistoryDays = -1 // force reload
            await viewModel.loadHistoricalData(days: selectedPeriod.days)
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            Task {
                await viewModel.loadHistoricalData(days: newPeriod.days)
            }
        }
    }

    // MARK: - Data Helpers

    /// Closed signals filtered to the selected period
    private var closedSignals: [TradeSignal] {
        let all = viewModel.historicalSignals.filter { $0.outcomePct != nil }
        guard let days = selectedPeriod.days else { return all }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return all.filter { ($0.closedAt ?? $0.generatedAt) >= cutoff }
    }

    /// Group signals by the day they closed
    private var signalsByDay: [String: [TradeSignal]] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return Dictionary(grouping: closedSignals) { signal in
            fmt.string(from: signal.closedAt ?? signal.generatedAt)
        }
    }

    /// High-impact event dates (just the date strings)
    private var highImpactDates: Set<String> {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let highEvents = viewModel.historicalEvents.filter { $0.impact == .high }
        return Set(highEvents.map { fmt.string(from: $0.date) })
    }

    /// Signals on days with high-impact events
    private var volatileDaySignals: [TradeSignal] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return closedSignals.filter { signal in
            let day = fmt.string(from: signal.closedAt ?? signal.generatedAt)
            return highImpactDates.contains(day)
        }
    }

    /// Signals on days without high-impact events
    private var quietDaySignals: [TradeSignal] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return closedSignals.filter { signal in
            let day = fmt.string(from: signal.closedAt ?? signal.generatedAt)
            return !highImpactDates.contains(day)
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        let signals = closedSignals
        let wins = signals.filter { $0.outcome == .win }.count
        let total = signals.count
        let hitRate = total > 0 ? Double(wins) / Double(total) * 100 : 0
        let pnls = signals.compactMap(\.outcomePct)
        let cumPnl = pnls.reduce(0, +)
        let avgPnl = pnls.isEmpty ? 0 : cumPnl / Double(pnls.count)

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedPeriod.label)
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(1)

                    Text(String(format: "%+.1f%% avg", avgPnl))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(avgPnl >= 0 ? AppColors.success : AppColors.error)
                        .monospacedDigit()

                    Text("per trade move")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(total) trades")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(textPrimary)

                    Text(String(format: "%.0f%% win rate", hitRate))
                        .font(AppFonts.caption12Medium)
                        .foregroundColor(hitRate >= 50 ? AppColors.success : AppColors.error)

                    Text(String(format: "%+.1f%% cumulative", cumPnl))
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(cardBg))
        .padding(.horizontal)
    }

    // MARK: - Event Density Card (Quiet vs Volatile)

    private var eventDensityCard: some View {
        let quiet = quietDaySignals
        let volatile = volatileDaySignals

        let quietWins = quiet.filter { $0.outcome == .win }.count
        let quietHitRate = quiet.isEmpty ? 0 : Double(quietWins) / Double(quiet.count) * 100
        let quietAvgPnl = quiet.compactMap(\.outcomePct).isEmpty ? 0 :
            quiet.compactMap(\.outcomePct).reduce(0, +) / Double(quiet.compactMap(\.outcomePct).count)

        let volWins = volatile.filter { $0.outcome == .win }.count
        let volHitRate = volatile.isEmpty ? 0 : Double(volWins) / Double(volatile.count) * 100
        let volAvgPnl = volatile.compactMap(\.outcomePct).isEmpty ? 0 :
            volatile.compactMap(\.outcomePct).reduce(0, +) / Double(volatile.compactMap(\.outcomePct).count)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("QUIET vs VOLATILE DAYS")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(1)
                Spacer()
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
            }

            Text("Volatile = days with high-impact economic events (FOMC, CPI, NFP, etc.)")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary.opacity(0.7))

            HStack(spacing: 16) {
                densityColumn(
                    label: "Quiet Days",
                    icon: "sun.max.fill",
                    iconColor: AppColors.accent,
                    count: quiet.count,
                    hitRate: quietHitRate,
                    avgPnl: quietAvgPnl
                )

                Rectangle()
                    .fill(AppColors.textSecondary.opacity(0.15))
                    .frame(width: 1)
                    .padding(.vertical, 4)

                densityColumn(
                    label: "Volatile Days",
                    icon: "bolt.fill",
                    iconColor: AppColors.warning,
                    count: volatile.count,
                    hitRate: volHitRate,
                    avgPnl: volAvgPnl
                )
            }

            // Insight banner
            if !quiet.isEmpty && !volatile.isEmpty {
                let diff = quietHitRate - volHitRate
                let better = diff > 0 ? "quiet" : "volatile"
                let absDiff = abs(diff)

                if absDiff >= 5 {
                    HStack(spacing: 8) {
                        Image(systemName: better == "quiet" ? "sun.max.fill" : "bolt.fill")
                            .font(.system(size: 11))
                            .foregroundColor(better == "quiet" ? AppColors.accent : AppColors.warning)

                        Text("Signals perform \(String(format: "%.0f%%", absDiff)) better on \(better) days")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textPrimary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((better == "quiet" ? AppColors.accent : AppColors.warning).opacity(colorScheme == .dark ? 0.08 : 0.05))
                    )
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(cardBg))
        .padding(.horizontal)
    }

    private func densityColumn(label: String, icon: String, iconColor: Color, count: Int, hitRate: Double, avgPnl: Double) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(iconColor)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(textPrimary)
            }

            Text("\(count)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(textPrimary)
                .monospacedDigit()
            Text("trades")
                .font(.system(size: 9))
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text(String(format: "%.0f%%", hitRate))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(hitRate >= 50 ? AppColors.success : AppColors.error)
                        .monospacedDigit()
                    Text("Win Rate")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                }
                VStack(spacing: 1) {
                    Text(String(format: "%+.1f%%", avgPnl))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(avgPnl >= 0 ? AppColors.success : AppColors.error)
                        .monospacedDigit()
                    Text("Avg P&L")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Calendar Heatmap

    private var calendarHeatmap: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let numDays = selectedPeriod.calendarDays
        let startDate = calendar.date(byAdding: .day, value: -(numDays - 1), to: today)!

        let days: [Date] = (0..<numDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDate)
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "d"

        // For 7-day view show day names, for longer views show month markers
        let showMonthHeaders = numDays > 14

        // Group into weeks (rows of 7)
        let weeks = stride(from: 0, to: days.count, by: 7).map { start in
            Array(days[start..<min(start + 7, days.count)])
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text("DAILY P&L CALENDAR")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            Text("Shows average P&L per trade each day")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary.opacity(0.7))

            // Legend
            HStack(spacing: 12) {
                legendItem(color: AppColors.success, label: "Winning day")
                legendItem(color: AppColors.error, label: "Losing day")
                legendItem(color: AppColors.warning, label: "Event day")
                Spacer()
            }

            // Calendar grid
            if numDays <= 14 {
                // Compact layout for 7D — horizontal row
                calendarRow(days: days, fmt: fmt, dayFmt: dayFmt)
            } else {
                // Grid layout for 30D/90D
                VStack(spacing: 4) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { weekIdx, week in
                        // Month label for first day of each month
                        if showMonthHeaders, let first = week.first {
                            let dayOfMonth = calendar.component(.day, from: first)
                            if weekIdx == 0 || dayOfMonth <= 7 {
                                let monthFmt = DateFormatter()
                                let _ = monthFmt.dateFormat = "MMM"
                                Text(monthFmt.string(from: first))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.top, weekIdx == 0 ? 0 : 4)
                            }
                        }

                        HStack(spacing: numDays > 60 ? 2 : 4) {
                            ForEach(week, id: \.timeIntervalSince1970) { day in
                                calendarCell(day: day, fmt: fmt, dayFmt: dayFmt, compact: numDays > 60)
                            }

                            if week.count < 7 {
                                ForEach(0..<(7 - week.count), id: \.self) { _ in
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(cardBg))
        .padding(.horizontal)
    }

    /// Horizontal row for 7-day view
    private func calendarRow(days: [Date], fmt: DateFormatter, dayFmt: DateFormatter) -> some View {
        let calendar = Calendar.current
        let weekdayFmt = DateFormatter()
        weekdayFmt.dateFormat = "EEE"

        return HStack(spacing: 6) {
            ForEach(days, id: \.timeIntervalSince1970) { day in
                let dateStr = fmt.string(from: day)
                let daySignals = signalsByDay[dateStr] ?? []
                let dayPnl = daySignals.compactMap(\.outcomePct).reduce(0, +)
                let dayAvgPnl = daySignals.isEmpty ? 0.0 : dayPnl / Double(daySignals.count)
                let hasHighEvent = highImpactDates.contains(dateStr)
                let isToday = calendar.isDateInToday(day)

                VStack(spacing: 3) {
                    Text(weekdayFmt.string(from: day))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    Text(dayFmt.string(from: day))
                        .font(.system(size: 11, weight: isToday ? .bold : .medium))
                        .foregroundColor(isToday ? AppColors.accent : textPrimary)

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(cellColor(pnl: dayAvgPnl, hasSignals: !daySignals.isEmpty))
                            .frame(height: 36)

                        if !daySignals.isEmpty {
                            VStack(spacing: 0) {
                                Text(String(format: "%+.1f", dayAvgPnl))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .monospacedDigit()
                                Text("\(daySignals.count)t")
                                    .font(.system(size: 7, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }

                    if hasHighEvent {
                        Circle().fill(AppColors.warning).frame(width: 5, height: 5)
                    } else {
                        Circle().fill(Color.clear).frame(width: 5, height: 5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Single calendar cell for grid layouts
    private func calendarCell(day: Date, fmt: DateFormatter, dayFmt: DateFormatter, compact: Bool) -> some View {
        let calendar = Calendar.current
        let dateStr = fmt.string(from: day)
        let daySignals = signalsByDay[dateStr] ?? []
        let dayPnl = daySignals.compactMap(\.outcomePct).reduce(0, +)
        let dayAvgPnl = daySignals.isEmpty ? 0.0 : dayPnl / Double(daySignals.count)
        let hasHighEvent = highImpactDates.contains(dateStr)
        let isToday = calendar.isDateInToday(day)

        return VStack(spacing: 2) {
            Text(dayFmt.string(from: day))
                .font(.system(size: compact ? 8 : 10, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? AppColors.accent : textPrimary)

            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(cellColor(pnl: dayAvgPnl, hasSignals: !daySignals.isEmpty))
                    .frame(height: compact ? 20 : 28)

                if !daySignals.isEmpty {
                    if compact {
                        Text(String(format: "%+.0f", dayAvgPnl))
                            .font(.system(size: 6, weight: .bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    } else {
                        VStack(spacing: 0) {
                            Text(String(format: "%+.1f", dayAvgPnl))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .monospacedDigit()
                            Text("\(daySignals.count)t")
                                .font(.system(size: 6, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }

            if hasHighEvent {
                Circle().fill(AppColors.warning).frame(width: compact ? 4 : 5, height: compact ? 4 : 5)
            } else {
                Circle().fill(Color.clear).frame(width: compact ? 4 : 5, height: compact ? 4 : 5)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cellColor(pnl: Double, hasSignals: Bool) -> Color {
        guard hasSignals else {
            return AppColors.textSecondary.opacity(colorScheme == .dark ? 0.08 : 0.06)
        }
        if pnl > 0 {
            return AppColors.success.opacity(min(0.3 + abs(pnl) * 0.1, 0.9))
        } else if pnl < 0 {
            return AppColors.error.opacity(min(0.3 + abs(pnl) * 0.1, 0.9))
        }
        return AppColors.textSecondary.opacity(0.2)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.6))
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    // MARK: - Weekly Breakdown

    private var weeklyBreakdownCard: some View {
        let calendar = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        // Group signals by ISO week
        let grouped = Dictionary(grouping: closedSignals) { signal -> String in
            let date = signal.closedAt ?? signal.generatedAt
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            let year = calendar.component(.yearForWeekOfYear, from: date)
            return "\(year)-W\(weekOfYear)"
        }

        let sortedWeeks = grouped.keys.sorted()

        return VStack(alignment: .leading, spacing: 12) {
            Text("WEEKLY BREAKDOWN")
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            if sortedWeeks.isEmpty {
                Text("No data available")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(sortedWeeks, id: \.self) { weekKey in
                    let signals = grouped[weekKey] ?? []
                    let wins = signals.filter { $0.outcome == .win }.count
                    let losses = signals.filter { $0.outcome == .loss }.count
                    let total = wins + losses
                    let hitRate = total > 0 ? Double(wins) / Double(total) * 100 : 0
                    let pnls = signals.compactMap(\.outcomePct)
                    let totalPnl = pnls.reduce(0, +)
                    let avgPnl = pnls.isEmpty ? 0 : totalPnl / Double(pnls.count)

                    let weekDates = signals.compactMap(\.closedAt).map { fmt.string(from: $0) }
                    let eventCount = weekDates.filter { highImpactDates.contains($0) }.count

                    weekRow(
                        weekLabel: formatWeekLabel(weekKey),
                        trades: total,
                        wins: wins,
                        losses: losses,
                        hitRate: hitRate,
                        totalPnl: totalPnl,
                        avgPnl: avgPnl,
                        eventCount: eventCount
                    )

                    if weekKey != sortedWeeks.last {
                        Divider().opacity(0.2)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(cardBg))
        .padding(.horizontal)
    }

    private func weekRow(weekLabel: String, trades: Int, wins: Int, losses: Int, hitRate: Double, totalPnl: Double, avgPnl: Double, eventCount: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(weekLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textPrimary)

                if eventCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                        Text("\(eventCount)")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(AppColors.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppColors.warning.opacity(colorScheme == .dark ? 0.12 : 0.08))
                    .cornerRadius(4)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%+.1f%% avg", avgPnl))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(avgPnl >= 0 ? AppColors.success : AppColors.error)
                        .monospacedDigit()
                    Text(String(format: "%+.1f%% total", totalPnl))
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("\(trades)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(textPrimary)
                    Text("trades")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                }

                HStack(spacing: 4) {
                    Text("\(wins)W")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.success)
                    Text("/")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                    Text("\(losses)L")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.error)
                }

                Text(String(format: "%.0f%% WR", hitRate))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(hitRate >= 50 ? AppColors.success : AppColors.error)

                Spacer()

                // Mini win/loss bar
                GeometryReader { geo in
                    let total = max(wins + losses, 1)
                    let winWidth = geo.size.width * CGFloat(wins) / CGFloat(total)
                    HStack(spacing: 1) {
                        Rectangle()
                            .fill(AppColors.success)
                            .frame(width: max(winWidth, 0))
                        Rectangle()
                            .fill(AppColors.error)
                    }
                    .cornerRadius(2)
                }
                .frame(width: 50, height: 6)
            }
        }
    }

    private func formatWeekLabel(_ weekKey: String) -> String {
        let parts = weekKey.split(separator: "-W")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let week = Int(parts[1]) else { return weekKey }

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current

        guard let startOfWeek = calendar.date(from: DateComponents(weekOfYear: week, yearForWeekOfYear: year)) else {
            return weekKey
        }
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? startOfWeek

        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: startOfWeek)) – \(fmt.string(from: endOfWeek))"
    }

    // MARK: - Event Days List

    private var eventDaysList: some View {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let eventDaysWithSignals = highImpactDates.filter { signalsByDay[$0] != nil }.sorted()

        guard !eventDaysWithSignals.isEmpty else {
            return AnyView(EmptyView())
        }

        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "EEE, MMM d"

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("HIGH-IMPACT EVENT DAYS")
                    .font(AppFonts.caption12Medium)
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(1)

                ForEach(eventDaysWithSignals, id: \.self) { dateStr in
                    let daySignals = signalsByDay[dateStr] ?? []
                    let dayPnl = daySignals.compactMap(\.outcomePct).reduce(0, +)
                    let dayWins = daySignals.filter { $0.outcome == .win }.count

                    let dayEvents = viewModel.historicalEvents.filter { event in
                        fmt.string(from: event.date) == dateStr && event.impact == .high
                    }

                    let parsedDate = fmt.date(from: dateStr) ?? Date()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(displayFmt.string(from: parsedDate))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(textPrimary)

                            Spacer()

                            Text(String(format: "%+.1f%%", dayPnl))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(dayPnl >= 0 ? AppColors.success : AppColors.error)
                                .monospacedDigit()
                        }

                        ForEach(dayEvents.prefix(3)) { event in
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(AppColors.warning)
                                Text(event.title)
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.textSecondary)

                                if let beatMiss = event.beatMiss {
                                    Text(beatMiss)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(beatMiss == "Beat" ? AppColors.success : (beatMiss == "Miss" ? AppColors.error : AppColors.textSecondary))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background((beatMiss == "Beat" ? AppColors.success : (beatMiss == "Miss" ? AppColors.error : AppColors.textSecondary)).opacity(0.12))
                                        .cornerRadius(3)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            Text("\(daySignals.count) trades")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textSecondary)
                            Text("\(dayWins)W / \(daySignals.count - dayWins)L")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    if dateStr != eventDaysWithSignals.last {
                        Divider().opacity(0.2)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(cardBg))
            .padding(.horizontal)
        )
    }
}
