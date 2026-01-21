import SwiftUI

// MARK: - Create Passcode View
struct CreatePasscodeView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    /// Whether the Continue button should be shown (at 4 or 5 digits)
    private var showContinueButton: Bool {
        viewModel.passcode.count >= 4 && viewModel.passcode.count < 6
    }

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            VStack(spacing: ArkSpacing.xxl) {
                // Header
                OnboardingHeader(
                    icon: "lock.circle.fill",
                    title: "Create a passcode",
                    subtitle: "Enter 4 or 6 digits"
                )

                // Passcode keypad
                PasscodeKeypad(
                    code: $viewModel.passcode,
                    length: 6,
                    title: "",
                    onComplete: { _ in
                        viewModel.createPasscode()
                    }
                )

                // Continue button (shown at 4-5 digits)
                if showContinueButton {
                    PrimaryButton(
                        title: "Continue with \(viewModel.passcode.count) digits",
                        action: {
                            viewModel.createPasscode()
                        }
                    )
                    .padding(.horizontal, ArkSpacing.xl)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.error)
                        .transition(.opacity)
                }

                Spacer()
            }
            .animation(.easeInOut(duration: 0.2), value: showContinueButton)
        }
        .onboardingBackButton { viewModel.previousStep() }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        CreatePasscodeView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
