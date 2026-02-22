import SwiftUI

struct AdminDashboardView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appState: AppState

    private var isDarkMode: Bool {
        appState.darkModePreference == .dark ||
        (appState.darkModePreference == .automatic && colorScheme == .dark)
    }

    var body: some View {
        ZStack {
            MeshGradientBackground()

            List {
                // Quick Actions
                Section {
                    NavigationLink(destination: SendInviteView()) {
                        AdminDashboardRow(
                            icon: "paperplane.fill",
                            iconColor: AppColors.success,
                            title: "Send Invite",
                            subtitle: "Payment or comped invite"
                        )
                    }

                    NavigationLink(destination: AdminQuickShareView()) {
                        AdminDashboardRow(
                            icon: "qrcode",
                            iconColor: AppColors.accent,
                            title: "Quick Share",
                            subtitle: "Share payment link & QR code"
                        )
                    }
                } header: {
                    Text("Quick Actions")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Management
                Section {
                    NavigationLink(destination: InviteCodeManagementView()) {
                        AdminDashboardRow(
                            icon: "ticket.fill",
                            iconColor: AppColors.accent,
                            title: "Invite Codes",
                            subtitle: "Generate & manage codes"
                        )
                    }

                    NavigationLink(destination: FeatureBacklogView()) {
                        AdminDashboardRow(
                            icon: "lightbulb.fill",
                            iconColor: AppColors.warning,
                            title: "Feature Backlog",
                            subtitle: "Review feature requests"
                        )
                    }

                    NavigationLink(destination: MemberManagementView()) {
                        AdminDashboardRow(
                            icon: "person.2.fill",
                            iconColor: AppColors.info,
                            title: "Members",
                            subtitle: "View & manage members"
                        )
                    }

                    NavigationLink(destination: RevenueDashboardView()) {
                        AdminDashboardRow(
                            icon: "chart.bar.fill",
                            iconColor: AppColors.success,
                            title: "Revenue",
                            subtitle: "MRR, ARR & metrics"
                        )
                    }
                } header: {
                    Text("Management")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))

                // Coming Soon
                Section {
                    AdminDashboardRow(
                        icon: "person.badge.plus",
                        iconColor: AppColors.textTertiary,
                        title: "Leads",
                        subtitle: "Coming soon"
                    )
                    .opacity(0.5)

                    AdminDashboardRow(
                        icon: "bell.fill",
                        iconColor: AppColors.textTertiary,
                        title: "Notifications",
                        subtitle: "Coming soon"
                    )
                    .opacity(0.5)
                } header: {
                    Text("Coming Soon")
                }
                .listRowBackground(AppColors.cardBackground(colorScheme))
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Admin Panel")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }
}

// MARK: - Dashboard Row

struct AdminDashboardRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var subtitle: String? = nil
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: ArkSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.body14Medium)
                    .foregroundColor(AppColors.textPrimary(colorScheme))

                if let subtitle {
                    Text(subtitle)
                        .font(AppFonts.caption12)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding(.vertical, ArkSpacing.xxs)
    }
}

#Preview {
    NavigationStack {
        AdminDashboardView()
            .environmentObject(AppState())
    }
}
