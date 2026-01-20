import SwiftUI

// MARK: - Enter Email View
struct EnterEmailView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isEmailFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Progress
            OnboardingProgress(progress: viewModel.currentStep.progress)

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("What's your email?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("We'll send you a verification code")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "A1A1AA"))
                    }
                    .padding(.top, 40)

                    // Email Input
                    VStack(spacing: 16) {
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
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }

            // Continue Button
            VStack(spacing: 16) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color(hex: "EF4444"))
                }

                PrimaryButton(
                    title: "Continue",
                    action: {
                        Task {
                            await viewModel.sendVerificationCode()
                        }
                    },
                    isLoading: viewModel.isLoading,
                    isDisabled: !viewModel.isEmailValid
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(hex: "0F0F0F"))
        .navigationBarBackButtonHidden()
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
}
