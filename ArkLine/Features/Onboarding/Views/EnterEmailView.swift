import SwiftUI

// MARK: - Enter Email View
struct EnterEmailView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isEmailFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            ScrollView {
                VStack(spacing: ArkSpacing.xxl) {
                    // Header
                    OnboardingHeader(
                        icon: "envelope.circle.fill",
                        title: "What's your email?",
                        subtitle: "We'll send you a verification code"
                    )

                    // Email Input
                    VStack(spacing: ArkSpacing.md) {
                        #if canImport(UIKit)
                        CustomTextField(
                            placeholder: "Email address",
                            text: $viewModel.email,
                            icon: "envelope.fill",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never,
                            errorMessage: viewModel.errorMessage
                        )
                        #else
                        CustomTextField(
                            placeholder: "Email address",
                            text: $viewModel.email,
                            icon: "envelope.fill",
                            errorMessage: viewModel.errorMessage
                        )
                        #endif
                    }
                    .padding(.horizontal, ArkSpacing.xl)

                    Spacer(minLength: ArkSpacing.xxxl)
                }
            }

            // Bottom actions
            OnboardingBottomActions(
                primaryTitle: "Continue",
                primaryAction: {
                    Task {
                        await viewModel.sendVerificationCode()
                    }
                },
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.isEmailValid,
                errorMessage: viewModel.errorMessage
            )
        }
        .onboardingBackButton { viewModel.previousStep() }
        .onAppear {
            isEmailFocused = true
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        EnterEmailView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
