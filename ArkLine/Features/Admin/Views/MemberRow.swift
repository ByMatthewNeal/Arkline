import SwiftUI

struct MemberRow: View {
    let member: AdminMember
    @Environment(\.colorScheme) var colorScheme

    // Badge reflects the date-aware effective status (see AdminMember.effectiveStatus),
    // so a lapsed trial reads "Expired" instead of a stale "Active"/"Trial".
    private var statusColor: Color {
        color(for: member.effectiveStatus.colorName)
    }

    private var statusLabel: String {
        member.effectiveStatus.label
    }

    private func color(for token: String) -> Color {
        switch token {
        case "success": return AppColors.success
        case "info": return AppColors.info
        case "warning": return AppColors.warning
        case "error": return AppColors.error
        case "textSecondary": return AppColors.textSecondary
        default: return AppColors.textTertiary
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
