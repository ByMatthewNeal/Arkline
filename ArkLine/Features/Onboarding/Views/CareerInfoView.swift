import SwiftUI

struct CareerInfoView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(progress: viewModel.currentStep.progress)

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Your investing experience?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)

                    VStack(spacing: 12) {
                        ForEach(ExperienceLevel.allCases, id: \.self) { level in
                            ExperienceLevelButton(
                                level: level,
                                isSelected: viewModel.experienceLevel == level
                            ) {
                                viewModel.experienceLevel = level
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }

            VStack(spacing: 12) {
                PrimaryButton(
                    title: "Continue",
                    action: { viewModel.saveCareerInfo() }
                )

                Button(action: { viewModel.skipStep() }) {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "A1A1AA"))
                }
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

struct ExperienceLevelButton: View {
    let level: ExperienceLevel
    let isSelected: Bool
    let action: () -> Void

    var description: String {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(Color(hex: "A1A1AA"))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "6366F1"))
                }
            }
            .padding(16)
            .background(isSelected ? Color(hex: "6366F1").opacity(0.1) : Color(hex: "1F1F1F"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "6366F1") : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    NavigationStack {
        CareerInfoView(viewModel: OnboardingViewModel())
    }
}
