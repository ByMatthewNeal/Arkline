import SwiftUI

struct PremiumFeatureGate<Content: View>: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    let feature: PremiumFeature
    @ViewBuilder let content: () -> Content
    @State private var showPaywall = false

    var body: some View {
        if appState.isPro {
            content()
        } else {
            lockedView
                .sheet(isPresented: $showPaywall) {
                    PaywallView(feature: feature)
                }
        }
    }

    private var lockedView: some View {
        VStack(spacing: ArkSpacing.lg) {
            Spacer()

            Image(systemName: feature.icon)
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.accentLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(feature.title)
                .font(AppFonts.title18Bold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            Text(feature.description)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ArkSpacing.xxl)

            Button(action: { showPaywall = true }) {
                HStack(spacing: ArkSpacing.xs) {
                    Image(systemName: "crown.fill")
                    Text("Unlock with Pro")
                }
                .font(AppFonts.body14Bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.sm)
                .background(
                    LinearGradient(
                        colors: [AppColors.accent, AppColors.accentDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(ArkSpacing.Radius.sm)
            }
            .padding(.horizontal, ArkSpacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background(colorScheme))
    }
}
