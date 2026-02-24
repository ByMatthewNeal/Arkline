import SwiftUI
import UserNotifications

// MARK: - Notification Setup View
struct NotificationSetupView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        OnboardingContainer(step: viewModel.currentStep) {
            VStack(spacing: ArkSpacing.xxl) {
                // Header with bell icon
                VStack(spacing: ArkSpacing.sm) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.fillPrimary, AppColors.accentLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.bottom, ArkSpacing.xs)

                    Text("Stay in the Loop")
                        .font(AppFonts.title30)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Get timely updates so you never miss an opportunity")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ArkSpacing.xl)
                }
                .padding(.top, ArkSpacing.xxxl)

                // Feature list
                VStack(spacing: ArkSpacing.md) {
                    BiometricFeatureRow(
                        icon: "megaphone.fill",
                        title: "Coach Updates",
                        description: "Real-time insights and broadcasts",
                        colorScheme: colorScheme
                    )

                    BiometricFeatureRow(
                        icon: "calendar.badge.clock",
                        title: "DCA Reminders",
                        description: "Never miss a scheduled investment",
                        colorScheme: colorScheme
                    )

                    BiometricFeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Market Alerts",
                        description: "Key moves and risk level changes",
                        colorScheme: colorScheme
                    )
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.top, ArkSpacing.md)

                Spacer()

                // Bottom buttons
                VStack(spacing: ArkSpacing.sm) {
                    PrimaryButton(
                        title: "Enable Notifications",
                        action: { requestNotifications() },
                        isLoading: viewModel.isLoading,
                        isDisabled: viewModel.isLoading
                    )

                    Button(action: { viewModel.skipNotifications() }) {
                        Text("Maybe Later")
                            .font(AppFonts.body14Medium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .disabled(viewModel.isLoading)
                }
                .padding(.horizontal, ArkSpacing.xl)
                .padding(.bottom, ArkSpacing.xxl)
            }
        }
        .onboardingBackButton { viewModel.previousStep() }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                viewModel.enableNotifications()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        NotificationSetupView(viewModel: OnboardingViewModel())
    }
    .preferredColorScheme(.dark)
}
