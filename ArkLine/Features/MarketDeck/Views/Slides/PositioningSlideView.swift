import SwiftUI

struct PositioningSlideView: View {
    let data: PositioningSlideData
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            SlideHeader(title: title)

            // Distribution bars
            if !data.distribution.isEmpty {
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    ForEach(data.distribution) { cat in
                        distributionRow(cat)
                    }
                }
            }

            // Notable changes
            if !data.signalChanges.isEmpty {
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    Text("NOTABLE CHANGES")
                        .font(AppFonts.interFont(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(1.5)

                    ForEach(data.signalChanges) { change in
                        signalChangeRow(change)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func distributionRow(_ cat: CategoryDistribution) -> some View {
        let total = max(cat.bullish + cat.neutral + cat.bearish, 1)

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(cat.category.capitalized)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.7))

                Spacer()

                HStack(spacing: ArkSpacing.sm) {
                    miniLabel(count: cat.bullish, color: AppColors.success)
                    miniLabel(count: cat.neutral, color: AppColors.warning)
                    miniLabel(count: cat.bearish, color: AppColors.error)
                }
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    if cat.bullish > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.success)
                            .frame(width: geo.size.width * CGFloat(cat.bullish) / CGFloat(total))
                    }
                    if cat.neutral > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.warning.opacity(0.6))
                            .frame(width: geo.size.width * CGFloat(cat.neutral) / CGFloat(total))
                    }
                    if cat.bearish > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.error)
                            .frame(width: geo.size.width * CGFloat(cat.bearish) / CGFloat(total))
                    }
                }
            }
            .frame(height: 6)
        }
        .padding(ArkSpacing.md)
        .background(AppColors.textPrimary(colorScheme).opacity(0.06))
        .cornerRadius(ArkSpacing.Radius.md)
    }

    @ViewBuilder
    private func miniLabel(count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(AppFonts.interFont(size: 11, weight: .semibold))
            .foregroundColor(color)
    }

    @ViewBuilder
    private func signalChangeRow(_ change: SignalChangeEntry) -> some View {
        HStack(spacing: ArkSpacing.sm) {
            Text(change.asset)
                .font(AppFonts.body14Medium)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Spacer()

            // From
            Text(change.from)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            Image(systemName: "arrow.right")
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)

            // To (colored)
            Text(change.to)
                .font(AppFonts.caption12Medium)
                .foregroundColor(signalColor(change.to))
        }
        .padding(.vertical, ArkSpacing.xs)
        .padding(.horizontal, ArkSpacing.md)
        .background(AppColors.textPrimary(colorScheme).opacity(0.04))
        .cornerRadius(ArkSpacing.Radius.sm)
    }

    private func signalColor(_ signal: String) -> Color {
        switch signal.lowercased() {
        case "bullish": return AppColors.success
        case "bearish": return AppColors.error
        default: return AppColors.warning
        }
    }
}
