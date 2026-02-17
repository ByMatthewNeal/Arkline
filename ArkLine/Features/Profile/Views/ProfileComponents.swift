import SwiftUI
import Kingfisher

// MARK: - Profile Header
struct ProfileHeader: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: ProfileViewModel
    var onEditTap: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            // Avatar with edit button
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.2))
                        .frame(width: 100, height: 100)

                    if let user = viewModel.user,
                       user.usePhotoAvatar,
                       let avatarUrl = user.avatarUrl,
                       let url = URL(string: avatarUrl) {
                        KFImage(url)
                            .resizable()
                            .placeholder {
                                Text(viewModel.initials)
                                    .font(AppFonts.title30)
                                    .foregroundColor(AppColors.accent)
                            }
                            .fade(duration: 0.2)
                            .scaledToFill()
                            .frame(width: 96, height: 96)
                            .clipShape(Circle())
                    } else {
                        Text(viewModel.initials)
                            .font(AppFonts.title30)
                            .foregroundColor(AppColors.accent)
                    }
                }

                // Edit button
                Button(action: onEditTap) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(AppColors.accent)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColors.background(colorScheme), lineWidth: 2)
                        )
                }
                .offset(x: 4, y: 4)
            }

            // Name & Username
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Text(viewModel.displayName)
                        .font(AppFonts.title24)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    if appState.isPro {
                        Text("PRO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "F59E0B"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "F59E0B").opacity(0.15))
                            .cornerRadius(ArkSpacing.Radius.xs)
                    }
                }

                if let username = viewModel.user?.username {
                    Text("@\(username)")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Member Since
            Text("Member since \(viewModel.memberSince)")
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            // Social Links
            if let social = viewModel.user?.socialLinks {
                HStack(spacing: 16) {
                    if let twitter = social.twitter {
                        SocialLinkButton(platform: "twitter", username: twitter)
                    }
                    if let linkedin = social.linkedin {
                        SocialLinkButton(platform: "linkedin", username: linkedin)
                    }
                    if let telegram = social.telegram {
                        SocialLinkButton(platform: "telegram", username: telegram)
                    }
                }
            }
        }
    }
}

// MARK: - Social Link Button
struct SocialLinkButton: View {
    let platform: String
    let username: String

    var icon: String {
        switch platform {
        case "twitter": return "at"
        case "linkedin": return "link"
        case "telegram": return "paperplane"
        default: return "globe"
        }
    }

    var body: some View {
        Button(action: openLink) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppColors.accent)
                .frame(width: 44, height: 44)
                .background(AppColors.accent.opacity(0.1))
                .clipShape(Circle())
        }
    }

    private func openLink() {
        var urlString = ""
        switch platform {
        case "twitter":
            urlString = "https://twitter.com/\(username)"
        case "linkedin":
            urlString = "https://linkedin.com/in/\(username)"
        case "telegram":
            urlString = "https://t.me/\(username)"
        default:
            urlString = username
        }

        #if canImport(UIKit)
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

// MARK: - Quick Actions
struct ProfileQuickActions: View {
    @Environment(\.colorScheme) var colorScheme
    let onReferral: () -> Void
    let onPortfolio: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            ProfileQuickActionButton(
                icon: "person.badge.plus",
                title: "Refer Friends",
                color: AppColors.success,
                action: onReferral
            )

            ProfileQuickActionButton(
                icon: "chart.pie",
                title: "My Portfolio",
                color: AppColors.accent,
                action: onPortfolio
            )
        }
    }
}

struct ProfileQuickActionButton: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(title)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassCard(cornerRadius: 12)
        }
    }
}

// MARK: - Admin Quick Actions
struct AdminQuickActions: View {
    @Environment(\.colorScheme) var colorScheme
    let onFeatureBacklog: () -> Void
    let onInviteCodes: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ArkSpacing.sm) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.warning)
                Text("Admin")
                    .font(ArkFonts.caption)
                    .foregroundColor(AppColors.warning)
            }

            HStack(spacing: 12) {
                ProfileQuickActionButton(
                    icon: "lightbulb.fill",
                    title: "Feature Backlog",
                    color: AppColors.warning,
                    action: onFeatureBacklog
                )
                ProfileQuickActionButton(
                    icon: "ticket.fill",
                    title: "Invite Codes",
                    color: AppColors.accent,
                    action: onInviteCodes
                )
            }
        }
    }
}

// MARK: - Profile Stats
struct ProfileStats: View {
    @Environment(\.colorScheme) var colorScheme
    let stats: ProfileStatsData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            HStack(spacing: 12) {
                ProfileStatItem(value: "\(stats.dcaReminders)", label: "DCA Reminders")
                ProfileStatItem(value: "\(stats.chatSessions)", label: "Chat Sessions")
                ProfileStatItem(value: "\(stats.portfolios)", label: "Portfolios")
            }
        }
    }
}

struct ProfileStatItem: View {
    @Environment(\.colorScheme) var colorScheme
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppFonts.number24)
                .foregroundColor(AppColors.accent)

            Text(label)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Recent Activity
struct ProfileRecentActivity: View {
    @Environment(\.colorScheme) var colorScheme
    let activities: [ActivityItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(AppFonts.title18SemiBold)
                .foregroundColor(AppColors.textPrimary(colorScheme))

            if activities.isEmpty {
                Text("No recent activity")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(activities) { activity in
                        ActivityRow(
                            icon: activity.icon,
                            iconColor: activity.iconColor,
                            title: activity.title,
                            subtitle: activity.formattedTime
                        )
                    }
                }
            }
        }
    }
}

struct ActivityRow: View {
    @Environment(\.colorScheme) var colorScheme
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text(subtitle)
                    .font(AppFonts.caption12)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Refer Friend View
struct ReferFriendView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: "gift.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.accent)

                // Title
                VStack(spacing: 8) {
                    Text("Invite Friends")
                        .font(AppFonts.title30)
                        .foregroundColor(AppColors.textPrimary(colorScheme))

                    Text("Share your referral code and earn rewards together!")
                        .font(AppFonts.body14)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Referral Code
                VStack(spacing: 12) {
                    Text("Your Code")
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)

                    HStack {
                        Text(viewModel.referralCode)
                            .font(AppFonts.number24)
                            .foregroundColor(AppColors.textPrimary(colorScheme))

                        Button(action: { viewModel.copyReferralCode() }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(AppColors.accent)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .glassCard(cornerRadius: 12)
                }

                // Stats
                HStack(spacing: 32) {
                    VStack {
                        Text("\(viewModel.referralCount)")
                            .font(AppFonts.number24)
                            .foregroundColor(AppColors.accent)
                        Text("Friends Invited")
                            .font(AppFonts.caption12)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()

                // Share Button
                Button(action: { viewModel.shareReferral() }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Referral Link")
                    }
                    .font(AppFonts.body14Bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppColors.accent)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Refer Friends")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            #endif
        }
    }
}

// MARK: - Portfolio Sheet View
struct PortfolioSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.accent)

                Text("My Portfolio")
                    .font(AppFonts.title24)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Track your crypto holdings and performance in one place.")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                Button {
                    dismiss()
                    // Navigate to Portfolio tab
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appState.selectedTab = .portfolio
                    }
                } label: {
                    Text("View Portfolio")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Portfolio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            #endif
        }
    }
}
