import SwiftUI

struct ProfileView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState
    @State private var viewModel = ProfileViewModel()
    @State private var showReferral = false
    @State private var showPortfolio = false
    @State private var showAlerts = false
    @State private var showEditProfile = false

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background with subtle blue glow
                MeshGradientBackground()

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                    // Profile Header
                    ProfileHeader(viewModel: viewModel, onEditTap: { showEditProfile = true })

                    // Quick Actions
                    ProfileQuickActions(
                        onReferral: { showReferral = true },
                        onPortfolio: { showPortfolio = true },
                        onAlerts: { showAlerts = true }
                    )
                    .padding(.horizontal, 20)

                    // Stats
                    ProfileStats(stats: viewModel.stats)
                        .padding(.horizontal, 20)

                    // Recent Activity
                    ProfileRecentActivity(activities: viewModel.recentActivity)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .foregroundColor(AppColors.accent)
                    }
                }
            }
            #endif
            .sheet(isPresented: $showReferral) {
                ReferFriendView(viewModel: viewModel)
            }
            .sheet(isPresented: $showPortfolio) {
                PortfolioSheetView()
            }
            .sheet(isPresented: $showAlerts) {
                AlertsSheetView()
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView(user: viewModel.user) { updatedUser in
                    viewModel.user = updatedUser
                    appState.setAuthenticated(true, user: updatedUser)
                }
            }
            .onAppear {
                // Use the actual user from AppState if available
                if let currentUser = appState.currentUser {
                    viewModel.user = currentUser
                }
            }
        }
    }
}

// MARK: - Profile Header
struct ProfileHeader: View {
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

                    if let avatarUrl = viewModel.user?.avatarUrl,
                       let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Text(viewModel.initials)
                                .font(AppFonts.title30)
                                .foregroundColor(AppColors.accent)
                        }
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
    let onAlerts: () -> Void

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

            ProfileQuickActionButton(
                icon: "bell",
                title: "Alerts",
                color: AppColors.warning,
                action: onAlerts
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

// MARK: - Alerts Sheet View
struct AlertsSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.warning)

                Text("Price Alerts")
                    .font(AppFonts.title24)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                Text("Set up alerts to get notified when prices hit your targets.")
                    .font(AppFonts.body14)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Coming Soon Badge
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                    Text("Coming Soon")
                        .font(AppFonts.body14Medium)
                }
                .foregroundColor(AppColors.warning)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AppColors.warning.opacity(0.15))
                .cornerRadius(20)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Got It")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.warning)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Alerts")
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

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    let user: User?
    let onSave: (User) -> Void

    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var email: String = ""

    init(user: User?, onSave: @escaping (User) -> Void) {
        self.user = user
        self.onSave = onSave
        _fullName = State(initialValue: user?.fullName ?? "")
        _username = State(initialValue: user?.username ?? "")
        _email = State(initialValue: user?.email ?? "")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.2))
                        .frame(width: 100, height: 100)

                    Text(initials)
                        .font(AppFonts.title30)
                        .foregroundColor(AppColors.accent)
                }
                .padding(.top, 20)

                // Form fields
                VStack(spacing: 16) {
                    EditProfileField(
                        label: "Full Name",
                        text: $fullName,
                        placeholder: "Enter your name"
                    )

                    EditProfileField(
                        label: "Username",
                        text: $username,
                        placeholder: "Enter username"
                    )

                    EditProfileField(
                        label: "Email",
                        text: $email,
                        placeholder: "Enter email",
                        keyboardType: .emailAddress
                    )
                    .disabled(true)
                    .opacity(0.6)
                }
                .padding(.horizontal, 20)

                Spacer()

                // Save button
                Button(action: saveProfile) {
                    Text("Save Changes")
                        .font(AppFonts.body14Bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppColors.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(fullName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .background(AppColors.background(colorScheme))
            .navigationTitle("Edit Profile")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            #endif
        }
    }

    private var initials: String {
        let name = fullName.isEmpty ? (user?.username ?? "U") : fullName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func saveProfile() {
        guard var updatedUser = user else { return }
        updatedUser.fullName = fullName.trimmingCharacters(in: .whitespaces)
        updatedUser.username = username.trimmingCharacters(in: .whitespaces)
        onSave(updatedUser)
        dismiss()
    }
}

// MARK: - Edit Profile Field
struct EditProfileField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppFonts.caption12)
                .foregroundColor(AppColors.textSecondary)

            TextField(placeholder, text: $text)
                .font(AppFonts.body14)
                .foregroundColor(AppColors.textPrimary(colorScheme))
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color(hex: "1F1F1F") : Color(hex: "F5F5F7"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.divider(colorScheme), lineWidth: 1)
                )
                #if os(iOS)
                .keyboardType(keyboardType)
                .autocapitalization(keyboardType == .emailAddress ? .none : .words)
                #endif
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
