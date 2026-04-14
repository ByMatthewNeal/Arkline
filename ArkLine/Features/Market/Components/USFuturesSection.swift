import SwiftUI

// MARK: - US Market Session

/// Determines the current US equity market session based on Eastern Time.
///
/// Schedule (all times Eastern):
/// - **Pre-Market**: Mon–Fri 4:00 AM – 9:30 AM
/// - **Regular Session**: Mon–Fri 9:30 AM – 4:00 PM
/// - **After Hours**: Mon–Fri 4:00 PM – 8:00 PM
/// - **Overnight**: Sun 6:00 PM – Mon 4:00 AM, Mon–Thu 8:00 PM – next day 4:00 AM
/// - **Weekend**: Fri 8:00 PM – Sun 6:00 PM (futures halted)
enum USMarketSession: String {
    case preMarket = "Pre-Market"
    case regularSession = "Market Open"
    case afterHours = "After Hours"
    case overnight = "Overnight"
    case weekend = "Weekend"

    static var current: USMarketSession {
        let eastern = TimeZone(identifier: "America/New_York") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eastern

        let now = Date()
        let weekday = calendar.component(.weekday, from: now) // 1=Sun, 7=Sat
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let totalMinutes = hour * 60 + minute

        switch weekday {
        case 7: // Saturday — all day closed
            return .weekend

        case 1: // Sunday
            // Futures resume at 6:00 PM ET Sunday
            if totalMinutes >= 1080 { // 6:00 PM+
                return .overnight
            }
            return .weekend

        case 2: // Monday
            if totalMinutes < 240 { // Before 4:00 AM — overnight from Sunday open
                return .overnight
            }
            return weekdaySession(totalMinutes)

        case 6: // Friday
            let session = weekdaySession(totalMinutes)
            // After 8:00 PM Friday → weekend (futures halt at ~5 PM but extended runs to 8 PM)
            if totalMinutes >= 1200 {
                return .weekend
            }
            return session

        default: // Tue–Thu (weekdays 3, 4, 5)
            if totalMinutes < 240 { // Before 4:00 AM — overnight from previous evening
                return .overnight
            }
            return weekdaySession(totalMinutes)
        }
    }

    /// Standard weekday session windows (Mon–Fri, 4 AM onward)
    private static func weekdaySession(_ totalMinutes: Int) -> USMarketSession {
        // Pre-market: 4:00 AM – 9:30 AM ET
        if totalMinutes >= 240 && totalMinutes < 570 { return .preMarket }
        // Regular session: 9:30 AM – 4:00 PM ET
        if totalMinutes >= 570 && totalMinutes < 960 { return .regularSession }
        // After hours: 4:00 PM – 8:00 PM ET
        if totalMinutes >= 960 && totalMinutes < 1200 { return .afterHours }
        // 8:00 PM+ → overnight (futures still trading)
        if totalMinutes >= 1200 { return .overnight }
        // Before 4:00 AM (shouldn't reach here from weekdaySession, but safety)
        return .overnight
    }

    var icon: String {
        switch self {
        case .preMarket: return "sunrise.fill"
        case .regularSession: return "chart.line.uptrend.xyaxis"
        case .afterHours: return "sunset.fill"
        case .overnight: return "moon.stars.fill"
        case .weekend: return "moon.zzz.fill"
        }
    }

    var color: Color {
        switch self {
        case .preMarket: return Color(hex: "F59E0B")   // amber
        case .regularSession: return Color(hex: "22C55E")   // green
        case .afterHours: return Color(hex: "8B5CF6")   // purple
        case .overnight: return Color(hex: "6366F1")     // indigo
        case .weekend: return Color(hex: "64748B")       // slate
        }
    }

    /// Whether futures are actively trading right now
    var futuresActive: Bool {
        switch self {
        case .preMarket, .regularSession, .afterHours, .overnight: return true
        case .weekend: return false
        }
    }

    // MARK: - Local Time Helpers

    /// The next session transition time, converted to the user's local timezone.
    /// e.g. "Opens 6:30 AM" for a Pacific time user during pre-market.
    var localTimeSubtitle: String {
        switch self {
        case .preMarket:
            return "Opens \(formatET(hour: 9, minute: 30))"
        case .regularSession:
            return "Closes \(formatET(hour: 16, minute: 0))"
        case .afterHours:
            return "Extended until \(formatET(hour: 20, minute: 0))"
        case .overnight:
            return "Pre-market \(formatET(hour: 4, minute: 0))"
        case .weekend:
            return "Futures resume \(formatWeekendResume())"
        }
    }

    /// Formats an Eastern Time hour:minute into the user's local timezone as "h:mm a"
    private func formatET(hour: Int, minute: Int) -> String {
        let eastern = TimeZone(identifier: "America/New_York") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eastern

        // Build a date for today at the given ET hour
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0

        guard let etDate = calendar.date(from: components) else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        return formatter.string(from: etDate)
    }

    /// For weekends, shows "Sun 3:00 PM" (or whatever 6 PM ET Sunday is locally)
    private func formatWeekendResume() -> String {
        let eastern = TimeZone(identifier: "America/New_York") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = eastern

        // Find next Sunday
        let now = Date()
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: now)
        components.weekday = 1 // Sunday
        components.hour = 18   // 6 PM ET
        components.minute = 0
        components.second = 0

