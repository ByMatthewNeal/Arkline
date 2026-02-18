import SwiftUI

struct MemberRow: View {
    let member: AdminMember
    @Environment(\.colorScheme) var colorScheme

    private var statusColor: Color {
        switch member.subscriptionStatus {
        case "active": return AppColors.success
        case "trialing": return AppColors.info
        case "past_due": return AppColors.warning
        case "canceled": return AppColors.error
        case "paused": return AppColors.textSecondary
        default: return AppColors.textTertiary
        }
    }

    private var statusLabel: String {
        switch member.subscriptionStatus {
        case "active": return "Active"
        case "trialing": return "Trial"
        case "past_due": return "Past Due"
        case "canceled": return "Canceled"
        case "paused": return "Paused"
        case "none": return "No Sub"
        default: return member.subscriptionStatus.capitalized
        }
    }

    var body: some View {
        HStack(spacing: ArkSpacing.sm) {
            // Avatar
            Text(member.initials)
                .font(AppFonts.caption12Medium)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(AppColors.accent.opacity(0.8))
                .clipShape(Circle())

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: ArkSpacing.xxs) {
                    Text(member.displayName)
                        .font(AppFonts.body14Medium)
                        .foregroundColor(AppColors.textPrimary(colorScheme))
                        .lineLimit(1)

                    if !member.isActive {
                        Text("INACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AppColors.error.opacity(0.15))
                            .cornerRadius(3)
                    }
                }

                Text(member.email)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Status + Plan badges
            VStack(alignment: .trailing, spacing: 4) {
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.12))
                    .cornerRadius(ArkSpacing.Radius.xs)

                if let plan = member.subscription?.plan {
                    Text(plan.capitalized)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(.vertical, ArkSpacing.xxs)
    }
}
