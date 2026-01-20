import SwiftUI

struct EventRowView: View {
    let event: EconomicEvent

    var body: some View {
        HStack(spacing: 12) {
            // Impact Indicator
            VStack(spacing: 4) {
                Circle()
                    .fill(event.impact.color)
                    .frame(width: 8, height: 8)

                Rectangle()
                    .fill(Color(hex: "2A2A2A"))
                    .frame(width: 2, height: 24)
            }

            // Event Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(event.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(Color(hex: "A1A1AA"))
                }

                HStack(spacing: 8) {
                    // Country
                    Text(event.country)
                        .font(.caption2)
                        .foregroundColor(Color(hex: "A1A1AA"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "2A2A2A"))
                        .cornerRadius(4)

                    // Impact text
                    Text(event.impact.displayName)
                        .font(.caption2)
                        .foregroundColor(Color(hex: "A1A1AA"))

                    Spacer()

                    // Impact Badge
                    ImpactBadge(impact: event.impact)
                }
            }
        }
        .padding(12)
        .background(Color(hex: "2A2A2A"))
        .cornerRadius(12)
    }
}

// MARK: - Impact Badge
struct ImpactBadge: View {
    let impact: EventImpact

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < impact.level ? impact.color : Color(hex: "3A3A3A"))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Event Impact Extension
extension EventImpact {
    var level: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    var color: Color {
        switch self {
        case .low: return Color(hex: "22C55E")
        case .medium: return Color(hex: "EAB308")
        case .high: return Color(hex: "EF4444")
        }
    }
}

// MARK: - Compact Event Row
struct CompactEventRow: View {
    let title: String
    let time: Date
    let impact: EventImpact

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(impact.color)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            Text(time.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundColor(Color(hex: "A1A1AA"))
        }
    }
}

#Preview {
    VStack {
        EventRowView(
            event: EconomicEvent(
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
                description: "Federal Open Market Committee meeting minutes release"
            )
        )

        CompactEventRow(
            title: "Initial Jobless Claims",
            time: Date(),
            impact: .medium
        )
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
