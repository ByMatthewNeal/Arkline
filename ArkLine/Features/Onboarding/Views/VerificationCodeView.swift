import SwiftUI
import Combine

// MARK: - Verification Code View
struct VerificationCodeView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            ScrollView {
                VStack(spacing: ArkSpacing.xxl) {
                    // Header
                    OnboardingHeader(
                        icon: "number.circle.fill",
                        title: "Enter verification code",
                        subtitle: "We sent a code to \(viewModel.email)"
                    )

                    // Code Input via keypad
                    PasscodeKeypad(
                        code: $viewModel.verificationCode,
                        length: 8,
                        title: ""
                    )
                    .padding(.horizontal, ArkSpacing.xl)

                    // Resend link
                    Button(action: {
                        Task {
                            await viewModel.sendVerificationCode()
                        }
                    }) {
                        Text("Didn't receive code? Resend")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.fillPrimary)
                    }

                    Spacer(minLength: ArkSpacing.xxxl)
                }
            }

            // Bottom actions
            OnboardingBottomActions(
                primaryTitle: "Verify",
                primaryAction: {
                    Task {
                        await viewModel.verifyCode()
                    }
                },
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.isVerificationCodeValid,
                errorMessage: viewModel.errorMessage
            )
        }
        .onboardingBackButton { viewModel.previousStep() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("DeepLinkAuthSuccess"))) { _ in
            // Auth succeeded via magic link, advance to next step
            viewModel.nextStep()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        VerificationCodeView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
