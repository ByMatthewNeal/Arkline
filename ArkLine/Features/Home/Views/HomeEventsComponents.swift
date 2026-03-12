import SwiftUI

// MARK: - Upcoming Events Section
struct UpcomingEventsSection: View {
    let events: [EconomicEvent]
    var lastUpdated: Date?
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    /// Home screen: only show Today + Tomorrow
    private var homeEvents: [EconomicEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDateInToday(event.date) || calendar.isDateInTomorrow(event.date)
        }
    }

    private var groupedEvents: [(key: String, events: [EconomicEvent])] {
        let grouped = Dictionary(grouping: homeEvents) { $0.dateGroupKey }
        return grouped.sorted { first, second in
            guard let firstDate = first.value.first?.date,
                  let secondDate = second.value.first?.date else { return false }
            return firstDate < secondDate
        }.map { (key: $0.key, events: $0.value.sorted { ($0.time ?? Date()) < ($1.time ?? Date()) }) }
    }

    private var lastUpdatedText: String {
        guard let lastUpdated = lastUpdated else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastUpdated, relativeTo: Date()))"
    }

    private var maxGroups: Int {
        switch size {
        case .compact: return 1
        case .standard: return 3
        case .expanded: return 5
        }
    }

    private var maxEventsPerGroup: Int {
        switch size {
        case .compact: return 2
        case .standard: return 4
        case .expanded: return 6
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            HStack {
                Text("Upcoming Events")
                    .font(size == .compact ? .subheadline : .title3)
                    .foregroundColor(textPrimary)

                Spacer()

                if lastUpdated != nil && size != .compact {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.success)
                            .frame(width: 6, height: 6)
                        Text(lastUpdatedText)
                            .font(.system(size: 10))
                            .foregroundColor(textPrimary.opacity(0.5))
                    }
                }

                NavigationLink(destination: AllEventsView(events: events)) {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.accent)
                }
                .buttonStyle(PlainButtonStyle())
            }

            VStack(alignment: .leading, spacing: size == .compact ? 8 : 16) {
                if events.isEmpty {
                    HStack {
                        Spacer()
                        Text("No upcoming events")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    ForEach(groupedEvents.prefix(maxGroups), id: \.key) { group in
                        EventDateGroup(
                            dateKey: group.key,
                            events: Array(group.events.prefix(maxEventsPerGroup)),
                            isCompact: size == .compact
                        )
                    }
                }
            }
            .padding(size == .compact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: size == .compact ? 12 : 16)
                    .fill(cardBackground)
            )
            .arkShadow(ArkSpacing.Shadow.card)
        }
    }
}

// MARK: - Event Date Group
struct EventDateGroup: View {
    let dateKey: String
    let events: [EconomicEvent]
    var isCompact: Bool = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var isToday: Bool {
        guard let firstEvent = events.first else { return false }
        return Calendar.current.isDateInToday(firstEvent.date)
    }

    private var isTomorrow: Bool {
        guard let firstEvent = events.first else { return false }
        return Calendar.current.isDateInTomorrow(firstEvent.date)
    }

    private var displayDateKey: String {
        if isToday { return "Today" }
        else if isTomorrow { return "Tomorrow" }
        return dateKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
            HStack(spacing: 8) {
                Text(displayDateKey)
                    .font(.system(size: isCompact ? 11 : 13, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.5))
                    .textCase(.uppercase)

                if isToday {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, isCompact ? 2 : 4)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Events for \(displayDateKey)")
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(events) { event in
                    NavigationLink(destination: EventInfoView(event: event)) {
                        UpcomingEventRow(event: event, isCompact: isCompact)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    if event.id != events.last?.id {
                        Divider()
                            .background(textPrimary.opacity(0.1))
                    }
                }
            }
        }
    }
}

