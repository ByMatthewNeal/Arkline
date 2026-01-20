import SwiftUI

// MARK: - Verification Code View
struct VerificationCodeView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(progress: viewModel.currentStep.progress)

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "number.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Enter verification code")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("We sent a code to \(viewModel.email)")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "A1A1AA"))
                    }
                    .padding(.top, 40)

                    // Code Input
                    PasscodeKeypad(
                        code: $viewModel.verificationCode,
                        length: 6,
                        title: ""
                    )
                    .padding(.horizontal, 24)

                    // Resend
                    Button(action: {
                        Task {
                            await viewModel.sendVerificationCode()
                        }
                    }) {
                        Text("Didn't receive code? Resend")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "6366F1"))
                    }

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
                    title: "Verify",
                    action: {
                        Task {
                            await viewModel.verifyCode()
                        }
                    },
                    isLoading: viewModel.isLoading,
                    isDisabled: !viewModel.isVerificationCodeValid
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color(hex: "0F0F0F"))
        .navigationBarBackButtonHidden()
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { viewModel.previousStep() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
            }
        }
        #endif
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        VerificationCodeView(viewModel: OnboardingViewModel())
    }
}
