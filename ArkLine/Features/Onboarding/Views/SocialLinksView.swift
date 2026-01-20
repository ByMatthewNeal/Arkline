import SwiftUI

struct SocialLinksView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgress(progress: viewModel.currentStep.progress)

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "8B5CF6")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Add social links")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Optional - connect with the community")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "A1A1AA"))
                    }
                    .padding(.top, 40)

                    VStack(spacing: 16) {
                        #if canImport(UIKit)
                        CustomTextField(
                            placeholder: "Twitter handle",
                            text: $viewModel.twitterHandle,
                            icon: "at",
                            autocapitalization: .never
                        )

                        CustomTextField(
                            placeholder: "LinkedIn URL",
                            text: $viewModel.linkedinUrl,
                            icon: "link",
                            keyboardType: .URL,
                            autocapitalization: .never
                        )

                        CustomTextField(
                            placeholder: "Telegram username",
                            text: $viewModel.telegramHandle,
                            icon: "paperplane.fill",
                            autocapitalization: .never
                        )

                        CustomTextField(
                            placeholder: "Website URL",
                            text: $viewModel.websiteUrl,
                            icon: "globe",
                            keyboardType: .URL,
                            autocapitalization: .never
                        )
                        #else
                        CustomTextField(
                            placeholder: "Twitter handle",
                            text: $viewModel.twitterHandle,
                            icon: "at"
                        )

                        CustomTextField(
                            placeholder: "LinkedIn URL",
                            text: $viewModel.linkedinUrl,
                            icon: "link"
                        )

                        CustomTextField(
                            placeholder: "Telegram username",
                            text: $viewModel.telegramHandle,
                            icon: "paperplane.fill"
                        )

                        CustomTextField(
                            placeholder: "Website URL",
                            text: $viewModel.websiteUrl,
                            icon: "globe"
                        )
                        #endif
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }

            VStack(spacing: 12) {
                PrimaryButton(
                    title: "Continue",
                    action: { viewModel.saveSocialLinks() }
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

#Preview {
    NavigationStack {
        SocialLinksView(viewModel: OnboardingViewModel())
    }
}
