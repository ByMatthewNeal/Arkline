import SwiftUI

struct PortfolioGoalsView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    var body: some View {
        VStack(spacing: 28) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "target")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.accent)
            }

            // Title
            VStack(spacing: 8) {
                Text("What matters most to you?")
                    .font(.title2.bold())
                    .foregroundColor(textPrimary)
                    .multilineTextAlignment(.center)

                Text("We'll prioritize features based on your focus.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Goal cards
            VStack(spacing: 10) {
                ForEach(PortfolioGoal.allCases) { goal in
                    let isSelected = viewModel.portfolioGoal == goal

                    Button {
                        Haptics.selection()
                        viewModel.portfolioGoal = goal
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: goal.icon)
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? .white : AppColors.accent)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(isSelected ? AppColors.accent.opacity(0.3) : AppColors.accent.opacity(0.1))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(goal.rawValue)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : textPrimary)

                                Text(goal.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(isSelected ? .white.opacity(0.7) : AppColors.textSecondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isSelected ? AppColors.accent : (colorScheme == .dark ? Color(hex: "1F1F1F") : Color.white))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Continue
            Button(action: { viewModel.savePortfolioGoals() }) {
                Text(viewModel.portfolioGoal == nil ? "Skip for now" : "Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.accent)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .padding(.top, 20)
    }
}
