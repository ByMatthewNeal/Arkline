import SwiftUI

struct CryptoApproachView: View {
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
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.accent)
            }

            // Title
            VStack(spacing: 8) {
                Text("How do you approach crypto?")
                    .font(.title2.bold())
                    .foregroundColor(textPrimary)
                    .multilineTextAlignment(.center)

                Text("Pick the one that fits best right now.")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Approach cards
            VStack(spacing: 10) {
                ForEach(CryptoApproach.allCases) { approach in
                    let isSelected = viewModel.cryptoApproach == approach

                    Button {
                        Haptics.selection()
                        viewModel.cryptoApproach = approach
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: approach.icon)
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? .white : AppColors.accent)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(isSelected ? AppColors.accent.opacity(0.3) : AppColors.accent.opacity(0.1))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(approach.rawValue)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(isSelected ? .white : textPrimary)

                                Text(approach.description)
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
            Button(action: { viewModel.saveCryptoApproach() }) {
                Text(viewModel.cryptoApproach == nil ? "Skip for now" : "Continue")
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
