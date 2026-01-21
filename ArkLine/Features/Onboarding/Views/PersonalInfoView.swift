import SwiftUI

// MARK: - Personal Info View
struct PersonalInfoView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            ScrollView {
                VStack(spacing: ArkSpacing.xxl) {
                    // Header
                    OnboardingHeader(
                        icon: "person.circle.fill",
                        title: "What's your name?"
                    )

                    // Form fields
                    VStack(spacing: ArkSpacing.md) {
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

                        // Date of birth
                        VStack(alignment: .leading, spacing: ArkSpacing.xs) {
                            Text("Date of Birth")
                                .font(AppFonts.body14Medium)
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
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(AppColors.fillPrimary)
                            }
                            .padding(.horizontal, ArkSpacing.md)
                            .padding(.vertical, ArkSpacing.sm)
                            .background(AppColors.cardBackground(colorScheme))
                            .cornerRadius(ArkSpacing.Radius.input)

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
                primaryAction: { viewModel.savePersonalInfo() },
                isDisabled: !viewModel.isPersonalInfoValid
            )
        }
        .onboardingBackButton { viewModel.previousStep() }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        PersonalInfoView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
