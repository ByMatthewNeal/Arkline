import SwiftUI

struct CareerIndustryView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(progress: viewModel.currentStep.progress)

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "briefcase.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("What industry are you in?")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Optional - helps personalize your experience")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "A1A1AA"))
                    }
                    .padding(.top, 40)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(CareerIndustry.allCases, id: \.self) { industry in
                            IndustryButton(
                                title: industry.displayName,
                                isSelected: viewModel.careerIndustry == industry
                            ) {
                                viewModel.careerIndustry = industry
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
                    action: { viewModel.saveCareerIndustry() }
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

struct IndustryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : Color(hex: "A1A1AA"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSelected ? Color(hex: "6366F1") : Color(hex: "1F1F1F"))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.clear : Color(hex: "2A2A2A"), lineWidth: 1)
                )
        }
    }
}

#Preview {
    NavigationStack {
        CareerIndustryView(viewModel: OnboardingViewModel())
    }
}
