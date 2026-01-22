import SwiftUI

struct TodaysEventsWidget: View {
    let events: [EconomicEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Events")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                NavigationLink(destination: EconomicCalendarView()) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(Color(hex: "6366F1"))
                }
            }

            VStack(spacing: 8) {
                ForEach(events) { event in
                    EventRowView(event: event)
                }
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Placeholder Economic Calendar View
struct EconomicCalendarView: View {
    var body: some View {
        Text("Economic Calendar")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "0F0F0F"))
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
                forecast: nil,
                previous: nil,
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
        ]
    )
    .padding()
    .background(Color(hex: "0F0F0F"))
}
