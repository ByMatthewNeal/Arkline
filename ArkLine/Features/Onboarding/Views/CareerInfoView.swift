import SwiftUI

// MARK: - Career Info View
struct CareerInfoView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            ScrollView {
                VStack(spacing: ArkSpacing.xxl) {
                    // Header
                    OnboardingHeader(
                        icon: "chart.bar.xaxis",
                        title: "Your investing experience?",
                        isOptional: true
                    )

                    // Experience level options
                    VStack(spacing: ArkSpacing.sm) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            ExperienceLevelCard(
                                level: level,
                                isSelected: viewModel.experienceLevel == level,
                                colorScheme: colorScheme
                            ) {
                                viewModel.experienceLevel = level
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
                primaryAction: { viewModel.saveCareerInfo() },
                showSkip: true,
                skipAction: { viewModel.skipStep() }
            )
        }
        .onboardingBackButton { viewModel.previousStep() }
    }
}

// MARK: - Experience Level Card
struct ExperienceLevelCard: View {
    let level: ExperienceLevel
    let isSelected: Bool
    let colorScheme: ColorScheme
    let action: () -> Void

    private var description: String {
        switch level {
        case .beginner: return "New to investing"
        case .intermediate: return "1-3 years of experience"
        case .advanced: return "3-5 years of experience"
        case .expert: return "5+ years of experience"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: ArkSpacing.xxs) {
                    Text(level.displayName)
                        .font(AppFonts.title16)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text(description)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(AppColors.fillPrimary)
                }
            }
            .padding(ArkSpacing.md)
            .background(
                isSelected
                    ? AppColors.fillPrimary.opacity(0.1)
                    : AppColors.cardBackground(colorScheme)
            )
            .cornerRadius(ArkSpacing.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: ArkSpacing.Radius.md)
                    .stroke(
                        isSelected ? AppColors.fillPrimary : Color.clear,
                        lineWidth: ArkSpacing.Border.medium
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        CareerInfoView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