// MARK: - Upcoming Event Row
struct UpcomingEventRow: View {
    let event: EconomicEvent
    var isCompact: Bool = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        textPrimary.opacity(0.5)
    }

    private var flag: String {
        event.countryFlag ?? (event.currency == "USD" ? "🇺🇸" : event.currency == "JPY" ? "🇯🇵" : "🏳️")
    }

    private var timeString: String {
        guard let time = event.time else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: time).lowercased()
    }

    private var hasData: Bool {
        (event.actual?.isEmpty == false) ||
        (event.forecast?.isEmpty == false) ||
        (event.previous?.isEmpty == false)
    }

    private var beatMissValue: String? {
        if let bm = event.beatMiss, !bm.isEmpty { return bm }
        guard let a = event.actual, !a.isEmpty, let f = event.forecast, !f.isEmpty else { return nil }
        let cleanA = a.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "K", with: "").replacingOccurrences(of: "M", with: "")
        let cleanF = f.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "K", with: "").replacingOccurrences(of: "M", with: "")
        guard let av = Double(cleanA), let fv = Double(cleanF) else { return nil }
        if abs(av - fv) < 0.01 { return "inline" }
        return av > fv ? "beat" : "miss"
    }

    private var beatMissColor: Color {
        switch beatMissValue {
        case "beat": return AppColors.success
        case "miss": return AppColors.error
        default: return AppColors.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Impact bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.impact.color)
                .frame(width: 3, height: isCompact ? 28 : 36)
                .padding(.trailing, isCompact ? 6 : 8)

            // Title + time + data
            VStack(alignment: .leading, spacing: isCompact ? 1 : 2) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.system(size: isCompact ? 11 : 13, weight: .medium))
                        .foregroundColor(textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if let bm = beatMissValue, !isCompact {
                        Text(bm.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(beatMissColor))
                    }

                    if event.impact == .high {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(event.impact.color)
                    }
                }

                HStack(spacing: 6) {
                    if !timeString.isEmpty {
                        Text(timeString)
                            .font(.system(size: isCompact ? 9 : 10, weight: .medium, design: .monospaced))
                            .foregroundColor(textSecondary)
                    }

                    if !isCompact {
                        if let prev = event.previous, !prev.isEmpty {
                            dataBadge(label: "P", value: prev, highlight: false)
                        }
                        if let forecast = event.forecast, !forecast.isEmpty {
                            dataBadge(label: "F", value: forecast, highlight: false)
                        }
                        if let actual = event.actual, !actual.isEmpty {
                            dataBadge(label: "A", value: actual, highlight: true)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding(.vertical, isCompact ? 3 : 6)
    }

    @ViewBuilder
    private func dataBadge(label: String, value: String, highlight: Bool) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(textSecondary)
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(highlight ? beatMissColor : textPrimary.opacity(0.8))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(highlight
                    ? beatMissColor.opacity(0.12)
                    : textPrimary.opacity(0.05))
        )
    }
}

// MARK: - Event Data Pill
struct EventDataPill: View {
    let label: String
    let value: String
    let isActual: Bool
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.5))
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isActual ? AppColors.accent : textPrimary.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(colorScheme == .dark ? Color(hex: "2A2A2A") : Color(hex: "F0F0F0"))
        )
    }
}

// MARK: - Event Impact Tag
struct EventImpactTag: View {
    let impact: EventImpact

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(impact.color)
                .frame(width: 3, height: 14)
            Text(impact.displayName + " Impact")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(impact.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(impact.color.opacity(0.15))
        )
    }
}

// MARK: - Event Data Column
struct EventDataColumn: View {
    let label: String
    let value: String?
    let highlight: Bool
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(textPrimary.opacity(0.5))
            Text(value ?? "-")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(highlight && value != nil ? AppColors.accent : textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - All Events View
struct AllEventsView: View {
    let events: [EconomicEvent]
    @State private var allEvents: [EconomicEvent] = []
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var displayEvents: [EconomicEvent] {
        allEvents.isEmpty ? events : allEvents
    }

    private var groupedEvents: [(key: String, events: [EconomicEvent])] {
        let grouped = Dictionary(grouping: displayEvents) { $0.dateGroupKey }
        return grouped.sorted { first, second in
            guard let firstDate = first.value.first?.date,
                  let secondDate = second.value.first?.date else { return false }
            return firstDate < secondDate
        }.map { (key: $0.key, events: $0.value.sorted { ($0.time ?? Date()) < ($1.time ?? Date()) }) }
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(groupedEvents, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(group.key.uppercased())
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 20)

                            VStack(spacing: 0) {
                                ForEach(group.events) { event in
                                    NavigationLink(destination: EventInfoView(event: event)) {
                                        EventDetailRow(event: event)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    if event.id != group.events.last?.id {
                                        Divider()
                                            .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                                            .padding(.horizontal, 16)
                                    }
                                }
                            }
                            .background(cardBackground)
                            .cornerRadius(ArkSpacing.Radius.card)
                            .arkShadow(ArkSpacing.Shadow.card)
                            .padding(.horizontal, 20)
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Economic Calendar")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            // Load yesterday through 7 days out (includes past results)
            let calendar = Calendar.current
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date())) ?? Date()
            let weekOut = calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            let loaded = await EconomicEventsService.shared.fetchEvents(
                from: yesterday, to: weekOut, impactFilter: [.high, .medium]
            )
            if !loaded.isEmpty {
                allEvents = loaded
            }
        }
    }
}

