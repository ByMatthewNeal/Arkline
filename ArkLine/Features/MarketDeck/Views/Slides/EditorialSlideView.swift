import SwiftUI

struct EditorialSlideView: View {
    let data: EditorialSlideData
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.lg) {
            // Header
            VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                if let category = data.category, !category.isEmpty {
                    Text(category.uppercased())
                        .font(AppFonts.interFont(size: 11, weight: .semibold))
                        .foregroundColor(categoryColor.opacity(0.7))
                        .tracking(1.5)
                }

                Text(title)
                    .font(AppFonts.urbanistFont(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Rectangle()
                    .fill(categoryColor.opacity(0.3))
                    .frame(height: 1)
            }

            // Bullet points
            VStack(alignment: .leading, spacing: ArkSpacing.sm) {
                ForEach(data.bullets) { bullet in
                    HStack(alignment: .top, spacing: ArkSpacing.sm) {
                        Rectangle()
                            .fill(categoryColor.opacity(0.5))
                            .frame(width: 2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(bullet.text)
                                .font(AppFonts.body14)
                                .foregroundColor(AppColors.textPrimary(colorScheme).opacity(0.85))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)

                            if let detail = bullet.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(AppFonts.caption12)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, ArkSpacing.xs)
                    .padding(.horizontal, ArkSpacing.sm)
                    .background(AppColors.textPrimary(colorScheme).opacity(0.03))
                    .cornerRadius(ArkSpacing.Radius.sm)
                }
            }
        }
    }

    private var categoryColor: Color {
        switch data.category?.lowercased() {
        case "fed", "fomc": return Color(hex: "60A5FA")
        case "inflation", "economic": return Color(hex: "FBBF24")
        case "geopolitics", "trade": return Color(hex: "F87171")
        case "liquidity", "macro": return Color(hex: "A78BFA")
        case "crypto", "bitcoin": return Color(hex: "34D399")
        case "central banks", "boj", "ecb": return Color(hex: "FB923C")
        default: return AppColors.accent
        }
    }
}
