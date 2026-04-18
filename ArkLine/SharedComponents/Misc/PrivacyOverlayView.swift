import SwiftUI

struct PrivacyOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AppColors.background(colorScheme)
                .ignoresSafeArea()

            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.surface(colorScheme),
                    AppColors.background(colorScheme)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: ArkSpacing.xl) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    AppColors.fillPrimary.opacity(0.3),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 20,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)

                    Image("LaunchIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                }

                VStack(spacing: ArkSpacing.md) {
                    Text("ArkLine")
                        .font(AppFonts.title32)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    VStack(spacing: 4) {
                        Text("Everyone sees the price.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)

                        Text("Few see the shift.")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
        }
    }
}
