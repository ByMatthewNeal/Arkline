import SwiftUI

// MARK: - Welcome View
/// Intro carousel that showcases ArkLine's key features before registration
struct WelcomeView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentPage = 0

    private let slides: [WelcomeSlide] = [
        WelcomeSlide(
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Your Portfolio",
            description: "Monitor all your crypto investments in one place with real-time price updates and performance analytics.",
            accentColor: AppColors.fillPrimary
        ),
        WelcomeSlide(
            icon: "brain.head.profile",
            title: "AI-Powered Insights",
            description: "Get personalized market analysis and investment suggestions powered by advanced AI technology.",
            accentColor: AppColors.success
        ),
        WelcomeSlide(
            icon: "person.3.fill",
            title: "Join the Community",
            description: "Connect with fellow investors, share strategies, and learn from the best in the crypto space.",
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
                        title: "Get Started",
                        action: { viewModel.nextStep() },
                        icon: "arrow.right"
                    )

                    Button(action: { viewModel.nextStep() }) {
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
    }
}

// MARK: - Welcome Slide Model
struct WelcomeSlide {
    let icon: String
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
