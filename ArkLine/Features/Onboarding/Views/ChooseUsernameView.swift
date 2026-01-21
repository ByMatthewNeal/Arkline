import SwiftUI

// MARK: - Choose Username View (Now Name Entry View)
struct ChooseUsernameView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            ScrollView {
                VStack(spacing: ArkSpacing.xxl) {
                    // Header
                    OnboardingHeader(
                        icon: "person.circle.fill",
                        title: "What's your name?",
                        subtitle: "First name is required"
                    )

                    // Name Input Fields
                    VStack(spacing: ArkSpacing.md) {
                        // First Name (Required)
                        #if canImport(UIKit)
                        CustomTextField(
                            placeholder: "First Name",
                            text: $viewModel.firstName,
                            icon: "person.fill",
                            textContentType: .givenName,
                            errorMessage: viewModel.errorMessage
                        )
                        #else
                        CustomTextField(
                            placeholder: "First Name",
                            text: $viewModel.firstName,
                            icon: "person.fill",
                            errorMessage: viewModel.errorMessage
                        )
                        #endif

                        // Last Name (Optional)
                        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                            #if canImport(UIKit)
                            CustomTextField(
                                placeholder: "Last Name",
                                text: $viewModel.lastName,
                                icon: "person",
                                textContentType: .familyName
                            )
                            #else
                            CustomTextField(
                                placeholder: "Last Name",
                                text: $viewModel.lastName,
                                icon: "person"
                            )
                            #endif

                            Text("Optional")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        }

                        // Date of Birth - styled to match text fields
                        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                            Text("Date of Birth")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary)

                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 18))
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(width: 24)

                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: { viewModel.dateOfBirth ?? Date() },
                                        set: { viewModel.dateOfBirth = $0 }
                                    ),
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(colorScheme == .dark ? Color(hex: "1F1F1F") : Color(hex: "F5F5F5"))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(colorScheme == .dark ? Color.clear : Color(hex: "E2E8F0"), lineWidth: 1.5)
                            )

                            Text("Optional")
                                .font(AppFonts.caption12)
                                .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, ArkSpacing.xl)

                    Spacer(minLength: ArkSpacing.xxxl)
                }
            }

            // Bottom actions
            OnboardingBottomActions(
                primaryTitle: "Continue",
                primaryAction: {
                    viewModel.saveName()
                },
                isLoading: viewModel.isLoading,
                isDisabled: !viewModel.isNameValid
            )
        }
        .onboardingBackButton { viewModel.previousStep() }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ChooseUsernameView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
