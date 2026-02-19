import SwiftUI

// MARK: - Onboarding Header
/// Reusable header component for onboarding screens
/// Uses design system tokens for colors, fonts, and spacing
struct OnboardingHeader: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var isOptional: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    var body: some View {
        VStack(spacing: ArkSpacing.sm) {
            // Icon with gradient
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.fillPrimary, AppColors.accentLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

            // Title
            Text(title)
                .font(AppFonts.title30)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.35).delay(0.2), value: appeared)

            // Subtitle (if provided)
            if let subtitle = subtitle {
                HStack(spacing: ArkSpacing.xxs) {
                    Text(subtitle)

                    if isOptional {
                        Text("(Optional)")
                            .foregroundColor(AppColors.textSecondary.opacity(0.7))
                    }
                }
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.35).delay(0.3), value: appeared)
            }
        }
        .padding(.top, ArkSpacing.xxxl)
        .onAppear { appeared = true }
    }
}

// MARK: - Step Indicator
/// Shows "Step X of Y" with category label
struct OnboardingStepIndicator: View {
    let step: OnboardingStep

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: ArkSpacing.xs) {
            // Category pill
            Text(step.category.rawValue)
                .font(AppFonts.caption12Medium)
                .foregroundColor(AppColors.fillPrimary)
                .padding(.horizontal, ArkSpacing.xs)
                .padding(.vertical, ArkSpacing.xxs)
                .background(AppColors.fillPrimary.opacity(0.15))
                .clipShape(Capsule())

            Spacer()

            // Step counter
            if step.stepNumber > 0 {
                Text("Step \(step.stepNumber) of \(OnboardingStep.totalSteps)")
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, ArkSpacing.xl)
        .padding(.top, ArkSpacing.sm)
    }
}

// MARK: - Onboarding Container
/// Wraps onboarding content with consistent layout and background
struct OnboardingContainer<Content: View>: View {
    let step: OnboardingStep
    let showStepIndicator: Bool
    @ViewBuilder let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        step: OnboardingStep,
        showStepIndicator: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.step = step
        self.showStepIndicator = showStepIndicator
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar (skip for gate steps)
            if step != .welcome && step != .inviteCode {
                OnboardingProgressBar(progress: step.progress)
            }

            // Step indicator
            if showStepIndicator && step != .welcome && step != .inviteCode {
                OnboardingStepIndicator(step: step)
            }

            // Content
            content()
        }
        .background(AppColors.background(colorScheme))
        .navigationBarBackButtonHidden()
    }
}

// MARK: - Onboarding Progress Bar
/// Progress bar with gradient fill - uses design system colors
struct OnboardingProgressBar: View {
    let progress: Double

    @Environment(\.colorScheme) private var colorScheme
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.divider(colorScheme))
                    .frame(height: 5)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.fillPrimary, AppColors.accentLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 5)
                    .overlay(
                        // Shimmer effect
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 60)
                        .offset(x: shimmerOffset * geometry.size.width * progress)
                        .clipShape(Capsule())
                    )
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.5)) {
                shimmerOffset = 1
            }
        }
    }
}

// MARK: - Onboarding Bottom Actions
/// Consistent bottom action bar with primary button and optional skip/secondary
struct OnboardingBottomActions: View {
    let primaryTitle: String
    let primaryAction: () -> Void
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var showSkip: Bool = false
    var skipAction: (() -> Void)? = nil
    var errorMessage: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    var body: some View {
        VStack(spacing: ArkSpacing.sm) {
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.error)
                    .transition(.opacity)
            }

            // Primary button
            PrimaryButton(
                title: primaryTitle,
                action: primaryAction,
                isLoading: isLoading,
                isDisabled: isDisabled
            )
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(.easeOut(duration: 0.35).delay(0.35), value: appeared)

            // Skip button
            if showSkip, let skipAction = skipAction {
                Button(action: skipAction) {
                    Text("Skip for now")
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.top, ArkSpacing.xxs)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(0.45), value: appeared)
            }
        }
        .padding(.horizontal, ArkSpacing.xl)
        .padding(.bottom, ArkSpacing.xxl)
        .onAppear { appeared = true }
    }
}

// MARK: - Back Button Modifier
struct OnboardingBackButton: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            #if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: action) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            #endif
    }
}

extension View {
    func onboardingBackButton(action: @escaping () -> Void) -> some View {
        modifier(OnboardingBackButton(action: action))
    }
}

// MARK: - Previews
#Preview("Header") {
    VStack {
        OnboardingHeader(
            icon: "envelope.circle.fill",
            title: "What's your email?",
            subtitle: "We'll send you a verification code"
        )

        Spacer()
    }
    .background(Color(hex: "0F0F0F"))
}

#Preview("Step Indicator") {
    VStack {
        OnboardingStepIndicator(step: .email)
        OnboardingStepIndicator(step: .careerIndustry)
        OnboardingStepIndicator(step: .faceIDSetup)
    }
    .background(Color(hex: "0F0F0F"))
}

#Preview("Progress Bar") {
    VStack(spacing: 20) {
        OnboardingProgressBar(progress: 0.25)
        OnboardingProgressBar(progress: 0.5)
        OnboardingProgressBar(progress: 0.75)
        OnboardingProgressBar(progress: 1.0)
    }
    .padding()
    .background(Color(hex: "0F0F0F"))
}
