import SwiftUI

struct EconomicSlideView: View {
    let data: EconomicSlideData
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            SlideHeader(title: title)

            if !data.thisWeek.isEmpty {
                eventSection(label: "THIS WEEK", events: data.thisWeek, showResults: true)
            }

            if !data.nextWeek.isEmpty {
                eventSection(label: "NEXT WEEK", events: data.nextWeek, showResults: false)
            }
        }
    }

    @ViewBuilder
    private func eventSection(label: String, events: [EconomicEventEntry], showResults: Bool) -> some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            Text(label)
                .font(AppFonts.interFont(size: 11, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1.5)

            ForEach(events) { event in
                eventRow(event, showResults: showResults)
            }
        }
    }

    @ViewBuilder
    private func eventRow(_ event: EconomicEventEntry, showResults: Bool) -> some View {
        HStack(alignment: .top, spacing: ArkSpacing.sm) {
            Circle()
                .fill(impactColor(event.impact))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.85))

                Text(event.date)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            if showResults {
                VStack(alignment: .trailing, spacing: 2) {
                    if let actual = event.actual {
                        Text(actual)
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                    }
                    if let forecast = event.forecast {
                        Text("F: \(forecast)")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                if let beat = event.beat {
                    Text(beat ? "BEAT" : "MISS")
                        .font(AppFonts.interFont(size: 10, weight: .semibold))
                        .foregroundColor(beat ? AppColors.success : AppColors.error)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(
                                (beat ? AppColors.success : AppColors.error).opacity(0.15)
                            )
                        )
                }
            } else {
                if let forecast = event.forecast {
                    Text("F: \(forecast)")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(ArkSpacing.sm)
        .background(AppColors.textPrimary(colorScheme).opacity(0.04))
        .cornerRadius(ArkSpacing.Radius.sm)
    }

    private func impactColor(_ impact: String) -> Color {
        switch impact.lowercased() {
        case "high": return AppColors.error
        case "medium": return AppColors.warning
        default: return AppColors.textSecondary.opacity(0.3)
        }
    }
}
