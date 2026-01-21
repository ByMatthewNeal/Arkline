import SwiftUI

// MARK: - Confirm Passcode View
struct ConfirmPasscodeView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            VStack(spacing: ArkSpacing.xxl) {
                // Header
                OnboardingHeader(
                    icon: "lock.circle.fill",
                    title: "Confirm your passcode",
                    subtitle: "Re-enter your \(viewModel.passcodeLength)-digit passcode"
                )

                // Passcode keypad (length matches created passcode)
                PasscodeKeypad(
                    code: $viewModel.confirmPasscode,
                    length: viewModel.passcodeLength,
                    title: "",
                    onComplete: { _ in
                        viewModel.confirmPasscodeEntry()
                    }
                )

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.error)
                        .transition(.opacity)
                }

                Spacer()
            }
        }
        .onboardingBackButton { viewModel.previousStep() }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ConfirmPasscodeView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
