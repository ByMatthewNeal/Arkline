import SwiftUI

struct PersonalInfoView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(progress: viewModel.currentStep.progress)

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("What's your name?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 16) {
                        #if canImport(UIKit)
                        CustomTextField(
                            placeholder: "Full Name",
                            text: $viewModel.fullName,
                            icon: "person.fill",
                            textContentType: .name
                        )
                        #else
                        CustomTextField(
                            placeholder: "Full Name",
                            text: $viewModel.fullName,
                            icon: "person.fill"
                        )
                        #endif

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date of Birth (Optional)")
                                .font(.subheadline)
                                .foregroundColor(Color(hex: "A1A1AA"))

                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { viewModel.dateOfBirth ?? Date() },
                                    set: { viewModel.dateOfBirth = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(Color(hex: "6366F1"))
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }

            VStack(spacing: 16) {
                PrimaryButton(
                    title: "Continue",
                    action: { viewModel.savePersonalInfo() },
                    isDisabled: !viewModel.isPersonalInfoValid
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
        PersonalInfoView(viewModel: OnboardingViewModel())
    }
}
