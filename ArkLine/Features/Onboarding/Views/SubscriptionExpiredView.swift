import SwiftUI

// MARK: - Subscription Expired View
/// Full-screen lockout shown when a user's subscription has ended.
/// Blocks all app access. User can re-subscribe via IAP or sign out.
///
/// ANTI-STEERING NOTE: This view previously opened https://arkline.io/renew
/// in a browser to direct users to Stripe checkout. That was a 3.1.3
/// violation. The renew button now presents the in-app IAP paywall.
struct SubscriptionExpiredView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var isSigningOut = false
    @State private var showPaywall = false

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
                Text("Re-subscribe to continue receiving signals, briefings, and portfolio insights. Your data is safe — when you re-subscribe, everything will be right where you left it.")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ArkSpacing.xl)

                Spacer()

                // Actions
                VStack(spacing: ArkSpacing.md) {
                    // Primary: Re-subscribe via IAP
                    Button {
                        Haptics.selection()
                        showPaywall = true
                    } label: {
                        Text("Re-subscribe")
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
        .sheet(isPresented: $showPaywall) {
            ArkPaywallSheet { outcome in
                showPaywall = false
                switch outcome {
                case .purchased, .restored:
                    // Refresh the user profile so the gate re-evaluates.
                    // The Supabase profile may take a beat to update via
                    // the RevenueCat webhook; AppState polling handles that.
                    Task {
                        await appState.refreshUserProfile()
                    }
                case .dismissed:
                    break
                }
            }
        }
    }
}

#Preview {
    SubscriptionExpiredView()
        .environmentObject(AppState())
}
