import SwiftUI

struct WeeklyOutlookSlideView: View {
    let data: WeeklyOutlookSlideData
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            SlideHeader(title: title)

            // Headline
            Text(data.headline)
                .font(AppFonts.interFont(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Tone badge
            HStack(spacing: ArkSpacing.xs) {
                Circle()
                    .fill(toneColor)
                    .frame(width: 8, height: 8)
                Text(data.tone.capitalized)
                    .font(AppFonts.interFont(size: 11, weight: .semibold))
                    .foregroundColor(toneColor)
            }
            .padding(.horizontal, ArkSpacing.sm)
            .padding(.vertical, ArkSpacing.xxs)
            .background(Capsule().fill(toneColor.opacity(0.12)))

            // Risk asset impact
            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                Text("IMPACT ON RISK ASSETS")
                    .font(AppFonts.interFont(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.accent.opacity(0.6))
                    .tracking(1.5)

                Text(data.riskAssetImpact)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.85))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(ArkSpacing.md)
            .background(AppColors.textPrimary(colorScheme).opacity(0.04))
            .cornerRadius(ArkSpacing.Radius.md)

            // Look ahead
            if !data.lookAhead.isEmpty {
                VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                    Text("WHAT TO WATCH")
                        .font(AppFonts.interFont(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.accent.opacity(0.6))
                        .tracking(1.5)

                    ForEach(Array(data.lookAhead.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: ArkSpacing.sm) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.accent.opacity(0.5))
                                .padding(.top, 2)

                            Text(item)
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.8))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var toneColor: Color {
        switch data.tone.lowercased() {
        case "bullish": return AppColors.success
        case "bearish": return AppColors.error
        case "cautious": return AppColors.warning
        default: return AppColors.textSecondary
        }
    }
}
