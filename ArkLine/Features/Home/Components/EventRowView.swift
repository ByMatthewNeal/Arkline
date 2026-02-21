import SwiftUI

struct EventRowView: View {
    let event: EconomicEvent
    var isCompact: Bool = false
    var showDate: Bool = false
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color {
        AppColors.textPrimary(colorScheme)
    }

    private var textSecondary: Color {
        textPrimary.opacity(0.5)
    }

    private var hasDataValues: Bool {
        event.actual != nil || event.forecast != nil || event.previous != nil
    }

    private var countryCode: String {
        event.country.uppercased()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Vertical impact indicator bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(event.impact.color)
                .frame(width: 3, height: isCompact ? 32 : 44)
                .padding(.trailing, isCompact ? 8 : 12)

            VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                HStack(spacing: isCompact ? 6 : 10) {
                    // Country code badge
                    Text(countryCode)
                        .font(.system(size: isCompact ? 9 : 10, weight: .semibold))
                        .foregroundColor(textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(textPrimary.opacity(0.08))
                        )

                    // Event title
                    Text(event.title)
                        .font(.system(size: isCompact ? 11 : 13, weight: .medium))
                        .foregroundColor(textPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Time on the right
                    Text(event.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: isCompact ? 10 : 11, weight: .medium, design: .monospaced))
                        .foregroundColor(textSecondary)
                }

                // Data values row (forecast, previous, actual)
                if hasDataValues && !isCompact {
                    HStack(spacing: 12) {
                        if let actual = event.actual, !actual.isEmpty {
                            EventDataBadge(label: "Act", value: actual, isActual: true)
                        }
                        if let forecast = event.forecast, !forecast.isEmpty {
                            EventDataBadge(label: "Fcst", value: forecast, isActual: false)
                        }
                        if let previous = event.previous, !previous.isEmpty {
                            EventDataBadge(label: "Prev", value: previous, isActual: false)
                        }

                        Spacer()
                    }
                }

                // Show date if requested
                if showDate {
                    Text(event.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundColor(textSecondary)
                }
            }
        }
        .padding(.vertical, isCompact ? 4 : 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.title), \(event.date.formatted(date: .omitted, time: .shortened)), \(event.impact.rawValue) impact\(event.actual.map { ", actual \($0)" } ?? "")\(event.forecast.map { ", forecast \($0)" } ?? "")")
    }
}

// MARK: - Event Data Badge
struct EventDataBadge: View {
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(impact.rawValue) impact")
        .accessibilityAddTraits(.isImage)
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
                description: "Federal Open Market Committee meeting minutes release",
                countryFlag: "🇺🇸"
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
