import SwiftUI

struct SectionTitleSlideView: View {
    let data: SectionTitleSlideData
    let title: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.md) {
            Spacer()

            Rectangle()
                .fill(AppColors.accent)
                .frame(width: 40, height: 2)

            Text(title)
                .font(AppFonts.urbanistFont(size: 32, weight: .bold))
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if let subtitle = data.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .lineSpacing(4)
            }

            Spacer()
        }
    }
}
