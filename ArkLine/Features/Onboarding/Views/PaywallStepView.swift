import SwiftUI

// MARK: - Paywall Step
//
// Onboarding gate that runs AFTER the account exists (email + verification), so
// the user is authenticated and RevenueCat is linked to their Supabase UUID
// before any purchase — the fix for anonymous IAP purchases being dropped by the
// webhook.
//
// Behavior on appear:
//   1. Ensure RevenueCat is logged in as this Supabase user (sets appUserID = UUID).
//   2. If they already have access (a comp, a prior web/Stripe purchase, or a
//      restorable Apple purchase), skip straight through.
//   3. Otherwise present the paywall. A completed purchase attributes to the UUID,
//      so the revenuecat-webhook writes their source='apple' subscription row.

struct PaywallStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var isChecking = true
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            MeshGradientBackground().ignoresSafeArea()

            if isChecking {
                ProgressView()
                    .controlSize(.large)
            } else {
                // Shown if the user dismissed the paywall without buying — they
                // can reopen it or go back. They cannot proceed without access.
                VStack(spacing: ArkSpacing.lg) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundColor(AppColors.accent)

                    VStack(spacing: ArkSpacing.xs) {
                        Text("Unlock Arkline Pro")
                            .font(AppFonts.title24)
                            .foregroundColor(AppColors.textPrimary(colorScheme))
                        Text("Full access to every signal, briefing, and macro read. Start with a 7-day free trial. Cancel anytime.")
                            .font(AppFonts.body14)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, ArkSpacing.xl)

                    PrimaryButton(
                        title: "See Plans",
                        action: { showPaywall = true },
                        icon: "sparkles"
                    )
                    .padding(.horizontal, ArkSpacing.xl)

                    // Back returns to WELCOME, not the previous step — the previous
                    // step is the verification screen whose code is already used,
                    // a dead end. Welcome offers the real choices (try again / sign in).
                    Button("Back") {
                        viewModel.isMovingForward = false
                        viewModel.currentStep = .welcome
                    }
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .navigationBarBackButtonHidden()
        .task { await evaluateAccess() }
        .sheet(isPresented: $showPaywall) {
            ArkPaywallSheet { outcome in
                showPaywall = false
                switch outcome {
                case .purchased, .restored:
                    // Purchase attributed to the UUID; the webhook writes the
                    // subscription row. Continue onboarding.
                    viewModel.nextStep()
                case .dismissed:
                    // Stay on this step — access is required to proceed.
                    break
                }
            }
        }
    }

    private func evaluateAccess() async {
        defer { isChecking = false }

        // Right after OTP verification the cached auth state may not have
        // propagated yet — this step's task can run before the listener fires.
        // Fetch the session itself (async, authoritative) so a subscribed
        // returning user isn't shown the paywall because of a race.
        var resolvedUserId = SupabaseAuthManager.shared.currentUserId
        if resolvedUserId == nil {
            resolvedUserId = try? await SupabaseManager.shared.client.auth.session.user.id
        }
        guard let userId = resolvedUserId else {
            // Truly no session — show the paywall (they can go Back to sign in).
            showPaywall = true
            return
        }

        // Link RevenueCat to this user before any purchase so IAP attributes to
        // the Supabase UUID (removes the auth→logIn race).
        await RevenueCatService.shared.logIn(userId: userId)

        if await viewModel.hasActiveAccess(userId: userId) {
            viewModel.nextStep()   // already comped / subscribed — skip the paywall
        } else {
            showPaywall = true
        }
    }
}
