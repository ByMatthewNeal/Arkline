import SwiftUI

struct InvestmentInterestsView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) var colorScheme

    private var textPrimary: Color { AppColors.textPrimary(colorScheme) }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 32) {
            // Icon
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.accent)
            }

            // Title
            VStack(spacing: 8) {
                Text("What do you invest in?")
                    .font(.title2.bold())
                    .foregroundColor(textPrimary)
                    .multilineTextAlignment(.center)

                Text("Select all that apply. This helps us personalize your experience.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            // Interest grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(InvestmentInterest.allCases) { interest in
                    let isSelected = viewModel.investmentInterests.contains(interest)

                    Button {
                        Haptics.selection()
                        if isSelected {
                            viewModel.investmentInterests.remove(interest)
                        } else {
                            viewModel.investmentInterests.insert(interest)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: interest.icon)
                                .font(.system(size: 18))
                                .foregroundColor(isSelected ? .white : AppColors.accent)

                            Text(interest.rawValue)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(isSelected ? .white : textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? AppColors.accent : AppColors.accent.opacity(colorScheme == .dark ? 0.08 : 0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? AppColors.accent : AppColors.textSecondary.opacity(0.15), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Continue button
            VStack(spacing: 12) {
                Button(action: { viewModel.saveInvestmentInterests() }) {
                    Text(viewModel.investmentInterests.isEmpty ? "Skip for now" : "Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.accent)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 20)
        }
        .padding(.top, 20)
    }
}