        guard var sundayET = calendar.date(from: components) else { return "Sunday" }
        // If we're already past Sunday 6 PM, advance a week
        if sundayET <= now {
            sundayET = calendar.date(byAdding: .weekOfYear, value: 1, to: sundayET) ?? sundayET
        }

        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"

        // If it's today (Sunday before 6 PM ET), just show the time
        let localCalendar = Calendar.current
        if localCalendar.isDateInToday(sundayET) {
            formatter.dateFormat = "h:mm a"
            return "at \(formatter.string(from: sundayET))"
        }

        // Otherwise show day + time
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: sundayET)
    }
}

// MARK: - US Futures Section

struct USFuturesSection: View {
    var refreshId: UUID = UUID()
    @Environment(\.colorScheme) var colorScheme
    @State private var futures: [USFuturesQuote] = []
    @State private var isLoading = true
    @State private var session = USMarketSession.current
    @State private var sessionTimer: Timer?

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }
    private let yahoo = YahooFinanceService.shared

    /// Overall market bias based on majority of futures direction
    private var marketBias: (label: String, color: Color)? {
        guard !futures.isEmpty else { return nil }
        // If all futures are flat (0.00%), don't show a bias
        if futures.allSatisfy(\.isFlat) { return nil }
        let positiveCount = futures.filter(\.isPositive).count
        let negativeCount = futures.filter { !$0.isPositive && !$0.isFlat }.count
        if positiveCount == futures.count {
            return ("bullish", AppColors.success)
        } else if negativeCount == futures.count {
            return ("bearish", AppColors.error)
        }
        return ("mixed", AppColors.warning)
    }

    /// Context-aware bias text that changes with the session
    private var biasText: String? {
        guard let bias = marketBias else { return nil }
        switch session {
        case .preMarket:
            return "Futures indicate a \(bias.label) open"
        case .regularSession:
            return "Markets trading \(bias.label) today"
        case .afterHours:
            return "After-hours trading is \(bias.label)"
        case .overnight:
            return "Overnight futures are \(bias.label)"
        case .weekend:
            return "Futures closed \(bias.label) on Friday"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Text("US Futures")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                Spacer()

                // Session badge with local time
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: session.icon)
                            .font(.system(size: 10))
                        Text(session.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(session.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(session.color.opacity(0.12))
                    .cornerRadius(6)

                    Text(session.localTimeSubtitle)
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if isLoading {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color(hex: "E8E8ED"))
                        .frame(height: 64)
                }
            } else if futures.isEmpty {
                Text("Unable to load futures data")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                // Bias summary row
                if let text = biasText, let bias = marketBias {
                    HStack {
                        Circle()
                            .fill(bias.color)
                            .frame(width: 8, height: 8)
                        Text(text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(bias.color)
                        Spacer()
                    }
                }

                // Futures cards
                ForEach(futures) { quote in
                    FuturesQuoteRow(quote: quote)
                }
            }
        }
        .padding(.horizontal)
        .task(id: refreshId) {
            await loadFutures()
        }
        .onAppear {
            startSessionTimer()
        }
        .onDisappear {
            sessionTimer?.invalidate()
            sessionTimer = nil
        }
    }

    /// Updates the session badge every 30 seconds so transitions are reflected live
    private func startSessionTimer() {
        session = USMarketSession.current
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            let newSession = USMarketSession.current
            if newSession != session {
                withAnimation(.easeInOut(duration: 0.3)) {
                    session = newSession
                }
            }
        }
    }

    private func loadFutures() async {
        session = USMarketSession.current
        do {
            let result = try await withTimeout(seconds: 10) { [yahoo] in
                try await yahoo.fetchFutures()
            }
            futures = result
        } catch {
            logWarning("USFuturesSection: \(error.localizedDescription)", category: .network)
        }
        isLoading = false
    }
}

// MARK: - Futures Quote Row

private struct FuturesQuoteRow: View {
    let quote: USFuturesQuote
    @Environment(\.colorScheme) var colorScheme

    private var changeColor: Color {
        quote.isFlat ? AppColors.textSecondary : (quote.isPositive ? AppColors.success : AppColors.error)
    }

    private var abbreviation: String {
        switch quote.symbol {
        case "ES=F": return "ES"
        case "YM=F": return "YM"
        case "NQ=F": return "NQ"
        default: return String(quote.symbol.prefix(2))
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Ticker badge
            Text(abbreviation)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(AppColors.accent)
                .frame(width: 40, height: 40)
                .background(AppColors.accent.opacity(0.12))
                .cornerRadius(10)

            // Name + price
            VStack(alignment: .leading, spacing: 2) {
                Text(quote.shortName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                Text(formatPrice(quote.price))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Change info
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%+.2f%%", quote.changePercent))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(changeColor)
                Text(String(format: "%+.2f", quote.change))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(changeColor.opacity(0.8))
            }

            // Direction indicator
            Image(systemName: quote.isFlat ? "minus" : (quote.isPositive ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill"))
                .font(.system(size: 10))
                .foregroundColor(changeColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white)
        )
    }

    private func formatPrice(_ price: Double) -> String {
        if price >= 10000 {
            return String(format: "%.2f", price)
        }
        return String(format: "%.2f", price)
    }
}
