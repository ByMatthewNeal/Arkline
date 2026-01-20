import SwiftUI

struct CreatePasscodeView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(progress: viewModel.currentStep.progress)

            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Create a passcode")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Used to secure your app")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "A1A1AA"))
                }
                .padding(.top, 40)

                PasscodeKeypad(
                    code: $viewModel.passcode,
                    length: 6,
                    title: "",
                    onComplete: { _ in
                        viewModel.createPasscode()
                    }
                )

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Color(hex: "EF4444"))
                }

                Spacer()
            }
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

#Preview {
    NavigationStack {
        CreatePasscodeView(viewModel: OnboardingViewModel())
    }
}
