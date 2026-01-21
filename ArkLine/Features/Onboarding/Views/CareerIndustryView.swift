import SwiftUI

// MARK: - Career Industry View
struct CareerIndustryView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            ScrollView {
                VStack(spacing: ArkSpacing.xxl) {
                    // Header
                    OnboardingHeader(
                        icon: "briefcase.circle.fill",
                        title: "What industry are you in?",
                        subtitle: "Helps personalize your experience",
                        isOptional: true
                    )

                    // Industry grid
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: ArkSpacing.sm
                    ) {
                        ForEach(CareerIndustry.allCases, id: \.self) { industry in
                            SelectableChip(
                                title: industry.displayName,
                                isSelected: viewModel.careerIndustry == industry,
                                colorScheme: colorScheme
                            ) {
                                viewModel.careerIndustry = industry
                            }
                        }
                    }
                    .padding(.horizontal, ArkSpacing.xl)

                    Spacer(minLength: ArkSpacing.xxxl)
                }
            }

            // Bottom actions
            OnboardingBottomActions(
                primaryTitle: "Continue",
                primaryAction: { viewModel.saveCareerIndustry() },
                showSkip: true,
                skipAction: { viewModel.skipStep() }
            )
        }
        .onboardingBackButton { viewModel.previousStep() }
    }
}

// MARK: - Selectable Chip
/// Reusable selection chip for grids
struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.body14Medium)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, ArkSpacing.sm)
                .background(isSelected ? AppColors.fillPrimary : AppColors.cardBackground(colorScheme))
                .cornerRadius(ArkSpacing.Radius.input)
                .overlay(
                    RoundedRectangle(cornerRadius: ArkSpacing.Radius.input)
                        .stroke(
                            isSelected ? Color.clear : AppColors.divider(colorScheme),
                            lineWidth: ArkSpacing.Border.thin
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        CareerIndustryView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
