import SwiftUI

// MARK: - Subscription Expired View
/// Full-screen lockout shown when a user's subscription has ended.
/// Blocks all app access. User can renew via web or sign out.
struct SubscriptionExpiredView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var isSigningOut = false

    var body: some View {
        ZStack {
            MeshGradientBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: ArkSpacing.xl) {
                Spacer()

                // Lock icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundColor(AppColors.textSecondary.opacity(0.5))

                // Headline
                Text("Your ArkLine membership has ended")
                    .font(AppFonts.title24)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .multilineTextAlignment(.center)

                // Body
                Text("Renew to continue receiving signals, briefings, and portfolio insights. Your data is safe — when you re-subscribe, everything will be right where you left it.")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ArkSpacing.xl)

                Spacer()

                // Actions
                VStack(spacing: ArkSpacing.md) {
                    // Primary: Renew
                    Button {
                        if let url = URL(string: "https://arkline.io/renew") {
                            #if canImport(UIKit)
                            UIApplication.shared.open(url)
                            #endif
                        }
                    } label: {
                        Text("Renew Subscription")
                            .font(AppFonts.body14Bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppColors.accent)
                            .cornerRadius(ArkSpacing.Radius.md)
                    }

                    // Secondary: Sign Out
                    Button {
                        isSigningOut = true
                        Task {
                            appState.signOut()
                            isSigningOut = false
                        }
                    } label: {
                        Text("Sign Out")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .disabled(isSigningOut)

                    // Tertiary: Support
                    Button {
                        if let url = URL(string: "mailto:support@arkline.io") {
                            #if canImport(UIKit)
                            UIApplication.shared.open(url)
                            #endif
                        }
                    } label: {
                        Text("Need help? Contact support@arkline.io")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.bottom, ArkSpacing.xxl)
            }
        }
        .onAppear {
            Haptics.warning()
        }
    }
}

#Preview {
    SubscriptionExpiredView()
        .environmentObject(AppState())
}
