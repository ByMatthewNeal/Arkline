import SwiftUI

struct TodaysEventsWidget: View {
    let events: [EconomicEvent]
    var size: WidgetSize = .standard
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white
    }

    private var groupedEvents: [(key: String, events: [EconomicEvent])] {
        let grouped = Dictionary(grouping: events) { $0.dateGroupKey }
        return grouped.sorted { first, second in
            guard let firstDate = first.value.first?.date,
                  let secondDate = second.value.first?.date else { return false }
            return firstDate < secondDate
        }.map { (key: $0.key, events: $0.value.sorted { $0.date < $1.date }) }
    }

    private var maxGroups: Int {
        switch size {
        case .compact: return 1
        case .standard: return 2
        case .expanded: return 4
        }
    }

    private var maxEventsPerGroup: Int {
        switch size {
        case .compact: return 2
        case .standard: return 3
        case .expanded: return 5
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Upcoming Events")
                    .font(size == .compact ? .subheadline : .headline)
                    .foregroundColor(textPrimary)

                Spacer()

                NavigationLink(destination: AllEventsView(events: events)) {
                    HStack(spacing: 4) {
                        Text("See all")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.accent)
                }
            }

            // Events grouped by date
            VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
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
                        EventDateGroupView(
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
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Event Date Group View
struct EventDateGroupView: View {
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
            // Date header
            HStack(spacing: 8) {
                Text(displayDateKey.uppercased())
                    .font(.system(size: isCompact ? 10 : 11, weight: .semibold))
                    .foregroundColor(textPrimary.opacity(0.5))
                    .tracking(0.5)

                if isToday {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, isCompact ? 2 : 4)

            // Events list
            VStack(spacing: 0) {
                ForEach(events) { event in
                    EventRowView(event: event, isCompact: isCompact)

                    if event.id != events.last?.id {
                        Divider()
                            .background(textPrimary.opacity(0.1))
                    }
                }
            }
        }
    }
}

// MARK: - Placeholder Economic Calendar View
struct EconomicCalendarView: View {
    var events: [EconomicEvent] = []

    var body: some View {
        AllEventsView(events: events)
    }
}

#Preview {
    TodaysEventsWidget(
        events: [
            EconomicEvent(
                id: UUID(),
                title: "FOMC Meeting Minutes",
                country: "US",
                date: Date(),
                time: nil,
                impact: .high,
                forecast: "5.25%",
                previous: "5.00%",
                actual: nil,
                currency: "USD",
                description: "Federal Open Market Committee meeting minutes release",
                countryFlag: "🇺🇸"
            ),
            EconomicEvent(
                id: UUID(),
                title: "Initial Jobless Claims",
                country: "US",
                date: Date(),
                time: nil,
                impact: .medium,
                forecast: "210K",
                previous: "215K",
                actual: nil,
                currency: "USD",
                description: "Weekly unemployment claims",
                countryFlag: "🇺🇸"
            )
        ],
        size: .standard
    )
    .padding()
    .background(Color(hex: "0F0F0F"))
    .environmentObject(AppState())
}
