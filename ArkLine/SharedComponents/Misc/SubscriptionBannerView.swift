import SwiftUI

// MARK: - Subscription Banner View

/// Shows contextual banners based on the user's subscription status.
/// - past_due: Yellow warning to update payment
/// - canceled: Red alert that subscription ended
/// - trialing (< 7 days): Blue notice about trial ending
struct SubscriptionBannerView: View {
    let status: SubscriptionStatus
    let trialDaysRemaining: Int?

    @Environment(\.colorScheme) private var colorScheme

    init(status: SubscriptionStatus, trialDaysRemaining: Int? = nil) {
        self.status = status
        self.trialDaysRemaining = trialDaysRemaining
    }

    var body: some View {
        if let config = bannerConfig {
            HStack(spacing: ArkSpacing.sm) {
                Image(systemName: config.icon)
                    .font(.system(size: 14, weight: .semibold))

                Text(config.message)
                    .font(AppFonts.caption12Medium)
                    .lineLimit(2)

                Spacer()
            }
            .foregroundColor(config.textColor)
            .padding(.horizontal, ArkSpacing.md)
            .padding(.vertical, ArkSpacing.sm)
            .background(config.backgroundColor)
            .cornerRadius(ArkSpacing.sm)
        }
    }

    // MARK: - Banner Config

    private struct BannerConfig {
        let icon: String
        let message: String
        let textColor: Color
        let backgroundColor: Color
    }

    private var bannerConfig: BannerConfig? {
        switch status {
        case .pastDue:
            return BannerConfig(
                icon: "exclamationmark.triangle.fill",
                message: "Payment issue — update your payment method to keep access.",
                textColor: .black.opacity(0.85),
                backgroundColor: AppColors.warning.opacity(0.2)
            )
        case .canceled:
            return BannerConfig(
                icon: "xmark.circle.fill",
                message: "Your subscription has ended. Renew to regain full access.",
                textColor: .white.opacity(0.95),
                backgroundColor: AppColors.error.opacity(0.85)
            )
        case .trialing:
            if let days = trialDaysRemaining, days <= 7 {
                return BannerConfig(
                    icon: "clock.fill",
                    message: days <= 1
                        ? "Your trial ends today."
                        : "Your trial ends in \(days) days.",
                    textColor: colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8),
                    backgroundColor: AppColors.accent.opacity(0.15)
                )
            }
            return nil
        case .active, .none:
            return nil
        }
    }
}