// MARK: - Event Detail Row
struct EventDetailRow: View {
    let event: EconomicEvent
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        AppColors.textSecondary
    }

    private var timeString: String {
        guard let time = event.time else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: time).lowercased()
    }

    private var countryCode: String {
        event.country.uppercased()
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.impact.color)
                .frame(width: 3, height: 44)
                .padding(.trailing, 12)

            if !timeString.isEmpty {
                Text(timeString)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(textSecondary)
                    .frame(width: 60, alignment: .leading)
            }

            Text(countryCode)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(textPrimary.opacity(0.08))
                )
                .padding(.trailing, 10)

            Text(event.title)
                .font(.subheadline)
                .foregroundColor(textPrimary)
                .lineLimit(2)

            Spacer()

            HStack(spacing: 8) {
                if let prev = event.previous, !prev.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Prev")
                            .font(.system(size: 9))
                            .foregroundColor(textSecondary)
                        Text(prev)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary.opacity(0.7))
                    }
                }
                if let forecast = event.forecast, !forecast.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Fcst")
                            .font(.system(size: 9))
                            .foregroundColor(textSecondary)
                        Text(forecast)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textPrimary)
                    }
                }
                if let actual = event.actual, !actual.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Act")
                            .font(.system(size: 9))
                            .foregroundColor(textSecondary)
                        Text(actual)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Event Info View (Detail)
