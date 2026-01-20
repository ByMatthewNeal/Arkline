import SwiftUI

struct ChooseUsernameView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(progress: viewModel.currentStep.progress)

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "at.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Choose a username")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("This is how others will see you")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "A1A1AA"))
                    }
                    .padding(.top, 40)

                    #if canImport(UIKit)
                    CustomTextField(
                        placeholder: "Username",
                        text: $viewModel.username,
                        icon: "at",
                        autocapitalization: .never,
                        errorMessage: viewModel.errorMessage
                    )
                    .padding(.horizontal, 24)
                    #else
                    CustomTextField(
                        placeholder: "Username",
                        text: $viewModel.username,
                        icon: "at",
                        errorMessage: viewModel.errorMessage
                    )
                    .padding(.horizontal, 24)
                    #endif

                    Spacer()
                }
            }

            VStack(spacing: 16) {
                PrimaryButton(
                    title: "Continue",
                    action: {
                        Task {
                            await viewModel.validateUsername()
                        }
                    },
                    isLoading: viewModel.isLoading,
                    isDisabled: !viewModel.isUsernameValid
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

#Preview {
    NavigationStack {
        ChooseUsernameView(viewModel: OnboardingViewModel())
    }
}
