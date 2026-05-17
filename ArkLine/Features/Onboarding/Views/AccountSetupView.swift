import SwiftUI

/// Full-screen loading gate shown while waiting for Stripe webhook to confirm
/// a new user's subscription. Polls refreshUserProfile every 3 seconds; after
/// ~2 minutes switches to a recovery view with support contact options.
struct AccountSetupView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @State private var attemptCount: Int = 0
    @State private var hasTimedOut: Bool = false

    private let pollInterval: Duration = .seconds(3)
    private let maxAttempts: Int = 40 // ~2 minutes

    var body: some View {
        ZStack {
            MeshGradientBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if hasTimedOut {
                recoveryView
            } else {
                loadingView
            }
        }
        .task(id: hasTimedOut) {
            guard !hasTimedOut else { return }
            await pollUntilResolved()
        }
    }

    // MARK: - Polling

    private func pollUntilResolved() async {
        await appState.refreshUserProfile()

        while attemptCount < maxAttempts && !Task.isCancelled {
            try? await Task.sleep(for: pollInterval)
            attemptCount += 1
            await appState.refreshUserProfile()
        }

        if !Task.isCancelled {
            hasTimedOut = true
            Haptics.warning()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: ArkSpacing.xl) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.accent)

            Text("Setting up your account\u{2026}")
                .font(AppFonts.title24)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .multilineTextAlignment(.center)

            Text("This usually takes a few seconds. We\u{2019}re confirming your payment with Stripe.")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ArkSpacing.xl)

            Spacer()

            Button {
                openMailto()
            } label: {
                Text("Having trouble? Contact support@arkline.io")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.bottom, ArkSpacing.xxl)
        }
        .onAppear { Haptics.light() }
    }

    // MARK: - Recovery View

    private var recoveryView: some View {
        VStack(spacing: ArkSpacing.xl) {
            Spacer()

            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 48))
                .foregroundColor(AppColors.warning)

            Text("We\u{2019}re having trouble setting up your account")
                .font(AppFonts.title24)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, ArkSpacing.lg)

            Text("Don\u{2019}t worry \u{2014} your payment went through. Email support@arkline.io and we\u{2019}ll get you in within a few hours.")
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ArkSpacing.xl)

            Spacer()

            VStack(spacing: ArkSpacing.md) {
                // Primary: Email support
                Button { openMailto() } label: {
                    Text("Email Support")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.accent)
                        .cornerRadius(ArkSpacing.Radius.md)
                }

                // Secondary: Try again
                Button {
                    attemptCount = 0
                    hasTimedOut = false
                } label: {
                    Text("Try Again")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }

                // Tertiary: Sign out
                Button {
                    appState.signOut()
                } label: {
                    Text("Sign Out")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, ArkSpacing.xl)
            .padding(.bottom, ArkSpacing.xxl)
        }
    }

    // MARK: - Helpers

    private func openMailto() {
        let email = appState.currentUser?.email ?? ""
        let subject = "Account setup help — \(email)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "Hi Arkline team, my account isn't activating. My signup email is \(email). Thanks.".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:support@arkline.io?subject=\(subject)&body=\(body)") {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        }
    }
}