struct EventInfoView: View {
    let event: EconomicEvent
    @State private var enrichedEvent: EconomicEvent?
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var displayEvent: EconomicEvent {
        enrichedEvent ?? event
    }

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var timeString: String {
        guard let time = event.time else { return "TBD" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: event.date)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(event.impact.color)
                                    .frame(width: 3, height: 14)
                                Text(event.impact.rawValue.capitalized + " Impact")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(event.impact.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(event.impact.color.opacity(0.12))
                            .cornerRadius(6)

                            Text(event.country.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(textPrimary.opacity(0.06))
                                )

                            Spacer()
                        }

                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(textPrimary)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Date")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                Text(dateString)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(textPrimary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Time")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                Text(timeString)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(textPrimary)
                            }
                        }
                    }
                    .padding(20)
                    .background(cardBackground)
                    .cornerRadius(ArkSpacing.Radius.card)
                    .arkShadow(ArkSpacing.Shadow.card)
                    .padding(.horizontal, 20)

                    // Data Card
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Economic Data")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        HStack(spacing: 0) {
                            EventDataColumn(label: "Previous", value: displayEvent.previous, highlight: false)
                            Divider().frame(height: 50)
                            EventDataColumn(label: "Forecast", value: displayEvent.forecast, highlight: true)
                            Divider().frame(height: 50)
                            EventDataColumn(label: "Actual", value: displayEvent.actual, highlight: displayEvent.actual != nil)
                        }
                    }
                    .padding(20)
                    .background(cardBackground)
                    .cornerRadius(ArkSpacing.Radius.card)
                    .arkShadow(ArkSpacing.Shadow.card)
                    .padding(.horizontal, 20)

                    // Post-Release Analysis Card
                    if let actual = displayEvent.actual, !actual.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "chart.line.text.clipboard")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.accent)
                                Text("Market Analysis")
                                    .font(.headline)
                                    .foregroundColor(textPrimary)
                                Spacer()
                                beatMissBadge
                            }

                            if let analysis = displayEvent.claudeAnalysis, !analysis.isEmpty {
                                Text(markdownAttributed(analysis))
                                    .font(.subheadline)
                                    .foregroundColor(textPrimary.opacity(0.85))
                                    .lineSpacing(5)
                            } else {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Analysis generating...")
                                        .font(.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(20)
                        .background(cardBackground)
                        .cornerRadius(ArkSpacing.Radius.card)
                        .arkShadow(ArkSpacing.Shadow.card)
                        .padding(.horizontal, 20)
                    }

                    // Description Card
                    if let description = event.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About This Event")
                                .font(.headline)
                                .foregroundColor(textPrimary)

                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(cardBackground)
                        .cornerRadius(ArkSpacing.Radius.card)
                        .arkShadow(ArkSpacing.Shadow.card)
                        .padding(.horizontal, 20)
                    }

                    // Why It Matters Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why It Matters")
                            .font(.headline)
                            .foregroundColor(textPrimary)

                        Text(whyItMatters)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding(20)
                    .background(cardBackground)
                    .cornerRadius(ArkSpacing.Radius.card)
                    .arkShadow(ArkSpacing.Shadow.card)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("Event Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // Load enriched event (with analysis) from Supabase
            if let loaded = await EconomicEventsService.shared.fetchEventWithAnalysis(
                title: event.title, date: event.date
            ) {
                enrichedEvent = loaded
            }
        }
    }

    @ViewBuilder
    private var beatMissBadge: some View {
        let bm = displayEvent.beatMiss ?? computeBeatMiss()
        if !bm.isEmpty {
            Text(bm.capitalized)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(bm == "beat" ? AppColors.success : bm == "miss" ? AppColors.error : AppColors.textSecondary)
                )
        }
    }

    private func computeBeatMiss() -> String {
        guard let actualStr = displayEvent.actual, let forecastStr = displayEvent.forecast else { return "" }
        let cleanActual = actualStr.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "K", with: "").replacingOccurrences(of: "M", with: "")
        let cleanForecast = forecastStr.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "K", with: "").replacingOccurrences(of: "M", with: "")
        guard let a = Double(cleanActual), let f = Double(cleanForecast) else { return "" }
        if abs(a - f) < 0.01 { return "inline" }
        return a > f ? "beat" : "miss"
    }

    private func markdownAttributed(_ text: String) -> AttributedString {
        // Try native markdown parsing (handles **bold**, *italic*, etc.)
        if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return attributed
        }
        return AttributedString(text)
    }

    private var whyItMatters: String {
        let title = event.title.lowercased()

        if title.contains("cpi") || title.contains("inflation") {
            return "Consumer Price Index (CPI) measures inflation by tracking changes in prices paid by consumers. Higher than expected readings can signal rising inflation, potentially leading to interest rate hikes and impacting risk assets like crypto negatively in the short term."
        } else if title.contains("gdp") {
            return "Gross Domestic Product (GDP) measures the total value of goods and services produced. Strong GDP growth typically signals a healthy economy, which can be positive for risk assets. However, very strong growth may lead to inflation concerns."
        } else if title.contains("unemployment") || title.contains("employment") || title.contains("payroll") || title.contains("nfp") {
            return "Employment data is a key indicator of economic health. Strong job numbers suggest economic growth but may also signal potential inflation, which could lead to tighter monetary policy. Weak numbers may indicate economic slowdown."
        } else if title.contains("interest rate") || title.contains("policy rate") || title.contains("fed") || title.contains("fomc") {
            return "Central bank interest rate decisions directly impact liquidity and borrowing costs across the economy. Rate hikes typically strengthen the local currency and can pressure risk assets, while rate cuts often boost risk appetite."
        } else if title.contains("pce") {
            return "Personal Consumption Expenditures (PCE) is the Federal Reserve's preferred inflation measure. It influences monetary policy decisions and can significantly impact market expectations for interest rates."
        } else if title.contains("trade balance") {
            return "Trade balance measures the difference between a country's exports and imports. A surplus can strengthen the currency, while a deficit may weaken it. Large imbalances can affect currency valuations and international capital flows."
        } else if title.contains("pmi") || title.contains("manufacturing") {
            return "Purchasing Managers' Index (PMI) is a leading indicator of economic health. Readings above 50 indicate expansion, while below 50 signals contraction. It often moves markets as it provides early insight into economic trends."
        } else {
            return "Economic events can significantly impact financial markets by influencing investor sentiment, currency valuations, and monetary policy expectations. High-impact events often lead to increased volatility."
        }
    }
}
