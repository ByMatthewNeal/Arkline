import SwiftUI

// MARK: - Welcome View
/// Intro carousel that showcases ArkLine's key features before registration
struct WelcomeView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPage = 0
    @State private var showPaywall = false

    private let slides: [WelcomeSlide] = [
        WelcomeSlide(
            icon: "shield.checkered",
            assetImage: "ArkLineLogo",
            title: "Invest with Confidence",
            description: "Real-time risk scoring, macro indicators, and daily intel — so you always know when to act, hold, or wait.",
            accentColor: AppColors.fillPrimary
        ),
        WelcomeSlide(
            icon: "bell.badge.fill",
            title: "Always On, Always Informed",
            description: "Live broadcasts, DCA reminders, and market alerts — so you never miss a move.",
            accentColor: AppColors.success
        ),
        WelcomeSlide(
            icon: "sparkles",
            title: "Intel That Keeps Up",
            description: "Risk models that recalibrate as markets move — so your read is never a day behind.",
            accentColor: AppColors.info
        )
    ]

    var body: some View {
        ZStack {
            // Animated mesh background
            MeshGradientBackground()

            VStack(spacing: 0) {
                Spacer()

                // Carousel
                TabView(selection: $currentPage) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        WelcomeSlideView(slide: slide, colorScheme: colorScheme)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 400)

                // Page indicator
                HStack(spacing: ArkSpacing.xs) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? AppColors.fillPrimary : AppColors.divider(colorScheme))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.top, ArkSpacing.xl)

                Spacer()

                // Bottom buttons
                VStack(spacing: ArkSpacing.sm) {
                    PrimaryButton(
                        title: "Get Arkline Pro",
                        action: { showPaywall = true },
                        icon: "sparkles"
                    )

                    Button(action: { viewModel.skipToLogin() }) {
                        Text("I already have an account")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, ArkSpacing.xs)
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.bottom, ArkSpacing.xxl)
            }
        }
        .navigationBarBackButtonHidden()
        .sheet(isPresented: $showPaywall) {
            ArkPaywallSheet { outcome in
                // Always dismiss the sheet first.
                showPaywall = false

                switch outcome {
                case .purchased, .restored:
                    // TODO (Phase 3 follow-up): route to account-creation flow
                    // so the new IAP customer can set up email + password and
                    // we can link the apple_original_transaction_id to a
                    // Supabase user. For now, just continue through the
                    // existing onboarding (which still goes through invite
                    // code — that step needs to be conditionalized for IAP
                    // users in the next iteration).
                    viewModel.nextStep()
                case .dismissed:
                    // User backed out without buying. Stay on the welcome
                    // screen; they can try again or sign in instead.
                    break
                }
            }
        }
    }
}

// MARK: - Welcome Slide Model
struct WelcomeSlide {
    let icon: String
    var assetImage: String? = nil
    let title: String
    let description: String
    let accentColor: Color
}

// MARK: - Welcome Slide View
struct WelcomeSlideView: View {
    let slide: WelcomeSlide
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: ArkSpacing.xl) {
            // Icon with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                slide.accentColor.opacity(0.4),
                                slide.accentColor.opacity(0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                // Icon container
                ZStack {
                    Circle()
                        .fill(AppColors.glassBackground(colorScheme))
                        .frame(width: 120, height: 120)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 120, height: 120)

                    if let assetImage = slide.assetImage {
                        Image(assetImage)
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [slide.accentColor, slide.accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        Image(systemName: slide.icon)
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [slide.accentColor, slide.accentColor.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }

            // Text content
            VStack(spacing: ArkSpacing.sm) {
                Text(slide.title)
                    .font(AppFonts.title30)
                    .foregroundColor(AppColors.textPrimary(colorScheme))
                    .multilineTextAlignment(.center)

                Text(slide.description)
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, ArkSpacing.xl)
            }
        }
        .padding(.horizontal, ArkSpacing.md)
    }
}

// MARK: - Preview
#Preview {
    WelcomeView(viewModel: OnboardingViewModel())
        .preferredColorScheme(.dark)
}
