import SwiftUI

// MARK: - Social Links View
struct SocialLinksView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            ScrollView {
                VStack(spacing: ArkSpacing.xxl) {
                    // Header
                    OnboardingHeader(
                        icon: "link.circle.fill",
                        title: "Add social links",
                        subtitle: "Connect with the community",
                        isOptional: true
                    )

                    // Social link inputs
                    VStack(spacing: ArkSpacing.md) {
                        #if canImport(UIKit)
                        SocialLinkField(
                            placeholder: "Twitter / X handle",
                            text: $viewModel.twitterHandle,
                            icon: "at"
                        )

                        SocialLinkField(
                            placeholder: "LinkedIn URL",
                            text: $viewModel.linkedinUrl,
                            icon: "link",
                            keyboardType: .URL
                        )

                        SocialLinkField(
                            placeholder: "Telegram username",
                            text: $viewModel.telegramHandle,
                            icon: "paperplane.fill"
                        )

                        SocialLinkField(
                            placeholder: "Website URL",
                            text: $viewModel.websiteUrl,
                            icon: "globe",
                            keyboardType: .URL
                        )
                        #else
                        CustomTextField(
                            placeholder: "Twitter / X handle",
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
                    .padding(.horizontal, ArkSpacing.xl)

                    Spacer(minLength: ArkSpacing.xxxl)
                }
            }

            // Bottom actions
            OnboardingBottomActions(
                primaryTitle: "Continue",
                primaryAction: { viewModel.saveSocialLinks() },
                showSkip: true,
                skipAction: { viewModel.skipStep() }
            )
        }
        .onboardingBackButton { viewModel.previousStep() }
    }
}

// MARK: - Social Link Field (iOS specific)
#if canImport(UIKit)
struct SocialLinkField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        CustomTextField(
            placeholder: placeholder,
            text: $text,
            icon: icon,
            keyboardType: keyboardType,
            autocapitalization: .never
        )
    }
}
#endif

// MARK: - Preview
#Preview {
    NavigationStack {
        SocialLinksView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
